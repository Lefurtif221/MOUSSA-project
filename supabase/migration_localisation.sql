-- Ndoket — Localisation partagée dans le détail du rendez-vous
-- Le client et le prestataire peuvent envoyer leur position ;
-- elle s'affiche dans le détail du RDV et s'ouvre dans Google Maps.
-- À exécuter dans l'éditeur SQL Supabase.

alter table public.reservations add column if not exists localisation_client text;
alter table public.reservations add column if not exists localisation_presta text;
