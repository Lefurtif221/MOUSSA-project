-- ============================================================
-- Ndoket — Schéma MVP complet (DROP + CREATE)
-- Exécuter dans Supabase SQL Editor
-- ============================================================

-- Supprimer les anciennes tables si elles existent
DROP TABLE IF EXISTS public.avis CASCADE;
DROP TABLE IF EXISTS public.reservations CASCADE;
DROP TABLE IF EXISTS public.disponibilites CASCADE;
DROP TABLE IF EXISTS public.bloquages CASCADE;
DROP TABLE IF EXISTS public.services CASCADE;
DROP TABLE IF EXISTS public.prestataires CASCADE;
DROP TABLE IF EXISTS public.profils CASCADE;

create extension if not exists "pgcrypto";

-- 1. PROFILS (client ET prestataire)
create table public.profils (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'client' check (role in ('client','prestataire')),
  nom text not null,
  prenom text not null,
  telephone text,
  adresse text,
  avatar_url text,
  bio text,
  date_naissance date,
  prestataire_id uuid,
  created_at timestamptz not null default now()
);

-- 2. PRESTATAIRES
create table public.prestataires (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  nom text not null,
  categorie text not null default 'Coiffure',
  description text,
  adresse text not null,
  ville text not null default 'Dakar',
  note_globale numeric(2,1) not null default 5.0,
  note_count int not null default 0,
  distance_km numeric(4,1) default 1.5,
  telephone text,
  bio text,
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

-- 3. SERVICES
create table public.services (
  id uuid primary key default gen_random_uuid(),
  prestataire_id uuid not null references public.prestataires(id) on delete cascade,
  nom text not null,
  description text,
  prix numeric(10,0) not null,
  duree_min int default 60,
  categorie text default 'General',
  mode_prestation text default 'sur_place',
  actif boolean not null default true,
  created_at timestamptz not null default now()
);

-- 4. DISPONIBILITES
create table public.disponibilites (
  id uuid primary key default gen_random_uuid(),
  prestataire_id uuid not null references public.prestataires(id) on delete cascade,
  jour_semaine int not null check (jour_semaine between 0 and 6),
  heure_debut time not null,
  heure_fin time not null,
  actif boolean not null default true,
  created_at timestamptz not null default now(),
  unique(prestataire_id, jour_semaine, heure_debut)
);

-- 5. BLOQUAGES
create table public.bloquages (
  id uuid primary key default gen_random_uuid(),
  prestataire_id uuid not null references public.prestataires(id) on delete cascade,
  date_specifique date,
  jour_semaine int check (jour_semaine between 0 and 6),
  heure_debut time,
  heure_fin time,
  motif text,
  created_at timestamptz not null default now()
);

-- 6. RESERVATIONS
create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  code text unique not null default 'ND-' || upper(substr(md5(random()::text), 1, 6)),
  client_id uuid references public.profils(id) on delete set null,
  prestataire_id uuid not null references public.prestataires(id),
  service_id uuid not null references public.services(id),
  mode text not null default 'sur_place' check (mode in ('sur_place','a_domicile')),
  adresse_domicile text,
  date_rdv date not null,
  heure_debut time not null,
  heure_fin time not null,
  montant_total int not null,
  nombre_coupes int not null default 1,
  perles boolean not null default false,
  statut text not null default 'confirme' check (statut in ('confirme','paye','termine','annule')),
  paiement_method text check (paiement_method in ('wave','orange','free','especes')),
  paiement_statut text not null default 'sur_place' check (paiement_statut in ('sur_place','paye_online')),
  notes text,
  created_at timestamptz not null default now()
);

-- 7. AVIS
create table public.avis (
  id uuid primary key default gen_random_uuid(),
  prestataire_id uuid not null references public.prestataires(id) on delete cascade,
  client_id uuid references public.profils(id) on delete set null,
  reservation_id uuid references public.reservations(id) on delete set null,
  note int check (note between 1 and 5),
  commentaire text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- INDEX
-- ============================================================
create index idx_services_prestataire on public.services(prestataire_id);
create index idx_reservations_client on public.reservations(client_id);
create index idx_reservations_prestataire on public.reservations(prestataire_id);
create index idx_reservations_date on public.reservations(date_rdv, heure_debut);
create index idx_disponibilites_prestataire on public.disponibilites(prestataire_id);
create index idx_bloquages_prestataire on public.bloquages(prestataire_id);

-- ============================================================
-- RLS
-- ============================================================
alter table public.profils enable row level security;
alter table public.prestataires enable row level security;
alter table public.services enable row level security;
alter table public.disponibilites enable row level security;
alter table public.bloquages enable row level security;
alter table public.reservations enable row level security;
alter table public.avis enable row level security;

-- PROFILS
create policy "own profile" on public.profils for select using (id = auth.uid());
create policy "insert profile" on public.profils for insert with check (id = auth.uid());
create policy "update profile" on public.profils for update using (id = auth.uid());

-- PRESTATAIRES
create policy "public read prestataires" on public.prestataires for select using (true);
create policy "insert prestataire" on public.prestataires for insert with check (auth.uid() is not null);
create policy "update prestataire" on public.prestataires for update using (user_id = auth.uid());

-- SERVICES
create policy "public read services" on public.services for select using (true);
create policy "insert service" on public.services for insert
  with check (
    exists (select 1 from public.prestataires p where p.id = services.prestataire_id and p.user_id = auth.uid())
  );
create policy "update own service" on public.services for update
  using (
    exists (select 1 from public.prestataires p where p.id = services.prestataire_id and p.user_id = auth.uid())
  );
create policy "delete own service" on public.services for delete
  using (
    exists (select 1 from public.prestataires p where p.id = services.prestataire_id and p.user_id = auth.uid())
  );

-- DISPONIBILITES
create policy "public read disponibilites" on public.disponibilites for select using (true);
create policy "insert disponibilite" on public.disponibilites for insert
  with check (
    exists (select 1 from public.prestataires p where p.id = disponibilites.prestataire_id and p.user_id = auth.uid())
  );
create policy "update own disponibilite" on public.disponibilites for update
  using (
    exists (select 1 from public.prestataires p where p.id = disponibilites.prestataire_id and p.user_id = auth.uid())
  );
create policy "delete own disponibilite" on public.disponibilites for delete
  using (
    exists (select 1 from public.prestataires p where p.id = disponibilites.prestataire_id and p.user_id = auth.uid())
  );

-- BLOQUAGES
create policy "public read bloquages" on public.bloquages for select using (true);
create policy "insert bloquage" on public.bloquages for insert
  with check (
    exists (select 1 from public.prestataires p where p.id = bloquages.prestataire_id and p.user_id = auth.uid())
  );
create policy "delete own bloquage" on public.bloquages for delete
  using (
    exists (select 1 from public.prestataires p where p.id = bloquages.prestataire_id and p.user_id = auth.uid())
  );

-- RESERVATIONS
create policy "own reservations" on public.reservations
  for select using (
    client_id = auth.uid() or
    exists (select 1 from public.prestataires p where p.id = reservations.prestataire_id and p.user_id = auth.uid())
  );
create policy "insert reservation" on public.reservations for insert
  with check (client_id = auth.uid());
create policy "update reservation status" on public.reservations for update
  using (
    client_id = auth.uid() or
    exists (select 1 from public.prestataires p where p.id = reservations.prestataire_id and p.user_id = auth.uid())
  );

-- AVIS
create policy "public read avis" on public.avis for select using (true);
create policy "insert avis" on public.avis for insert with check (auth.uid() is not null);

-- ============================================================
-- DONNEES DE DEMO
-- ============================================================
insert into public.prestataires (user_id, nom, categorie, adresse, ville, distance_km, note_globale, note_count, telephone, bio) values
(null, 'Fatou Tresses',   'Coiffure',   'Mermoz, Dakar',     'Dakar', 1.2, 4.9, 128, '+221 77 123 45 67', 'Spécialiste en tresses africaines depuis 8 ans'),
(null, 'Awa Ndiaye',      'Manucure',   'Ouakam, Dakar',     'Dakar', 2.4, 4.8, 96,  '+221 78 234 56 78', 'Manucure et pédicure professionnelle'),
(null, 'Khady Makeup',    'Maquillage', 'Sacre-Coeur, Dakar','Dakar', 3.1, 4.9, 61,  '+221 76 345 67 89', 'Maquillage professionnel et artistique'),
(null, 'Modou Fresh Cut', 'Barbier',    'Mermoz, Dakar',     'Dakar', 0.9, 4.7, 143, '+221 70 456 78 90', 'Barbier moderne, coupes tendance');

-- Services
insert into public.services (prestataire_id, nom, description, prix, duree_min, categorie)
select p.id, s.nom, s.descr, s.prix, s.duree, s.categorie
from public.prestataires p
cross join (values
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
where p.nom = case
  when s.categorie = 'Coiffure' then 'Fatou Tresses'
  when s.categorie = 'Manucure' then 'Awa Ndiaye'
  when s.categorie = 'Maquillage' then 'Khady Makeup'
  when s.categorie = 'Barbier' then 'Modou Fresh Cut'
end;

-- Disponibilités (lun-ven 9h-18h pour tous)
insert into public.disponibilites (prestataire_id, jour_semaine, heure_debut, heure_fin)
select p.id, d.jour, '09:00'::time, '18:00'::time
from public.prestataires p
cross join generate_series(1, 5) as d(jour);

-- Corrections fonctionnelles (voir migration_business_fixes.sql)
alter table public.prestataires add column if not exists wave_numero text;
alter table public.prestataires add column if not exists om_numero text;
alter table public.prestataires add column if not exists paiement_titulaire text;
alter table public.profils add column if not exists genre text;
