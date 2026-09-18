import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const body = await request.json().catch(() => null);
  const email = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
  const deviceId = typeof body?.device_id === "string" ? body.device_id.trim() : "";
  if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json({ error: "Invalid request" }, 400);
  }

  const ip = request.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

  const { data: limit, error: limitError } = await admin.rpc("check_verification_rate_limit", {
    p_email: email,
    p_ip: ip,
    p_device: deviceId,
  });
  if (limitError) return json({ error: "Unable to process request" }, 500);
  if (!limit?.[0]?.allowed) {
    return json({ error: "Too many requests", retry_after: limit?.[0]?.retry_after ?? 60 }, 429);
  }

  const response = await fetch(`${supabaseUrl}/auth/v1/resend`, {
    method: "POST",
    headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ type: "signup", email, options: { email_redirect_to: "https://konex-app-rho.vercel.app/auth/callback" } }),
  });
  if (!response.ok) return json({ error: "Unable to send verification email" }, response.status === 429 ? 429 : 502);

  return json({ sent: true });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
