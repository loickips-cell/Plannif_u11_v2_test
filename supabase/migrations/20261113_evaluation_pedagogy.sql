-- Planinf U11 V2 : bilan pédagogique structuré, sans perte des évaluations existantes.
alter table public.u11_session_evaluations
 add column if not exists successes text not null default '',
 add column if not exists difficulties text not null default '';
-- collective_notes reste conservé pour l'historique ; next_steps reste la suite pédagogique.

alter table public.u11_session_evaluations add column if not exists objectives jsonb not null default '[]'::jsonb;
