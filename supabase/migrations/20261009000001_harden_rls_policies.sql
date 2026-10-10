/*
  # Endurecer políticas RLS

  1. user_module_permissions
    - Antes: cualquier Admin o Gestor podía otorgar/quitar cualquier módulo a
      cualquier usuario (incluido a sí mismo o a un Administrador).
    - Ahora: el Administrador gestiona permisos de cualquier usuario excepto los
      suyos; el Gestor solo los de usuarios Editor/Analista, nunca los propios.

  2. prospects
    - Se elimina el INSERT público directo. El formulario usa la Edge Function
      `send-contact-email` (service role), que valida y limita envíos; la política
      pública permitía saltarse esas validaciones con la anon key.

  3. storage `landing-files`
    - Subir, actualizar y borrar archivos requiere permiso de edición
      (can_edit), igual que las landings. El Analista queda en solo lectura.

  4. Funciones SECURITY DEFINER
    - Se fija search_path para evitar que se resuelvan objetos de otro esquema.
*/

-- 1. Permisos por módulo -------------------------------------------------------

CREATE OR REPLACE FUNCTION can_manage_permissions_of(target_user_id uuid)
RETURNS boolean AS $$
DECLARE
  caller_role user_role;
  target_role user_role;
BEGIN
  IF target_user_id = auth.uid() THEN
    RETURN false;
  END IF;

  SELECT role INTO caller_role FROM public.user_profiles WHERE id = auth.uid();
  SELECT role INTO target_role FROM public.user_profiles WHERE id = target_user_id;

  IF caller_role = 'Administrador' THEN
    RETURN true;
  END IF;

  IF caller_role = 'Gestor' AND target_role IN ('Editor', 'Analista') THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP POLICY IF EXISTS "Admins and Gestors can insert permissions" ON user_module_permissions;
DROP POLICY IF EXISTS "Admins and Gestors can delete permissions" ON user_module_permissions;

CREATE POLICY "Admins and Gestors can insert permissions"
  ON user_module_permissions FOR INSERT
  TO authenticated
  WITH CHECK (can_manage_permissions_of(user_id));

CREATE POLICY "Admins and Gestors can delete permissions"
  ON user_module_permissions FOR DELETE
  TO authenticated
  USING (can_manage_permissions_of(user_id));

-- 2. Prospectos ----------------------------------------------------------------

DROP POLICY IF EXISTS "Allow public prospect insertion via form" ON prospects;

-- 3. Storage -------------------------------------------------------------------

DROP POLICY IF EXISTS "Authenticated users can upload landing files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update landing files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete landing files" ON storage.objects;

CREATE POLICY "Editors can upload landing files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'landing-files' AND public.can_edit(auth.uid()));

CREATE POLICY "Editors can update landing files"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'landing-files' AND public.can_edit(auth.uid()))
  WITH CHECK (bucket_id = 'landing-files' AND public.can_edit(auth.uid()));

CREATE POLICY "Editors can delete landing files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'landing-files' AND public.can_edit(auth.uid()));

-- 4. search_path en funciones SECURITY DEFINER ---------------------------------

ALTER FUNCTION is_admin(uuid) SET search_path = public;
ALTER FUNCTION is_gestor(uuid) SET search_path = public;
ALTER FUNCTION is_admin_or_gestor(uuid) SET search_path = public;
ALTER FUNCTION can_edit(uuid) SET search_path = public;
ALTER FUNCTION has_module_permission(uuid, text) SET search_path = public;
ALTER FUNCTION handle_new_user() SET search_path = public;
