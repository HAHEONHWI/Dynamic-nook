import assert from "node:assert/strict";
import test from "node:test";
import {
  activationPayload,
  normalizeLicenseKey,
  sha256Base64URL,
  signActivationToken,
  validateLicenseRecord,
} from "../src/index.js";
import worker from "../src/index.js";

test("normalizes and hashes license keys deterministically", async () => {
  assert.equal(normalizeLicenseKey(" dn-pro-ab cd \n"), "DN-PRO-ABCD");
  assert.equal(await sha256Base64URL("DN-PRO-ABCD"), await sha256Base64URL("DN-PRO-ABCD"));
});

test("rejects revoked and expired records", () => {
  const base = { product: "dynamic-nook", tier: "pro", expires_at: null, revoked_at: null };
  assert.equal(validateLicenseRecord(base, 100), null);
  assert.equal(validateLicenseRecord({ ...base, revoked_at: 90 }, 100).code, "revoked");
  assert.equal(validateLicenseRecord({ ...base, expires_at: 99 }, 100).code, "expired");
});

test("creates device-bound standard payload and bounded validation time", () => {
  const record = {
    id: "license-id",
    product: "dynamic-nook",
    kind: "standard",
    customer_reference: "ORDER-1",
    expires_at: 1_500,
  };
  const payload = activationPayload(record, "device-hash", 1_000, 604_800);
  assert.equal(payload.deviceKeyHash, "device-hash");
  assert.equal(payload.validatedUntil, 1_500);
  assert.deepEqual(Object.keys(payload), [...Object.keys(payload)].sort());
});

test("signs activation token with Ed25519 JWK", async () => {
  const keyPair = await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]);
  const privateJWK = await crypto.subtle.exportKey("jwk", keyPair.privateKey);
  const token = await signActivationToken({ version: 2 }, privateJWK);
  const [, payload, signature] = token.split(".");
  const valid = await crypto.subtle.verify(
    { name: "Ed25519" },
    keyPair.publicKey,
    Buffer.from(signature, "base64url"),
    Buffer.from(payload, "base64url")
  );
  assert.equal(valid, true);
});

test("rejects malformed JSON before database access", async () => {
  const response = await worker.fetch(
    new Request("https://license.example/v1/activate", {
      method: "POST",
      body: "{broken",
      headers: { "content-type": "application/json" },
    }),
    {}
  );
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error.code, "invalid_json");
});
