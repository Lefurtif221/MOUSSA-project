// Ndoket — paytech-ipn (Edge Function)
// Reçoit les notifications PayTech (IPN, formulaire POST), vérifie les
// signatures SHA-256, puis :
//   sale_complete → statut "paye" + création automatique de la réservation
//   sale_canceled → statut "annule"
// Idempotent : un IPN rejoué ne crée jamais de doublon.

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function sha256hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

function methodToDb(method: string): string {
  if (method === "orange") return "orange";
  if (method === "free") return "free";
  return "wave";
}

serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("OK", { status: 200 });

  const API_KEY = Deno.env.get("PAYTECH_API_KEY") || "";
  const API_SECRET = Deno.env.get("PAYTECH_API_SECRET") || "";
  if (!API_KEY || !API_SECRET) return new Response("Non configuré", { status: 500 });

  // PayTech envoie du FORMULAIRE encodé, pas du JSON
  const raw = await req.text();
  const p = new URLSearchParams(raw);
  const g = (k: string) => p.get(k) || "";
  const ref = g("ref_command");
  const type = g("type_event");

  if ((await sha256hex(API_KEY)) !== g("api_key_sha256")) {
    return new Response("Clé API invalide", { status: 401 });
  }
  if ((await sha256hex(API_SECRET)) !== g("api_secret_sha256")) {
    return new Response("Secret invalide", { status: 401 });
  }
  if (!ref) return new Response("Sans référence", { status: 400 });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") || "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
  );
  const { data: pay } = await admin.from("paiements")
    .select("*").eq("ref_command", ref).single();
  if (!pay) return new Response("Paiement inconnu", { status: 404 });

  if (type === "sale_complete") {
    if (pay.statut !== "paye") {
      if (!pay.reservation_id) {
        const { data: r, error } = await admin.from("reservations").insert({
          client_id: pay.client_id,
          prestataire_id: pay.prestataire_id,
          service_id: pay.service_id,
          date_rdv: pay.date_rdv,
          heure_debut: pay.heure_debut,
          heure_fin: pay.heure_fin,
          mode: pay.mode || "sur_place",
          adresse_domicile: pay.adresse_domicile || "",
          paiement_method: methodToDb(pay.method),
          montant_total: pay.montant,
          statut: "paye",
          paiement_statut: "paye_online",
          notes: pay.note || "",
          nombre_coupes: pay.nombre_coupes || 1,
          perles: !!pay.perles,
          photo_reference: pay.photo_reference,
          localisation_client: pay.localisation_client,
          transaction_ref: pay.ref_command,
        }).select("id").single();
        if (error || !r) return new Response("Erreur réservation", { status: 500 });
        await admin.from("paiements")
          .update({ statut: "paye", reservation_id: r.id }).eq("id", pay.id);
      } else {
        await admin.from("paiements").update({ statut: "paye" }).eq("id", pay.id);
        await admin.from("reservations")
          .update({ statut: "paye", paiement_statut: "paye_online" })
          .eq("id", pay.reservation_id);
      }
    }
  } else if (type === "sale_canceled") {
    await admin.from("paiements").update({ statut: "annule" }).eq("id", pay.id);
  }
  return new Response("OK", { status: 200 });
});
