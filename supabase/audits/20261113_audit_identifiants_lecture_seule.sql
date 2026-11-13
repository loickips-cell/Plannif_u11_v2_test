-- AUDIT LECTURE SEULE — aucune donnée modifiée
-- Exécuter dans Supabase SQL Editor et partager les résultats pour validation.
-- 1. Inventaire des séances existantes
select id, session_code, session_number, session_type, month_name, phase, theme, reference_page, is_custom
from public.u11_sessions
order by coalesce(is_custom,false), session_number nulls last, session_code;

-- 2. Détection de doublons sur les codes actuels (hors séances supplémentaires)
select upper(regexp_replace(trim(session_code), '[[:space:]]+', '', 'g')) as code_normalise,
       count(*) as occurrences, array_agg(session_code) as codes
from public.u11_sessions
where coalesce(is_custom,false)=false
group by 1 having count(*)>1;

-- 3. Comparaison aux 46 identifiants du PDF : 1..35 et M1..M11
with expected as (
 select 'S'||lpad(n::text,2,'0') canonical_code from generate_series(1,35) n
 union all select 'M'||lpad(n::text,2,'0') from generate_series(1,11) n
), existing as (
 select id,session_code,session_type,theme,
 case
 when upper(trim(session_code)) ~ '^S?0*[0-9]+$'
 then 'S'||lpad((regexp_replace(upper(trim(session_code)),'^S?0*',''))::int::text,2,'0')
 when upper(trim(session_code)) ~ '^M0*[0-9]+$'
 then 'M'||lpad((regexp_replace(upper(trim(session_code)),'^M0*',''))::int::text,2,'0')
 else null end as canonical_code
 from public.u11_sessions where coalesce(is_custom,false)=false
)
select e.canonical_code, count(x.id) as matches,
       array_remove(array_agg(x.session_code),null) as codes_found,
       array_remove(array_agg(x.theme),null) as themes_found
from expected e left join existing x using(canonical_code)
group by e.canonical_code
order by e.canonical_code;

-- 4. Codes qui ne correspondent à aucune séance initiale du PDF
select session_code,session_type,theme
from public.u11_sessions
where coalesce(is_custom,false)=false and
not (
 upper(trim(session_code)) ~ '^S?0*([1-9]|[12][0-9]|3[0-5])$'
 or upper(trim(session_code)) ~ '^M0*([1-9]|1[01])$'
);
