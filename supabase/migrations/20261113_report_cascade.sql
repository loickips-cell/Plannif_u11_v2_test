-- Planinf U11 V2 — report en cascade atomique.
-- Exécuter après 20261113_session_occurrences.sql.
-- La transaction annule toutes les modifications si une validation échoue.
create or replace function public.u11_report_occurrences(p_updates jsonb)
returns void language plpgsql security invoker set search_path=public as $$
declare
  v_item jsonb;
  v_id uuid;
  v_date date;
  v_status text;
  v_owner uuid := auth.uid();
  v_count int;
begin
  if v_owner is null then raise exception 'Authentification requise'; end if;
  if jsonb_typeof(p_updates) <> 'array' or jsonb_array_length(p_updates) < 1
     or jsonb_array_length(p_updates) > 1000 then
    raise exception 'Liste de reports invalide';
  end if;
  if (select count(distinct item->>'id') from jsonb_array_elements(p_updates) item)
     <> jsonb_array_length(p_updates) then
    raise exception 'Occurrences dupliquées';
  end if;
  -- Verrouiller toutes les occurrences de cet éducateur pendant le report.
  perform 1 from public.u11_session_occurrences
   where owner_id=v_owner for update;
  for v_item in select value from jsonb_array_elements(p_updates) loop
    v_id := (v_item->>'id')::uuid;
    v_date := (v_item->>'planned_date')::date;
    v_status := v_item->>'status';
    if v_date is null or extract(isodow from v_date)::int not in (2,3,5) then
      raise exception 'Les reports doivent tomber mardi, mercredi ou vendredi';
    end if;
    if v_status not in ('prevue','reportee') then
      raise exception 'Statut de report invalide';
    end if;
    update public.u11_session_occurrences
       set planned_date=v_date,status=v_status,updated_at=now()
     where id=v_id and owner_id=v_owner and status in ('prevue','reportee');
    get diagnostics v_count=row_count;
    if v_count<>1 then raise exception 'Séance non modifiable ou introuvable'; end if;
  end loop;
  if exists (
    select 1 from public.u11_session_occurrences a
    join public.u11_session_occurrences b
      on a.owner_id=b.owner_id and a.planned_date=b.planned_date and a.id<b.id
    where a.owner_id=v_owner and a.planned_date is not null
      and a.status in ('prevue','reportee','realisee')
      and b.status in ('prevue','reportee','realisee')
  ) then raise exception 'Deux séances occupent le même créneau'; end if;
end;
$$;
revoke all on function public.u11_report_occurrences(jsonb) from public;
grant execute on function public.u11_report_occurrences(jsonb) to authenticated;
