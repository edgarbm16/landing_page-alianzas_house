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

interface ContactFormData {
  name: string;
  email: string;
  phone: string;
  interest: string;
  budget: string;
  message: string;
  landing_id?: string;
}

interface EmailRecipient {
  email: string;
  recipient_type: 'to' | 'cc' | 'bcc';
}

function escapeHtml(str: string): string {
  return (str ?? '').toString()
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

Deno.serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const formData: ContactFormData = await req.json();

    // Input validation
    if (!formData.name?.trim() || !formData.email?.trim() || !formData.phone?.trim() || !formData.interest?.trim()) {
      return new Response(
        JSON.stringify({ error: "Nombre, email, teléfono e interés son requeridos." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (!EMAIL_REGEX.test(formData.email)) {
      return new Response(
        JSON.stringify({ error: "Email inválido." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (formData.name.length > 200) {
      return new Response(
        JSON.stringify({ error: "El nombre es demasiado largo." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (formData.message && formData.message.length > 5000) {
      return new Response(
        JSON.stringify({ error: "El mensaje es demasiado largo." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!resendApiKey) throw new Error("RESEND_API_KEY not configured");
    if (!supabaseUrl || !supabaseServiceKey) throw new Error("Supabase configuration not found");

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Rate limit: max 3 submissions per email per hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { count: recentCount } = await supabase
      .from('prospects')
      .select('*', { count: 'exact', head: true })
      .eq('email', formData.email.trim().toLowerCase())
      .gte('created_at', oneHourAgo);

    if ((recentCount ?? 0) >= 3) {
      return new Response(
        JSON.stringify({ error: "Demasiadas solicitudes. Intenta de nuevo más tarde." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const prospectData: any = {
      name: formData.name.trim(),
      email: formData.email.trim().toLowerCase(),
      phone: formData.phone.trim(),
      interest: formData.interest,
      budget: formData.budget || null,
      message: formData.message?.trim() || '',
      status: 'nuevo'
    };

    if (formData.landing_id) prospectData.landing_id = formData.landing_id;

    const { data: prospect, error: prospectError } = await supabase
      .from('prospects')
      .insert(prospectData)
      .select()
      .single();

    if (prospectError) {
      console.error("Error saving prospect:", prospectError);
      throw new Error("Failed to save prospect");
    }

    const { data: siteSettings } = await supabase
      .from('settings')
      .select('company_name')
      .limit(1)
      .maybeSingle();

    const companyName = siteSettings?.company_name || '';

    let landingName = 'Landing Page Principal';
    if (formData.landing_id) {
      const { data: landing } = await supabase
        .from('landings')
        .select('name')
        .eq('id', formData.landing_id)
        .maybeSingle();
      if (landing) landingName = landing.name;
    }

    const registrationDate = new Date(prospect.created_at);
    const formattedDate = registrationDate.toLocaleDateString('es-MX', {
      day: '2-digit', month: 'long', year: 'numeric'
    });
    const formattedTime = registrationDate.toLocaleTimeString('es-MX', {
      hour: '2-digit', minute: '2-digit', hour12: true
    });

    const { data: recipients, error: recipientsError } = await supabase
      .from('email_recipients')
      .select('email, recipient_type')
      .eq('is_active', true);

    if (recipientsError) throw new Error("Failed to fetch email recipients");
    if (!recipients || recipients.length === 0) throw new Error("No active email recipients configured");

    const toRecipients  = recipients.filter((r: EmailRecipient) => r.recipient_type === 'to').map((r: EmailRecipient) => r.email);
    const ccRecipients  = recipients.filter((r: EmailRecipient) => r.recipient_type === 'cc').map((r: EmailRecipient) => r.email);
    const bccRecipients = recipients.filter((r: EmailRecipient) => r.recipient_type === 'bcc').map((r: EmailRecipient) => r.email);

    if (toRecipients.length === 0) throw new Error("No TO recipients configured");

    const interestLabels: Record<string, string> = {
      "comprar": "Comprar", "rentar": "Rentar", "vender": "Vender", "invertir": "Invertir",
    };
    const budgetLabels: Record<string, string> = {
      "0-200k": "Menos de $200,000",
      "200k-500k": "$200,000 - $500,000",
      "500k-1m": "$500,000 - $1,000,000",
      "1m+": "Más de $1,000,000",
    };

    // Escape all user-controlled values before embedding in HTML
    const safeName     = escapeHtml(prospectData.name);
    const safeEmail    = escapeHtml(prospectData.email);
    const safePhone    = escapeHtml(prospectData.phone);
    const safeInterest = escapeHtml(interestLabels[formData.interest] ?? formData.interest);
    const safeBudget   = escapeHtml(budgetLabels[formData.budget] ?? formData.budget ?? '—');
    const safeMessage  = escapeHtml(prospectData.message || 'No se proporcionó mensaje');

    const emailHtml = `
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #1e3a5f; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
            .content { background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }
            .field { margin-bottom: 20px; }
            .label { font-weight: bold; color: #1e3a5f; margin-bottom: 5px; }
            .value { color: #333; padding: 10px; background: white; border-radius: 4px; }
            .info-section { background: #e0f2fe; padding: 15px; border-radius: 4px; margin-bottom: 20px; border-left: 4px solid #1e3a5f; }
            .info-section .label { color: #0c4a6e; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h2>Nuevo Registro de Contacto - ${escapeHtml(companyName)}</h2>
            </div>
            <div class="content">
              <div class="info-section">
                <div class="field">
                  <div class="label">Fecha y Hora de Registro:</div>
                  <div class="value">${formattedDate} a las ${formattedTime}</div>
                </div>
                <div class="field" style="margin-bottom: 0;">
                  <div class="label">Landing de Origen:</div>
                  <div class="value">${escapeHtml(landingName)}</div>
                </div>
              </div>
              <div class="field">
                <div class="label">Nombre Completo:</div>
                <div class="value">${safeName}</div>
              </div>
              <div class="field">
                <div class="label">Correo Electrónico:</div>
                <div class="value">${safeEmail}</div>
              </div>
              <div class="field">
                <div class="label">Teléfono:</div>
                <div class="value">${safePhone}</div>
              </div>
              <div class="field">
                <div class="label">Interés:</div>
                <div class="value">${safeInterest}</div>
              </div>
              <div class="field">
                <div class="label">Presupuesto:</div>
                <div class="value">${safeBudget}</div>
              </div>
              <div class="field">
                <div class="label">Mensaje:</div>
                <div class="value">${safeMessage}</div>
              </div>
            </div>
          </div>
        </body>
      </html>
    `;

    const emailPayload: any = {
      from: `${companyName} <onboarding@resend.dev>`,
      to: toRecipients,
      subject: `Nuevo Registro: ${prospectData.name} - ${interestLabels[formData.interest] ?? formData.interest}`,
      html: emailHtml,
    };

    if (ccRecipients.length > 0)  emailPayload.cc  = ccRecipients;
    if (bccRecipients.length > 0) emailPayload.bcc = bccRecipients;

    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify(emailPayload),
    });

    if (!emailResponse.ok) {
      const errorData = await emailResponse.text();
      console.error("Resend API error:", errorData);
      throw new Error(`Failed to send email (${emailResponse.status})`);
    }

    const emailData = await emailResponse.json();

    return new Response(
      JSON.stringify({ success: true, emailId: emailData.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : error);
    return new Response(
      JSON.stringify({ success: false, error: "No se pudo enviar el formulario. Intenta de nuevo más tarde." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
