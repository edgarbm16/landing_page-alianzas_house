/*
  # Recreate Admin User Correctly

  1. Removes incorrectly created admin user if exists
  2. Admin user must be created via the create-admin Edge Function
*/

-- Delete existing user and related records
DELETE FROM auth.identities WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'admin@example.com');
DELETE FROM auth.users WHERE email = 'admin@example.com';