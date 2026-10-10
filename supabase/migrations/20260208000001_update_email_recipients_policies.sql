/*
  # Update email_recipients policies to use module permissions
  
  1. Changes
    - Drop existing INSERT, UPDATE, DELETE policies that only allow Administrators
    - Create new policies that check for 'emails' module permission
    - This allows users with the 'emails' permission (Editor, Gestor) to manage recipients
  
  2. Security
    - Uses has_module_permission function to check permissions
    - Administrators automatically have all permissions
    - Other roles need explicit 'emails' module permission
*/

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Administrators can insert email recipients" ON email_recipients;
DROP POLICY IF EXISTS "Administrators can update email recipients" ON email_recipients;
DROP POLICY IF EXISTS "Administrators can delete email recipients" ON email_recipients;

-- Create new policies using module permissions

-- Policy: Users with 'emails' permission can insert email recipients
CREATE POLICY "Users with emails permission can insert"
  ON email_recipients
  FOR INSERT
  TO authenticated
  WITH CHECK (
    has_module_permission(auth.uid(), 'emails')
  );

-- Policy: Users with 'emails' permission can update email recipients
CREATE POLICY "Users with emails permission can update"
  ON email_recipients
  FOR UPDATE
  TO authenticated
  USING (
    has_module_permission(auth.uid(), 'emails')
  )
  WITH CHECK (
    has_module_permission(auth.uid(), 'emails')
  );

-- Policy: Users with 'emails' permission can delete email recipients
CREATE POLICY "Users with emails permission can delete"
  ON email_recipients
  FOR DELETE
  TO authenticated
  USING (
    has_module_permission(auth.uid(), 'emails')
  );

-- Also update SELECT policy to allow users with permission to see all (including inactive)
DROP POLICY IF EXISTS "Authenticated users can read email recipients" ON email_recipients;

CREATE POLICY "Users with emails permission can read all"
  ON email_recipients
  FOR SELECT
  TO authenticated
  USING (
    has_module_permission(auth.uid(), 'emails')
  );
