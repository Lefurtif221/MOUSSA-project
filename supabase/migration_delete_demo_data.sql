-- Supprimer les données de démonstration
-- 1. Réservations de démo
DELETE FROM public.reservations
WHERE client_id NOT IN (SELECT id FROM public.profils WHERE role = 'client')
   OR client_id IS NULL;

-- 2. Services des prestataires démo (pas liés à un vrai user)
DELETE FROM public.services
WHERE prestataire_id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);

-- 3. Prestataires démo (pas liés à un profil)
DELETE FROM public.prestataires
WHERE id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);

-- 4. Avis des prestataires démo
DELETE FROM public.avis
WHERE prestataire_id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);

-- 5. Disponibilités des prestataires démo
DELETE FROM public.disponibilites
WHERE prestataire_id NOT IN (
  SELECT prestataire_id FROM public.profils WHERE prestataire_id IS NOT NULL
);

-- 6. Comptes profils qui ne sont pas des vrais auth users
DELETE FROM public.profils
WHERE id NOT IN (SELECT id FROM auth.users);
