import csv, json, sys
O = sys.argv[1]; S = sys.argv[2]
q = lambda s: "NULL" if s in (None, '') else "'" + str(s).replace("'", "''") + "'"
rec = list(csv.DictReader(open(f'{O}/fr_reconciliation.csv'))); new = list(csv.DictReader(open(f'{O}/new_restaurants.csv')))
D = json.load(open(f'{S}/diff.json'))
fix = [(c, n, o, t) for c, n, o, t in D['star_fix']]
HOLD = {'rest_0972'}  # Jean Imbert au Plaza Athénée -> page now 'La Grande Table du Plaza Athénée': rename decision first (QA)
urls = [(r['code'], r['michelin_url_now']) for r in rec if 'michelin_url' in r['action'] and r['code'] not in HOLD]
first, last = new[0]['code'], new[-1]['code']; n_new = len(new)
L = []; A = L.append
A(f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Guide France 2026 (announced 16 March 2026): complete and correct
-- the French catalogue against MICHELIN's own selection. Written 2026-10-28.
--
-- SOURCE: MICHELIN only.
--   * "La liste complète des Étoiles du Guide MICHELIN France 2026"
--     (guide.michelin.com, published 2026-03-16): 668 restaurants, 31 x 3,
--     84 x 2, 553 x 1, of which 9 in Monaco (out of scope: no MC country).
--     France alone: 659.
--   * guide.michelin.com/en/fr/restaurants/all-starred on 2026-10-28: 646
--     (30 x 3, 79 x 2, 537 x 1). Every one of the 646 is one of the article's
--     659 and every star count agrees between article, listing and the
--     restaurant's own page (JSON-LD award dateAwarded 2026). The other 13
--     have since been withdrawn by MICHELIN (page 404) -- see
--     withdrawn_since_march.csv; this file does not touch them.
--   Per-row evidence: fr_reconciliation.csv, new_restaurants.csv; method and
--   findings: FR_STARS_2026_REPORT.md.
--
-- GUIDE YEAR: the August 2026 France import (rest_0895..rest_1367) was taken
-- from screenshots of the live site in August 2026, i.e. the 2026 edition,
-- and its award rows carry guide_year 2026. Checked: 36 of the restaurants
-- MICHELIN marks "Nouveau" in 2026 are already in production with the 2026
-- value. So, unlike the Netherlands, NO relabel: existing 2026 rows stay,
-- and wrong ones are corrected in place (transcription errors, QA log).
--
-- WHAT CHANGES
--   1. {len(fix)} star corrections: the restaurant's current 2026 row and
--      restaurants.michelin_stars set to MICHELIN's 2026 value. Each old value
--      is asserted first.
--   2. michelin_url set or corrected for {len(urls)} restaurants: canonical
--      https://guide.michelin.com/en/<region>/<city>/restaurant/<slug> form.
--      Most are the same page in another locale (nl/nl, us/en, pt_BR...);
--      some pages moved; 15 rows had none; one held stray text
--      (" + Nominatim venue resolution") and one pointed at a hotel page.
--      Held back: rest_0972 Jean Imbert au Plaza Athénée, whose MICHELIN page
--      is now 'La Grande Table du Plaza Athénée' -- rename decision first (QA).
--   3. {n_new} restaurants added ({first}..{last}), each with a 2026 award row.
--
-- PREREQUISITE: every new restaurant's city must exist in FR. 82 do not yet:
-- supabase/migrations/20261019120000_add_fr_2026_star_cities.sql. The file aborts and names
-- any missing city.
--
-- One transaction; every check raises, rolling the whole file back.
-- Re-running after success aborts at the first check.

begin;

do $$
begin
  if exists (select 1 from public.restaurants
              where restaurant_code ~ '^rest_[0-9]+$'
                and substring(restaurant_code from 6)::int between {first[5:]} and {last[5:]}) then
    raise exception 'codes {first}..{last} are no longer free -- re-check';
  end if;
  if (select count(*) from public.restaurants where country_code = 'FR' and michelin_stars is not null) <> 479 then
    raise exception 'expected 479 starred FR restaurants (export of 2026-10-28) -- production changed, re-check';
  end if;
end $$;

-- 1. star corrections (2026 rows that disagree with MICHELIN's 2026 list)
create temp table _fix (code text primary key, old_stars smallint, new_stars smallint) on commit drop;
insert into _fix values""")
A('\n'.join(f"    ({q(c)}, {o}, {t}){',' if i < len(fix) - 1 else ';'}  -- {n}" for i, (c, n, o, t) in enumerate(fix)))
A(f"""
do $$
declare n int;
begin
  select count(*) into n from _fix f join public.restaurants r on r.restaurant_code = f.code
   where r.country_code = 'FR' and r.michelin_stars = f.old_stars;
  if n <> {len(fix)} then raise exception 'star corrections: expected {len(fix)} rows at their old value, found %', n; end if;
  select count(*) into n from _fix f join public.restaurants r on r.restaurant_code = f.code
    join public.award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id
   where ah.award_type = 'michelin_stars' and ah.guide_year = 2026 and ah.is_current and ah.award_value = f.old_stars;
  if n <> {len(fix)} then raise exception 'star corrections: expected {len(fix)} current 2026 rows at their old value, found %', n; end if;
end $$;

update public.award_history ah set award_value = f.new_stars, announced_on = date '2026-03-16'
  from public.restaurants r, _fix f
 where r.restaurant_code = f.code and ah.entity_type = 'restaurant' and ah.entity_id = r.id
   and ah.award_type = 'michelin_stars' and ah.guide_year = 2026 and ah.is_current;

update public.restaurants r set michelin_stars = f.new_stars, updated_at = now()
  from _fix f where r.restaurant_code = f.code;

-- 2. michelin_url
create temp table _urls (code text primary key, michelin_url text unique) on commit drop;
insert into _urls values""")
A(',\n'.join(f"    ({q(c)}, {q(u)})" for c, u in urls) + ';')
A(f"""
do $$
declare bad text;
begin
  select string_agg(u.code, ', ') into bad from _urls u
   where not exists (select 1 from public.restaurants r where r.restaurant_code = u.code and r.country_code = 'FR');
  if bad is not null then raise exception 'unknown or non-FR code: %', bad; end if;
  select string_agg(u.code, ', ') into bad from _urls u
    join public.restaurants r on r.michelin_url = u.michelin_url and r.restaurant_code <> u.code;
  if bad is not null then raise exception 'new michelin_url already used by another row: %', bad; end if;
end $$;

update public.restaurants r set michelin_url = u.michelin_url, updated_at = now()
  from _urls u where r.restaurant_code = u.code;

-- 3. restaurants in MICHELIN's 2026 France selection that production lacks
create temp table _new (code text, name text, stars smallint, city text, address text,
                        lon float8, lat float8, michelin_url text, website_url text,
                        phone text) on commit drop;
insert into _new values""")
A(',\n'.join(f"    ({q(r['code'])}, {q(r['name'])}, {r['stars']}::smallint, {q(r['city'])}, {q(r['address'])}, {r['longitude']}, {r['latitude']}, {q(r['michelin_url'])}, {q(r['website_url'])}, {q(r['phone'])})" for r in new) + ';')
A(f"""
do $$
declare bad text;
begin
  select string_agg(distinct n.city, ', ') into bad from _new n
   where (select count(*) from public.cities c where c.country_code = 'FR' and c.name = n.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one FR row: %', bad; end if;
  select string_agg(n.name, ', ') into bad from _new n
    join public.restaurants r on r.michelin_url = n.michelin_url;
  if bad is not null then raise exception 'new restaurant already present (michelin_url): %', bad; end if;
end $$;

insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
   address, location, michelin_url, website_url, phone)
select n.code, n.name, n.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = 'FR' and c.name = n.city),
       'FR', n.address, ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)::geography,
       n.michelin_url, n.website_url, n.phone
from _new n;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', n.stars, true, date '2026-03-16'
from _new n join public.restaurants r on r.restaurant_code = n.code;

-- Post-conditions
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = 'FR' and michelin_stars is not null;
  if n <> 652 then raise exception 'expected 652 starred FR restaurants (646 live + 6 withdrawn already present), found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'FR' and michelin_stars = 3;
  if n <> 30 then raise exception 'expected 30 three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'FR' and michelin_stars = 2;
  if n <> 80 then raise exception 'expected 80 two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'FR' and michelin_stars = 1;
  if n <> 542 then raise exception 'expected 542 one-star, found %', n; end if;
  -- every starred FR restaurant: exactly one current star row, agreeing with michelin_stars
  select count(*) into n from public.restaurants r
   where r.country_code = 'FR' and r.michelin_stars is not null
     and (select count(*) from public.award_history ah
           where ah.entity_type = 'restaurant' and ah.entity_id = r.id
             and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '% starred FR restaurants do not have exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r
    join public.award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id
                                and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = 'FR' and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '% FR restaurants disagree with their current award_history row', n; end if;
end $$;

commit;
""")
open(f'{O}/prepared_fr_stars_2026.sql', 'w').write('\n'.join(L))
# ---- phone backfill (existing rows) ----
ph = [r for r in csv.DictReader(open(f'{O}/fr_phones_existing.csv')) if r['certainty'] == 'confirmed']
P = [f"""-- PREPARED -- NOT APPLIED.
--
-- Phone numbers for MICHELIN-starred restaurants in France already in
-- production, written 2026-10-28. Input: production export of every FR
-- restaurant (2026-10-28); rows with phone already set are not touched.
--
-- {len(ph)} numbers, all `confirmed`: MICHELIN's number for the restaurant
-- (its guide.michelin.com page) also appears on the restaurant's own website
-- (source_url per row in fr_phones_existing.csv). Rows left out on purpose,
-- with the reason per row, are in the same CSV -- see FR_STARS_2026_REPORT.md.
-- Stored in the human-readable international format restaurants.phone uses.
--
-- Independent of prepared_fr_stars_2026.sql: either can run first.
-- Fills only empty values (`phone is null`) -- never overwrites. One
-- transaction; aborts if any code is unknown or in the wrong country.

begin;

create temp table _fr_phones (code text primary key, phone text, country_code text) on commit drop;
insert into _fr_phones values"""]
P.append(',\n'.join(f"    ({q(r['code'])}, {q(r['phone'])}, 'FR')" for r in ph) + ';')
P.append(f"""
do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _fr_phones p
   where not exists (select 1 from public.restaurants r
                      where r.restaurant_code = p.code and r.country_code = p.country_code);
  if bad is not null then raise exception 'unknown code or country mismatch: %', bad; end if;
end $$;

update public.restaurants r set phone = p.phone, updated_at = now()
  from _fr_phones p
 where r.restaurant_code = p.code and r.phone is null;

commit;
""")
open(f'{O}/prepared_fr_phone_backfill.sql', 'w').write('\n'.join(P))
# ---- proposed cities migration ----
cities = json.load(open(f'{S}/missing_cities.json'))
C = [f"""-- PROPOSED MIGRATION -- not in supabase/migrations, not applied.
-- Move to supabase/migrations/<next sequence number>_add_fr_2026_star_cities.sql
-- only with the product owner's go-ahead (CLAUDE.md: no migrations as a side
-- effect of another task).
--
-- MICHELIN Guide France 2026: city-only prerequisite for {sum(1 for r in new if r['city_in_production']=='no')} of the {n_new}
-- restaurants in supabase/data/enrichment/michelin_fr_stars_2026/
-- prepared_fr_stars_2026.sql. Written 2026-10-28.
--
-- Adds ONLY public.cities rows. Checked read-only against production on
-- 2026-10-28: these {len(cities)} names returned 0 FR rows by exact name, and none
-- differs from an existing FR row by accents alone (the two that did --
-- Saint-Emilion, Bretignolles-sur-Mer -- use the existing rows). Names are
-- MICHELIN's destination names from each restaurant's guide.michelin.com page.
-- Their absence fits the August import's gap: whole regions (Rhône-Alpes,
-- Brittany, Pays de la Loire) were missing from the screenshots.
--
-- region and postal_municipality are left NULL, matching 325 of the 329
-- existing FR rows (region is only used to separate homonyms inside the
-- table, and no new name collides with an existing one).
--
-- Idempotent: ON CONFLICT targets cities_unique_key
-- (country_code, name, coalesce(region, '')).

begin;

insert into public.cities (country_code, name, region)
values"""]
C.append(',\n'.join(f"  ('FR', {q(c)}, NULL)" for c in cities))
C.append("""on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""")
open(f'{O}/supabase/migrations/20261019120000_add_fr_2026_star_cities.sql', 'w').write('\n'.join(C))
print(len(fix), len(urls), n_new, len(ph), len(cities))
