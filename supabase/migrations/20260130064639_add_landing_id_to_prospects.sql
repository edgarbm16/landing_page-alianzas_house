/*
  # Add landing_id to prospects table

  1. Changes
    - Add `landing_id` column to prospects table
    - Add foreign key constraint to landings table
    - Add index for performance
  
  2. Notes
    - This allows tracking which landing page generated each prospect
    - landing_id is nullable to support prospects from other sources
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'prospects' AND column_name = 'landing_id'
  ) THEN
    ALTER TABLE prospects ADD COLUMN landing_id uuid REFERENCES landings(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_prospects_landing_id ON prospects(landing_id);
  END IF;
END $$;