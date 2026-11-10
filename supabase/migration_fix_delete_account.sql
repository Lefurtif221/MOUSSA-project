-- ============================================================
-- Ndoket — Permettre la suppression de compte prestataire
-- Problème : reservations.prestataire_id bloque la cascade.
-- Solution : ON DELETE SET NULL (les réservations historiques restent).
-- À exécuter dans Supabase SQL Editor.
-- ============================================================

-- Supprimer l'ancienne contrainte FK et la recréer avec SET NULL
alter table public.reservations
  drop constraint if exists reservations_prestataire_id_fkey;

alter table public.reservations
  add constraint reservations_prestataire_id_fkey
  foreign key (prestataire_id)
  references public.prestataires(id)
  on delete set null;

-- Aussi pour les services et disponibilites (déjà CASCADE mais on s'assure)
alter table public.services
  drop constraint if exists services_prestataire_id_fkey;

alter table public.services
  add constraint services_prestataire_id_fkey
  foreign key (prestataire_id)
  references public.prestataires(id)
  on delete cascade;

alter table public.disponibilites
  drop constraint if exists disponibilites_prestataire_id_fkey;

alter table public.disponibilites
  add constraint disponibilites_prestataire_id_fkey
  foreign key (prestataire_id)
  references public.prestataires(id)
  on delete cascade;

-- La table photos aussi
alter table public.photos
  drop constraint if exists photos_prestataire_id_fkey;

alter table public.photos
  add constraint photos_prestataire_id_fkey
  foreign key (prestataire_id)
  references public.prestataires(id)
  on delete cascade;
