-- Prepared data update for the guide-source links. NOT APPLIED.
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

-- 1. QA-244: the 8 Austrian "not found" placeholders become NULL.
do $$ declare n int; begin
  update public.gault_millau_awards set gault_millau_url = null
   where gault_millau_url is not null and gault_millau_url !~ '^https?://';
  get diagnostics n = row_count;
  if n <> 8 then raise exception 'placeholders: expected 8, got %', n; end if;
end $$;

-- 2a. QA-244: the 7 Austrian pages found in gaultmillau.at's own sitemap
--     and verified (gault_millau_at_urls.csv). Obauer stays NULL.
do $$ declare n int; begin
  update public.gault_millau_awards g set gault_millau_url = v.url
    from (values
    ('rest_0267', 'https://www.gaultmillau.at/restaurant/dollerer'),
    ('rest_0275', 'https://www.gaultmillau.at/restaurant/ikarus-2'),
    ('rest_0282', 'https://www.gaultmillau.at/restaurant/konstantin-filippou-2'),
    ('rest_0283', 'https://www.gaultmillau.at/restaurant/mraz-sohn'),
    ('rest_0284', 'https://www.gaultmillau.at/restaurant/silvio-nickol-gourmet-restaurant-2'),
    ('rest_0269', 'https://www.gaultmillau.at/restaurant/stuva'),
    ('rest_0279', 'https://www.gaultmillau.at/restaurant/taubenkobel')
    ) v(code, url), public.restaurants r
   where r.restaurant_code = v.code and g.restaurant_id = r.id
     and g.guide_year = 2026 and g.gault_millau_url is null;
  get diagnostics n = row_count;
  if n <> 7 then raise exception 'AT urls: expected 7, got %', n; end if;
end $$;

-- 2b. QA-245: 21 toque counts read from each restaurant's own page, only
--     where the page score equals ours (gault_millau_toques.csv).
do $$ declare n int; begin
  update public.gault_millau_awards g set toque_count = v.toques
    from (values
    ('rest_0164', 4, 18.0),
    ('rest_0155', 5, 19.0),
    ('rest_0156', 4, 17.5),
    ('rest_0166', 4, 17.5),
    ('rest_0169', 4, 18.0),
    ('rest_0159', 4, 18.0),
    ('rest_0165', 4, 18.0),
    ('rest_0161', 4, 18.0),
    ('rest_0154', 4, 18.5),
    ('rest_0146', 4, 18.0),
    ('rest_0018', 5, 19.0),
    ('rest_0025', 5, 19.0),
    ('rest_0030', 4, 17.5),
    ('rest_0037', 5, 19.5),
    ('rest_0038', 4, 18.0),
    ('rest_0040', 4, 17.5),
    ('rest_0041', 4, 17.5),
    ('rest_0047', 4, 18.0),
    ('rest_0048', 4, 18.0),
    ('rest_0079', 4, 17.5),
    ('rest_0110', 5, 19.0)
    ) v(code, toques, score), public.restaurants r
   where r.restaurant_code = v.code and g.restaurant_id = r.id
     and g.guide_year = 2026 and g.toque_count is null and g.score = v.score;
  get diagnostics n = row_count;
  if n <> 21 then raise exception 'toques: expected 21, got %', n; end if;
end $$;

-- 3. World's 50 Best restaurant pages (113, worlds_50_best_restaurant_urls.csv apply=yes).
do $$ declare n int; begin
  update public.restaurants r set worlds_50_best_url = v.url
    from (values
    ('rest_0037', 'https://www.the50.com/discovery/Establishments/Netherlands/Zwolle/De-Librije.html'),
    ('rest_0044', 'https://www.the50.com/discovery/Establishments/Spain/Madrid/DiverXO.html'),
    ('rest_0045', 'https://www.the50.com/discovery/Establishments/US/New-York/Eleven-Madison-Park.html'),
    ('rest_0059', 'https://www.the50.com/discovery/Establishments/US/New-York/Le-Bernardin.html'),
    ('rest_0071', 'https://www.the50.com/discovery/Establishments/Türkiye/Istanbul/Neolokal.html'),
    ('rest_0078', 'https://www.the50.com/discovery/Establishments/Italy/Modena/Osteria-Francescana.html'),
    ('rest_0080', 'https://www.the50.com/discovery/Establishments/US/New-York/Per-Se.html'),
    ('rest_0124', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Les-Amis.html'),
    ('rest_0125', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Odette.html'),
    ('rest_0126', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Zén.html'),
    ('rest_0128', 'https://www.the50.com/discovery/Establishments/United-Arab-Emirates/Dubai/Trèsind-Studio.html'),
    ('rest_0132', 'https://www.the50.com/discovery/Establishments/Mexico/Mexico-City/Quintonil.html'),
    ('rest_0133', 'https://www.the50.com/discovery/Establishments/Mexico/Mexico-City/Pujol.html'),
    ('rest_0134', 'https://www.the50.com/discovery/Establishments/Peru/Lima/Maido.html'),
    ('rest_0135', 'https://www.the50.com/discovery/Establishments/Peru/Lima/Kjolle.html'),
    ('rest_0136', 'https://www.the50.com/discovery/Establishments/Argentina/Buenos-Aires/Don-Julio.html'),
    ('rest_0137', 'https://www.the50.com/discovery/Establishments/China/Hong-Kong/The-Chairman.html'),
    ('rest_0138', 'https://www.the50.com/discovery/Establishments/Chile/Santiago/Boragó.html'),
    ('rest_0139', 'https://www.the50.com/discovery/Establishments/Peru/Lima/Mérito.html'),
    ('rest_0140', 'https://www.the50.com/discovery/Establishments/Brazil/Rio-de-Janeiro/Lasai.html'),
    ('rest_0141', 'https://www.the50.com/discovery/Establishments/Peru/Lima/Mayta.html'),
    ('rest_0143', 'https://www.the50.com/discovery/Establishments/Colombia/Cartagena/Celele.html'),
    ('rest_0156', 'https://www.the50.com/discovery/Establishments/Belgium/Brussels/Bozar-Restaurant.html'),
    ('rest_0165', 'https://www.the50.com/discovery/Establishments/Belgium/Kruisem/Hof-van-Cleve.html'),
    ('rest_0182', 'https://www.the50.com/discovery/Establishments/Germany/Munich/Restaurant-Jan.html'),
    ('rest_0190', 'https://www.the50.com/discovery/Establishments/Germany/Berlin/CODA.html'),
    ('rest_0193', 'https://www.the50.com/discovery/Establishments/Germany/Berlin/Restaurant-Tim-Raue.html'),
    ('rest_0212', 'https://www.the50.com/discovery/Establishments/Germany/Munich/Tantris.html'),
    ('rest_0236', 'https://www.the50.com/discovery/Establishments/Switzerland/Crissier/Restaurant-de-lHôtel-de-Ville.html'),
    ('rest_0237', 'https://www.the50.com/discovery/Establishments/Switzerland/Fürstenau/Schloss-Schauenstein.html'),
    ('rest_0266', 'https://www.the50.com/discovery/Establishments/Austria/Vienna/Steirereck.html'),
    ('rest_0296', 'https://www.the50.com/discovery/Establishments/Spain/Atxondo/Asador-Etxebarri.html'),
    ('rest_0297', 'https://www.the50.com/discovery/Establishments/Denmark/Copenhagen/Alchemist.html'),
    ('rest_0298', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Gaggan.html'),
    ('rest_0299', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Sézanne.html'),
    ('rest_0300', 'https://www.the50.com/discovery/Establishments/France/Paris/Table.html'),
    ('rest_0301', 'https://www.the50.com/discovery/Establishments/China/Hong-Kong/Wing.html'),
    ('rest_0302', 'https://www.the50.com/discovery/Establishments/US/New-York/Atomix.html'),
    ('rest_0303', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Potong.html'),
    ('rest_0304', 'https://www.the50.com/discovery/Establishments/France/Paris/Plénitude.html'),
    ('rest_0305', 'https://www.the50.com/discovery/Establishments/UK/London/Ikoyi.html'),
    ('rest_0307', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Sorn.html'),
    ('rest_0308', 'https://www.the50.com/discovery/Establishments/Italy/Castel-di-Sangro/Reale.html'),
    ('rest_0309', 'https://www.the50.com/discovery/Establishments/Italy/Brunico/Atelier-Moessmer-Norbert-Niederkofler.html'),
    ('rest_0310', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Narisawa.html'),
    ('rest_0311', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Sühring.html'),
    ('rest_0312', 'https://www.the50.com/discovery/Establishments/Spain/Getaria/Elkano.html'),
    ('rest_0313', 'https://www.the50.com/discovery/Establishments/South-Korea/Seoul/Mingles.html'),
    ('rest_0314', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Le-Du.html'),
    ('rest_0315', 'https://www.the50.com/discovery/Establishments/Italy/Rubano/Le-Calandre.html'),
    ('rest_0316', 'https://www.the50.com/discovery/Establishments/Italy/Alba/Piazza-Duomo.html'),
    ('rest_0318', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Nusara.html'),
    ('rest_0319', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Florilège.html'),
    ('rest_0320', 'https://www.the50.com/discovery/Establishments/United-Arab-Emirates/Dubai/Orfali-Bros.html'),
    ('rest_0321', 'https://www.the50.com/discovery/Establishments/Sweden/Stockholm/Frantzén.html'),
    ('rest_0322', 'https://www.the50.com/discovery/Establishments/France/Paris/Septime.html'),
    ('rest_0323', 'https://www.the50.com/discovery/Establishments/Denmark/Copenhagen/Kadeau.html'),
    ('rest_0324', 'https://www.the50.com/discovery/Establishments/Portugal/Lisbon/Belcanto.html'),
    ('rest_0325', 'https://www.the50.com/discovery/Establishments/Italy/Senigallia/Uliassi.html'),
    ('rest_0326', 'https://www.the50.com/discovery/Establishments/Japan/Osaka/La-Cime.html'),
    ('rest_0327', 'https://www.the50.com/discovery/Establishments/France/Paris/Arpège.html'),
    ('rest_0328', 'https://www.the50.com/discovery/Establishments/Mexico/Mexico-City/Rosetta.html'),
    ('rest_0329', 'https://www.the50.com/discovery/Establishments/UK/London/Kol.html'),
    ('rest_0330', 'https://www.the50.com/discovery/Establishments/Spain/Barcelona/Cocina-Hermanos-Torres.html'),
    ('rest_0331', 'https://www.the50.com/discovery/Establishments/Spain/Barcelona/Disfrutar.html'),
    ('rest_0333', 'https://www.the50.com/discovery/Establishments/Spain/Dénia/Quique-Dacosta.html'),
    ('rest_0336', 'https://www.the50.com/discovery/Establishments/Spain/El-Puerto-de-Santa-María/Aponiente.html'),
    ('rest_0337', 'https://www.the50.com/discovery/Establishments/Spain/Girona/El-Celler-de-Can-Roca.html'),
    ('rest_0338', 'https://www.the50.com/discovery/Establishments/Spain/Larrabetzu/Azurmendi.html'),
    ('rest_0339', 'https://www.the50.com/discovery/Establishments/Spain/Lasarte-Oria/Martin-Berasategui.html'),
    ('rest_0356', 'https://www.the50.com/discovery/Establishments/Spain/Errenteria/Mugaritz.html'),
    ('rest_0381', 'https://www.the50.com/discovery/Establishments/Italy/Florence/Enoteca-Pinchiorri.html'),
    ('rest_0383', 'https://www.the50.com/discovery/Establishments/Italy/Milan/Enrico-Bartolini.html'),
    ('rest_0424', 'https://www.the50.com/discovery/Establishments/Slovenia/Kobarid/Hiša-Franko.html'),
    ('rest_0430', 'https://www.the50.com/discovery/Establishments/Norway/Oslo/Maaemo.html'),
    ('rest_0440', 'https://www.the50.com/discovery/Establishments/China/Cotai/Chef-Tams-Seasons.html'),
    ('rest_0441', 'https://www.the50.com/discovery/Establishments/China/Hong-Kong/8-12-Otto-e-Mezzo-Bombana.html'),
    ('rest_0473', 'https://www.the50.com/discovery/Establishments/Denmark/Copenhagen/Geranium.html'),
    ('rest_0474', 'https://www.the50.com/discovery/Establishments/Denmark/Copenhagen/Jordnær.html'),
    ('rest_0476', 'https://www.the50.com/discovery/Establishments/Denmark/Copenhagen/Koan.html'),
    ('rest_0532', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Den.html'),
    ('rest_0735', 'https://www.the50.com/discovery/Establishments/US/Yountville/The-French-Laundry.html'),
    ('rest_0736', 'https://www.the50.com/discovery/Establishments/US/Healdsburg/SingleThread.html'),
    ('rest_0738', 'https://www.the50.com/discovery/Establishments/US/San-Francisco/Atelier-Crenn.html'),
    ('rest_0762', 'https://www.the50.com/discovery/Establishments/US/Pocantico-Hills/Blue-Hill-at-Stone-Barns.html'),
    ('rest_0763', 'https://www.the50.com/discovery/Establishments/US/New-York/César.html'),
    ('rest_0766', 'https://www.the50.com/discovery/Establishments/US/New-York/Jean-Georges.html'),
    ('rest_0772', 'https://www.the50.com/discovery/Establishments/US/Chicago/Alinea.html'),
    ('rest_0842', 'https://www.the50.com/discovery/Establishments/Belgium/Koksijde/Willem-Hiele.html'),
    ('rest_1369', 'https://www.the50.com/discovery/Establishments/Mexico/Guadalajara/Alcalde.html'),
    ('rest_1370', 'https://www.the50.com/discovery/Establishments/Colombia/Bogotá/El-Chato.html'),
    ('rest_1372', 'https://www.the50.com/discovery/Establishments/South-Korea/Seoul/Onjium.html'),
    ('rest_1373', 'https://www.the50.com/discovery/Establishments/Germany/Berlin/Nobelhart-and-Schmutzig.html'),
    ('rest_1374', 'https://www.the50.com/discovery/Establishments/Ecuador/Quito/Nuema.html'),
    ('rest_1375', 'https://www.the50.com/discovery/Establishments/China/Shanghai/Fu-He-Hui.html'),
    ('rest_1376', 'https://www.the50.com/discovery/Establishments/Australia/Sydney/Saint-Peter.html'),
    ('rest_1378', 'https://www.the50.com/discovery/Establishments/India/Mumbai/Masque.html'),
    ('rest_1379', 'https://www.the50.com/discovery/Establishments/Brazil/São-Paulo/Tuju.html'),
    ('rest_1380', 'https://www.the50.com/discovery/Establishments/UK/London/Mountain.html'),
    ('rest_1381', 'https://www.the50.com/discovery/Establishments/Peru/Near-Cusco/Mil.html'),
    ('rest_1382', 'https://www.the50.com/discovery/Establishments/Colombia/Bogotá/Leo.html'),
    ('rest_1383', 'https://www.the50.com/discovery/Establishments/France/Saint-Vrain/Le-Doyenné.html'),
    ('rest_1384', 'https://www.the50.com/discovery/Establishments/Brazil/Rio-de-Janeiro/Oteque.html'),
    ('rest_1385', 'https://www.the50.com/discovery/Establishments/South-Africa/Cape-Town/Fyn-Restaurant.html'),
    ('rest_1386', 'https://www.the50.com/discovery/Establishments/Brazil/São-Paulo/A-Casa-do-Porco.html'),
    ('rest_1387', 'https://www.the50.com/discovery/Establishments/Spain/Bilbao/Txispa.html'),
    ('rest_1388', 'https://www.the50.com/discovery/Establishments/UK/London/The-Clove-Club.html'),
    ('rest_1389', 'https://www.the50.com/discovery/Establishments/South-Africa/Cape-Town/Salsify-at-the-Roundhouse.html'),
    ('rest_1390', 'https://www.the50.com/discovery/Establishments/Mexico/Merida/Huniik.html'),
    ('rest_1391', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Burnt-Ends.html'),
    ('rest_1393', 'https://www.the50.com/discovery/Establishments/Brazil/São-Paulo/Evvai.html'),
    ('rest_1394', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Labyrinth.html'),
    ('rest_1578', 'https://www.the50.com/discovery/Establishments/Peru/Lima/Central.html')
    ) v(code, url)
   where r.restaurant_code = v.code and r.worlds_50_best_url is null;
  get diagnostics n = row_count;
  if n <> 113 then raise exception 'restaurant urls: expected 113, got %', n; end if;
end $$;

-- 4. World's 50 Best hotel pages (123, worlds_50_best_hotel_urls.csv apply=yes).
do $$ declare n int; begin
  update public.hotels h set worlds_50_best_url = v.url
    from (values
    ('hotel_186', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Raffles-Singapore.html'),
    ('hotel_187', 'https://www.the50.com/discovery/Establishments/Singapore/Singapore/Capella-Singapore.html'),
    ('hotel_193', 'https://www.the50.com/hotels/best-in-the-world/the-list/hotel-de-paris-monte-carlo.html'),
    ('hotel_195', 'https://www.the50.com/discovery/Establishments/Brazil/Rio-de-Janeiro/Copacabana-Palace-A-Belmond-Hotel.html'),
    ('hotel_30', 'https://www.the50.com/hotels/best-in-the-world/the-list/hotel-sacher-vienna.html'),
    ('hotel_320', 'https://www.the50.com/discovery/Establishments/Italy/Positano/Il-San-Pietro-di-Positano.html'),
    ('hotel_328', 'https://www.the50.com/discovery/Establishments/Italy/Venice/Aman-Venice.html'),
    ('hotel_338', 'https://www.the50.com/discovery/Establishments/Italy/Lisciano-Niccone/Reschio-Hotel.html'),
    ('hotel_343', 'https://www.the50.com/discovery/Establishments/Italy/Positano/Le-Sirenuse.html'),
    ('hotel_346', 'https://www.the50.com/discovery/Establishments/Italy/Modena/Casa-Maria-Luigia.html'),
    ('hotel_401', 'https://www.the50.com/discovery/Establishments/Italy/Milan/Portrait-Milano.html'),
    ('hotel_452', 'https://www.the50.com/discovery/Establishments/Italy/Savelletri/Borgo-Egnazia.html'),
    ('hotel_470', 'https://www.the50.com/discovery/Establishments/Spain/Madrid/Four-Seasons-Madrid.html'),
    ('hotel_540', 'https://www.the50.com/discovery/Establishments/Spain/Madrid/Mandarin-Oriental-Ritz-Madrid.html'),
    ('hotel_55', 'https://www.the50.com/discovery/Establishments/Switzerland/St-Moritz/Badrutts-Palace.html'),
    ('hotel_575', 'https://www.the50.com/discovery/Establishments/Japan/Osaka/Patina-Osaka.html'),
    ('hotel_635', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/The-Okura.html'),
    ('hotel_643', 'https://www.the50.com/discovery/Establishments/Japan/Kyoto/Hotel-the-Mitsui-Kyoto.html'),
    ('hotel_647', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Bulgari-Hotel-Tokyo.html'),
    ('hotel_658', 'https://www.the50.com/discovery/Establishments/Japan/Kyoto/Park-Hyatt-Kyoto.html'),
    ('hotel_681', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Janu-Tokyo.html'),
    ('hotel_688', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Aman-Tokyo.html'),
    ('hotel_689', 'https://www.the50.com/discovery/Establishments/Italy/Amalfi/Borgo-Santandrea.html'),
    ('hotel_690', 'https://www.the50.com/discovery/Establishments/Italy/Rome/Bulgari-Roma.html'),
    ('hotel_691', 'https://www.the50.com/discovery/Establishments/Italy/Florence/Four-Seasons-Firenze.html'),
    ('hotel_692', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Hoshinoya-Tokyo.html'),
    ('hotel_693', 'https://www.the50.com/discovery/Establishments/Italy/Venice/Hotel-Cipriani.html'),
    ('hotel_694', 'https://www.the50.com/discovery/Establishments/Italy/Località-Sbarcatello/Il-Pellicano.html'),
    ('hotel_695', 'https://www.the50.com/discovery/Establishments/Brazil/Foz-do-Iguaçu/Hotel-das-Cataratas.html'),
    ('hotel_696', 'https://www.the50.com/discovery/Establishments/Italy/Lake-Como/Passalacqua.html'),
    ('hotel_697', 'https://www.the50.com/discovery/Establishments/Brazil/São-Paulo/Rosewood-São-Paulo.html'),
    ('hotel_698', 'https://www.the50.com/discovery/Establishments/Spain/Portinatx/Six-Senses-Ibiza.html'),
    ('hotel_699', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/The-Tokyo-Edition-Toranomon.html'),
    ('hotel_700', 'https://www.the50.com/discovery/Establishments/Australia/Sydney/Capella-Sydney.html'),
    ('hotel_701', 'https://www.the50.com/discovery/Establishments/Australia/Hanson-Bay/Southern-Ocean-Lodge.html'),
    ('hotel_702', 'https://www.the50.com/discovery/Establishments/Australia/Brisbane/The-Calile.html'),
    ('hotel_703', 'https://www.the50.com/discovery/Establishments/Australia/Hobart/The-Tasman.html'),
    ('hotel_704', 'https://www.the50.com/discovery/Establishments/China/Beijing/Mandarin-Oriental-Qianmen.html'),
    ('hotel_705', 'https://www.the50.com/discovery/Establishments/Mexico/Jalisco/Four-Seasons-Resort-Tamarindo.html'),
    ('hotel_707', 'https://www.the50.com/discovery/Establishments/France/Paris/Cheval-Blanc.html'),
    ('hotel_708', 'https://www.the50.com/discovery/Establishments/France/Paris/Hôtel-de-Crillon.html'),
    ('hotel_709', 'https://www.the50.com/discovery/Establishments/France/Antibes/Hotel-Du-Cap-Eden-Roc.html'),
    ('hotel_710', 'https://www.the50.com/discovery/Establishments/France/Nice/Hôtel-du-Couvent.html'),
    ('hotel_711', 'https://www.the50.com/discovery/Establishments/France/Paris/La-Réserve.html'),
    ('hotel_712', 'https://www.the50.com/discovery/Establishments/France/Paris/Le-Bristol.html'),
    ('hotel_713', 'https://www.the50.com/discovery/Establishments/France/Paris/Hôtel-Plaza-Athénée.html'),
    ('hotel_714', 'https://www.the50.com/discovery/Establishments/France/Roquebrune-Cap-Martin/The-Maybourne-Riviera.html'),
    ('hotel_716', 'https://www.the50.com/discovery/Establishments/Greece/Athens/Four-Seasons-Astir-Palace.html'),
    ('hotel_717', 'https://www.the50.com/discovery/Establishments/Hong-Kong/Hong-Kong/Four-Seasons-Hong-Kong.html'),
    ('hotel_718', 'https://www.the50.com/discovery/Establishments/Hong-Kong/Hong-Kong/Mandarin-Oriental-Hong-Kong.html'),
    ('hotel_719', 'https://www.the50.com/discovery/Establishments/Hong-Kong/Hong-Kong/Rosewood-Hong-Kong.html'),
    ('hotel_720', 'https://www.the50.com/discovery/Establishments/Hong-Kong/Hong-Kong/The-Peninsula-Hong-Kong.html'),
    ('hotel_721', 'https://www.the50.com/discovery/Establishments/Hong-Kong/Hong-Kong/Upper-House-Hong-Kong.html'),
    ('hotel_724', 'https://www.the50.com/discovery/Establishments/India/Jaipur/The-Johri.html'),
    ('hotel_725', 'https://www.the50.com/discovery/Establishments/India/Agra/The-Oberoi-Amarvilas.html'),
    ('hotel_726', 'https://www.the50.com/discovery/Establishments/India/Mumbai/Taj-Mahal-Palace-Mumbai.html'),
    ('hotel_727', 'https://www.the50.com/discovery/Establishments/Indonesia/Bali/Desa-Potato-Head.html'),
    ('hotel_728', 'https://www.the50.com/discovery/Establishments/Indonesia/Bali/Mandapa-a-Ritz-Carlton-Reserve.html'),
    ('hotel_729', 'https://www.the50.com/discovery/Establishments/Indonesia/Sumba-Island/Nihi-Sumba.html'),
    ('hotel_730', 'https://www.the50.com/discovery/Establishments/Malaysia/Langkawi/The-Datai-Langkawi.html'),
    ('hotel_731', 'https://www.the50.com/discovery/Establishments/Maldives/Maldives/Soneva-Fushi.html'),
    ('hotel_732', 'https://www.the50.com/discovery/Establishments/Maldives/Maldives/Soneva-Jani.html'),
    ('hotel_734', 'https://www.the50.com/discovery/Establishments/Mexico/Chocholá/Chablé-Yucatán.html'),
    ('hotel_735', 'https://www.the50.com/discovery/Establishments/Mexico/Tulum/Hotel-Esencia.html'),
    ('hotel_736', 'https://www.the50.com/discovery/Establishments/Mexico/San-José-del-Cabo/Rosewood-Las-Ventanas-Al-Paraiso.html'),
    ('hotel_737', 'https://www.the50.com/discovery/Establishments/Mexico/Quintana-Roo/Belmond-Maroma.html'),
    ('hotel_738', 'https://www.the50.com/discovery/Establishments/Mexico/Cabo-San-Lucas/Montage-Los-Cabos.html'),
    ('hotel_741', 'https://www.the50.com/discovery/Establishments/Morocco/Marrakech/La-Mamounia.html'),
    ('hotel_742', 'https://www.the50.com/discovery/Establishments/Morocco/Marrakech/Royal-Mansour.html'),
    ('hotel_744', 'https://www.the50.com/discovery/Establishments/Oman/Dibba-Musandam/Six-Senses-Zighy-Bay.html'),
    ('hotel_745', 'https://www.the50.com/discovery/Establishments/Peru/Cusco/Palacio-Nazarenas-A-Belmond-Hotel-Cusco.html'),
    ('hotel_746', 'https://www.the50.com/discovery/Establishments/South-Africa/Cape-Town/Mount-Nelson.html'),
    ('hotel_748', 'https://www.the50.com/discovery/Establishments/Sri-Lanka/Galle/Amangalla.html'),
    ('hotel_749', 'https://www.the50.com/discovery/Establishments/French-West-Indies/St-Barths/Eden-Rock.html'),
    ('hotel_750', 'https://www.the50.com/discovery/Establishments/Sweden/Stockholm/Ett-Hem.html'),
    ('hotel_751', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Aman-Nai-Lert.html'),
    ('hotel_752', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Capella-Bangkok.html'),
    ('hotel_753', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Dusit-Thani-Bangkok.html'),
    ('hotel_754', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Four-Seasons-Bangkok-at-Chao-Phraya-River.html'),
    ('hotel_755', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Mandarin-Oriental-Bangkok.html'),
    ('hotel_756', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/Rosewood-Bangkok.html'),
    ('hotel_757', 'https://www.the50.com/discovery/Establishments/Thailand/Bangkok/The-Siam.html'),
    ('hotel_760', 'https://www.the50.com/discovery/Establishments/UAE/Dubai/Jumeirah-Marsa-Al-Arab.html'),
    ('hotel_761', 'https://www.the50.com/discovery/Establishments/United-Arab-Emirates/Dubai/The-Lana.html'),
    ('hotel_762', 'https://www.the50.com/discovery/Establishments/UK/London/Claridges.html'),
    ('hotel_763', 'https://www.the50.com/discovery/Establishments/UK/North-Leigh/Estelle-Manor.html'),
    ('hotel_764', 'https://www.the50.com/discovery/Establishments/UK/Auchterarder/Gleneagles.html'),
    ('hotel_765', 'https://www.the50.com/discovery/Establishments/UK/London/NoMad-London.html'),
    ('hotel_766', 'https://www.the50.com/discovery/Establishments/UK/London/Raffles-London-at-The-OWO.html'),
    ('hotel_767', 'https://www.the50.com/discovery/Establishments/UK/London/The-Connaught.html'),
    ('hotel_768', 'https://www.the50.com/discovery/Establishments/UK/London/The-Emory.html'),
    ('hotel_769', 'https://www.the50.com/discovery/Establishments/UK/Bruton/The-Newt.html'),
    ('hotel_770', 'https://www.the50.com/discovery/Establishments/UK/London/The-Savoy.html'),
    ('hotel_771', 'https://www.the50.com/discovery/Establishments/US/New-York/Aman-New-York.html'),
    ('hotel_773', 'https://www.the50.com/discovery/Establishments/US/New-York/Equinox-Hotel-New-York.html'),
    ('hotel_774', 'https://www.the50.com/discovery/Establishments/US/Miami/Four-Seasons-Hotel-at-the-Surf-Club.html'),
    ('hotel_775', 'https://www.the50.com/discovery/Establishments/US/Los-Angeles/Hotel-Bel-Air.html'),
    ('hotel_776', 'https://www.the50.com/discovery/Establishments/US/Santa-Barbara/San-Ysidro-Ranch.html'),
    ('hotel_777', 'https://www.the50.com/discovery/Establishments/US/Los-Angeles/The-Beverly-Hills-Hotel.html'),
    ('hotel_778', 'https://www.the50.com/discovery/Establishments/US/New-York/The-Carlyle.html'),
    ('hotel_779', 'https://www.the50.com/discovery/Establishments/US/New-York/The-Fifth-Avenue-Hotel.html'),
    ('hotel_780', 'https://www.the50.com/discovery/Establishments/US/New-York/The-Greenwich.html'),
    ('hotel_781', 'https://www.the50.com/discovery/Establishments/US/New-York/The-Mark.html'),
    ('hotel_782', 'https://www.the50.com/discovery/Establishments/Mexico/Riviera-Nayarit/OneandOnly-Mandarina.html'),
    ('hotel_783', 'https://www.the50.com/discovery/Establishments/Turkey/Istanbul/The-Peninsula-Istanbul.html'),
    ('hotel_785', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Park-Hyatt-Tokyo.html'),
    ('hotel_786', 'https://www.the50.com/discovery/Establishments/UK/London/Rosewood-London.html'),
    ('hotel_787', 'https://www.the50.com/discovery/Establishments/Italy/Montalcino/Rosewood-Castiglion-del-Bosco.html'),
    ('hotel_788', 'https://www.the50.com/discovery/Establishments/Panama/Panama-City/Sofitel-Legend-Casco-Viejo-Panama-City.html'),
    ('hotel_790', 'https://www.the50.com/discovery/Establishments/Italy/Brixen/Forestis-Dolomites.html'),
    ('hotel_791', 'https://www.the50.com/discovery/Establishments/France/Paris/Ritz-Paris.html'),
    ('hotel_792', 'https://www.the50.com/discovery/Establishments/Japan/Tokyo/Palace-Hotel-Tokyo.html'),
    ('hotel_793', 'https://www.the50.com/discovery/Establishments/France/Cannes/Carlton-Cannes.html'),
    ('hotel_794', 'https://www.the50.com/discovery/Establishments/Vietnam/Hanoi/Capella-Hanoi.html'),
    ('hotel_795', 'https://www.the50.com/discovery/Establishments/Japan/Osaka/Waldorf-Astoria-Osaka.html'),
    ('hotel_796', 'https://www.the50.com/discovery/Establishments/China/Shenzhen/Mandarin-Oriental-Shenzhen.html'),
    ('hotel_797', 'https://www.the50.com/discovery/Establishments/Italy/Positano/Villa-Treville.html'),
    ('hotel_798', 'https://www.the50.com/discovery/Establishments/China/Macau/Wynn-Palace.html'),
    ('hotel_799', 'https://www.the50.com/discovery/Establishments/India/Udaipur/The-Oberoi-Udaivilas.html'),
    ('hotel_800', 'https://www.the50.com/discovery/Establishments/China/Shanghai/The-Peninsula-Shanghai.html'),
    ('hotel_801', 'https://www.the50.com/discovery/Establishments/South-Africa/Kruger-National-Park/Singita-Kruger-National-Park.html'),
    ('hotel_802', 'https://www.the50.com/discovery/Establishments/India/Pali-Marwar/Suján-Jawai.html'),
    ('hotel_803', 'https://www.the50.com/discovery/Establishments/Maldives/Kulhudhuffushi/Soneva-Secret.html')
    ) v(code, url)
   where h.hotel_code = v.code and h.worlds_50_best_url is null;
  get diagnostics n = row_count;
  if n <> 123 then raise exception 'hotel urls: expected 123, got %', n; end if;
end $$;

commit;
