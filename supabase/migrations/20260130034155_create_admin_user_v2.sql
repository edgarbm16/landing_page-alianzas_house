/*
  # Create Admin User (obsoleta)

  Esta migración creaba el usuario administrador con credenciales en el código.
  Se dejó vacía intencionalmente: el usuario se eliminaba en la migración
  siguiente (20260130034641_recreate_admin_user.sql) y el administrador se crea
  mediante la Edge Function `create-admin` o desde el dashboard de Supabase.

  Se conserva el archivo para no alterar el historial de versiones de migraciones.
*/
SELECT 1;
