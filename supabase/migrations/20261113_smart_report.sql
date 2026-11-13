-- Planinf U11 V2 : report intelligent atomique, sans suppression de données.
-- À exécuter une fois dans Supabase SQL Editor.
create or replace function public.u11_apply_smart_report(p_updates jsonb)
returns void language plpgsql security invoker set search_path=public as $$
declare
 v_owner uuid := auth.uid();
 v_item jsonb;
 v_id uuid;
 v_date date;
 v_status text;
 v_count integer;
 v_index integer := 0;
begin
 if v_owner is null then raise exception 'Authentification requise'; end if;
 if jsonb_typeof(p_updates) is distinct from 'array' or
    jsonb_array_length(p_updates) not between 1 and 1000 then
  raise exception 'Liste de reports invalide';
 end if;
 if (select count(distinct item->>'id') from jsonb_array_elements(p_updates) item)
    <> jsonb_array_length(p_updates) then
  raise exception 'Occurrences dupliquees';
 end if;
 perform 1 from public.u11_session_occurrences where owner_id=v_owner for update;
 for v_item in select value from jsonb_array_elements(p_updates) loop
  v_index := v_index+1;
  v_id := (v_item->>'id')::uuid;
  v_date := (v_item->>'planned_date')::date;
  v_status := v_item->>'status';
  if v_date is null or v_status not in ('prevue','reportee') then
   raise exception 'Date ou statut invalide';
  end if;
  -- Le premier changement est la date choisie manuellement, libre.
  -- Les changements suivants sont automatiques : jamais pendant les treves.
  if v_index>1 and (
    (v_date between date '2026-10-19' and date '2026-11-02') or
    (v_date between date '2026-12-14' and date '2027-01-05') or
    extract(isodow from v_date)::integer not in (2,3,5)
  ) then
   raise exception 'Decalage automatique interdit pendant les treves ou hors entrainement';
  end if;
  update public.u11_session_occurrences
   set planned_date=v_date,status=v_status,updated_at=now()
   where id=v_id and owner_id=v_owner and status in ('prevue','reportee');
  get diagnostics v_count=row_count;
  if v_count<>1 then raise exception 'Seance non modifiable ou introuvable'; end if;
 end loop;
 if exists (
  select 1 from public.u11_session_occurrences a
  join public.u11_session_occurrences b
   on a.owner_id=b.owner_id and a.planned_date=b.planned_date and a.id<b.id
  where a.owner_id=v_owner and a.planned_date is not null
   and a.status in ('prevue','reportee','realisee')
   and b.status in ('prevue','reportee','realisee')
 ) then raise exception 'Deux seances occupent la meme date'; end if;
end;
$$;
revoke all on function public.u11_apply_smart_report(jsonb) from public;
grant execute on function public.u11_apply_smart_report(jsonb) to authenticated;
