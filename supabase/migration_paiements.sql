-- Ndoket — Paiements en ligne PayTech (Wave / Orange Money / Free Money)
-- 1) La cliente choisit un moyen de paiement → l'app appelle la fonction
--    "paytech-init" qui crée une ligne "pending" ici + une demande PayTech.
-- 2) PayTech notifie la fonction "paytech-ipn" → statut "paye" + création
--    automatique de la réservation (plus de paiement en espèces).
-- À exécuter dans l'éditeur SQL Supabase (idempotent : peut être relancé).

create table if not exists public.paiements (
  id uuid primary key default gen_random_uuid(),
  ref_command text unique not null,
  client_id uuid references public.profils(id) on delete set null,
  prestataire_id uuid references public.prestataires(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  date_rdv date,
  heure_debut time,
  heure_fin time,
  mode text,
  adresse_domicile text,
  montant int not null,
  method text,
  note text,
  photo_reference text,
  localisation_client text,
  statut text not null default 'pending',
  paytech_token text,
  reservation_id uuid references public.reservations(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.paiements enable row level security;

drop policy if exists "own paiements" on public.paiements;
create policy "own paiements" on public.paiements
  for select using (client_id = auth.uid());

-- Colonnes utilisées par le flux de commande (si migrations précédentes non jouées)
alter table public.reservations add column if not exists photo_reference text;
alter table public.reservations add column if not exists localisation_client text;
alter table public.reservations add column if not exists localisation_presta text;
alter table public.reservations add column if not exists transaction_ref text;
