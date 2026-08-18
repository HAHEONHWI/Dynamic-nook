const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        return json({ ok: true, service: "dynamic-nook-license" });
      }
      if (request.method === "POST" && url.pathname === "/v1/activate") {
        return await activate(request, env);
      }
      if (request.method === "POST" && url.pathname === "/v1/admin/licenses") {
        return await createLicense(request, env);
      }
      const revokeMatch = url.pathname.match(/^\/v1\/admin\/licenses\/([^/]+)\/revoke$/);
      if (request.method === "POST" && revokeMatch) {
        return await revokeLicense(request, env, decodeURIComponent(revokeMatch[1]));
      }
      const resetMatch = url.pathname.match(/^\/v1\/admin\/licenses\/([^/]+)\/reset-device$/);
      if (request.method === "POST" && resetMatch) {
        return await resetDevice(request, env, decodeURIComponent(resetMatch[1]));
      }
      return errorResponse(404, "not_found", "Endpoint not found.");
    } catch (error) {
      if (error instanceof RequestError) {
        return errorResponse(error.status, error.code, error.message);
      }
      console.error("license-server-error", error instanceof Error ? error.message : "unknown");
      return errorResponse(500, "server_error", "The license server could not complete the request.");
    }
  },
};

async function activate(request, env) {
  const body = await readJSON(request);
  const licenseKey = normalizeLicenseKey(body.licenseKey);
  const deviceHash = typeof body.deviceHash === "string" ? body.deviceHash.trim() : "";
  if (!licenseKey || !deviceHash || deviceHash.length > 128) {
    return errorResponse(400, "invalid_request", "License key and device identity are required.");
  }

  const keyHash = await sha256Base64URL(licenseKey);
  let record = await env.DB.prepare(
    "SELECT * FROM licenses WHERE key_hash = ?1 LIMIT 1"
  ).bind(keyHash).first();
  const now = unixTime();
  const validationError = validateLicenseRecord(record, now, env.PRODUCT_ID);
  if (validationError) return errorResponse(validationError.status, validationError.code, validationError.message);

  if (record.kind === "standard") {
    if (!record.device_hash) {
      await env.DB.prepare(
        "UPDATE licenses SET device_hash = ?1 WHERE id = ?2 AND device_hash IS NULL"
      ).bind(deviceHash, record.id).run();
      record = await env.DB.prepare("SELECT * FROM licenses WHERE id = ?1 LIMIT 1")
        .bind(record.id).first();
    }
    if (record.device_hash !== deviceHash) {
      return errorResponse(409, "device_limit", "This key is already active on another Mac.");
    }
  }

  await env.DB.prepare("UPDATE licenses SET last_validated_at = ?1 WHERE id = ?2")
    .bind(now, record.id).run();
  const ttl = Math.max(3600, Math.min(Number(env.TOKEN_TTL_SECONDS || 604800), 2592000));
  const payload = activationPayload(record, deviceHash, now, ttl);
  const activationToken = await signActivationToken(payload, env.SIGNING_KEY_JWK);
  return json({ activationToken, validatedUntil: payload.validatedUntil });
}

async function createLicense(request, env) {
  if (!(await isAuthorizedAdmin(request, env.ADMIN_API_TOKEN))) {
    return errorResponse(401, "unauthorized", "Administrator authorization failed.");
  }
  const body = await readJSON(request);
  const licenseKey = normalizeLicenseKey(body.licenseKey);
  const kind = body.kind === "master" ? "master" : body.kind === "standard" ? "standard" : "";
  const reference = typeof body.customerReference === "string" ? body.customerReference.trim() : "";
  const expiresAt = body.expiresAt == null ? null : Number(body.expiresAt);
  if (!licenseKey || !kind || !reference || reference.length > 200 ||
      (expiresAt != null && (!Number.isSafeInteger(expiresAt) || expiresAt <= unixTime()))) {
    return errorResponse(400, "invalid_request", "License data is invalid.");
  }

  const id = crypto.randomUUID();
  const now = unixTime();
  const keyHash = await sha256Base64URL(licenseKey);
  try {
    await env.DB.prepare(
      `INSERT INTO licenses
       (id, key_hash, product, kind, tier, customer_reference, issued_at, expires_at)
       VALUES (?1, ?2, ?3, ?4, 'pro', ?5, ?6, ?7)`
    ).bind(id, keyHash, env.PRODUCT_ID, kind, reference, now, expiresAt).run();
  } catch (error) {
    if (String(error).includes("UNIQUE")) {
      return errorResponse(409, "duplicate_key", "This license key already exists.");
    }
    throw error;
  }
  return json({ id, kind, tier: "pro", expiresAt }, 201);
}

async function revokeLicense(request, env, id) {
  if (!(await isAuthorizedAdmin(request, env.ADMIN_API_TOKEN))) {
    return errorResponse(401, "unauthorized", "Administrator authorization failed.");
  }
  const result = await env.DB.prepare("UPDATE licenses SET revoked_at = ?1 WHERE id = ?2")
    .bind(unixTime(), id).run();
  return result.meta?.changes ? json({ ok: true }) : errorResponse(404, "not_found", "License not found.");
}

async function resetDevice(request, env, id) {
  if (!(await isAuthorizedAdmin(request, env.ADMIN_API_TOKEN))) {
    return errorResponse(401, "unauthorized", "Administrator authorization failed.");
  }
  const result = await env.DB.prepare("UPDATE licenses SET device_hash = NULL WHERE id = ?1 AND kind = 'standard'")
    .bind(id).run();
  return result.meta?.changes ? json({ ok: true }) : errorResponse(404, "not_found", "Standard license not found.");
}

export function validateLicenseRecord(record, now, productID = "dynamic-nook") {
  if (!record) return { status: 404, code: "invalid_key", message: "License key not found." };
  if (record.product !== productID || record.tier !== "pro") {
    return { status: 403, code: "wrong_product", message: "A Dynamic Nook Pro license is required." };
  }
  if (record.revoked_at != null) return { status: 403, code: "revoked", message: "This license was revoked." };
  if (record.expires_at != null && now > record.expires_at) {
    return { status: 403, code: "expired", message: "This license has expired." };
  }
  return null;
}

export function activationPayload(record, deviceHash, now, ttl) {
  const validatedUntil = record.expires_at == null
    ? now + ttl
    : Math.min(now + ttl, record.expires_at);
  const payload = {
    customerReference: record.customer_reference,
    deviceKeyHash: record.kind === "standard" ? deviceHash : undefined,
    expiresAt: record.expires_at == null ? undefined : record.expires_at,
    issuedAt: now,
    kind: record.kind,
    licenseID: record.id,
    product: record.product,
    tier: "pro",
    validatedUntil,
    version: 2,
  };
  return Object.fromEntries(Object.entries(payload).filter(([, value]) => value !== undefined));
}

export async function signActivationToken(payload, signingJWK) {
  const payloadBytes = new TextEncoder().encode(JSON.stringify(payload));
  const keyData = typeof signingJWK === "string" ? JSON.parse(signingJWK) : signingJWK;
  const key = await crypto.subtle.importKey("jwk", keyData, { name: "Ed25519" }, false, ["sign"]);
  const signature = await crypto.subtle.sign({ name: "Ed25519" }, key, payloadBytes);
  return `DNL1.${base64URL(payloadBytes)}.${base64URL(new Uint8Array(signature))}`;
}

export function normalizeLicenseKey(value) {
  return typeof value === "string" ? value.trim().toUpperCase().replace(/\s+/g, "") : "";
}

export async function sha256Base64URL(value) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return base64URL(new Uint8Array(digest));
}

async function isAuthorizedAdmin(request, expectedToken) {
  const header = request.headers.get("authorization") || "";
  const supplied = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!supplied || !expectedToken) return false;
  const [left, right] = await Promise.all([sha256Bytes(supplied), sha256Bytes(expectedToken)]);
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left[index] ^ right[index];
  return difference === 0;
}

async function sha256Bytes(value) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
}

async function readJSON(request) {
  const contentLength = Number(request.headers.get("content-length") || 0);
  if (contentLength > 16_384) {
    throw new RequestError(413, "request_too_large", "Request body is too large.");
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > 16_384) {
    throw new RequestError(413, "request_too_large", "Request body is too large.");
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new RequestError(400, "invalid_json", "Request body must be valid JSON.");
  }
}

class RequestError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function unixTime() {
  return Math.floor(Date.now() / 1000);
}

function base64URL(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: JSON_HEADERS });
}

function errorResponse(status, code, message) {
  return json({ error: { code, message } }, status);
}
