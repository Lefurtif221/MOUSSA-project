-- ============================================================
-- Ndoket — Données de démo (exécuter APRÈS le schéma, une seule fois)
-- ============================================================

-- Nettoyage total du catalogue (reproductible)
truncate table public.reservations cascade;
truncate table public.avis cascade;
truncate table public.services cascade;
truncate table public.prestataires cascade;

insert into public.prestataires (nom, categorie, adresse, ville, distance_km, note_globale, note_count) values
('Fatou Tresses',   'Coiffure',   'Mermoz, Dakar',      'Dakar', 1.2, 4.9, 128),
('Awa Ndiaye',      'Manucure',   'Ouakam, Dakar',      'Dakar', 2.4, 4.8, 96),
('Khady Makeup',    'Maquillage', 'Sacre-Coeur, Dakar', 'Dakar', 3.1, 4.9, 61),
('Modou Fresh Cut', 'Barbier',    'Mermoz, Dakar',      'Dakar', 0.9, 4.7, 143);

insert into public.services (prestataire_id, nom, prix, duree_min)
select id, 'Tresses complètes', 15000, 120 from public.prestataires where nom = 'Fatou Tresses'
union all
select id, 'Nattes collées', 12000, 90  from public.prestataires where nom = 'Fatou Tresses'
union all
select id, 'Coupe + défrisage', 8000, 60 from public.prestataires where nom = 'Fatou Tresses'
union all
select id, 'Manucure classique', 5000, 45  from public.prestataires where nom = 'Awa Ndiaye'
union all
select id, 'Manucure + gel', 10000, 75    from public.prestataires where nom = 'Awa Ndiaye'
union all
select id, 'Make-up complet', 15000, 60   from public.prestataires where nom = 'Khady Makeup'
union all
select id, 'Maquillage mariée', 40000, 120 from public.prestataires where nom = 'Khady Makeup'
union all
select id, 'Coupe homme', 3000, 30        from public.prestataires where nom = 'Modou Fresh Cut'
union all
select id, 'Barbe + coupe', 5000, 45      from public.prestataires where nom = 'Modou Fresh Cut';