-- ============================================================
-- Ndoket — Sauvegarde atomique des disponibilités
-- Empêche la perte totale des dispos si un insert échoue.
-- À exécuter dans Supabase SQL Editor.
-- ============================================================

create or replace function public.save_disponibilites(
  p_prestataire_id uuid,
  p_slots jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  s jsonb;
begin
  -- Le caller doit être le propriétaire du profil prestataire
  if not exists (
    select 1 from public.profils p
    where p.id = auth.uid() and p.prestataire_id = p_prestataire_id
  ) and not exists (
    select 1 from public.prestataires pr
    where pr.id = p_prestataire_id and pr.user_id = auth.uid()
  ) then
    raise exception 'Non autorisé';
  end if;

  -- Supprimer les anciennes dispos
  delete from public.disponibilites where prestataire_id = p_prestataire_id;

  -- Insérer les nouvelles
  for s in select * from jsonb_array_elements(p_slots) loop
    insert into public.disponibilites (prestataire_id, jour_semaine, heure_debut, heure_fin)
    values (
      p_prestataire_id,
      (s->>'jour_semaine')::int,
      (s->>'heure_debut')::time,
      (s->>'heure_fin')::time
    );
  end loop;
end;
$$;

revoke all on function public.save_disponibilites(uuid, jsonb) from public, anon;
grant execute on function public.save_disponibilites(uuid, jsonb) to authenticated;
