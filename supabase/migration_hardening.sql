-- ============================================================
-- Ndoket — Migration de durcissement (sécurité + cohérence)
-- Idempotent : peut être relancé. À exécuter dans Supabase SQL Editor.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Réservations : options de commande (coupes / perles) + note client
--    (ces colonnes étaient calculées/paiées dans l'app mais jamais stockées)
-- ------------------------------------------------------------
alter table public.reservations add column if not exists nombre_coupes int not null default 1;
alter table public.reservations add column if not exists perles boolean not null default false;
alter table public.reservations add column if not exists notes text;

-- même chose sur la table de paiements (buffer avant création de la réservation)
alter table public.paiements add column if not exists nombre_coupes int not null default 1;
alter table public.paiements add column if not exists perles boolean not null default false;

-- ------------------------------------------------------------
-- 2. Durcissement des mises à jour de réservations
--    Le client ne peut modifier QUE : son annulation + sa position.
--    (empêche de se marquer "payé" soi-même ou de changer le montant)
-- ------------------------------------------------------------
revoke update on table public.reservations from anon, authenticated;
grant update (statut, localisation_client, localisation_presta)
  on table public.reservations to authenticated;

drop trigger if exists trg_reservations_statut_guard on public.reservations;
create or replace function public.reservations_statut_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- service_role (paytech-ipn) : auth.uid() est null → passe
  if auth.uid() is null then
    return new;
  end if;
  if new.statut is distinct from old.statut then
    -- la cliente ne peut qu'annuler sa réservation
    if auth.uid() = old.client_id and new.statut <> 'annule' then
      raise exception 'Seule une annulation est autorisée depuis l''application cliente';
    end if;
  end if;
  return new;
end;
$$;
create trigger trg_reservations_statut_guard
  before update on public.reservations
  for each row execute function public.reservations_statut_guard();

-- ------------------------------------------------------------
-- 3. Avis : un seul avis par réservation + note du prestataire recalculée
-- ------------------------------------------------------------
create unique index if not exists uq_avis_reservation
  on public.avis (reservation_id) where reservation_id is not null;

drop policy if exists "insert avis" on public.avis;
create policy "insert avis" on public.avis for insert
  with check (client_id = auth.uid());

drop trigger if exists trg_avis_recalc on public.avis;
create or replace function public.avis_after_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid := coalesce(new.prestataire_id, old.prestataire_id);
begin
  update public.prestataires p set
    note_count = (select count(*) from public.avis a where a.prestataire_id = target),
    note_globale = coalesce(
      (select round(avg(a.note)::numeric, 1) from public.avis a where a.prestataire_id = target),
      p.note_globale)
  where p.id = target;
  return null;
end;
$$;
create trigger trg_avis_recalc
  after insert or update or delete on public.avis
  for each row execute function public.avis_after_change();

-- ------------------------------------------------------------
-- 4. Lecture des profils des interlocuteurs (RLS "own profile" trop stricte)
--    Retourne prénom/nom/tél/adresse/position des personnes liées par une
--    réservation (client ↔ prestataire), sans exposer les autres profils.
-- ------------------------------------------------------------
drop function if exists public.get_profils_brief(uuid[]);
create or replace function public.get_profils_brief(p_ids uuid[])
returns table (
  id uuid,
  prenom text,
  nom text,
  telephone text,
  adresse text,
  latitude double precision,
  longitude double precision
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.prenom, p.nom, p.telephone, p.adresse, p.latitude, p.longitude
  from public.profils p
  where p.id = any(p_ids)
    and (
      p.id = auth.uid()
      or exists ( -- mes clientes (je suis leur prestataire)
        select 1 from public.reservations r
        join public.prestataires pr on pr.id = r.prestataire_id and pr.user_id = auth.uid()
        where r.client_id = p.id
      )
      or exists ( -- ma prestataire (je suis sa cliente)
        select 1 from public.reservations r
        join public.prestataires pr on pr.id = r.prestataire_id and pr.user_id = p.id
        where r.client_id = auth.uid()
      )
    );
$$;

revoke all on function public.get_profils_brief(uuid[]) from public, anon;
grant execute on function public.get_profils_brief(uuid[]) to authenticated;
