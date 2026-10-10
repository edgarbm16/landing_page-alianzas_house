/*
  # Create prospects table for contact form submissions

  1. New Tables
    - `prospects`
      - `id` (uuid, primary key) - Unique identifier
      - `name` (text) - Full name of the prospect
      - `email` (text) - Email address
      - `phone` (text) - Phone number
      - `interest` (text) - Type of interest: 'comprar', 'rentar', 'vender', 'invertir'
      - `budget` (text) - Budget range
      - `message` (text) - Additional message from prospect
      - `rating` (integer) - Prospect rating from 1-5 stars
      - `notes` (text) - Internal notes about the prospect
      - `status` (text) - Status: 'nuevo', 'contactado', 'calificado', 'cerrado'
      - `created_at` (timestamptz) - Creation timestamp
      - `updated_at` (timestamptz) - Last update timestamp
  
  2. Security
    - Enable RLS on `prospects` table
    - Add policy for authenticated users to read prospects
    - Add policy for authenticated users to insert prospects
    - Add policy for authenticated users to update prospects
    - Add policy for administrators to delete prospects
  
  3. Notes
    - Prospects are created when users submit the contact form
    - Authenticated users can view and manage prospects
    - Ratings are optional and can be from 1 to 5
    - Notes are internal and not visible to the prospect
*/

CREATE TABLE IF NOT EXISTS prospects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  interest text NOT NULL CHECK (interest IN ('comprar', 'rentar', 'vender', 'invertir')),
  budget text NOT NULL,
  message text DEFAULT '',
  rating integer CHECK (rating >= 1 AND rating <= 5),
  notes text DEFAULT '',
  status text DEFAULT 'nuevo' CHECK (status IN ('nuevo', 'contactado', 'calificado', 'cerrado')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prospects_status ON prospects(status);
CREATE INDEX IF NOT EXISTS idx_prospects_created_at ON prospects(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_prospects_rating ON prospects(rating);
CREATE INDEX IF NOT EXISTS idx_prospects_email ON prospects(email);

ALTER TABLE prospects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read prospects"
  ON prospects
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert prospects"
  ON prospects
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update prospects"
  ON prospects
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Administrators can delete prospects"
  ON prospects
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'Administrador'
    )
  );

CREATE OR REPLACE FUNCTION update_prospects_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prospects_updated_at
  BEFORE UPDATE ON prospects
  FOR EACH ROW
  EXECUTE FUNCTION update_prospects_updated_at();
