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

interface DeleteUserRequest {
  userId: string;
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
  // Verificar el token directamente via REST, sin parseo local de JWT
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
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const caller = await getCallerProfile(req, supabaseUrl, supabaseServiceKey);
    if (!caller || !["Administrador", "Gestor"].includes(caller.role)) {
      return new Response(
        JSON.stringify({ error: "No autorizado. Se requiere rol Administrador o Gestor." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const { userId }: DeleteUserRequest = await req.json();

    if (!userId) {
      return new Response(
        JSON.stringify({ error: "userId es requerido" }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    if (userId === caller.id) {
      return new Response(
        JSON.stringify({ error: "No puedes eliminar tu propia cuenta." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate role hierarchy: caller must outrank target
    const { data: targetProfile } = await supabaseAdmin
      .from("user_profiles")
      .select("role")
      .eq("id", userId)
      .single();

    if (!targetProfile) {
      return new Response(
        JSON.stringify({ error: "Usuario destino no encontrado." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if ((ROLE_LEVEL[caller.role] ?? 0) <= (ROLE_LEVEL[targetProfile.role] ?? 0)) {
      return new Response(
        JSON.stringify({ error: "No puedes eliminar a un usuario con igual o mayor rango." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (error) {
      throw error;
    }

    return new Response(
      JSON.stringify({ success: true }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error: any) {
    console.error("Error deleting user:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Error al eliminar usuario" }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
