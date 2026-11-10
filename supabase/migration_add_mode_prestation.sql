-- Migration: Ajouter mode_prestation à la table services
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS mode_prestation text DEFAULT 'sur_place';
