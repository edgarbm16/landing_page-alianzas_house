/*
  # User Management Schema
  
  1. New Tables
    - `user_profiles`
      - `id` (uuid, primary key, references auth.users)
      - `email` (text, not null)
      - `role` (user_role enum, not null)
      - `full_name` (text)
      - `created_at` (timestamptz, default now())
      - `updated_at` (timestamptz, default now())
      
  2. Types
    - `user_role` enum with values: 'Administrador', 'Analista', 'Editor'
    
  3. Security
    - Enable RLS on `user_profiles` table
    - Add policy for authenticated users to view all profiles
    - Add policy for administrators to manage users
    - Add policy for users to view their own profile
    
  4. Functions
    - Trigger to automatically create profile when auth user is created
    - Trigger to update `updated_at` timestamp
*/

-- Create user_role enum type
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('Administrador', 'Analista', 'Editor');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  role user_role NOT NULL DEFAULT 'Editor',
  full_name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = user_id AND role = 'Administrador'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policy: Users can view their own profile
CREATE POLICY "Users can view own profile"
  ON user_profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Policy: Authenticated users can view all profiles (for dashboard listing)
CREATE POLICY "Authenticated users can view all profiles"
  ON user_profiles FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Only administrators can insert new user profiles
CREATE POLICY "Administrators can insert profiles"
  ON user_profiles FOR INSERT
  TO authenticated
  WITH CHECK (is_admin(auth.uid()));

-- Policy: Only administrators can update user profiles
CREATE POLICY "Administrators can update profiles"
  ON user_profiles FOR UPDATE
  TO authenticated
  USING (is_admin(auth.uid()))
  WITH CHECK (is_admin(auth.uid()));

-- Policy: Only administrators can delete user profiles
CREATE POLICY "Administrators can delete profiles"
  ON user_profiles FOR DELETE
  TO authenticated
  USING (is_admin(auth.uid()));

-- Function to automatically create profile for new auth users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, role)
  VALUES (NEW.id, NEW.email, 'Editor');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at on profile changes
DROP TRIGGER IF EXISTS on_profile_updated ON user_profiles;
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Create profile for existing admin user
-- Nota: el correo es un marcador. En una instalación nueva, crea el usuario
-- admin y asígnale el rol 'Administrador' en user_profiles manualmente.
INSERT INTO user_profiles (id, email, role, full_name)
SELECT id, email, 'Administrador', 'Administrador'
FROM auth.users
WHERE email = 'admin@example.com'
ON CONFLICT (id) DO UPDATE
SET role = 'Administrador', full_name = 'Administrador';