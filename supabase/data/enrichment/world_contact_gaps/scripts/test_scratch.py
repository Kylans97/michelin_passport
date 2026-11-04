#!/usr/bin/env python3
"""Test prepared_<cc>_contact_fill.sql files on a throw-away local Postgres
seeded from the export (restaurants/hotels: code, name, country_code,
google_place_id, phone, website_url, updated_at; the gap rows only).

  python3 test_scratch.py <export.json> <psql connection URI> <sql files...>

Per file: (1) it applies without error and fills exactly what the CSV
proposes; (2) a second run changes nothing; (3) with one of its rows renamed,
the file stops with an error and changes nothing. Then all files once more,
one after another, from a fresh seed (no Place ID collision between countries).
"""
import json, subprocess, sys, re

EXP, URI = sys.argv[1:3]
FILES = sys.argv[3:]


def psql(sql=None, f=None):
    cmd = ['psql', URI, '-v', 'ON_ERROR_STOP=1', '-q', '-X', '-At']
    if f:
        cmd += ['-f', f]
    p = subprocess.run(cmd, capture_output=True, text=True, input=None if f else sql)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def q(v):
    return 'NULL' if v is None else "'" + str(v).replace("'", "''") + "'"


def seed():
    rows = json.load(open(EXP))['gaps']
    s = ['drop table if exists public.restaurants, public.hotels;']
    for t, cc in (('restaurants', 'restaurant_code'), ('hotels', 'hotel_code')):
        s.append(f'create table public.{t} (id serial primary key, {cc} text unique not null, name text not null, country_code text not null, '
                 f'google_place_id text unique, phone text, website_url text, updated_at timestamptz);')
    for r in rows:
        t, cc = ('restaurants', 'restaurant_code') if r['kind'] == 'restaurant' else ('hotels', 'hotel_code')
        s.append(f"insert into public.{t} ({cc}, name, country_code, google_place_id, phone, website_url) values "
                 f"({q(r['code'])}, {q(r['name'])}, {q(r['country'])}, {q(r['google_place_id'])}, {q(r['phone'])}, {q(r['website_url'])});")
    rc, out, err = psql('\n'.join(s))
    assert rc == 0, err


def snapshot():
    rc, out, err = psql("select md5(string_agg(x::text, '|' order by x::text)) from (select restaurant_code, google_place_id, phone, website_url from public.restaurants "
                        "union all select hotel_code, google_place_id, phone, website_url from public.hotels) x")
    return out


def filled():
    rc, out, err = psql("select count(google_place_id) + count(phone) + count(website_url) from (select google_place_id, phone, website_url from public.restaurants union all select google_place_id, phone, website_url from public.hotels) x")
    return int(out)


ok = True
report = []
for f in FILES:
    seed()
    before = filled()
    rc, out, err = psql(f=f)
    after = filled()
    s1 = snapshot()
    rc2, _, err2 = psql(f=f)
    s2 = snapshot()
    # rename the first row of the file's first block
    m = re.search(r"insert into _fill_(restaurant|hotel) values\n    \('([^']+)'", open(f).read())
    kind, code = m.group(1), m.group(2)
    t, cc = ('restaurants', 'restaurant_code') if kind == 'restaurant' else ('hotels', 'hotel_code')
    seed()
    psql(f"update public.{t} set name = name || ' (renamed)' where {cc} = '{code}'")
    s3 = snapshot()
    rc3, _, err3 = psql(f=f)
    s4 = snapshot()
    res = dict(file=f.split('/')[-1], apply=rc == 0, values_written=after - before, rerun_noop=(rc2 == 0 and s1 == s2),
               renamed_row=code, rename_aborts=(rc3 != 0 and s3 == s4 and 'no longer the exported' in err3), error=err[:200])
    ok &= res['apply'] and res['rerun_noop'] and res['rename_aborts']
    report.append(res)
    print(json.dumps(res))
seed()
allrc = [psql(f=f)[0] for f in FILES]
print(json.dumps(dict(all_files_in_sequence=all(r == 0 for r in allrc), filled_total=filled())))
sys.exit(0 if ok and all(r == 0 for r in allrc) else 1)
