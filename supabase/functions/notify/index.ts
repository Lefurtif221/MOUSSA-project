// Ndoket — notify (Edge Function)
// Envoie une notification push FCM à un utilisateur.
// Sécurisé par le JWT utilisateur + service role côté serveur.
//
// Corps attendu :
// { to: "user" | "prestataire", prestataire_id?, client_id?, title, body, data? }

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

async function sendFcm(token: string, title: string, body: string, data: Record<string, string>): Promise<boolean> {
  const SERVER_KEY = Deno.env.get("FCM_SERVER_KEY") || "";
  if (!SERVER_KEY) return false;

  // API HTTP v1 de FCM
  const accessToken = await getFcmAccessToken();
  if (!accessToken) return false;

  try {
    const res = await fetch("https://fcm.googleapis.com/v1/projects/ndoket-cac43/messages:send", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id: "ndoket_default",
              sound: "default",
              click_action: "OPEN_ACTIVITY_1",
            },
          },
        },
      }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

async function getFcmAccessToken(): Promise<string | null> {
  const SA_KEY = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
  if (!SA_KEY) return null;

  try {
    const sa = JSON.parse(SA_KEY);
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: "RS256", typ: "JWT" };
    const nowStr = Math.floor(Date.now() / 1000).toString();
    const exp = (now + 3600).toString();

    const claims = {
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: nowStr,
      exp: exp,
    };

    const b64 = (obj: unknown) => btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    const unsigned = `${b64(header)}.${b64(claims)}`;

    // Importer la clé privée RSA
    const keyData = atob(sa.private_key.replace(/-----BEGIN PRIVATE KEY-----\n/, "").replace(/\n-----END PRIVATE KEY-----/, "").replace(/\n/g, ""));
    const keyBytes = new Uint8Array([...keyData].map((c) => c.charCodeAt(0)));
    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      keyBuffer(keyBytes),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(unsigned));
    const b64sig = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${unsigned}.${b64sig}`,
    });
    const tokenJson = await tokenRes.json();
    return tokenJson.access_token || null;
  } catch {
    return null;
  }
}

function keyBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  if (req.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
  const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  // Vérifier l'authentification
  const auth = req.headers.get("Authorization") || "";
  const supaUser = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await supaUser.auth.getUser();
  if (!user) return json({ error: "Non autorisé" }, 401);

  let b: Record<string, unknown> = {};
  try {
    b = await req.json();
  } catch {
    return json({ error: "Requête invalide" }, 400);
  }

  const title = String(b.title || "Ndoket");
  const body = String(b.body || "");
  const to = String(b.to || "");
  const data = (b.data as Record<string, string>) || {};

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // Récupérer les jetons cibles
  let tokens: string[] = [];
  if (to === "prestataire" && b.prestataire_id) {
    const { data: rows } = await admin.rpc("get_prestataire_tokens", {
      p_prestataire_id: b.prestataire_id,
    });
    tokens = (rows || []).map((r: { token: string }) => r.token);
  } else if (to === "user" && b.user_id) {
    const { data: rows } = await admin.rpc("get_client_tokens", {
      p_client_id: b.user_id,
    });
    tokens = (rows || []).map((r: { token: string }) => r.token);
  } else {
    return json({ error: "Destinataire invalide" }, 400);
  }

  if (!tokens.length) return json({ sent: 0, message: "Aucun appareil enregistré" });

  let sent = 0;
  for (const token of tokens) {
    const ok = await sendFcm(token, title, body, data);
    if (ok) sent++;
  }

  return json({ sent, total: tokens.length });
});
