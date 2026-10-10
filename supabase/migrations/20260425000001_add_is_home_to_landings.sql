-- Add is_home column to landings table
ALTER TABLE landings ADD COLUMN IF NOT EXISTS is_home boolean NOT NULL DEFAULT false;

-- Ensure only one landing can be marked as home at a time
CREATE UNIQUE INDEX IF NOT EXISTS landings_is_home_unique ON landings (is_home) WHERE is_home = true;
