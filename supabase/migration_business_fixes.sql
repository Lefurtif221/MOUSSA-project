-- ============================================================
-- Ndoket — Corrections fonctionnelles (comptes de réception, avis, créneaux)
-- Idempotent : peut être relancé. Exécuter dans Supabase SQL Editor.
-- ============================================================

-- 1. Compte de réception de la prestataire (versements manuels Ndoket)
--    La presta y entre son Wave / Orange Money + le nom du titulaire.
alter table public.prestataires add column if not exists wave_numero text;
alter table public.prestataires add column if not exists om_numero text;
alter table public.prestataires add column if not exists paiement_titulaire text;

-- 2. Genre du prestataire (étape d'inscription)
alter table public.profils add column if not exists genre text;

-- 3. Créneaux occupés — visible par la cliente malgré la RLS "own reservations"
--    (sinon les créneaux pris par d'autres clientes restent proposés)
create or replace function public.get_creneaux_pris(p_pid uuid, p_date date)
returns table (heure_debut time, heure_fin time)
language sql
security definer
set search_path = public
stable
as $$
  select r.heure_debut, r.heure_fin
  from public.reservations r
  where r.prestataire_id = p_pid
    and r.date_rdv = p_date
    and r.statut <> 'annule';
$$;
revoke all on function public.get_creneaux_pris(uuid, date) from public, anon;
grant execute on function public.get_creneaux_pris(uuid, date) to authenticated;

-- 4. Compteur public de RDV réalisés (fiche "À propos" — la RLS bloquait le select)
create or replace function public.count_rdv_realises(p_pid uuid)
returns bigint
language sql
security definer
set search_path = public
stable
as $$
  select count(*) from public.reservations r
  where r.prestataire_id = p_pid and r.statut <> 'annule';
$$;
revoke all on function public.count_rdv_realises(uuid) from public, anon;
grant execute on function public.count_rdv_realises(uuid) to authenticated;
