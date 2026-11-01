select r.restaurant_code, r.country_code, r.name, ci.name city, r.address, r.website_url, r.phone, r.michelin_stars, r.status, round(st_y(r.location::geometry)::numeric,5) lat, round(st_x(r.location::geometry)::numeric,5) lng,
 (select g.score||'|'||coalesce(g.toque_count::text,'')||'|'||g.guide_year from gault_millau_awards g where g.restaurant_id=r.id order by guide_year desc limit 1) gm_current
from restaurants r join cities ci on ci.id=r.city_id where r.country_code in ('NL','BE','LU') order by 2,1;
