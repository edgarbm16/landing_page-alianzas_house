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

interface CreateUserRequest {
  email: string;
  password: string;
  fullName?: string;
  role?: string;
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
    const callerLevel = ROLE_LEVEL[caller?.role ?? ""] ?? 0;

    if (callerLevel < ROLE_LEVEL["Gestor"]) {
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

    // createdBy se ignora si viene del cliente: siempre es quien hace la petición
    const { email, password, fullName, role }: CreateUserRequest = await req.json();

    const VALID_ROLES = ['Administrador', 'Gestor', 'Editor', 'Analista'];

    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: "Email y contraseña son requeridos" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (role && !VALID_ROLES.includes(role)) {
      return new Response(
        JSON.stringify({ error: "Rol inválido." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Caller can only assign roles below their own level
    const targetLevel = ROLE_LEVEL[role ?? ""] ?? 0;
    if (role && targetLevel >= callerLevel) {
      return new Response(
        JSON.stringify({ error: "No puedes crear un usuario con igual o mayor rango que el tuyo." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (password.length < 8) {
      return new Response(
        JSON.stringify({ error: "La contraseña debe tener al menos 8 caracteres." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: userData, error: userError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (userError) {
      throw userError;
    }

    const updateData: any = { created_by: caller!.id };
    if (fullName) updateData.full_name = fullName;
    if (role) updateData.role = role;

    const { error: profileError } = await supabaseAdmin
      .from("user_profiles")
      .update(updateData)
      .eq("id", userData.user.id);

    if (profileError) {
      console.error("Error updating profile:", profileError);
    }

    return new Response(
      JSON.stringify({ success: true, user: userData.user }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error: any) {
    console.error("Error creating user:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Error al crear usuario" }),
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
