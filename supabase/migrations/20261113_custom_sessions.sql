-- Planinf U11 V2 : séances supplémentaires, sans modifier les séances initiales.
-- À exécuter dans Supabase SQL Editor avant d'utiliser le formulaire.
begin;
alter table public.u11_sessions add column if not exists owner_id uuid references auth.users(id);
alter table public.u11_sessions add column if not exists is_custom boolean not null default false;
alter table public.u11_sessions add column if not exists principle text;
create sequence if not exists public.u11_custom_session_number_seq start with 47;
alter table public.u11_sessions enable row level security;
drop policy if exists "u11_custom_sessions_select_own" on public.u11_sessions;
create policy "u11_custom_sessions_select_own" on public.u11_sessions
 for select to authenticated using (is_custom=true and owner_id=(select auth.uid()));
create or replace function public.u11_create_custom_session(
 p_date date,p_title text,p_phase text default null,p_theme text default null,
 p_principle text default null,p_notes text default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid();v_id uuid;v_n bigint;v_code text;
begin
 if v_user is null then raise exception 'Authentification requise'; end if;
 if p_date is null or length(trim(coalesce(p_title,'')))<1 then
  raise exception 'Date et nom obligatoires';end if;
 if p_phase is not null and p_phase<>'' and p_phase not in
  ('ON A LE BALLON','TRANSITION DÉFENSIVE','ON N’A PAS LE BALLON','TRANSITION OFFENSIVE')
 then raise exception 'Phase FFF invalide';end if;
 if exists(select 1 from public.u11_session_occurrences
   where owner_id=v_user and planned_date=p_date and status<>'annulee') then
  raise exception 'Une séance occupe déjà cette date';end if;
 v_n:=nextval('public.u11_custom_session_number_seq');
 v_code:='SUP-'||v_n::text;
 insert into public.u11_sessions
 (session_code,session_number,session_type,month_name,phase,theme,tasks,owner_id,is_custom,principle)
 values(v_code,v_n,'football',to_char(p_date,'TMMonth'),nullif(p_phase,''),
        coalesce(nullif(trim(p_theme),''),trim(p_title)),
        jsonb_build_array(
         jsonb_build_object('name','Échauffement technique'),
         jsonb_build_object('name','Exercice technique orienté'),
         jsonb_build_object('name','Situation'),
         jsonb_build_object('name','Jeu')),
        v_user,true,nullif(trim(p_principle),''))
 returning id into v_id;
 insert into public.u11_session_occurrences(owner_id,session_id,planned_date,status,notes)
 values(v_user,v_id,p_date,'prevue',coalesce(p_notes,''));
 return v_id;
end;$$;
create or replace function public.u11_delete_custom_session(p_session_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Authentification requise';end if;
 if not exists(select 1 from public.u11_sessions
  where id=p_session_id and is_custom=true and owner_id=v_user)
 then raise exception 'Séance supplémentaire introuvable ou non autorisée';end if;
 if exists(select 1 from public.u11_session_evaluations where session_id=p_session_id)
 or exists(select 1 from public.u11_player_evaluations where session_id=p_session_id)
 then raise exception 'Suppression impossible : cette séance possède des évaluations';end if;
 delete from public.u11_session_occurrences where session_id=p_session_id and owner_id=v_user;
 delete from public.u11_sessions where id=p_session_id and owner_id=v_user and is_custom=true;
end;$$;
revoke all on function public.u11_create_custom_session(date,text,text,text,text,text) from public;
revoke all on function public.u11_delete_custom_session(uuid) from public;
grant execute on function public.u11_create_custom_session(date,text,text,text,text,text) to authenticated;
grant execute on function public.u11_delete_custom_session(uuid) to authenticated;
commit;
