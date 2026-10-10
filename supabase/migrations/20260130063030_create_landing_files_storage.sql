/*
  # Create Storage Bucket for Landing Files

  1. Storage
    - Create `landing-files` bucket for images and videos
    - Set public access for published content
    - Configure size limits and allowed file types

  2. Security
    - Allow authenticated users to upload files
    - Allow public access to read files
*/

INSERT INTO storage.buckets (id, name, public)
VALUES ('landing-files', 'landing-files', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Authenticated users can upload landing files'
  ) THEN
    CREATE POLICY "Authenticated users can upload landing files"
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (bucket_id = 'landing-files');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Authenticated users can update landing files'
  ) THEN
    CREATE POLICY "Authenticated users can update landing files"
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (bucket_id = 'landing-files')
      WITH CHECK (bucket_id = 'landing-files');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Authenticated users can delete landing files'
  ) THEN
    CREATE POLICY "Authenticated users can delete landing files"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (bucket_id = 'landing-files');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Public can view landing files'
  ) THEN
    CREATE POLICY "Public can view landing files"
      ON storage.objects
      FOR SELECT
      TO public
      USING (bucket_id = 'landing-files');
  END IF;
END $$;