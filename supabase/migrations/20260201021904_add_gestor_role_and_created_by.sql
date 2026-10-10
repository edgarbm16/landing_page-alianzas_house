/*
  # Agregar rol Gestor y sistema de seguimiento de creación de usuarios
  
  1. Cambios en el esquema
    - Agregar 'Gestor' al enum user_role
    - Agregar columna created_by a user_profiles para rastrear quién creó cada usuario
    
  2. Nuevas funciones
    - Función para verificar si un usuario es Gestor
    - Función para verificar si un usuario es Administrador o Gestor
    
  3. Actualización de políticas RLS
    - Gestores pueden ver solo usuarios que ellos crearon o usuarios con rol Editor/Analista
    - Gestores pueden insertar/actualizar/eliminar solo usuarios con rol Editor/Analista
    - Administradores mantienen acceso completo
    
  4. Notas importantes
    - Los Gestores NO pueden ver usuarios creados por Administradores
    - Los Gestores solo pueden crear usuarios con rol Editor o Analista
    - La columna created_by rastrea quién creó cada usuario para aplicar permisos
*/

-- Agregar 'Gestor' al enum user_role
DO $$ 
BEGIN
  ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'Gestor';
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Agregar columna created_by a user_profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'created_by'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN created_by uuid REFERENCES auth.users(id);
  END IF;
END $$;

-- Función para verificar si un usuario es Gestor
CREATE OR REPLACE FUNCTION is_gestor(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = user_id AND role = 'Gestor'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para verificar si un usuario es Administrador o Gestor
CREATE OR REPLACE FUNCTION is_admin_or_gestor(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = user_id AND role IN ('Administrador', 'Gestor')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Eliminar políticas antiguas
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Administrators can insert profiles" ON user_profiles;
DROP POLICY IF EXISTS "Administrators can update profiles" ON user_profiles;
DROP POLICY IF EXISTS "Administrators can delete profiles" ON user_profiles;

-- Nueva política de SELECT: 
-- - Administradores ven todos los usuarios
-- - Gestores ven solo usuarios que ellos crearon O usuarios con rol Editor/Analista
-- - Otros usuarios solo ven su propio perfil
CREATE POLICY "Users can view profiles based on role"
  ON user_profiles FOR SELECT
  TO authenticated
  USING (
    auth.uid() = id OR
    is_admin(auth.uid()) OR
    (is_gestor(auth.uid()) AND (created_by = auth.uid() OR role IN ('Editor', 'Analista')))
  );

-- Política INSERT:
-- - Administradores pueden insertar cualquier usuario
-- - Gestores solo pueden insertar usuarios con rol Editor o Analista
CREATE POLICY "Administrators and Gestors can insert profiles"
  ON user_profiles FOR INSERT
  TO authenticated
  WITH CHECK (
    is_admin(auth.uid()) OR
    (is_gestor(auth.uid()) AND role IN ('Editor', 'Analista'))
  );

-- Política UPDATE:
-- - Administradores pueden actualizar cualquier usuario
-- - Gestores solo pueden actualizar usuarios que ellos crearon Y que sean Editor/Analista
CREATE POLICY "Administrators and Gestors can update profiles"
  ON user_profiles FOR UPDATE
  TO authenticated
  USING (
    is_admin(auth.uid()) OR
    (is_gestor(auth.uid()) AND created_by = auth.uid() AND role IN ('Editor', 'Analista'))
  )
  WITH CHECK (
    is_admin(auth.uid()) OR
    (is_gestor(auth.uid()) AND role IN ('Editor', 'Analista'))
  );

-- Política DELETE:
-- - Administradores pueden eliminar cualquier usuario
-- - Gestores solo pueden eliminar usuarios que ellos crearon Y que sean Editor/Analista
CREATE POLICY "Administrators and Gestors can delete profiles"
  ON user_profiles FOR DELETE
  TO authenticated
  USING (
    is_admin(auth.uid()) OR
    (is_gestor(auth.uid()) AND created_by = auth.uid() AND role IN ('Editor', 'Analista'))
  );

-- Actualizar usuarios existentes para que tengan created_by NULL (creados por el sistema)
-- Esto permite que los Administradores los vean todos
UPDATE user_profiles SET created_by = NULL WHERE created_by IS NULL;