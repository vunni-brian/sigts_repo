-- Migration 008: Cultural narrative publish controls
-- Adds explicit publishing fields so that:
--   * The community member who verified each narrative is recorded.
--   * Public listings can require an explicit "published_at" stamp.
-- Publishing is gated in the application layer to require verified_by_community = true
-- AND verified_by_community_id IS NOT NULL.

BEGIN;

ALTER TABLE cultural_narratives
    ADD COLUMN IF NOT EXISTS verified_by_community_id UUID
        REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS published_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS published_by UUID
        REFERENCES users(user_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_cultural_narratives_published
    ON cultural_narratives(published_at)
    WHERE published_at IS NOT NULL;

COMMIT;
