-- PREPARED -- NOT APPLIED.
--
-- QA-230: phones for nine Peruvian Key hotels, under the rule the product
-- owner set on 2026-10-28: use the hotel's own local number from its own
-- site; if the site shows no local number, use the group line it shows.
-- Written 2026-10-28. Evidence per hotel: pe_key_hotels.csv (phone_status),
-- read from each hotel's own site during the Peru pass.
--
--   Own local number on the hotel's site:
--     hotel_804 Las Casitas        +51 908 851 660 (MICHELIN shows a
--                                  different mobile; the site's is used)
--     hotel_812 Monasterio         +51 84 604 000
--     hotel_813 Miraflores Park    +51 1 610 4000
--     hotel_814 Rio Sagrado        +51 84 201 384
--   Group line, the only number the hotel's site shows:
--     hotel_805 Titilaka, hotel_806 CIRQA, hotel_810 Atemporal,
--     hotel_811 Fausto             Andean, +51 1 700 5100
--     hotel_807 Inkaterra Hacienda Urubamba,
--     hotel_808 Inkaterra La Casona
--                                  Inkaterra reservations, +51 1 610 0400
--
-- Left NULL: hotel_815 Antigua Casona San Blas and hotel_817 Tambo del Inka.
-- Neither has an own site that could be reached, so there is no local or
-- group line from the hotel itself; MICHELIN's numbers alone don't meet
-- the rule.
--
-- Fills only empty values. One transaction; aborts if a code is not the
-- expected Peruvian hotel.

begin;

create temp table _ph (code text primary key, name text, phone text) on commit drop;
insert into _ph values
    ('hotel_804', 'Las Casitas, A Belmond Hotel', '+51 908 851 660'),
    ('hotel_805', 'Titilaka by Andean', '+51 1 700 5100'),
    ('hotel_806', 'CIRQA by Andean', '+51 1 700 5100'),
    ('hotel_807', 'Inkaterra Hacienda Urubamba', '+51 1 610 0400'),
    ('hotel_808', 'Inkaterra La Casona', '+51 1 610 0400'),
    ('hotel_810', 'Atemporal by Andean', '+51 1 700 5100'),
    ('hotel_811', 'Fausto by Andean', '+51 1 700 5100'),
    ('hotel_812', 'Monasterio, A Belmond Hotel', '+51 84 604 000'),
    ('hotel_813', 'Miraflores Park, A Belmond Hotel', '+51 1 610 4000'),
    ('hotel_814', 'Rio Sagrado, A Belmond Hotel', '+51 84 201 384');

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _ph p
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = p.code and h.country_code = 'PE' and lower(h.name) = lower(p.name));
  if bad is not null then raise exception 'not the expected Peruvian hotel: %', bad; end if;
end $$;

update public.hotels h set phone = p.phone, updated_at = now()
  from _ph p
 where h.hotel_code = p.code and h.phone is null;

commit;
