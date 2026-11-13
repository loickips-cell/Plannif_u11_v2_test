-- Planinf U11 V2 — planification souple, migration non destructive
-- Exécuter dans Supabase SQL Editor avec le rôle administrateur.
-- Ne modifie aucune ligne des tables existantes.
begin;
create table if not exists public.u11_session_occurrences (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 session_id uuid not null references public.u11_sessions(id) on delete restrict,
 planned_date date,
 actual_date date,
 status text not null default 'prevue'
   check (status in ('prevue','reportee','realisee','annulee')),
 reason text not null default '',
 notes text not null default '',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint u11_occurrence_dates check (status <> 'realisee' or actual_date is not null)
);
create index if not exists u11_occurrences_owner_dates_idx
 on public.u11_session_occurrences(owner_id, planned_date, actual_date);
create index if not exists u11_occurrences_session_idx
 on public.u11_session_occurrences(session_id);
alter table public.u11_session_occurrences enable row level security;
drop policy if exists "u11_occurrences_select_own" on public.u11_session_occurrences;
drop policy if exists "u11_occurrences_insert_own" on public.u11_session_occurrences;
drop policy if exists "u11_occurrences_update_own" on public.u11_session_occurrences;
drop policy if exists "u11_occurrences_delete_own" on public.u11_session_occurrences;
create policy "u11_occurrences_select_own" on public.u11_session_occurrences for select to authenticated using (owner_id = (select auth.uid()));
create policy "u11_occurrences_insert_own" on public.u11_session_occurrences for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "u11_occurrences_update_own" on public.u11_session_occurrences for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "u11_occurrences_delete_own" on public.u11_session_occurrences for delete to authenticated using (owner_id = (select auth.uid()));
-- Colonnes facultatives, pour relier les évaluations aux occurrences sans toucher aux évaluations existantes.
alter table public.u11_session_evaluations add column if not exists occurrence_id uuid references public.u11_session_occurrences(id) on delete set null;
alter table public.u11_player_evaluations add column if not exists occurrence_id uuid references public.u11_session_occurrences(id) on delete set null;
commit;
