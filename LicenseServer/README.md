# Dynamic Nook License Server

Cloudflare Workers + D1 backend for request-code-free activation.

Production health endpoint: `https://dynamic-nook-license.2010haheon.workers.dev/health`

## Deploy

1. Create a free Cloudflare account and authenticate Wrangler:

   ```bash
   npx wrangler login
   ```

2. Create D1, copy its ID into `wrangler.jsonc`, then apply the migration:

   ```bash
   cd LicenseServer
   npx wrangler d1 create dynamic-nook-license
   npx wrangler d1 migrations apply dynamic-nook-license --remote
   ```

3. Set secrets. Never commit either value:

   ```bash
   npx wrangler secret put ADMIN_API_TOKEN
   ../script/export_license_signing_jwk.sh | npx wrangler secret put SIGNING_KEY_JWK
   ```

4. Deploy and copy the resulting `workers.dev` URL:

   ```bash
   npx wrangler deploy
   ```

5. Build the app with that public URL:

   ```bash
   LICENSE_SERVER_URL="https://dynamic-nook-license.<account>.workers.dev" \
     ../script/build_and_run.sh --verify
   ```

Enter the same URL and `ADMIN_API_TOKEN` in the private License Issuer app. The issuer app is never included in the public DMG.

## Current production configuration

- Worker: `dynamic-nook-license`
- D1: `dynamic-nook-license` in APAC
- Standard key: bound atomically to the first Mac that activates it
- Master key: no device limit
- Signed activation cache: 7 days, then online revalidation is required
- Administrator token: macOS Keychain only (`dev.dynamicnook.licenseissuer`)
- Signing private key: Cloudflare Worker secret only (`SIGNING_KEY_JWK`)

The database stores only a SHA-256 hash of each customer license key. Raw customer keys are shown once by the private issuer and are not stored by the server.
