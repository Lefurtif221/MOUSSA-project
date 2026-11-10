-- ============================================================
-- Ndoket — Notifications push (FCM)
-- Table des jetons de notification + fonctions d'envoi.
-- À exécuter dans Supabase SQL Editor.
-- ============================================================

-- 1. Table des jetons FCM
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text default 'android',
  created_at timestamptz not null default now(),
  unique(user_id, token)
);

alter table public.push_tokens enable row level security;

-- Chacun gère ses propres jetons
drop policy if exists "own push tokens" on public.push_tokens;
create policy "own push tokens" on public.push_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2. Fonction : enregistrer un jeton (upsert)
create or replace function public.save_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.push_tokens (user_id, token, platform)
  values (auth.uid(), p_token, 'android')
  on conflict (user_id, token) do nothing;
end;
$$;

revoke all on function public.save_push_token(text) from public, anon;
grant execute on function public.save_push_token(text) to authenticated;

-- 3. Fonction : retirer un jeton (déconnexion)
create or replace function public.remove_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.push_tokens where user_id = auth.uid() and token = p_token;
end;
$$;

revoke all on function public.remove_push_token(text) from public, anon;
grant execute on function public.remove_push_token(text) to authenticated;

-- 4. Fonction : récupérer les jetons d'un prestataire (pour lui envoyer des notifs)
create or replace function public.get_prestataire_tokens(p_prestataire_id uuid)
returns table(token text)
language sql
security definer
set search_path = public
stable
as $$
  select pt.token
  from public.push_tokens pt
  join public.profils p on p.id = pt.user_id
  where p.prestataire_id = p_prestataire_id;
$$;

revoke all on function public.get_prestataire_tokens(uuid) from public, anon;
grant execute on function public.get_prestataire_tokens(uuid) to authenticated;

-- 5. Fonction : récupérer les jetons d'une cliente
create or replace function public.get_client_tokens(p_client_id uuid)
returns table(token text)
language sql
security definer
set search_path = public
stable
as $$
  select pt.token
  from public.push_tokens pt
  where pt.user_id = p_client_id;
$$;

revoke all on function public.get_client_tokens(uuid) from public, anon;
grant execute on function public.get_client_tokens(uuid) to authenticated;
