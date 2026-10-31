"""Generate the guarded, NOT-APPLIED insert file from the staging CSV.
Only rows with decision=PROPOSE are emitted, one section per tier, so each
tier can be approved (or cut) on its own. Keyed on restaurant_code +
country_code, never on name."""
import csv,sys,collections
src,out=sys.argv[1],sys.argv[2]
rows=[r for r in csv.DictReader(open(src)) if r['decision']=='PROPOSE']
by=collections.defaultdict(list)
for r in rows: by[r['match_tier']].append(r)
DESC={'A':'address (street + number + postcode) AND website or phone agree',
      'A2':'website AND phone agree; catalogue address differs from G&M (logged, not fixed)',
      'A3':'website or phone agrees AND G&M map pin within 150 m of ours; address text differs (logged, not fixed)',
      'B':'address only (catalogue holds no website and no conflicting phone)'}
def q(s): return "'"+s.replace("'","''")+"'"
L=["-- Gault&Millau Benelux (NL 2026, BE 2026, LU 2027) — prepared insert. NOT APPLIED.","--",
"-- Written 2026-10-31. Run only after review and an explicit go-ahead.",
"-- Generated from gault_millau_benelux_2026_staging.csv (decision = PROPOSE);",
"-- regenerate rather than hand-edit. Every value was read from the venue's",
"-- own profile page on gault-millau.nl / gaultmillau.be / gaultmillau.lu on 2026-10-31",
"-- (score from the page's score block, equal to its schema.org rating;",
"-- toques counted from the same block, never derived from the score).",
"-- Keyed on restaurant_code + country_code, never on name. INSERT only:",
"-- no UPDATE, no DELETE, no restaurant is created. Each section checks the",
"-- exact row count it expects and aborts the whole transaction if any",
"-- differs, so a changed production state can't be half-applied.",
"-- Delete a whole section to leave that tier out.","--",
"-- Run with: supabase db query --linked --file <absolute path to this file>","","begin;",""]
total=0
for tier in ('A','A2','A3','B'):
    rs=by.get(tier,[])
    if not rs: continue
    total+=len(rs)
    L.append(f"-- Tier {tier}: {len(rs)} rows — {DESC[tier]}.")
    L.append("do $$ declare n int; begin")
    L.append("  insert into public.gault_millau_awards")
    L.append("    (restaurant_id, guide_year, score, toque_count, recognition_type, gault_millau_url)")
    L.append("  select r.id, v.yr, v.score, v.toques, 'scored', v.url")
    L.append("    from (values")
    vals=[f"    ({q(r['restaurant_code'])}, {q(r['country_code'])}, {r['guide_year']}::smallint, {float(r['score'])}::numeric, {int(r['toque_count'])}::smallint, {q(r['gault_millau_url'])})" for r in rs]
    L.append(",\n".join(vals))
    L.append("    ) v(code, cc, yr, score, toques, url)")
    L.append("    join public.restaurants r on r.restaurant_code = v.code and r.country_code = v.cc")
    L.append("   where not exists (select 1 from public.gault_millau_awards g")
    L.append("                      where g.restaurant_id = r.id and g.guide_year = v.yr);")
    L.append("  get diagnostics n = row_count;")
    L.append(f"  if n <> {len(rs)} then raise exception 'tier {tier}: expected {len(rs)}, got %', n; end if;")
    L.append("end $$;"); L.append("")
L.append("commit;"); L.append(f"-- {total} rows in total.")
open(out,'w').write("\n".join(L)+"\n"); print(out,total,{k:len(v) for k,v in by.items()})
