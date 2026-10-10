CREATE POLICY "Public can read settings"
  ON settings
  FOR SELECT
  TO anon
  USING (true);
