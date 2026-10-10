import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function getCorsHeaders(req: Request): Record<string, string> {
  const siteUrl = Deno.env.get("SITE_URL") ?? "http://localhost:4321";
  const allowed = [siteUrl, "http://localhost:4321", "http://localhost:3000"];
  const origin = req.headers.get("origin") ?? "";
  return {
    "Access-Control-Allow-Origin": allowed.includes(origin) ? origin : siteUrl,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
  };
}

const ROLE_LEVEL: Record<string, number> = {
  Administrador: 4,
  Gestor: 3,
  Editor: 2,
  Analista: 1,
};

async function getCallerProfile(
  req: Request,
  supabaseUrl: string,
  supabaseServiceKey: string
): Promise<{ id: string; role: string } | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return null;

  const token = authHeader.replace("Bearer ", "");
  const authRes = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { Authorization: `Bearer ${token}`, apikey: supabaseServiceKey },
  });
  if (!authRes.ok) return null;
  const user = await authRes.json();

  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: profile } = await supabaseAdmin
    .from("user_profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!profile) return null;
  return { id: user.id, role: profile.role };
}

Deno.serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const caller = await getCallerProfile(req, supabaseUrl, supabaseServiceKey);
    if (!caller || !["Administrador", "Gestor"].includes(caller.role)) {
      return new Response(
        JSON.stringify({ error: "No autorizado." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { targetUserId, newPassword } = await req.json();

    if (!targetUserId || !newPassword || newPassword.length < 8) {
      return new Response(
        JSON.stringify({ error: "ID de usuario y contraseña (mín. 8 caracteres) son requeridos." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Validate role hierarchy: caller must outrank target
    const { data: targetProfile } = await supabaseAdmin
      .from("user_profiles")
      .select("role")
      .eq("id", targetUserId)
      .single();

    if (!targetProfile) {
      return new Response(
        JSON.stringify({ error: "Usuario destino no encontrado." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const callerLevel = ROLE_LEVEL[caller.role] ?? 0;
    const targetLevel = ROLE_LEVEL[targetProfile.role] ?? 0;

    if (callerLevel <= targetLevel) {
      return new Response(
        JSON.stringify({ error: "No puedes cambiar la contraseña de un usuario con igual o mayor rango." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { error } = await supabaseAdmin.auth.admin.updateUserById(targetUserId, {
      password: newPassword,
    });

    if (error) throw error;

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("Error updating password:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Error al actualizar contraseña" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
