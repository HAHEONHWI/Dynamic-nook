CREATE TABLE IF NOT EXISTS licenses (
    id TEXT PRIMARY KEY,
    key_hash TEXT NOT NULL UNIQUE,
    product TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('standard', 'master')),
    tier TEXT NOT NULL CHECK (tier = 'pro'),
    customer_reference TEXT NOT NULL,
    device_hash TEXT,
    issued_at INTEGER NOT NULL,
    expires_at INTEGER,
    revoked_at INTEGER,
    last_validated_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_licenses_key_hash ON licenses(key_hash);
CREATE INDEX IF NOT EXISTS idx_licenses_device_hash ON licenses(device_hash);
