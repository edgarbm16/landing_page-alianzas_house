/*
  # Sistema de Permisos por Módulo
  
  1. Nueva tabla
    - `user_module_permissions`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references user_profiles)
      - `module_name` (text, not null)
      - `created_at` (timestamptz, default now())
      - Constraint único para evitar duplicados: user_id + module_name
  
  2. Módulos disponibles
    - 'prospects' - Ver y gestionar prospectos
    - 'landings' - Gestionar landing pages
    - 'emails' - Configurar destinatarios de email
    - 'users' - Gestionar usuarios (solo Administrador y Gestor)
    - 'settings' - Configuración general
  
  3. Security
    - Enable RLS on `user_module_permissions` table
    - Los usuarios pueden ver sus propios permisos
    - Solo Administradores y Gestores pueden gestionar permisos
  
  4. Funciones auxiliares
    - Función para verificar si un usuario tiene permiso para un módulo específico
*/

-- Crear tabla de permisos por módulo
CREATE TABLE IF NOT EXISTS user_module_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  module_name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, module_name)
);

-- Enable RLS
ALTER TABLE user_module_permissions ENABLE ROW LEVEL SECURITY;

-- Los usuarios pueden ver sus propios permisos
CREATE POLICY "Users can view own permissions"
  ON user_module_permissions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Administradores y Gestores pueden ver todos los permisos
CREATE POLICY "Admins and Gestors can view all permissions"
  ON user_module_permissions FOR SELECT
  TO authenticated
  USING (is_admin_or_gestor(auth.uid()));

-- Solo Administradores y Gestores pueden insertar permisos
CREATE POLICY "Admins and Gestors can insert permissions"
  ON user_module_permissions FOR INSERT
  TO authenticated
  WITH CHECK (is_admin_or_gestor(auth.uid()));

-- Solo Administradores y Gestores pueden eliminar permisos
CREATE POLICY "Admins and Gestors can delete permissions"
  ON user_module_permissions FOR DELETE
  TO authenticated
  USING (is_admin_or_gestor(auth.uid()));

-- Función para verificar si un usuario tiene permiso para un módulo
CREATE OR REPLACE FUNCTION has_module_permission(user_id uuid, module text)
RETURNS boolean AS $$
DECLARE
  user_role user_role;
BEGIN
  SELECT role INTO user_role FROM user_profiles WHERE id = user_id;
  
  IF user_role = 'Administrador' THEN
    RETURN true;
  END IF;
  
  IF module = 'users' AND user_role = 'Gestor' THEN
    RETURN true;
  END IF;
  
  RETURN EXISTS (
    SELECT 1 FROM user_module_permissions
    WHERE user_module_permissions.user_id = has_module_permission.user_id
    AND user_module_permissions.module_name = module
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Índices para mejorar rendimiento
CREATE INDEX IF NOT EXISTS idx_user_module_permissions_user_id ON user_module_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_module_permissions_module_name ON user_module_permissions(module_name);