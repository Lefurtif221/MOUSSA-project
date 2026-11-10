-- ============================================================
-- Ndoket — Migration : photos + profil + nettoyage démo
-- Exécuter dans Supabase SQL Editor
-- ============================================================

-- 1. Colonnes photos sur services
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS photo_url text;

-- 2. Colonnes photos profil sur prestataires
ALTER TABLE public.prestataires ADD COLUMN IF NOT EXISTS photo_url text;
ALTER TABLE public.prestataires ADD COLUMN IF NOT EXISTS cover_url text;
ALTER TABLE public.prestataires ADD COLUMN IF NOT EXISTS galerie jsonb DEFAULT '[]'::jsonb;

-- 3. Table galerie photos
CREATE TABLE IF NOT EXISTS public.photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prestataire_id uuid NOT NULL REFERENCES public.prestataires(id) ON DELETE CASCADE,
  url text NOT NULL,
  legende text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "photos lecture publique" ON public.photos FOR SELECT USING (true);
CREATE POLICY "photos insert proprio" ON public.photos FOR INSERT WITH CHECK (
  auth.uid() IN (SELECT user_id FROM public.prestataires WHERE id = prestataire_id)
);
CREATE POLICY "photos delete proprio" ON public.photos FOR DELETE USING (
  auth.uid() IN (SELECT user_id FROM public.prestataires WHERE id = prestataire_id)
);

-- 4. Storage bucket photos
INSERT INTO storage.buckets (id, name, public) VALUES ('ndoket-photos', 'ndoket-photos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "photos bucket lecture" ON storage.objects FOR SELECT
  USING (bucket_id = 'ndoket-photos');
CREATE POLICY "photos bucket upload" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'ndoket-photos' AND auth.role() = 'authenticated');
CREATE POLICY "photos bucket delete" ON storage.objects FOR DELETE
  USING (bucket_id = 'ndoket-photos' AND auth.role() = 'authenticated');

-- 5. Supprimer données démo (ordre : réservations avant services)
DELETE FROM public.photos WHERE prestataire_id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);
DELETE FROM public.reservations WHERE client_id IS NULL
   OR client_id NOT IN (SELECT id FROM public.profils WHERE role = 'client')
   OR service_id IN (
     SELECT s.id FROM public.services s
     WHERE s.prestataire_id NOT IN (
       SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
     )
   );
DELETE FROM public.services WHERE prestataire_id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);
DELETE FROM public.avis WHERE prestataire_id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);
DELETE FROM public.disponibilites WHERE prestataire_id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);
DELETE FROM public.prestataires WHERE id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);
DELETE FROM public.profils WHERE id NOT IN (SELECT id FROM auth.users);
