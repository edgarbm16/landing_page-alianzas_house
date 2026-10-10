/*
  # Restringir rol Analista a solo lectura
  
  1. Cambios en políticas RLS
    - Actualizar políticas de `prospects` para que Analistas solo puedan leer
    - Actualizar políticas de `landings` para que Analistas solo puedan leer
    - Roles con permisos de escritura: Administrador, Gestor, Editor
    - Rol de solo lectura: Analista
  
  2. Funciones auxiliares
    - Función para verificar si un usuario puede editar (no es Analista)
  
  3. Tablas afectadas
    - prospects: Analistas solo SELECT
    - landings: Analistas solo SELECT
    - email_recipients: Ya restringido a Administradores
    - settings: Ya restringido a Administradores
    - user_profiles: Ya tiene políticas por rol
  
  4. Notas importantes
    - Administradores, Gestores y Editores mantienen permisos de escritura completos
    - Analistas solo pueden ver datos, no modificar, insertar o eliminar
*/

-- Función para verificar si un usuario puede editar (no es Analista)
CREATE OR REPLACE FUNCTION can_edit(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = user_id 
    AND role IN ('Administrador', 'Gestor', 'Editor')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PROSPECTS: Actualizar políticas
-- Eliminar políticas antiguas
DROP POLICY IF EXISTS "Authenticated users can insert prospects" ON prospects;
DROP POLICY IF EXISTS "Authenticated users can update prospects" ON prospects;

-- Nueva política INSERT: Solo usuarios que pueden editar (no Analistas)
CREATE POLICY "Users with edit permission can insert prospects"
  ON prospects
  FOR INSERT
  TO authenticated
  WITH CHECK (can_edit(auth.uid()));

-- Nueva política UPDATE: Solo usuarios que pueden editar (no Analistas)
CREATE POLICY "Users with edit permission can update prospects"
  ON prospects
  FOR UPDATE
  TO authenticated
  USING (can_edit(auth.uid()))
  WITH CHECK (can_edit(auth.uid()));

-- LANDINGS: Actualizar políticas
-- Eliminar políticas antiguas
DROP POLICY IF EXISTS "Authenticated users can insert landings" ON landings;
DROP POLICY IF EXISTS "Authenticated users can update landings" ON landings;
DROP POLICY IF EXISTS "Authenticated users can delete landings" ON landings;

-- Nueva política INSERT: Solo usuarios que pueden editar (no Analistas)
CREATE POLICY "Users with edit permission can insert landings"
  ON landings
  FOR INSERT
  TO authenticated
  WITH CHECK (can_edit(auth.uid()));

-- Nueva política UPDATE: Solo usuarios que pueden editar (no Analistas)
CREATE POLICY "Users with edit permission can update landings"
  ON landings
  FOR UPDATE
  TO authenticated
  USING (can_edit(auth.uid()))
  WITH CHECK (can_edit(auth.uid()));

-- Nueva política DELETE: Solo usuarios que pueden editar (no Analistas)
CREATE POLICY "Users with edit permission can delete landings"
  ON landings
  FOR DELETE
  TO authenticated
  USING (can_edit(auth.uid()));