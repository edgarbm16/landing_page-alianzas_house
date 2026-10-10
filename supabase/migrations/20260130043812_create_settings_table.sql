/*
  # Create settings table for application configuration

  1. New Tables
    - `settings`
      - `id` (uuid, primary key) - Unique identifier for each setting
      - `company_name` (text) - Name of the company/business
      - `logo_url` (text, nullable) - URL to the company logo
      - `favicon_url` (text, nullable) - URL to the favicon
      - `google_tag_manager_id` (text, nullable) - Google Tag Manager container ID
      - `updated_at` (timestamptz) - Last update timestamp
      - `updated_by` (uuid, foreign key to auth.users) - User who last updated
  
  2. Security
    - Enable RLS on `settings` table
    - Add policy for authenticated users to read settings
    - Add policy for administrators to update settings
  
  3. Notes
    - Only one row should exist in this table (singleton pattern)
    - Initial row is created with default values
*/

-- Create settings table
CREATE TABLE IF NOT EXISTS settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name text NOT NULL DEFAULT '',
  logo_url text,
  favicon_url text,
  google_tag_manager_id text,
  updated_at timestamptz DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone authenticated can read settings
CREATE POLICY "Authenticated users can read settings"
  ON settings
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Only administrators can update settings
CREATE POLICY "Administrators can update settings"
  ON settings
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'Administrador'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'Administrador'
    )
  );

-- Insert default settings row (singleton)
INSERT INTO settings (company_name)
VALUES ('')
ON CONFLICT DO NOTHING;
