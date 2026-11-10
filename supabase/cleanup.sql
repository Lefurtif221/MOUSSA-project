-- Nettoyage complet
DELETE FROM public.avis;
DELETE FROM public.reservations;
DELETE FROM public.disponibilites;
DELETE FROM public.bloquages;
DELETE FROM public.services;
DELETE FROM public.profils;
DELETE FROM public.prestataires;

-- Réinsérer les prestataires de démo SANS user_id
INSERT INTO public.prestataires (nom, categorie, adresse, ville, distance_km, note_globale, note_count, telephone, bio) VALUES
('Fatou Tresses',   'Coiffure',   'Mermoz, Dakar',     'Dakar', 1.2, 4.9, 128, '+221 77 123 45 67', 'Spécialiste en tresses africaines depuis 8 ans'),
('Awa Ndiaye',      'Manucure',   'Ouakam, Dakar',     'Dakar', 2.4, 4.8, 96,  '+221 78 234 56 78', 'Manucure et pédicure professionnelle'),
('Khady Makeup',    'Maquillage', 'Sacre-Coeur, Dakar','Dakar', 3.1, 4.9, 61,  '+221 76 345 67 89', 'Maquillage professionnel et artistique'),
('Modou Fresh Cut', 'Barbier',    'Mermoz, Dakar',     'Dakar', 0.9, 4.7, 143, '+221 70 456 78 90', 'Barbier moderne, coupes tendance');

-- Services
INSERT INTO public.services (prestataire_id, nom, description, prix, duree_min, categorie)
SELECT p.id, s.nom, s.descr, s.prix, s.duree, s.categorie
FROM public.prestataires p
CROSS JOIN (VALUES
  ('Tresses complètes', 'Tresses africaines, tressage complet', 15000, 120, 'Coiffure'),
  ('Nattes collées', 'Installation de nattes collées', 12000, 90, 'Coiffure'),
  ('Coupe + défrisage', 'Coupe et défrisage professionnel', 8000, 60, 'Coiffure'),
  ('Manucure classique', 'Manucure avec vernis', 5000, 45, 'Manucure'),
  ('Manucure + Art', 'Manucure avec nail art', 8000, 60, 'Manucure'),
  ('Maquillage mariage', 'Maquillage complet pour mariage', 25000, 90, 'Maquillage'),
  ('Maquillage soirée', 'Maquillage élégant pour soirée', 15000, 60, 'Maquillage'),
  ('Coupe homme', 'Coupe moderne pour homme', 3000, 30, 'Barbier'),
  ('Coupe + Barbe', 'Coupe et taille de barbe', 5000, 45, 'Barbier')
) as s(nom, descr, prix, duree, categorie)
WHERE p.nom = CASE
  WHEN s.categorie = 'Coiffure' THEN 'Fatou Tresses'
  WHEN s.categorie = 'Manucure' THEN 'Awa Ndiaye'
  WHEN s.categorie = 'Maquillage' THEN 'Khady Makeup'
  WHEN s.categorie = 'Barbier' THEN 'Modou Fresh Cut'
END;

-- Disponibilités
INSERT INTO public.disponibilites (prestataire_id, jour_semaine, heure_debut, heure_fin)
SELECT p.id, d.jour, '09:00'::time, '18:00'::time
FROM public.prestataires p
CROSS JOIN generate_series(1, 5) as d(jour);