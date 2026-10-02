-- Seeds public.countries with the full set of rows currently live in
-- production, as of 2026-10-02.
--
-- Why this exists: a from-scratch replay of all migration files in
-- supabase/migrations/ (filename order) against an empty database fails
-- at the first INSERT that carries a real country_code value —
-- 20260810160000_create_events.sql's seed row for 't Preuvenemint
-- (country_code = 'NL') — because public.countries is created empty by
-- 20260805141519_production_schema_v1.sql and nothing between that file
-- and the first country_code-carrying insert ever populates it. On the
-- live database this was never a problem because countries was seeded
-- by hand outside the migration history at some point after the schema
-- was first applied; a fresh replay (a shadow database, a preview
-- branch, or disaster recovery into an empty project) has no such
-- out-of-band step to rely on.
--
-- Why this filename/timestamp: 20260805141520 is the minute immediately
-- after 20260805141519_production_schema_v1.sql (which drops and
-- recreates public.countries) and sorts before every other migration,
-- including 20260810120000_create_planned_trips.sql and
-- 20260810160000_create_events.sql — the two earliest files with a real
-- (non-deferred) foreign key dependency on countries data being present.
-- Every other reference to public.countries in between (view definitions,
-- RLS policies, FK constraint declarations without an accompanying
-- insert) is DDL or deferred-execution SQL (view bodies, trigger function
-- bodies) that does not require populated data at migration-apply time.
--
-- Data source: live production (project wcmxugunvwsrulcpeyrc),
-- `select * from public.countries order by country_code` via
-- `supabase db query --linked`, run read-only on 2026-10-02. 55 rows.
-- flag_emoji is NOT NULL on every row, matching the column's own
-- not-null constraint.
--
-- Idempotent against production: `on conflict (country_code) do nothing`
-- means applying this to a database that already has countries populated
-- (i.e. the real production database) is a no-op.

insert into public.countries (country_code, name, flag_emoji) values
  ('AD', 'Andorra', '🇦🇩'),
  ('AE', 'United Arab Emirates', '🇦🇪'),
  ('AR', 'Argentina', '🇦🇷'),
  ('AT', 'Austria', '🇦🇹'),
  ('AU', 'Australia', '🇦🇺'),
  ('AW', 'Aruba', '🇦🇼'),
  ('BE', 'Belgium', '🇧🇪'),
  ('BL', 'St. Barthélemy', '🇧🇱'),
  ('BR', 'Brazil', '🇧🇷'),
  ('CH', 'Switzerland', '🇨🇭'),
  ('CL', 'Chile', '🇨🇱'),
  ('CN', 'China', '🇨🇳'),
  ('CO', 'Colombia', '🇨🇴'),
  ('DE', 'Germany', '🇩🇪'),
  ('DK', 'Denmark', '🇩🇰'),
  ('ES', 'Spain', '🇪🇸'),
  ('FI', 'Finland', '🇫🇮'),
  ('FO', 'Faroe Islands', '🇫🇴'),
  ('FR', 'France', '🇫🇷'),
  ('GB', 'United Kingdom', '🇬🇧'),
  ('GR', 'Greece', '🇬🇷'),
  ('HK', 'Hong Kong', '🇭🇰'),
  ('HR', 'Croatia', '🇭🇷'),
  ('HU', 'Hungary', '🇭🇺'),
  ('ID', 'Indonesia', '🇮🇩'),
  ('IN', 'India', '🇮🇳'),
  ('IT', 'Italy', '🇮🇹'),
  ('JP', 'Japan', '🇯🇵'),
  ('KR', 'South Korea', '🇰🇷'),
  ('LK', 'Sri Lanka', '🇱🇰'),
  ('LU', 'Luxembourg', '🇱🇺'),
  ('MA', 'Morocco', '🇲🇦'),
  ('MC', 'Monaco', '🇲🇨'),
  ('ME', 'Montenegro', '🇲🇪'),
  ('MO', 'Macau', '🇲🇴'),
  ('MT', 'Malta', '🇲🇹'),
  ('MV', 'Maldives', '🇲🇻'),
  ('MX', 'Mexico', '🇲🇽'),
  ('MY', 'Malaysia', '🇲🇾'),
  ('NL', 'Netherlands', '🇳🇱'),
  ('NO', 'Norway', '🇳🇴'),
  ('NZ', 'New Zealand', '🇳🇿'),
  ('OM', 'Oman', '🇴🇲'),
  ('PE', 'Peru', '🇵🇪'),
  ('PL', 'Poland', '🇵🇱'),
  ('PT', 'Portugal', '🇵🇹'),
  ('RS', 'Serbia', '🇷🇸'),
  ('SE', 'Sweden', '🇸🇪'),
  ('SG', 'Singapore', '🇸🇬'),
  ('SI', 'Slovenia', '🇸🇮'),
  ('TH', 'Thailand', '🇹🇭'),
  ('TR', 'Turkey', '🇹🇷'),
  ('TW', 'Taiwan', '🇹🇼'),
  ('US', 'United States', '🇺🇸'),
  ('ZA', 'South Africa', '🇿🇦')
on conflict (country_code) do nothing;
