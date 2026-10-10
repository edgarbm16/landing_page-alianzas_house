/*
  # Create Landing Content System

  ## Overview
  This migration implements a template-based landing page system where:
  - Admin users create the structure/template of landings
  - Editor users can only edit content of locked items created by admin
  - Editors cannot add or remove items from the template

  ## Changes

  1. **New Table: landing_content**
     - Stores all content items for landings
     - Each item has a section_type (hero, feature, property, testimonial, etc.)
     - `is_locked` field indicates if item is part of admin-defined template
     - `created_by` tracks which user created the item
     - Content fields: title, subtitle, description, image_url, price, location, author, rating, icon, link_url, link_text
     - `order` field for sorting items within a section

  2. **Security (RLS)**
     - Admins can do everything
     - Editors can only view and update content fields of locked items
     - Editors cannot change structure (add/delete/modify is_locked items)
     - Public users have no access

  ## Important Notes
  - All items created by admin should have `is_locked = true`
  - Editors can only UPDATE content fields (title, description, etc.)
  - Editors cannot modify: is_locked, section_type, order, or delete items
*/

-- Create landing_content table
CREATE TABLE IF NOT EXISTS landing_content (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  landing_id uuid NOT NULL REFERENCES landings(id) ON DELETE CASCADE,
  section_type text NOT NULL CHECK (section_type IN ('hero', 'feature', 'property', 'testimonial', 'cta', 'custom')),
  is_locked boolean NOT NULL DEFAULT true,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Content fields (all optional, editors will fill these)
  title text,
  subtitle text,
  description text,
  image_url text,
  price text,
  location text,
  author text,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  icon text,
  link_url text,
  link_text text,
  
  -- Ordering
  "order" integer NOT NULL DEFAULT 0,
  
  -- Timestamps
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_landing_content_landing_id ON landing_content(landing_id);
CREATE INDEX IF NOT EXISTS idx_landing_content_section_type ON landing_content(section_type);
CREATE INDEX IF NOT EXISTS idx_landing_content_order ON landing_content("order");

-- Enable RLS
ALTER TABLE landing_content ENABLE ROW LEVEL SECURITY;

-- Update the existing is_admin function to work without parameters
CREATE OR REPLACE FUNCTION is_current_user_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid() AND role = 'Administrador'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies for landing_content

-- Admins can view all landing content
CREATE POLICY "Admins can view all landing content"
  ON landing_content FOR SELECT
  TO authenticated
  USING (is_current_user_admin());

-- Admins can insert landing content
CREATE POLICY "Admins can insert landing content"
  ON landing_content FOR INSERT
  TO authenticated
  WITH CHECK (is_current_user_admin());

-- Admins can update landing content
CREATE POLICY "Admins can update landing content"
  ON landing_content FOR UPDATE
  TO authenticated
  USING (is_current_user_admin())
  WITH CHECK (is_current_user_admin());

-- Admins can delete landing content
CREATE POLICY "Admins can delete landing content"
  ON landing_content FOR DELETE
  TO authenticated
  USING (is_current_user_admin());

-- Editors can view locked items
CREATE POLICY "Editors can view locked landing content"
  ON landing_content FOR SELECT
  TO authenticated
  USING (NOT is_current_user_admin() AND is_locked = true);

-- Editors can only update content fields of locked items
-- The WITH CHECK ensures the item remains locked and structural fields don't change
CREATE POLICY "Editors can update content of locked items"
  ON landing_content FOR UPDATE
  TO authenticated
  USING (NOT is_current_user_admin() AND is_locked = true)
  WITH CHECK (
    NOT is_current_user_admin() 
    AND is_locked = true
  );

-- Trigger to prevent editors from modifying structural fields
CREATE OR REPLACE FUNCTION prevent_structure_changes()
RETURNS TRIGGER AS $$
DECLARE
  user_is_admin boolean;
BEGIN
  -- Check if current user is admin
  SELECT is_current_user_admin() INTO user_is_admin;
  
  -- If not admin, prevent changes to structural fields
  IF NOT user_is_admin THEN
    IF OLD.is_locked != NEW.is_locked THEN
      RAISE EXCEPTION 'Editors cannot change is_locked field';
    END IF;
    
    IF OLD.section_type != NEW.section_type THEN
      RAISE EXCEPTION 'Editors cannot change section_type field';
    END IF;
    
    IF OLD.created_by != NEW.created_by THEN
      RAISE EXCEPTION 'Editors cannot change created_by field';
    END IF;
    
    IF OLD.landing_id != NEW.landing_id THEN
      RAISE EXCEPTION 'Editors cannot change landing_id field';
    END IF;
    
    IF OLD."order" != NEW."order" THEN
      RAISE EXCEPTION 'Editors cannot change order field';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER enforce_editor_restrictions
  BEFORE UPDATE ON landing_content
  FOR EACH ROW
  EXECUTE FUNCTION prevent_structure_changes();

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_landing_content_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_landing_content_updated_at
  BEFORE UPDATE ON landing_content
  FOR EACH ROW
  EXECUTE FUNCTION update_landing_content_updated_at();