/*
  # Create Landings Management System

  1. New Tables
    - `landings`
      - `id` (uuid, primary key) - Unique identifier
      - `slug` (text, unique) - URL-friendly name (e.g., 'casas-venta')
      - `name` (text) - Display name of the landing
      - `h1` (text) - Main heading for hero section
      - `h2` (text) - Subheading for hero section
      - `description` (text) - Hero description
      - `meta_title` (text) - SEO meta title
      - `meta_description` (text) - SEO meta description
      - `phone` (text) - Contact phone number
      - `whatsapp` (text) - WhatsApp number
      - `whatsapp_message` (text) - Default WhatsApp message
      - `whatsapp_button_enabled` (boolean) - Show/hide floating WhatsApp button
      - `hero_type` (text) - Type of hero media ('image' or 'video')
      - `hero_url` (text) - URL to hero media file
      - `sections` (jsonb) - Array of content sections configuration
      - `published` (boolean) - Publication status
      - `created_at` (timestamptz) - Creation timestamp
      - `updated_at` (timestamptz) - Last update timestamp

  2. Security
    - Enable RLS on `landings` table
    - Add policy for authenticated users to manage landings
    - Add policy for public to view published landings
*/

CREATE TABLE IF NOT EXISTS landings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  h1 text DEFAULT '',
  h2 text DEFAULT '',
  description text DEFAULT '',
  meta_title text DEFAULT '',
  meta_description text DEFAULT '',
  phone text DEFAULT '',
  whatsapp text DEFAULT '',
  whatsapp_message text DEFAULT '',
  whatsapp_button_enabled boolean DEFAULT false,
  hero_type text DEFAULT 'image',
  hero_url text DEFAULT '',
  sections jsonb DEFAULT '[]'::jsonb,
  published boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE landings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view all landings"
  ON landings
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert landings"
  ON landings
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update landings"
  ON landings
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete landings"
  ON landings
  FOR DELETE
  TO authenticated
  USING (true);

CREATE POLICY "Public can view published landings"
  ON landings
  FOR SELECT
  TO anon
  USING (published = true);