-- APPLIED to production 2026-11-16 with the product owner's approval.
--
-- The three regional 50 Best lists, written 2026-11-16 (branch
-- claude/guide-inventory), into the shared guide tables of
-- supabase/migrations/20261101410000_add_shared_guide_tables.sql:
--   * 3 guides rows: asia_50_best, north_america_50_best,
--     latin_america_50_best (measure = rank);
--   * 111 guide_awards rows, one per ranked restaurant that is in the
--     catalogue: Asia's 50 Best 2026 (51 of 100), North America's 50
--     Best 2026 (32 of 50), Latin America's 50 Best 2025 (28 of 100 -- the
--     current edition until the 2026 list on 2026-12-01);
--   * the same 111 matches in guide_venue_links, with their evidence;
--   * 3 guide_coverage rows with the note the site shows.
--
-- PREREQUISITE (checked below): migration 20261101410000.
--
-- Catalogue data, applied explicitly after review, never by a db push:
--   supabase db query --linked --file prepared_regional_50_best_import.sql
-- One transaction; every check raises, which rolls the whole file back.
--
-- Keys: restaurant_code + country_code, never name. Per-entry source URL
-- and match basis: regional_50_best_matches.csv. Entries whose restaurant
-- is not in the catalogue are not added (a regional ranking does not make a
-- restaurant eligible); 3 Asian entries are held back (QA-490). See
-- REGIONAL_50_BEST_REPORT.md.

begin;

do $$ begin
  if to_regclass('public.guide_awards') is null then
    raise exception 'migration 20261101410000 (shared guide tables) is not applied';
  end if;
  if exists (select 1 from public.guides
             where guide_code in ('asia_50_best','north_america_50_best','latin_america_50_best')) then
    raise exception 'regional 50 Best guides already present -- this file has run before';
  end if;
end $$;

insert into public.guides (guide_code, name, publisher, venue_kind, measure, homepage_url, terms_url) values
  ('asia_50_best', 'Asia''s 50 Best Restaurants', 'William Reed Ltd (The 50)', 'restaurant', 'rank',
   'https://www.the50.com/restaurants/best-in-asia/list/1-50', NULL),
  ('north_america_50_best', 'North America''s 50 Best Restaurants', 'William Reed Ltd (The 50)', 'restaurant', 'rank',
   'https://www.the50.com/restaurants/best-in-north-america/list/1-50', NULL),
  ('latin_america_50_best', 'Latin America''s 50 Best Restaurants', 'William Reed Ltd (The 50)', 'restaurant', 'rank',
   'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', NULL);

create temp table regional_50_best_stage (
  guide_code text, edition_year smallint, list_name text, rank smallint,
  restaurant_code text, country_code char(2), profile_url text,
  list_page_url text, evidence text
) on commit drop;

insert into regional_50_best_stage values
    ('asia_50_best', 2026, 'top_50', 1, 'rest_0137', 'HK', 'https://www.the50.com/restaurants/best-in-asia/the-list/The-Chairman.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone agree with the catalogue row. QA-491: page says 3rd Floor, The Wellington, 198 Wellington St; catalogue 18 Kau U Fong (The Chairman''s former address).'),
    ('asia_50_best', 2026, 'top_50', 2, 'rest_0301', 'HK', 'https://www.the50.com/restaurants/best-in-asia/the-list/Wing.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 3, 'rest_0298', 'TH', 'https://www.the50.com/restaurants/best-in-asia/the-list/Gaggan.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 4, 'rest_0313', 'KR', 'https://www.the50.com/restaurants/best-in-asia/the-list/mingles.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 5, 'rest_0318', 'TH', 'https://www.the50.com/restaurants/best-in-asia/the-list/Nusara.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 7, 'rest_0440', 'MO', 'https://www.the50.com/restaurants/best-in-asia/the-list/Chef-Tams-Seasons.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 9, 'rest_2730', 'CN', 'https://www.the50.com/restaurants/best-in-asia/the-list/ling-long.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 10, 'rest_2757', 'CN', 'https://www.the50.com/restaurants/best-in-asia/the-list/Ru-Yuan.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 11, 'rest_1375', 'CN', 'https://www.the50.com/restaurants/best-in-asia/the-list/Fu-He-Hui.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 12, 'rest_0307', 'TH', 'https://www.the50.com/restaurants/best-in-asia/the-list/Sorn.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 13, 'rest_0326', 'JP', 'https://www.the50.com/restaurants/best-in-asia/the-list/La-Cime.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 14, 'rest_1372', 'KR', 'https://www.the50.com/restaurants/best-in-asia/the-list/onjium.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 15, 'rest_1378', 'IN', 'https://www.the50.com/restaurants/best-in-asia/the-list/Masque.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 16, 'rest_0299', 'JP', 'https://www.the50.com/restaurants/best-in-asia/the-list/sezanne.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 17, 'rest_2721', 'CN', 'https://www.the50.com/restaurants/best-in-asia/the-list/lamdre.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 18, 'rest_0311', 'TH', 'https://www.the50.com/restaurants/best-in-asia/the-list/Suhring.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 19, 'rest_0125', 'SG', 'https://www.the50.com/restaurants/best-in-asia/the-list/Odette.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 20, 'rest_4202', 'SG', 'https://www.the50.com/restaurants/best-in-asia/the-list/seroja.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 21, 'rest_0502', 'JP', 'https://www.the50.com/restaurants/best-in-asia/the-list/Sazenka.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 22, 'rest_0467', 'TW', 'https://www.the50.com/restaurants/best-in-asia/the-list/Logy.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 24, 'rest_2844', 'HK', 'https://www.the50.com/restaurants/best-in-asia/the-list/Neighborhood.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 25, 'rest_0303', 'TH', 'https://www.the50.com/restaurants/best-in-asia/the-list/Potong.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 26, 'rest_4203', 'KR', 'https://www.the50.com/restaurants/best-in-asia/the-list/eatanic-garden.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 28, 'rest_0534', 'JP', 'https://www.the50.com/restaurants/best-in-asia/the-list/maz.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 30, 'rest_4200', 'IN', 'https://www.the50.com/restaurants/best-in-asia/the-list/Naar.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 31, 'rest_0319', 'JP', 'https://www.the50.com/restaurants/best-in-asia/the-list/florilege.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 32, 'rest_2824', 'HK', 'https://www.the50.com/restaurants/best-in-asia/the-list/estro.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 34, 'rest_0512', 'JP', 'https://www.the50.com/restaurants/best-in-asia/the-list/crony.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 35, 'rest_0443', 'HK', 'https://www.the50.com/restaurants/best-in-asia/the-list/Caprice.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 36, 'rest_0314', 'TH', 'https://www.the50.com/restaurants/best-in-asia/the-list/Le-Du.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 37, 'rest_0310', 'JP', 'https://www.the50.com/restaurants/best-in-asia/the-list/Narisawa.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row. Narisawa Tokyo, not Narisawa Shanghai (rest_2746, shares the website only).'),
    ('asia_50_best', 2026, 'top_50', 38, 'rest_0124', 'SG', 'https://www.the50.com/restaurants/best-in-asia/the-list/Les-amis.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 40, 'rest_1394', 'SG', 'https://www.the50.com/restaurants/best-in-asia/the-list/Labyrinth.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 41, 'rest_4204', 'KR', 'https://www.the50.com/restaurants/best-in-asia/the-list/Mosu.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 46, 'rest_2841', 'HK', 'https://www.the50.com/restaurants/best-in-asia/the-list/mono.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'top_50', 50, 'rest_0463', 'TW', 'https://www.the50.com/restaurants/best-in-asia/the-list/jl-studio.html', 'https://www.the50.com/restaurants/best-in-asia/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 51, 'rest_0532', 'JP', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Den.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: the row already carries this restaurant''s World''s 50 Best ranks agree with the catalogue row. QA-491: discovery page says JIA building, 2-3-18 Jingumae, Shibuya; catalogue 2-2-32 Kanda Jinbocho (Den''s former address). The row carries Den''s global ranks 2023-2026.'),
    ('asia_50_best', 2026, 'extended_51_100', 52, 'rest_2674', 'CN', 'https://www.the50.com/discovery/Establishments/China/Beijing/Chef-1996.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 53, 'rest_4205', 'TH', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Baan-Tepa.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: website, the row already carries this restaurant''s World''s 50 Best ranks agree with the catalogue row. QA-491: discovery page says 2369 Ramkhamhaeng Rd; catalogue (added 2026-11-16 from the 50 Best page) 561 Ramkhamhaeng Road. Same website baantepabkk.com.'),
    ('asia_50_best', 2026, 'extended_51_100', 59, 'rest_1391', 'SG', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Burnt-Ends.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: website, the row already carries this restaurant''s World''s 50 Best ranks agree with the catalogue row. Discovery page still shows Burnt Ends'' former address (20 Teck Lim Road); catalogue has the current 7 Dempsey Rd. Same website.'),
    ('asia_50_best', 2026, 'extended_51_100', 61, 'rest_2911', 'TW', 'https://www.the50.com/discovery/Establishments/Taiwan/Taipei/Mume.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address, website agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 64, 'rest_2920', 'TW', 'https://www.the50.com/discovery/Establishments/Taiwan/Taipei/Silks-House.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 65, 'rest_2694', 'CN', 'https://www.the50.com/discovery/Establishments/China/Shenzhen/Fumée.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 68, 'rest_0446', 'HK', 'https://www.the50.com/discovery/Establishments/China/Hong-Kong/Ta-Vie.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: website agree with the catalogue row. Discovery page says 21 Stanley Street; catalogue 2/F The Pottinger, 74 Queen’s Road Central (the hotel spans both streets). Same website tavie.com.hk.'),
    ('asia_50_best', 2026, 'extended_51_100', 76, 'rest_0588', 'JP', 'https://www.the50.com/discovery/Establishments/Japan/Kyoto/Cenci.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address, website agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 79, 'rest_2684', 'CN', 'https://www.the50.com/discovery/Establishments/China/Shenzhen/Ensue.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 80, 'rest_0435', 'MO', 'https://www.the50.com/discovery/Establishments/China/Macau/Jade-Dragon.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 84, 'rest_0471', 'CN', 'https://www.the50.com/discovery/Establishments/China/Beijing/Xin-Rong-Ji-Xinyuan-South-Road.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 85, 'rest_2717', 'CN', 'https://www.the50.com/discovery/Establishments/China/Hangzhou/Jin-Sha.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 88, 'rest_2816', 'HK', 'https://www.the50.com/discovery/Establishments/China/Hong-Kong/Ando.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address, website agree with the catalogue row'),
    ('asia_50_best', 2026, 'extended_51_100', 90, 'rest_0442', 'HK', 'https://www.the50.com/discovery/Establishments/China/Hong-Kong/Amber.html', 'https://www.the50.com/restaurants/best-in-asia/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 1, 'rest_1370', 'CO', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/El-Chato.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 2, 'rest_0135', 'PE', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Kjolle.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 3, 'rest_0136', 'AR', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Don-Julio.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: the row already carries this restaurant''s World''s 50 Best ranks agree with the catalogue row. QA-491: page says Guatemala 4691 (corner Gurruchaga), catalogue Guatemala 4699 - same corner; the row carries Don Julio''s global ranks 2023-2026.'),
    ('latin_america_50_best', 2025, 'top_50', 4, 'rest_0139', 'PE', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Mérito.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: address agree with the catalogue row. Page says Barranco, catalogue address says Miraflores; same street address.'),
    ('latin_america_50_best', 2025, 'top_50', 5, 'rest_0143', 'CO', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Celele.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: phone agree with the catalogue row. QA-491: page says Calle del Espíritu Santo, Getsemaní; catalogue Calle del Estanco del Tabaco 35-80.'),
    ('latin_america_50_best', 2025, 'top_50', 6, 'rest_0138', 'CL', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Boragó.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: phone agree with the catalogue row. QA-491: page says San José María Escrivá de Balaguer 5970; catalogue Av. Nueva Costanera 3467.'),
    ('latin_america_50_best', 2025, 'top_50', 7, 'rest_0132', 'MX', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Quintonil.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 8, 'rest_1379', 'BR', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/tuju.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 10, 'rest_1374', 'EC', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/nuema.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 11, 'rest_0141', 'PE', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Mayta.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: phone agree with the catalogue row. QA-491: page says Av. Mariscal La Mar 1285; catalogue Calle Elias Aguirre 180.'),
    ('latin_america_50_best', 2025, 'top_50', 12, 'rest_4201', 'BR', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/nelita.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 13, 'rest_0140', 'BR', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Lasai.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: the row already carries this restaurant''s World''s 50 Best ranks agree with the catalogue row. QA-491: page says Largo dos Leões 35, Humaitá; catalogue Rua Conde de Irajá 191, Botafogo. The row carries Lasai''s global ranks 2023-2026; the catalogue address looks out of date.'),
    ('latin_america_50_best', 2025, 'top_50', 15, 'rest_1369', 'MX', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Alcalde.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 17, 'rest_4207', 'MX', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/fauna.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 20, 'rest_1393', 'BR', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/evvai.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 22, 'rest_1377', 'MX', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/arca.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 23, 'rest_1382', 'CO', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/leo.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 25, 'rest_1386', 'BR', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/a-casa-do-porco.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 30, 'rest_3287', 'MX', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Máximo.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 32, 'rest_1390', 'MX', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Huniik.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row. Huniik (C. 60 415-B), not La Barra de Huniik (rest_3280, C. 60 417).'),
    ('latin_america_50_best', 2025, 'top_50', 38, 'rest_1384', 'BR', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/oteque.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 39, 'rest_0328', 'MX', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Rosetta.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'top_50', 49, 'rest_1381', 'PE', 'https://www.the50.com/restaurants/best-in-latin-america/the-list/Mil.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row. Listed in Moray, catalogue city Cusco; same address (Vía a Moray, Maras).'),
    ('latin_america_50_best', 2025, 'extended_51_100', 51, 'rest_0133', 'MX', 'https://www.the50.com/discovery/Establishments/Mexico/Mexico-City/Pujol.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/51-100', 'the50.com discovery page: website, the row already carries this restaurant''s World''s 50 Best ranks agree with the catalogue row. Discovery page says Tennyson 113; catalogue Tennyson 133. Same website pujol.com.mx; the row carries Pujol''s global ranks.'),
    ('latin_america_50_best', 2025, 'extended_51_100', 58, 'rest_3282', 'MX', 'https://www.the50.com/discovery/Establishments/Mexico/Cancún/Le-Chique.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/51-100', 'the50.com discovery page: address agree with the catalogue row. Listed in Cancún; discovery address (Km 282 L21, Carretera Chetumal-Puerto Juárez) is the catalogue''s Hotel Xcaret Arte address in Playa del Carmen.'),
    ('latin_america_50_best', 2025, 'extended_51_100', 59, 'rest_3290', 'MX', 'https://www.the50.com/discovery/Establishments/Mexico/Mexico-City/Sud-777.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/51-100', 'the50.com discovery page: address agree with the catalogue row'),
    ('latin_america_50_best', 2025, 'extended_51_100', 71, 'rest_3273', 'MX', 'https://www.the50.com/discovery/Establishments/Mexico/Mexico-City/Em.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/51-100', 'the50.com discovery page: website agree with the catalogue row. QA-491: discovery page says Tonalá 133, Roma Norte; catalogue Ámsterdam 76, Condesa. Same website itsemilia.rest.'),
    ('latin_america_50_best', 2025, 'extended_51_100', 90, 'rest_3285', 'MX', 'https://www.the50.com/discovery/Establishments/Mexico/Ensenada/Lunario.html', 'https://www.the50.com/restaurants/best-in-latin-america/list/51-100', 'the50.com discovery page: address agree with the catalogue row. Listed in Valle de Guadalupe; catalogue city El Porvenir (same valley, same address).'),
    ('north_america_50_best', 2026, 'top_50', 1, 'rest_0745', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/smyth.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 3, 'rest_3257', 'CA', 'https://www.the50.com/restaurants/best-in-north-america/the-list/restaurant-pearl-morissette.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 4, 'rest_3042', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/dakar-nola.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 6, 'rest_3003', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/albi.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 7, 'rest_0302', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/atomix.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 8, 'rest_3255', 'CA', 'https://www.the50.com/restaurants/best-in-north-america/the-list/quetzal.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 9, 'rest_3266', 'CA', 'https://www.the50.com/restaurants/best-in-north-america/the-list/taniere3.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 10, 'rest_0763', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/cesar.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 13, 'rest_0059', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/le-bernadin.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 16, 'rest_0736', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/singlethread.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 17, 'rest_3254', 'CA', 'https://www.the50.com/restaurants/best-in-north-america/the-list/published-on-main.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 18, 'rest_0053', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/jungsik.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 20, 'rest_3052', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/emerils.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 22, 'rest_0746', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/saison.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 23, 'rest_0760', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/aska.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 25, 'rest_3237', 'CA', 'https://www.the50.com/restaurants/best-in-north-america/the-list/edulis.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 26, 'rest_3073', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/holbox.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 31, 'rest_0742', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/Addison-by-William-Bradley.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 32, 'rest_0743', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/providence.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 33, 'rest_0737', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/benu.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 34, 'rest_3258', 'CA', 'https://www.the50.com/restaurants/best-in-north-america/the-list/sabayon.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 35, 'rest_3231', 'CA', 'https://www.the50.com/restaurants/best-in-north-america/the-list/annalena.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 36, 'rest_3033', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/corima.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 38, 'rest_3214', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/Torrisi.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 40, 'rest_3063', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/friday-saturday-sunday.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 41, 'rest_3177', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/Semma.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 43, 'rest_3066', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/Gramercy-Tavern.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 44, 'rest_0738', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/atelier-crenn.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 45, 'rest_0750', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/Sons-Daughters.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 46, 'rest_0744', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/somni.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 48, 'rest_3267', 'CA', 'https://www.the50.com/restaurants/best-in-north-america/the-list/The-Pine.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row'),
    ('north_america_50_best', 2026, 'top_50', 49, 'rest_0757', 'US', 'https://www.the50.com/restaurants/best-in-north-america/the-list/kato.html', 'https://www.the50.com/restaurants/best-in-north-america/list/1-50', 'the50.com venue page: website, phone, address agree with the catalogue row');

-- Every staged code must resolve to exactly one catalogue row in its country.
do $$
declare missing int;
begin
  select count(*) into missing
  from regional_50_best_stage s
  left join public.restaurants r
    on r.restaurant_code = s.restaurant_code and r.country_code = s.country_code
  where r.id is null;
  if missing > 0 then
    raise exception '% staged rows do not resolve on restaurant_code + country_code', missing;
  end if;
end $$;

insert into public.guide_awards (guide_code, restaurant_id, edition_year, list_name, rank, source_url, announced_on)
select s.guide_code, r.id, s.edition_year, s.list_name, s.rank, s.list_page_url,
       case s.guide_code
         when 'asia_50_best' then date '2026-03-25'
         when 'north_america_50_best' then date '2026-05-28'
         else NULL  -- Latin America 2025: exact date not verified
       end
from regional_50_best_stage s
join public.restaurants r
  on r.restaurant_code = s.restaurant_code and r.country_code = s.country_code;

insert into public.guide_venue_links (guide_code, restaurant_id, profile_url, evidence, verified_at)
select s.guide_code, r.id, s.profile_url, s.evidence, date '2026-11-16'
from regional_50_best_stage s
join public.restaurants r
  on r.restaurant_code = s.restaurant_code and r.country_code = s.country_code;

insert into public.guide_coverage (guide_code, country_code, edition_year, coverage, note) values
  ('asia_50_best', NULL, 2026, 'partial',
   'Shown for the 51 restaurants of the 100 that are in our catalogue. Three more are still being checked.'),
  ('north_america_50_best', NULL, 2026, 'complete',
   'Shown for the 32 restaurants of the 50 that are in our catalogue.'),
  ('latin_america_50_best', NULL, 2025, 'complete',
   'Shown for the 28 restaurants of the 100 that are in our catalogue. The 2026 list follows on 1 December 2026.');

-- Post-checks.
do $$
declare a int; n int; l int; k int;
begin
  select count(*) into a from public.guide_awards where guide_code = 'asia_50_best' and edition_year = 2026;
  select count(*) into n from public.guide_awards where guide_code = 'north_america_50_best' and edition_year = 2026;
  select count(*) into l from public.guide_awards where guide_code = 'latin_america_50_best' and edition_year = 2025;
  select count(*) into k from public.guide_venue_links;
  if a <> 51 or n <> 32 or l <> 28 or k <> 111 then
    raise exception 'post-check failed: asia % na % latam % links %', a, n, l, k;
  end if;
end $$;

commit;
