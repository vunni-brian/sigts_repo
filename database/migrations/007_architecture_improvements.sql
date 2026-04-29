-- Migration 007: Architecture improvements
-- Adds tables/columns required for:
--   * Idempotency-Key middleware (Phase 2.1)
--   * Consent log gating location writes (Phase 3.1)
--   * Refresh-token rotation with reuse detection (Phase 3.2)
--   * Field-level access control on tourist medical notes (Phase 4.2)

BEGIN;

-- =====================================================
-- IDEMPOTENCY KEYS
-- One row per (user, key) capturing the first response so
-- that retried mutating requests return the same payload.
-- =====================================================
CREATE TABLE IF NOT EXISTS idempotency_keys (
    key UUID NOT NULL,
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    method VARCHAR(10) NOT NULL,
    path VARCHAR(255) NOT NULL,
    request_hash VARCHAR(64) NOT NULL,
    status_code SMALLINT NOT NULL,
    response_body JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '24 hours'),
    PRIMARY KEY (key, user_id)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires_at
    ON idempotency_keys(expires_at);

-- =====================================================
-- CONSENT LOG
-- Tracks user consent grants/revocations. Location writes
-- are blocked unless the user has a current grant for
-- consent_type = 'location_tracking'.
-- =====================================================
CREATE TABLE IF NOT EXISTS consent_log (
    consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    consent_type VARCHAR(50) NOT NULL CHECK (consent_type IN (
        'location_tracking',
        'analytics',
        'push_notifications',
        'cultural_content_imagery'
    )),
    granted BOOLEAN NOT NULL,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP WITH TIME ZONE,
    ip_address INET,
    user_agent TEXT,
    policy_version VARCHAR(20)
);

CREATE INDEX IF NOT EXISTS idx_consent_log_user_active
    ON consent_log(user_id, consent_type, granted_at DESC)
    WHERE revoked_at IS NULL;

-- =====================================================
-- REFRESH TOKEN FAMILIES
-- Each login creates a token family. Each rotation creates
-- a new token in the same family. If a previously-rotated
-- token is presented again, the entire family is revoked
-- (reuse detection). One row per individual refresh token.
-- =====================================================
CREATE TABLE IF NOT EXISTS refresh_token_families (
    family_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    issued_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP WITH TIME ZONE,
    revoke_reason VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_refresh_token_families_user_active
    ON refresh_token_families(user_id)
    WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS refresh_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES refresh_token_families(family_id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    issued_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    rotated_at TIMESTAMP WITH TIME ZONE,
    rotated_to UUID REFERENCES refresh_tokens(token_id),
    user_agent TEXT,
    ip_address INET
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family
    ON refresh_tokens(family_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at
    ON refresh_tokens(expires_at);

-- =====================================================
-- TOURIST MEDICAL NOTES
-- Sensitive field — RLS-style guard enforced in application
-- layer (only the currently-assigned guide for an active
-- tour, or the tourist themselves, may read it).
-- =====================================================
ALTER TABLE tourists
    ADD COLUMN IF NOT EXISTS medical_notes TEXT,
    ADD COLUMN IF NOT EXISTS medical_notes_updated_at TIMESTAMP WITH TIME ZONE;

COMMIT;
