import csv, sys

D = sys.argv[1]
q = lambda s: "'" + s.replace("'", "''") + "'"


def vals(rows, cols):
    return ',\n'.join('    (' + ', '.join(c(r) for c in cols) + ')' for r in rows)


rw = [r for r in csv.DictReader(open(f'{D}/worlds_50_best_restaurant_urls.csv')) if r['apply'] == 'yes']
hw = [r for r in csv.DictReader(open(f'{D}/worlds_50_best_hotel_urls.csv')) if r['apply'] == 'yes']
at = [r for r in csv.DictReader(open(f'{D}/gault_millau_at_urls.csv')) if r['status'] == 'verified']
tq = [r for r in csv.DictReader(open(f'{D}/gault_millau_toques.csv'))
      if r['status'] == 'verified' and not r['our_toque_count']]

out = f"""-- Prepared data update for the guide-source links. NOT APPLIED.
--
-- Written 2026-10-28 (feature/guide-sources). Run only after review and
-- an explicit go-ahead, and only after
-- supabase/migrations/20261021120000_add_worlds_50_best_urls.sql is live
-- (sections 3-4 need its columns). Every value comes from a CSV in this
-- folder with status verified; README.md says how each was proven.
-- Keyed on restaurant_code / hotel_code, never on name. Every step checks
-- the exact row count it expects and aborts the whole transaction if any
-- differs, so a changed production state can't be half-applied.
-- Generated from the CSVs; regenerate rather than hand-edit.
--
-- Run with: supabase db query --linked --file <absolute path to this file>

begin;

-- 1. QA-232: the 8 Austrian "not found" placeholders become NULL.
do $$ declare n int; begin
  update public.gault_millau_awards set gault_millau_url = null
   where gault_millau_url is not null and gault_millau_url !~ '^https?://';
  get diagnostics n = row_count;
  if n <> 8 then raise exception 'placeholders: expected 8, got %', n; end if;
end $$;

-- 2a. QA-232: the {len(at)} Austrian pages found in gaultmillau.at's own sitemap
--     and verified (gault_millau_at_urls.csv). Obauer stays NULL.
do $$ declare n int; begin
  update public.gault_millau_awards g set gault_millau_url = v.url
    from (values
{vals(at, [lambda r: q(r['restaurant_code']), lambda r: q(r['candidate_url'])])}
    ) v(code, url), public.restaurants r
   where r.restaurant_code = v.code and g.restaurant_id = r.id
     and g.guide_year = 2026 and g.gault_millau_url is null;
  get diagnostics n = row_count;
  if n <> {len(at)} then raise exception 'AT urls: expected {len(at)}, got %', n; end if;
end $$;

-- 2b. QA-233: {len(tq)} toque counts read from each restaurant's own page, only
--     where the page score equals ours (gault_millau_toques.csv).
do $$ declare n int; begin
  update public.gault_millau_awards g set toque_count = v.toques
    from (values
{vals(tq, [lambda r: q(r['restaurant_code']), lambda r: str(int(r['page_toque_count'])), lambda r: r['our_score']])}
    ) v(code, toques, score), public.restaurants r
   where r.restaurant_code = v.code and g.restaurant_id = r.id
     and g.guide_year = 2026 and g.toque_count is null and g.score = v.score;
  get diagnostics n = row_count;
  if n <> {len(tq)} then raise exception 'toques: expected {len(tq)}, got %', n; end if;
end $$;

-- 3. World's 50 Best restaurant pages ({len(rw)}, worlds_50_best_restaurant_urls.csv apply=yes).
do $$ declare n int; begin
  update public.restaurants r set worlds_50_best_url = v.url
    from (values
{vals(rw, [lambda r: q(r['code']), lambda r: q(r['url'])])}
    ) v(code, url)
   where r.restaurant_code = v.code and r.worlds_50_best_url is null;
  get diagnostics n = row_count;
  if n <> {len(rw)} then raise exception 'restaurant urls: expected {len(rw)}, got %', n; end if;
end $$;

-- 4. World's 50 Best hotel pages ({len(hw)}, worlds_50_best_hotel_urls.csv apply=yes).
do $$ declare n int; begin
  update public.hotels h set worlds_50_best_url = v.url
    from (values
{vals(hw, [lambda r: q(r['code']), lambda r: q(r['url'])])}
    ) v(code, url)
   where h.hotel_code = v.code and h.worlds_50_best_url is null;
  get diagnostics n = row_count;
  if n <> {len(hw)} then raise exception 'hotel urls: expected {len(hw)}, got %', n; end if;
end $$;

commit;
"""
open(f'{D}/apply_guide_source_links.sql', 'w').write(out)
print(len(at), len(tq), len(rw), len(hw))
