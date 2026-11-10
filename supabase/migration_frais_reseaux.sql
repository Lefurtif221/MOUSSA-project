-- ============================================================
-- Ndoket — Frais de déplacement + réseaux sociaux + catégories
-- Exécuter dans Supabase SQL Editor
-- ============================================================

-- 1. Frais de déplacement du prestataire (0 = gratuit)
ALTER TABLE public.prestataires ADD COLUMN IF NOT EXISTS frais_deplacement integer NOT NULL DEFAULT 0;

-- 2. Réseaux sociaux
ALTER TABLE public.prestataires ADD COLUMN IF NOT EXISTS instagram text;
ALTER TABLE public.prestataires ADD COLUMN IF NOT EXISTS tiktok text;
ALTER TABLE public.prestataires ADD COLUMN IF NOT EXISTS facebook text;

-- 3. Catégories de services standardisées (3 seulement)
UPDATE public.services SET categorie = 'Pose d''ongles' WHERE categorie IN ('Pose ongles', 'Ongles', 'Ongle', 'Onglerie', 'Manucure');
UPDATE public.services SET categorie = 'Pose de cils' WHERE categorie IN ('Pose cils', 'Cils', 'Maquillage');
UPDATE public.services SET categorie = 'Coiffure' WHERE categorie IN ('Coiffure', 'Coiffures', 'Tresses & nattes', 'Coiffure homme', 'Barbier');

UPDATE public.prestataires SET categorie = 'Pose d''ongles' WHERE categorie IN ('Pose ongles', 'Ongles', 'Ongle', 'Onglerie', 'Manucure', 'Manucure & pédicure');
UPDATE public.prestataires SET categorie = 'Pose de cils' WHERE categorie IN ('Pose cils', 'Cils', 'Maquillage');
UPDATE public.prestataires SET categorie = 'Coiffure' WHERE categorie IN ('Coiffure', 'Coiffures', 'Tresses & nattes', 'Coiffure homme', 'Barbier');
