// Ndoket — paytech-init (Edge Function)
// Crée une demande de paiement PayTech et renvoie l'URL de paiement.
// Les clés API PayTech sont lues depuis les secrets serveur :
//   supabase secrets set PAYTECH_API_KEY=... PAYTECH_API_SECRET=...
//   (optionnel) supabase secrets set PAYTECH_ENV=test
// Elles ne sont JAMAIS envoyées au téléphone.

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const METHODS: Record<string, string> = {
  wave: "Wave",
  orange: "Orange Money",
  free: "Free Money",
};

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

serve(async (req: Request) => {
  // Requête préliminaire CORS du navigateur / WebView
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  if (req.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);

  const API_KEY = Deno.env.get("PAYTECH_API_KEY") || "";
  const API_SECRET = Deno.env.get("PAYTECH_API_SECRET") || "";
  const PAY_ENV = Deno.env.get("PAYTECH_ENV") || "prod";
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
  const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (!API_KEY || !API_SECRET || !SUPABASE_URL || !SERVICE_KEY) {
    return json({ error: "Paiement non configuré" }, 500);
  }

  // Cliente authentifiée ?
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

  const amount = parseInt(String(b.montant), 10);
  const target = METHODS[String(b.method)];
  if (!amount || amount < 100) return json({ error: "Montant invalide" }, 400);
  if (!target) return json({ error: "Moyen de paiement invalide" }, 400);
  if (!b.prestataire_id || !b.service_id || !b.date || !b.heure_debut) {
    return json({ error: "Réservation incomplète" }, 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  const ref =
    "NDK-" + Date.now().toString(36).toUpperCase() +
    Math.random().toString(36).slice(2, 7).toUpperCase();

  const { error: insErr } = await admin.from("paiements").insert({
    ref_command: ref,
    client_id: user.id,
    prestataire_id: b.prestataire_id,
    service_id: b.service_id,
    date_rdv: b.date,
    heure_debut: b.heure_debut,
    heure_fin: b.heure_fin || null,
    mode: b.mode || "sur_place",
    adresse_domicile: b.adresse_domicile || "",
    montant: amount,
    method: String(b.method),
    note: b.note || "",
    nombre_coupes: Math.min(10, Math.max(1, parseInt(String(b.nombre_coupes), 10) || 1)),
    perles: b.perles === true || b.perles === "true",
    photo_reference: b.photo_ref || null,
    localisation_client: b.localisation_client || null,
    statut: "pending",
  });
  if (insErr) return json({ error: "Erreur enregistrement" }, 500);

  // Téléphone + nom pour pré-remplir la page PayTech
  const { data: prof } = await admin.from("profils")
    .select("prenom,nom,telephone").eq("id", user.id).single();

  const payload = {
    item_name: b.service_nom || "Réservation Ndoket",
    item_price: amount,
    currency: "XOF",
    ref_command: ref,
    command_name: "Réservation Ndoket " + ref,
    env: PAY_ENV,
    target_payment: target,
    ipn_url: SUPABASE_URL + "/functions/v1/paytech-ipn",
    success_url: "https://lefurtif221.github.io/ndoket-site/payment.html?status=success&ref=" + ref,
    cancel_url: "https://lefurtif221.github.io/ndoket-site/payment.html?status=cancel&ref=" + ref,
    custom_field: JSON.stringify({ ref }),
  };

  let pr: Response;
  try {
    pr = await fetch("https://paytech.sn/api/payment/request-payment", {
      method: "POST",
      headers: {
        "API_KEY": API_KEY,
        "API_SECRET": API_SECRET,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch {
    await admin.from("paiements").update({ statut: "erreur" }).eq("ref_command", ref);
    return json({ error: "PayTech injoignable, réessayez" }, 502);
  }

  let pj: Record<string, unknown> = {};
  try {
    pj = await pr.json();
  } catch {
    /* ignore */
  }
  if (pj.success !== 1 || !pj.redirect_url) {
    await admin.from("paiements").update({ statut: "erreur" }).eq("ref_command", ref);
    const msg = typeof pj.message === "string" && pj.message ? pj.message : "Paiement refusé par PayTech";
    return json({ error: msg }, 400);
  }

  // Pré-remplissage : ?pn=+221...&nn=...&fn=Nom&tp=Méthode&nac=1
  let url = String(pj.redirect_url);
  const digits = ((prof && prof.telephone) || "").replace(/\D/g, "");
  if (digits.length >= 9) {
    const nn = digits.startsWith("221") ? digits.slice(3) : digits.slice(-9);
    const fn = (((prof && prof.prenom) || "") + " " + ((prof && prof.nom) || "")).trim();
    const qs = new URLSearchParams({
      pn: "+" + digits,
      nn,
      fn,
      tp: target,
      nac: "1",
    }).toString();
    url += (url.includes("?") ? "&" : "?") + qs;
  }

  await admin.from("paiements").update({ paytech_token: (pj.token as string) || null })
    .eq("ref_command", ref);

  return json({ redirect_url: url, ref_command: ref });
});
