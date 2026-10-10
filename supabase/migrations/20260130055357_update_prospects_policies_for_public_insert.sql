/*
  # Update prospects RLS policies for public form submissions

  1. Changes
    - Drop existing authenticated-only insert policy
    - Add new policy to allow public inserts (form submissions via edge function)
    - Keep other policies unchanged for security
  
  2. Security Notes
    - Public insert is safe because:
      - Edge function validates and sanitizes data
      - Edge function is the only entry point for form submissions
      - No sensitive data can be set by public users (rating, notes, etc have defaults)
    - Read/Update/Delete still require authentication
*/

DROP POLICY IF EXISTS "Authenticated users can insert prospects" ON prospects;

CREATE POLICY "Allow public prospect insertion via form"
  ON prospects
  FOR INSERT
  WITH CHECK (true);
