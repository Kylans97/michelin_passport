-- Dutch words find cuisines too: "Frans" finds French, "Japans" Japanese,
-- "Duits" German. Reported by the product owner on 2026-11-02 while
-- testing 1.5.6 (25): free search matched only MICHELIN's English labels.
--
-- Search terms only: what's shown stays MICHELIN's own English label, and
-- the Explore filter keeps keying on family slugs. Each family gets its
-- Dutch name; a cuisine whose Dutch name differs from its family's gets
-- its own, so "Duits" finds German and not every Central European
-- restaurant. Where Dutch is often typed without an accent, both are
-- there (Israëlisch, Israelisch). These are translations, not catalogue
-- facts, so they carry no source column.
--
-- Free search reads restaurants_full.cuisine_search, built in the view, so
-- the view is redefined with the terms added to that one column. Every
-- other column is exactly as in 20261101150000 (copied from it; the
-- 2026-11-02 schema diff confirmed production matches it), in the same
-- order. No app change is needed: installed builds pick it up at once.
--
-- Real date: 2026-11-02. The filename is a sequence number, the next one
-- after the highest existing migration (20261101190000), per CLAUDE.md.

begin;

alter table public.cuisine_families add column search_terms text;
alter table public.cuisines add column search_terms text;

update public.cuisine_families set search_terms = 'Afrikaans' where slug = 'african';
update public.cuisine_families set search_terms = 'Amerikaans' where slug = 'north-american';
update public.cuisine_families set search_terms = 'Aziatisch' where slug = 'asian';
update public.cuisine_families set search_terms = 'Belgisch Nederlands' where slug = 'belgian-dutch';
update public.cuisine_families set search_terms = 'Brits' where slug = 'british-irish';
update public.cuisine_families set search_terms = 'Centraal-Europees Oost-Europees' where slug = 'central-european';
update public.cuisine_families set search_terms = 'Chinees' where slug = 'chinese';
update public.cuisine_families set search_terms = 'Klassiek Traditioneel' where slug = 'classic-traditional';
update public.cuisine_families set search_terms = 'Frans' where slug = 'french';
update public.cuisine_families set search_terms = 'Internationaal' where slug = 'fusion-international';
update public.cuisine_families set search_terms = 'Vlees Grill' where slug = 'grill-meat';
update public.cuisine_families set search_terms = 'Indiaas' where slug = 'indian';
update public.cuisine_families set search_terms = 'Italiaans' where slug = 'italian';
update public.cuisine_families set search_terms = 'Japans' where slug = 'japanese';
update public.cuisine_families set search_terms = 'Koreaans' where slug = 'korean';
update public.cuisine_families set search_terms = 'Latijns-Amerikaans Zuid-Amerikaans' where slug = 'latin-american';
update public.cuisine_families set search_terms = 'Mediterraans Midden-Oosten' where slug = 'mediterranean-middle-east';
update public.cuisine_families set search_terms = 'Modern Creatief Eigentijds' where slug = 'modern-creative';
update public.cuisine_families set search_terms = 'Scandinavisch Noords' where slug = 'nordic';
update public.cuisine_families set search_terms = 'Portugees' where slug = 'portuguese';
update public.cuisine_families set search_terms = 'Vis Zeevruchten' where slug = 'seafood';
update public.cuisine_families set search_terms = 'Seizoensgebonden Biologisch' where slug = 'seasonal-farm';
update public.cuisine_families set search_terms = 'Zuidoost-Aziatisch' where slug = 'southeast-asian';
update public.cuisine_families set search_terms = 'Spaans' where slug = 'spanish';
update public.cuisine_families set search_terms = 'Vegetarisch Plantaardig' where slug = 'vegetarian';

update public.cuisines set search_terms = 'Duits' where name = 'German';
update public.cuisines set search_terms = 'Oostenrijks' where name = 'Austrian';
update public.cuisines set search_terms = 'Zwitsers' where name = 'Swiss';
update public.cuisines set search_terms = 'Hongaars' where name = 'Hungarian';
update public.cuisines set search_terms = 'Pools' where name = 'Polish';
update public.cuisines set search_terms = 'Russisch' where name = 'Russian';
update public.cuisines set search_terms = 'Deens' where name = 'Danish';
update public.cuisines set search_terms = 'Zweeds' where name = 'Swedish';
update public.cuisines set search_terms = 'Grieks' where name = 'Greek';
update public.cuisines set search_terms = 'Turks' where name = 'Turkish';
update public.cuisines set search_terms = 'Israëlisch Israelisch' where name = 'Israeli';
update public.cuisines set search_terms = 'Mexicaans' where name = 'Mexican';
update public.cuisines set search_terms = 'Peruaans' where name = 'Peruvian';
update public.cuisines set search_terms = 'Braziliaans' where name = 'Brazilian';
update public.cuisines set search_terms = 'Colombiaans' where name = 'Colombian';
update public.cuisines set search_terms = 'Cubaans' where name = 'Cuban';
update public.cuisines set search_terms = 'Thais' where name = 'Thai';
update public.cuisines set search_terms = 'Vietnamees' where name = 'Vietnamese';
update public.cuisines set search_terms = 'Filipijns' where name = 'Filipino';
update public.cuisines set search_terms = 'Singaporees' where name = 'Singaporean';
update public.cuisines set search_terms = 'Baskisch' where name = 'Basque';
update public.cuisines set search_terms = 'Catalaans' where name = 'Catalan';
update public.cuisines set search_terms = 'Andalusisch' where name = 'Andalusian';
update public.cuisines set search_terms = 'Galicisch' where name = 'Galician';
update public.cuisines set search_terms = 'Kantonees' where name = 'Cantonese';
update public.cuisines set search_terms = 'Pakistaans' where name = 'Pakistani';
update public.cuisines set search_terms = 'Veganistisch' where name = 'Vegan';
update public.cuisines set search_terms = 'Belgisch' where name = 'Belgian';
update public.cuisines set search_terms = 'Iers' where name = 'Irish';
update public.cuisines set search_terms = 'Engels' where name = 'Traditional British';
update public.cuisines set search_terms = 'Engels' where name = 'Modern British';
update public.cuisines set search_terms = 'Vis Zeevruchten' where name = 'Fish and Seafood';
update public.cuisines set search_terms = 'Biologisch' where name = 'Organic';
update public.cuisines set search_terms = 'Seizoensgebonden' where name = 'Seasonal Cuisine';
update public.cuisines set search_terms = 'Streekkeuken' where name = 'Regional Cuisine';
update public.cuisines set search_terms = 'Vlees' where name = 'Steakhouse';
update public.cuisines set search_terms = 'Vlees' where name = 'Meats and Grills';
update public.cuisines set search_terms = 'Senegalees' where name = 'Senegalese';
update public.cuisines set search_terms = 'Noord-Afrikaans' where name = 'North African';
update public.cuisines set search_terms = 'Provençaals Provencaals' where name = 'Provençal';
update public.cuisines set search_terms = 'Elzassisch' where name = 'Alsatian';
update public.cuisines set search_terms = 'Corsicaans' where name = 'Corsican';
update public.cuisines set search_terms = 'Scandinavisch' where name = 'Scandinavian';
update public.cuisines set search_terms = 'Koreaans' where name = 'Korean Contemporary';

-- The families are seeded by 20261101150000, so every one must have
-- matched. The cuisines are loaded as data (prepared_restaurant_cuisines
-- .sql), not by a migration, so a fresh replay has none of them: their
-- 44 names were checked against production before this was applied,
-- not asserted here, where a replay would fail on them.
do $$
begin
  if (select count(*) from public.cuisine_families where search_terms is not null) <> 25 then
    raise exception 'expected 25 families with search terms';
  end if;
end;
$$;

create or replace view public.restaurants_full
  with (security_invoker = true)
  as
select
  r.id,
  r.restaurant_code,
  r.name,
  r.michelin_stars,
  r.inclusion_reason,
  r.cuisine_id,
  r.city_id,
  r.country_code,
  r.address,
  r.location,
  r.google_place_id,
  r.michelin_url,
  r.website_url,
  r.booking_url,
  r.property_name,
  r.status,
  r.status_since,
  r.status_note,
  r.created_at,
  r.updated_at,
  hr.id is not null or r.property_name is not null as is_in_hotel,
  coalesce(h.name, r.property_name) as hotel_name,
  h.id as hotel_id,
  ci.name as city_name,
  ci.region,
  co.name as country_name,
  co.flag_emoji,
  w.rank as worlds_50_best_rank,
  st_y(r.location::geometry) as latitude,
  st_x(r.location::geometry) as longitude,
  exists (
    select 1 from public.worlds_50_best hof
    where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame'
  ) as is_hall_of_fame,
  r.phone,
  r.ends_on is not null and r.ends_on < current_date as is_expired,
  r.starts_on,
  r.ends_on,
  r.parent_venue_type,
  r.parent_venue_id,
  r.opening_weekdays,
  r.missing_listing_report_id,
  cover.image_url as cover_photo_url,
  cover.focus_x as cover_focus_x,
  cover.focus_y as cover_focus_y,
  cover.zoom as cover_zoom,
  card.image_url as card_photo_url,
  card.card_focus_x,
  card.card_focus_y,
  card.card_zoom,
  r.worlds_50_best_url,
  cu.cuisine_names,
  cu.cuisine_slugs,
  cu.cuisine_family_slugs,
  cu.cuisine_search
from public.restaurants r
join public.cities ci on ci.id = r.city_id
join public.countries co on co.country_code = r.country_code
left join public.hotel_restaurants hr on hr.restaurant_id = r.id
left join public.hotels h on h.id = hr.hotel_id
left join public.worlds_50_best w
  on w.restaurant_id = r.id
 and w.year = (select max(year) from public.worlds_50_best where rank is not null)
left join lateral (
  select rp.image_url, rp.focus_x, rp.focus_y, rp.zoom
  from public.restaurant_photos rp
  where rp.restaurant_id = r.id
  order by rp.display_order
  limit 1
) cover on true
left join lateral (
  select rp.image_url, rp.card_focus_x, rp.card_focus_y, rp.card_zoom
  from public.restaurant_photos rp
  where rp.restaurant_id = r.id
  order by rp.is_card desc, rp.display_order
  limit 1
) card on true
left join lateral (
  select string_agg(c.name, ', ' order by e.position) as cuisine_names,
         array_agg(c.slug order by e.position) as cuisine_slugs,
         array_agg(distinct f.slug) filter (where f.slug is not null) as cuisine_family_slugs,
         string_agg(
           c.name || coalesce(' ' || c.search_terms, '')
             || coalesce(' ' || f.name, '') || coalesce(' ' || f.search_terms, ''),
           ' ' order by e.position
         ) as cuisine_search
  from public.restaurant_cuisines_effective e
  join public.cuisines c on c.id = e.cuisine_id
  left join public.cuisine_families f on f.id = c.family_id
  where e.restaurant_id = r.id
) cu on true;;

commit;
