/*
  # Create email recipients table for contact form notifications

  1. New Tables
    - `email_recipients`
      - `id` (uuid, primary key) - Unique identifier
      - `email` (text) - Email address of the recipient
      - `recipient_type` (text) - Type of recipient: 'to', 'cc', or 'bcc'
      - `is_active` (boolean) - Whether this recipient is active
      - `created_at` (timestamptz) - Creation timestamp
      - `created_by` (uuid, foreign key to auth.users) - User who created the recipient
  
  2. Security
    - Enable RLS on `email_recipients` table
    - Add policy for authenticated users to read email recipients
    - Add policy for administrators to insert, update, and delete email recipients
  
  3. Notes
    - Multiple recipients can be configured for each type (to, cc, bcc)
    - Only active recipients will receive emails
    - Administrators can manage all recipients
*/

-- Create email recipients table
CREATE TABLE IF NOT EXISTS email_recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  recipient_type text NOT NULL CHECK (recipient_type IN ('to', 'cc', 'bcc')),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_email_recipients_active ON email_recipients(is_active);
CREATE INDEX IF NOT EXISTS idx_email_recipients_type ON email_recipients(recipient_type);

-- Enable RLS
ALTER TABLE email_recipients ENABLE ROW LEVEL SECURITY;

-- Policy: Authenticated users can read active email recipients
CREATE POLICY "Authenticated users can read email recipients"
  ON email_recipients
  FOR SELECT
  TO authenticated
  USING (is_active = true);

-- Policy: Administrators can insert email recipients
CREATE POLICY "Administrators can insert email recipients"
  ON email_recipients
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'Administrador'
    )
  );

-- Policy: Administrators can update email recipients
CREATE POLICY "Administrators can update email recipients"
  ON email_recipients
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

-- Policy: Administrators can delete email recipients
CREATE POLICY "Administrators can delete email recipients"
  ON email_recipients
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role = 'Administrador'
    )
  );
