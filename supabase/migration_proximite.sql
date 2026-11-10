-- Ndoket — Système de proximité
-- Position (GPS) enregistrée à l'inscription et modifiable dans "Mes informations".
-- Sert à trier les prestataires / clients par distance la plus proche.
-- À exécuter dans l'éditeur SQL Supabase.

alter table public.profils add column if not exists latitude double precision;
alter table public.profils add column if not exists longitude double precision;

alter table public.prestataires add column if not exists latitude double precision;
alter table public.prestataires add column if not exists longitude double precision;
