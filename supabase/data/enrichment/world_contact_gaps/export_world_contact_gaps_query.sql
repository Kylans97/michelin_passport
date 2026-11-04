-- Read-only export: phone / website gaps, all countries (written 2026-11-04).
-- ONE row, ONE JSON cell. Run in the Supabase SQL Editor, download as CSV,
-- upload to the session. Same shape as europe_gaps/export_europe_gaps_query.sql,
-- without the country filter and limited to rows missing a phone or a website.
-- google_place_id is exported so the run can read the venue's own Google record.
select json_build_object(
  'exported_at', now(),
  'summary', (select json_agg(s order by s.country, s.kind) from (
      select 'restaurant' as kind, r.country_code as country, count(*) as total,
             count(*) filter (where r.phone is null) as no_phone,
             count(*) filter (where r.website_url is null) as no_website
        from public.restaurants r
       where r.status <> 'permanently_closed' group by r.country_code
      union all
      select 'hotel', h.country_code, count(*),
             count(*) filter (where h.phone is null),
             count(*) filter (where h.website_url is null)
        from public.hotels h
       where h.status <> 'permanently_closed' group by h.country_code) s),
  'gaps', (select json_agg(g order by g.country, g.kind, g.code) from (
      select 'restaurant' as kind, r.restaurant_code as code, r.country_code as country, r.name,
             c.name as city, r.address, ST_Y(r.location::geometry) as lat, ST_X(r.location::geometry) as lon,
             r.michelin_stars as stars, r.inclusion_reason, r.michelin_url, r.property_name,
             r.google_place_id, r.phone, r.website_url
        from public.restaurants r join public.cities c on c.id = r.city_id
       where r.status <> 'permanently_closed'
         and (r.phone is null or r.website_url is null)
      union all
      select 'hotel', h.hotel_code, h.country_code, h.name, c.name, h.address,
             ST_Y(h.location::geometry), ST_X(h.location::geometry),
             h.michelin_keys, null, h.michelin_url, null,
             h.google_place_id, h.phone, h.website_url
        from public.hotels h join public.cities c on c.id = h.city_id
       where h.status <> 'permanently_closed'
         and (h.phone is null or h.website_url is null)) g)
) as export;
