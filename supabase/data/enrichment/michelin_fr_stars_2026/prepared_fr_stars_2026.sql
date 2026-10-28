-- APPLIED to production 2026-10-28 (APPLY_FR_PE_2026.md).
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
--   1. 14 star corrections: the restaurant's current 2026 row and
--      restaurants.michelin_stars set to MICHELIN's 2026 value. Each old value
--      is asserted first.
--   2. michelin_url set or corrected for 410 restaurants: canonical
--      https://guide.michelin.com/en/<region>/<city>/restaurant/<slug> form.
--      Most are the same page in another locale (nl/nl, us/en, pt_BR...);
--      some pages moved; 15 rows had none; one held stray text
--      (" + Nominatim venue resolution") and one pointed at a hotel page.
--      Held back: rest_0972 Jean Imbert au Plaza Athénée, whose MICHELIN page
--      is now 'La Grande Table du Plaza Athénée' -- rename decision first (QA).
--   3. 173 restaurants added (rest_1405..rest_1577), each with a 2026 award row.
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
                and substring(restaurant_code from 6)::int between 1405 and 1577) then
    raise exception 'codes rest_1405..rest_1577 are no longer free -- re-check';
  end if;
  if (select count(*) from public.restaurants where country_code = 'FR' and michelin_stars is not null) <> 479 then
    raise exception 'expected 479 starred FR restaurants (export of 2026-10-28) -- production changed, re-check';
  end if;
end $$;

-- 1. star corrections (2026 rows that disagree with MICHELIN's 2026 list)
create temp table _fix (code text primary key, old_stars smallint, new_stars smallint) on commit drop;
insert into _fix values
    ('rest_0919', 1, 2),  -- Arbane
    ('rest_0980', 1, 2),  -- David Toutain
    ('rest_0983', 2, 1),  -- Gaya par Pierre Gagnaire
    ('rest_1038', 1, 2),  -- Le Jules Verne
    ('rest_1047', 1, 2),  -- Le Corot
    ('rest_1092', 2, 1),  -- Erre
    ('rest_1129', 2, 3),  -- Maison Lameloise
    ('rest_1132', 2, 1),  -- Château de Pray
    ('rest_1136', 2, 3),  -- Le Coquillage
    ('rest_1165', 2, 1),  -- L'Altitude
    ('rest_1206', 3, 1),  -- Le Suquet - Sébastien Bras
    ('rest_1252', 2, 1),  -- Skab
    ('rest_1261', 2, 3),  -- L'Oustau de Baumanière
    ('rest_1336', 1, 2);  -- La Voile - La Réserve Ramatuelle

do $$
declare n int;
begin
  select count(*) into n from _fix f join public.restaurants r on r.restaurant_code = f.code
   where r.country_code = 'FR' and r.michelin_stars = f.old_stars;
  if n <> 14 then raise exception 'star corrections: expected 14 rows at their old value, found %', n; end if;
  select count(*) into n from _fix f join public.restaurants r on r.restaurant_code = f.code
    join public.award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id
   where ah.award_type = 'michelin_stars' and ah.guide_year = 2026 and ah.is_current and ah.award_value = f.old_stars;
  if n <> 14 then raise exception 'star corrections: expected 14 current 2026 rows at their old value, found %', n; end if;
end $$;

update public.award_history ah set award_value = f.new_stars, announced_on = date '2026-03-16'
  from public.restaurants r, _fix f
 where r.restaurant_code = f.code and ah.entity_type = 'restaurant' and ah.entity_id = r.id
   and ah.award_type = 'michelin_stars' and ah.guide_year = 2026 and ah.is_current;

update public.restaurants r set michelin_stars = f.new_stars, updated_at = now()
  from _fix f where r.restaurant_code = f.code;

-- 2. michelin_url
create temp table _urls (code text primary key, michelin_url text unique) on commit drop;
insert into _urls values
    ('rest_0008', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/anne'),
    ('rest_0060', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-gabriel476630'),
    ('rest_0300', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/table-bruno-verjus'),
    ('rest_0304', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/plenitude-cheval-blanc-paris'),
    ('rest_0322', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/septime'),
    ('rest_0327', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/arpege'),
    ('rest_0895', 'https://guide.michelin.com/en/grand-est/reims/restaurant/assiette-champenoise'),
    ('rest_0896', 'https://guide.michelin.com/en/grand-est/champillon/restaurant/le-royal'),
    ('rest_0897', 'https://guide.michelin.com/en/grand-est/vinay/restaurant/alcove'),
    ('rest_0898', 'https://guide.michelin.com/en/grand-est/wingen-sur-moder/restaurant/villa-rene-lalique'),
    ('rest_0899', 'https://guide.michelin.com/en/grand-est/metz/restaurant/yozora'),
    ('rest_0901', 'https://guide.michelin.com/en/hauts-de-france/villeneuve-d-ascq_1550830/restaurant/harmonie-1245894'),
    ('rest_0902', 'https://guide.michelin.com/en/ile-de-france/montreuil-ile-de-france/restaurant/villa9trois'),
    ('rest_0903', 'https://guide.michelin.com/en/hauts-de-france/saint-omer/restaurant/bacove'),
    ('rest_0904', 'https://guide.michelin.com/en/normandie/rouen/restaurant/l-odas'),
    ('rest_0905', 'https://guide.michelin.com/en/hauts-de-france/croix/restaurant/arborescence'),
    ('rest_0906', 'https://guide.michelin.com/en/hauts-de-france/lille/restaurant/le-restaurant-du-cerisier'),
    ('rest_0907', 'https://guide.michelin.com/en/hauts-de-france/boeschepe/restaurant/auberge-du-vert-mont'),
    ('rest_0908', 'https://guide.michelin.com/en/hauts-de-france/lille/restaurant/ginko'),
    ('rest_0909', 'https://guide.michelin.com/en/hauts-de-france/lille/restaurant/purete'),
    ('rest_0910', 'https://guide.michelin.com/en/hauts-de-france/cassel/restaurant/haut-bonheur-de-la-table'),
    ('rest_0911', 'https://guide.michelin.com/en/hauts-de-france/bry_1545291/restaurant/le-camelia-1242759'),
    ('rest_0912', 'https://guide.michelin.com/en/hauts-de-france/busnes/restaurant/la-table-de-christophe-dufoss%C3%A9'),
    ('rest_0913', 'https://guide.michelin.com/en/hauts-de-france/la-madelaine-sous-montreuil/restaurant/la-grenouillere'),
    ('rest_0914', 'https://guide.michelin.com/en/hauts-de-france/trosly-loire_1550618/restaurant/auberge-de-la-grive'),
    ('rest_0915', 'https://guide.michelin.com/en/grand-est/malling/restaurant/alexis-baudin'),
    ('rest_0917', 'https://guide.michelin.com/en/hauts-de-france/courcelles-sur-vesle/restaurant/la-table-de-courcelles-chateau-de-courcelles'),
    ('rest_0919', 'https://guide.michelin.com/en/grand-est/reims/restaurant/arbane'),
    ('rest_0920', 'https://guide.michelin.com/en/grand-est/reims/restaurant/racine'),
    ('rest_0921', 'https://guide.michelin.com/en/grand-est/reims/restaurant/le-parc-les-crayeres'),
    ('rest_0922', 'https://guide.michelin.com/en/grand-est/hagondange/restaurant/quai-des-saveurs'),
    ('rest_0924', 'https://guide.michelin.com/en/hauts-de-france/touy/restaurant/l-oree-de-la-foret'),
    ('rest_0925', 'https://guide.michelin.com/en/grand-est/chlons-en-champagne/restaurant/jerome-feck'),
    ('rest_0928', 'https://guide.michelin.com/en/hauts-de-france/belle-glise/restaurant/la-grange-de-belle-eglise'),
    ('rest_0929', 'https://guide.michelin.com/en/normandie/lyons-la-fort/restaurant/la-licorne-royale'),
    ('rest_0931', 'https://guide.michelin.com/en/grand-est/nancy/restaurant/la-maison-dans-le-parc'),
    ('rest_0932', 'https://guide.michelin.com/en/ile-de-france/villeneuve-le-comte_1553696/restaurant/la-vieille-auberge-1206650'),
    ('rest_0933', 'https://guide.michelin.com/en/normandie/valmont/restaurant/maison-caillet'),
    ('rest_0934', 'https://guide.michelin.com/en/grand-est/baerenthal/restaurant/l-arnsbourg'),
    ('rest_0935', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/maison-rostang'),
    ('rest_0936', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/heritages'),
    ('rest_0937', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/irwin'),
    ('rest_0938', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/neso'),
    ('rest_0939', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-faham'),
    ('rest_0941', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/contraste1186546'),
    ('rest_0943', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/fleur-de-pave'),
    ('rest_0944', 'https://guide.michelin.com/en/ile-de-france/vincennes/restaurant/l-ours'),
    ('rest_0945', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/jacques-faussat'),
    ('rest_0947', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/frederic-simonin'),
    ('rest_0949', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/sushi-b514232'),
    ('rest_0951', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/geosmine'),
    ('rest_0952', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/onor'),
    ('rest_0954', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/accents-table-bourse'),
    ('rest_0956', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/nhome'),
    ('rest_0957', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/sushi-yoshinaga'),
    ('rest_0959', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/fief'),
    ('rest_0960', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/shabour'),
    ('rest_0961', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/akrame507272'),
    ('rest_0962', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/frenchie262795'),
    ('rest_0963', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/datil'),
    ('rest_0964', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/vaisseau'),
    ('rest_0965', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/sushi-shunei'),
    ('rest_0966', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/episodes'),
    ('rest_0967', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/epicure'),
    ('rest_0968', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-meurice-alain-ducasse'),
    ('rest_0970', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-baudelaire'),
    ('rest_0971', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/bellefeuille-saint-james-paris'),
    ('rest_0973', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/kei'),
    ('rest_0974', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/la-scene'),
    ('rest_0975', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-grand-restaurant-jean-francois-piege'),
    ('rest_0976', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-taillevent'),
    ('rest_0977', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/alliance'),
    ('rest_0978', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/marsan-par-helene-darroze'),
    ('rest_0980', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/david-toutain'),
    ('rest_0981', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/pantagruel'),
    ('rest_0982', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/origines-restaurant'),
    ('rest_0984', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/imperial-treasure1186891'),
    ('rest_0985', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/substance'),
    ('rest_0986', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/baieta'),
    ('rest_0987', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/zostera'),
    ('rest_0988', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/astrance'),
    ('rest_0989', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/restaurant-h'),
    ('rest_0990', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/l-arome174292'),
    ('rest_0991', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/yoshinori'),
    ('rest_0992', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/armani-ristorante'),
    ('rest_0993', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-violon-d-ingres5989'),
    ('rest_0996', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/pertinence'),
    ('rest_0998', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/114-faubourg'),
    ('rest_0999', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/lasserre'),
    ('rest_1000', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/jin'),
    ('rest_1002', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/granite'),
    ('rest_1003', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-cinq6102'),
    ('rest_1004', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/hakuba'),
    ('rest_1005', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/espadon'),
    ('rest_1006', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-george'),
    ('rest_1007', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/il-carpaccio300866'),
    ('rest_1008', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-tout-paris'),
    ('rest_1009', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/pierre-gagnaire6112'),
    ('rest_1010', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/l-abysse-paris'),
    ('rest_1012', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/l-ambroisie'),
    ('rest_1013', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/virtus'),
    ('rest_1014', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/hanada'),
    ('rest_1015', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/monsieur-dior-by-yannick-alleno'),
    ('rest_1017', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/aldehyde'),
    ('rest_1018', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/pavyllon-paris'),
    ('rest_1019', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/oxte'),
    ('rest_1020', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/tomy-co'),
    ('rest_1022', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/lucas-carton'),
    ('rest_1023', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/divellec'),
    ('rest_1025', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/relais-louis-xiii'),
    ('rest_1026', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/tour-d-argent'),
    ('rest_1027', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/don-juan-ii'),
    ('rest_1028', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/mallory-gabsi'),
    ('rest_1029', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/sola'),
    ('rest_1030', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/geoelia'),
    ('rest_1031', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/pilgrim1000208'),
    ('rest_1032', 'https://guide.michelin.com/en/ile-de-france/rueil-malmaison/restaurant/ochre'),
    ('rest_1033', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/comice'),
    ('rest_1034', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/neige-d-ete'),
    ('rest_1035', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/nakatani'),
    ('rest_1036', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/l-archeste'),
    ('rest_1037', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/quinsou'),
    ('rest_1038', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-jules-verne'),
    ('rest_1039', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/solstice'),
    ('rest_1040', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/mosuke'),
    ('rest_1041', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/aida'),
    ('rest_1042', 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/chakaiseiki-akiyoshi'),
    ('rest_1043', 'https://guide.michelin.com/en/ile-de-france/issy-les-moulineaux/restaurant/maison-avoise'),
    ('rest_1044', 'https://guide.michelin.com/en/ile-de-france/meudon/restaurant/l-escarbille'),
    ('rest_1045', 'https://guide.michelin.com/en/normandie/giverny/restaurant/le-jardin-des-plumes'),
    ('rest_1046', 'https://guide.michelin.com/en/ile-de-france/rolleboise/restaurant/le-panoramique-domaine-de-la-corniche'),
    ('rest_1047', 'https://guide.michelin.com/en/ile-de-france/ville-d-avray/restaurant/le-corot'),
    ('rest_1048', 'https://guide.michelin.com/en/grand-est/laubach/restaurant/la-merise'),
    ('rest_1049', 'https://guide.michelin.com/en/grand-est/lunville/restaurant/chateau-d-adomenil'),
    ('rest_1050', 'https://guide.michelin.com/en/ile-de-france/versailles/restaurant/ducasse-au-chateau-de-versailles-le-grand-controle'),
    ('rest_1051', 'https://guide.michelin.com/en/ile-de-france/versailles/restaurant/gordon-ramsay-au-trianon'),
    ('rest_1052', 'https://guide.michelin.com/en/ile-de-france/versailles/restaurant/la-table-du-11'),
    ('rest_1053', 'https://guide.michelin.com/en/grand-est/drusenheim/restaurant/au-gourmet'),
    ('rest_1054', 'https://guide.michelin.com/en/ile-de-france/gambais/restaurant/ruche'),
    ('rest_1056', 'https://guide.michelin.com/en/grand-est/la-wantzenau/restaurant/le-jardin-secret'),
    ('rest_1060', 'https://guide.michelin.com/en/grand-est/strasbourg/restaurant/au-crocodile'),
    ('rest_1061', 'https://guide.michelin.com/en/grand-est/strasbourg/restaurant/1741'),
    ('rest_1062', 'https://guide.michelin.com/en/grand-est/strasbourg/restaurant/umami202668'),
    ('rest_1063', 'https://guide.michelin.com/en/grand-est/strasbourg/restaurant/les-funambules'),
    ('rest_1064', 'https://guide.michelin.com/en/ile-de-france/fontainebleau/restaurant/l-axel'),
    ('rest_1065', 'https://guide.michelin.com/en/grand-est/strasbourg/restaurant/de-ja'),
    ('rest_1066', 'https://guide.michelin.com/en/grand-est/colroy-la-roche/restaurant/la-cheneaudiere-le-feuillage'),
    ('rest_1067', 'https://guide.michelin.com/en/grand-est/obernai/restaurant/thierry-schwartz-table-naturelle'),
    ('rest_1068', 'https://guide.michelin.com/en/grand-est/obernai/restaurant/la-fourchette-des-ducs'),
    ('rest_1069', 'https://guide.michelin.com/en/normandie/deauville/restaurant/maximin-hellio'),
    ('rest_1070', 'https://guide.michelin.com/en/normandie/deauville/restaurant/l-essentiel255041'),
    ('rest_1071', 'https://guide.michelin.com/en/grand-est/steige/restaurant/auberge-chez-guth'),
    ('rest_1072', 'https://guide.michelin.com/en/bourgogne-franche-comte/sens/restaurant/la-madeleine'),
    ('rest_1074', 'https://guide.michelin.com/en/grand-est/pinal/restaurant/les-ducs-de-lorraine'),
    ('rest_1075', 'https://guide.michelin.com/en/grand-est/la-vancelle/restaurant/auberge-frankenbourg'),
    ('rest_1076', 'https://guide.michelin.com/en/normandie/cabourg/restaurant/symbiose-1211835'),
    ('rest_1077', 'https://guide.michelin.com/en/grand-est/rhinau/restaurant/au-vieux-couvent'),
    ('rest_1078', 'https://guide.michelin.com/en/bourgogne-franche-comte/courban/restaurant/chateau-de-courban'),
    ('rest_1079', 'https://guide.michelin.com/en/centre-val-de-loire/chartres/restaurant/le-georges'),
    ('rest_1080', 'https://guide.michelin.com/en/grand-est/riquewihr/restaurant/la-table-du-gourmet'),
    ('rest_1081', 'https://guide.michelin.com/en/bourgogne-franche-comte/joigny/restaurant/la-cote-saint-jacques'),
    ('rest_1082', 'https://guide.michelin.com/en/grand-est/kaysersberg/restaurant/la-table-d-olivier-nasti'),
    ('rest_1083', 'https://guide.michelin.com/en/grand-est/illhaeusern/restaurant/auberge-de-l-ill'),
    ('rest_1084', 'https://guide.michelin.com/en/grand-est/kaysersberg/restaurant/l-alchemille'),
    ('rest_1085', 'https://guide.michelin.com/en/grand-est/ammerschwihr/restaurant/julien-binz'),
    ('rest_1086', 'https://guide.michelin.com/en/grand-est/langres/restaurant/bulle-d-osier'),
    ('rest_1087', 'https://guide.michelin.com/en/grand-est/wihr-au-val/restaurant/la-nouvelle-auberge'),
    ('rest_1088', 'https://guide.michelin.com/en/grand-est/colmar/restaurant/l-atelier-du-peintre'),
    ('rest_1089', 'https://guide.michelin.com/en/grand-est/colmar/restaurant/jy-s'),
    ('rest_1090', 'https://guide.michelin.com/en/grand-est/colmar/restaurant/restaurant-girardin'),
    ('rest_1092', 'https://guide.michelin.com/en/bourgogne-franche-comte/chassy_1527287/restaurant/erre'),
    ('rest_1093', 'https://guide.michelin.com/en/centre-val-de-loire/boismorand/restaurant/auberge-des-templiers'),
    ('rest_1094', 'https://guide.michelin.com/en/grand-est/ensisheim/restaurant/l-orchidee'),
    ('rest_1096', 'https://guide.michelin.com/en/grand-est/mulhouse/restaurant/il-cortile40020'),
    ('rest_1098', 'https://guide.michelin.com/en/centre-val-de-loire/gien/restaurant/cote-jardin'),
    ('rest_1099', 'https://guide.michelin.com/en/normandie/cherbourg-en-cotentin/restaurant/le-pily'),
    ('rest_1100', 'https://guide.michelin.com/en/bourgogne-franche-comte/danjoutin/restaurant/le-pot-d-etain'),
    ('rest_1101', 'https://guide.michelin.com/en/bourgogne-franche-comte/vault-de-lugny/restaurant/le-valucien-chateau-de-vault-de-lugny'),
    ('rest_1102', 'https://guide.michelin.com/en/grand-est/sierentz/restaurant/auberge-st-laurent'),
    ('rest_1103', 'https://guide.michelin.com/en/bourgogne-franche-comte/prenois/restaurant/auberge-de-la-charme'),
    ('rest_1104', 'https://guide.michelin.com/en/bourgogne-franche-comte/dijon/restaurant/loiseau-des-ducs'),
    ('rest_1105', 'https://guide.michelin.com/en/bourgogne-franche-comte/dijon/restaurant/william-frachot'),
    ('rest_1106', 'https://guide.michelin.com/en/bourgogne-franche-comte/dijon/restaurant/cibo'),
    ('rest_1107', 'https://guide.michelin.com/en/bourgogne-franche-comte/dijon/restaurant/l-asperule'),
    ('rest_1110', 'https://guide.michelin.com/en/normandie/la-ferrire-aux-tangs/restaurant/auberge-de-la-mine'),
    ('rest_1111', 'https://guide.michelin.com/en/bourgogne-franche-comte/saulieu/restaurant/la-cote-d-or'),
    ('rest_1112', 'https://guide.michelin.com/en/centre-val-de-loire/boulleret/restaurant/maison-medard'),
    ('rest_1114', 'https://guide.michelin.com/en/centre-val-de-loire/montlivault/restaurant/ezia'),
    ('rest_1115', 'https://guide.michelin.com/en/centre-val-de-loire/sancerre/restaurant/la-pomme-d-or'),
    ('rest_1116', 'https://guide.michelin.com/en/normandie/blainville-sur-mer/restaurant/le-mascaret'),
    ('rest_1117', 'https://guide.michelin.com/en/bourgogne-franche-comte/sampans/restaurant/chateau-du-mont-joly'),
    ('rest_1118', 'https://guide.michelin.com/en/pays-de-la-loire/le-mans/restaurant/l-auberge-de-bagatelle'),
    ('rest_1119', 'https://guide.michelin.com/en/centre-val-de-loire/blois/restaurant/christophe-hay-fleur-de-loire'),
    ('rest_1120', 'https://guide.michelin.com/en/bourgogne-franche-comte/bonntage/restaurant/l-etang-du-moulin'),
    ('rest_1121', 'https://guide.michelin.com/en/bourgogne-franche-comte/dole/restaurant/la-chaumiere11044'),
    ('rest_1122', 'https://guide.michelin.com/en/bourgogne-franche-comte/beaune/restaurant/le-clos-du-cedre'),
    ('rest_1124', 'https://guide.michelin.com/en/bourgogne-franche-comte/pommard/restaurant/aupres-du-clocher'),
    ('rest_1125', 'https://guide.michelin.com/en/pays-de-la-loire/mayenne/restaurant/l-eveil-des-sens'),
    ('rest_1126', 'https://guide.michelin.com/en/bourgogne-franche-comte/beaune/restaurant/le-carmin'),
    ('rest_1127', 'https://guide.michelin.com/en/bourgogne-franche-comte/levernois/restaurant/table-de-levernois'),
    ('rest_1128', 'https://guide.michelin.com/en/centre-val-de-loire/romorantin-lanthenay/restaurant/grand-hotel-du-lion-d-or'),
    ('rest_1129', 'https://guide.michelin.com/en/bourgogne-franche-comte/chagny/restaurant/maison-lameloise'),
    ('rest_1130', 'https://guide.michelin.com/en/normandie/servon/restaurant/auberge-sauvage'),
    ('rest_1131', 'https://guide.michelin.com/en/bourgogne-franche-comte/pupillin/restaurant/la-table-du-grapiot'),
    ('rest_1132', 'https://guide.michelin.com/en/centre-val-de-loire/amboise/restaurant/chateau-de-pray'),
    ('rest_1133', 'https://guide.michelin.com/en/bourgogne-franche-comte/saint-rmy/restaurant/cedric-burtin'),
    ('rest_1134', 'https://guide.michelin.com/en/bourgogne-franche-comte/malbuisson/restaurant/le-bon-accueil4521'),
    ('rest_1135', 'https://guide.michelin.com/en/bretagne/cancale/restaurant/la-table-breizh-cafe'),
    ('rest_1136', 'https://guide.michelin.com/en/bretagne/saint-mloir-des-ondes/restaurant/le-coquillage'),
    ('rest_1137', 'https://guide.michelin.com/en/centre-val-de-loire/fondettes/restaurant/l-opidom'),
    ('rest_1139', 'https://guide.michelin.com/en/bretagne/saint-malo/restaurant/le-st-placide'),
    ('rest_1143', 'https://guide.michelin.com/en/centre-val-de-loire/sach/restaurant/auberge-du-xiie-siecle'),
    ('rest_1145', 'https://guide.michelin.com/en/bretagne/vannes/restaurant/la-table-domaine-du-liziec'),
    ('rest_1146', 'https://guide.michelin.com/en/auvergne-rhone-alpes/saint-galmier/restaurant/la-source'),
    ('rest_1147', 'https://guide.michelin.com/en/bretagne/vannes/restaurant/la-tete-en-l-air'),
    ('rest_1148', 'https://guide.michelin.com/en/auvergne-rhone-alpes/saint-didier-de-la-tour/restaurant/ambroisie'),
    ('rest_1149', 'https://guide.michelin.com/en/pays-de-la-loire/montreverd/restaurant/la-chabotterie'),
    ('rest_1150', 'https://guide.michelin.com/en/auvergne-rhone-alpes/vienne/restaurant/la-pyramide-maison-henriroux'),
    ('rest_1151', 'https://guide.michelin.com/en/nouvelle-aquitaine/nieul_1470595/restaurant/chapelle-saint-martin'),
    ('rest_1153', 'https://guide.michelin.com/en/bretagne/kervignac/restaurant/l-inattendu-domaine-de-locguenole'),
    ('rest_1154', 'https://guide.michelin.com/en/bretagne/carnac/restaurant/cote-cuisine'),
    ('rest_1155', 'https://guide.michelin.com/en/bretagne/lorient/restaurant/louise1000376'),
    ('rest_1156', 'https://guide.michelin.com/en/pays-de-la-loire/la-roche-sur-yon/restaurant/les-reflets'),
    ('rest_1158', 'https://guide.michelin.com/en/auvergne-rhone-alpes/courchevel/restaurant/sylvestre-wahid-les-grandes-alpes'),
    ('rest_1159', 'https://guide.michelin.com/en/pays-de-la-loire/mareuil-sur-lay/restaurant/maison-desamy'),
    ('rest_1160', 'https://guide.michelin.com/en/auvergne-rhone-alpes/tignes/restaurant/ursus'),
    ('rest_1161', 'https://guide.michelin.com/en/auvergne-rhone-alpes/val-d-isre/restaurant/la-table-de-l-ours'),
    ('rest_1162', 'https://guide.michelin.com/en/auvergne-rhone-alpes/courchevel/restaurant/alpage'),
    ('rest_1163', 'https://guide.michelin.com/en/auvergne-rhone-alpes/courchevel/restaurant/le-1947'),
    ('rest_1164', 'https://guide.michelin.com/en/pays-de-la-loire/l-herbaudire/restaurant/la-marine3780'),
    ('rest_1165', 'https://guide.michelin.com/en/auvergne-rhone-alpes/courchevel/restaurant/l-altitude'),
    ('rest_1167', 'https://guide.michelin.com/en/auvergne-rhone-alpes/saint-martin-de-belleville/restaurant/rene-et-maxime-meilleur'),
    ('rest_1168', 'https://guide.michelin.com/en/bretagne/pont-aven/restaurant/moulin-de-rosmadec'),
    ('rest_1169', 'https://guide.michelin.com/en/nouvelle-aquitaine/massignac/restaurant/dyades-au-domaine-des-etangs'),
    ('rest_1170', 'https://guide.michelin.com/en/bretagne/plomodiern/restaurant/l-auberge-des-glazicks'),
    ('rest_1174', 'https://guide.michelin.com/en/auvergne-rhone-alpes/grenoble/restaurant/maison-fantin-latour-stephane-froidevaux'),
    ('rest_1175', 'https://guide.michelin.com/en/bretagne/quimper/restaurant/allium'),
    ('rest_1176', 'https://guide.michelin.com/en/pays-de-la-loire/brem-sur-mer/restaurant/les-genets'),
    ('rest_1177', 'https://guide.michelin.com/en/auvergne-rhone-alpes/saint-bonnet-le-froid/restaurant/restaurant-marcon'),
    ('rest_1179', 'https://guide.michelin.com/en/auvergne-rhone-alpes/autrans/restaurant/palegrie-chez-l-henri'),
    ('rest_1180', 'https://guide.michelin.com/en/bretagne/combrit/restaurant/les-trois-rochers'),
    ('rest_1181', 'https://guide.michelin.com/en/pays-de-la-loire/les-sables-d-olonne/restaurant/l-abissiou'),
    ('rest_1182', 'https://guide.michelin.com/en/auvergne-rhone-alpes/granges-les-beaumont/restaurant/les-cedres'),
    ('rest_1183', 'https://guide.michelin.com/en/bretagne/plougonvelin/restaurant/hostellerie-de-la-pointe-st-mathieu'),
    ('rest_1184', 'https://guide.michelin.com/en/nouvelle-aquitaine/la-rochelle/restaurant/christopher-coutanceau'),
    ('rest_1185', 'https://guide.michelin.com/en/auvergne-rhone-alpes/correnon-en-vercors/restaurant/asterales'),
    ('rest_1186', 'https://guide.michelin.com/en/auvergne-rhone-alpes/le-puy-en-velay/restaurant/le-chamarlenc'),
    ('rest_1187', 'https://guide.michelin.com/en/nouvelle-aquitaine/la-flotte/restaurant/l-ecailler'),
    ('rest_1189', 'https://guide.michelin.com/en/auvergne-rhone-alpes/alixan_1509150/restaurant/mandibule'),
    ('rest_1191', 'https://guide.michelin.com/en/auvergne-rhone-alpes/valence/restaurant/epitheque'),
    ('rest_1192', 'https://guide.michelin.com/en/auvergne-rhone-alpes/valence/restaurant/pic'),
    ('rest_1193', 'https://guide.michelin.com/en/nouvelle-aquitaine/bourg-charente/restaurant/la-ribaudiere'),
    ('rest_1194', 'https://guide.michelin.com/en/auvergne-rhone-alpes/tournemire/restaurant/le-puy-tilleul'),
    ('rest_1195', 'https://guide.michelin.com/en/nouvelle-aquitaine/cognac/restaurant/les-foudres'),
    ('rest_1196', 'https://guide.michelin.com/en/auvergne-rhone-alpes/alleyras/restaurant/le-haut-allier'),
    ('rest_1197', 'https://guide.michelin.com/en/nouvelle-aquitaine/cognac/restaurant/notes'),
    ('rest_1198', 'https://guide.michelin.com/en/auvergne-rhone-alpes/charmes-sur-rhne/restaurant/le-carre-d-alethius'),
    ('rest_1199', 'https://guide.michelin.com/en/nouvelle-aquitaine/brive-la-gaillarde/restaurant/la-table-d-olivier'),
    ('rest_1200', 'https://guide.michelin.com/en/auvergne-rhone-alpes/chaudes-aigues/restaurant/serge-vieira'),
    ('rest_1201', 'https://guide.michelin.com/en/auvergne-rhone-alpes/grane/restaurant/le-kleber-la-maison-bonnet'),
    ('rest_1202', 'https://guide.michelin.com/en/nouvelle-aquitaine/altillac/restaurant/cueillette'),
    ('rest_1203', 'https://guide.michelin.com/en/nouvelle-aquitaine/prigueux/restaurant/l-essentiel117707'),
    ('rest_1204', 'https://guide.michelin.com/en/nouvelle-aquitaine/saint-leon-sur-vezere/restaurant/le-petit-leon'),
    ('rest_1205', 'https://guide.michelin.com/en/auvergne-rhone-alpes/charols/restaurant/lavandin-chateau-les-oliviers-de-salettes'),
    ('rest_1206', 'https://guide.michelin.com/en/occitanie/laguiole/restaurant/le-suquet-sebastien-bras'),
    ('rest_1207', 'https://guide.michelin.com/en/auvergne-rhone-alpes/saint-germain/restaurant/auberge-de-montfleury'),
    ('rest_1208', 'https://guide.michelin.com/en/nouvelle-aquitaine/les-eyzies-de-tayac/restaurant/le-1862'),
    ('rest_1209', 'https://guide.michelin.com/en/auvergne-rhone-alpes/malataverne/restaurant/le-colombier'),
    ('rest_1210', 'https://guide.michelin.com/en/auvergne-rhone-alpes/grignan/restaurant/le-clair-de-la-plume'),
    ('rest_1211', 'https://guide.michelin.com/en/occitanie/conques/restaurant/emilie-thomas-moulin-de-cambelong'),
    ('rest_1212', 'https://guide.michelin.com/en/nouvelle-aquitaine/trmolat/restaurant/le-vieux-logis'),
    ('rest_1213', 'https://guide.michelin.com/en/nouvelle-aquitaine/monbazillac/restaurant/la-tour-des-vents'),
    ('rest_1214', 'https://guide.michelin.com/en/nouvelle-aquitaine/monestier/restaurant/les-fresques'),
    ('rest_1215', 'https://guide.michelin.com/en/occitanie/rodez/restaurant/restaurant-herve-busset'),
    ('rest_1216', 'https://guide.michelin.com/en/occitanie/belcastel/restaurant/vieux-pont'),
    ('rest_1218', 'https://guide.michelin.com/en/occitanie/saint-mdard/restaurant/le-gindreau'),
    ('rest_1219', 'https://guide.michelin.com/en/nouvelle-aquitaine/saint-milion/restaurant/logis-de-la-cadene'),
    ('rest_1220', 'https://guide.michelin.com/en/occitanie/sabran/restaurant/le-cedre-de-montcaud'),
    ('rest_1221', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/gigondas/restaurant/l-oustalet'),
    ('rest_1222', 'https://guide.michelin.com/en/nouvelle-aquitaine/saint-jean-de-blaignac/restaurant/auberge-st-jean'),
    ('rest_1223', 'https://guide.michelin.com/en/nouvelle-aquitaine/lormont/restaurant/le-prince-noir-vivien-durand'),
    ('rest_1224', 'https://guide.michelin.com/en/occitanie/saint-hilaire-de-brethmas_3915683/restaurant/le-saint-hilaire-1208787'),
    ('rest_1225', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/chteau-arnoux/restaurant/la-bonne-etape'),
    ('rest_1226', 'https://guide.michelin.com/en/occitanie/floressas_1492997/restaurant/holodeck'),
    ('rest_1228', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/le-cent-33'),
    ('rest_1229', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/l-oiseau-bleu'),
    ('rest_1230', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/le-pressoir-d-argent-gordon-ramsay'),
    ('rest_1231', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/solena'),
    ('rest_1232', 'https://guide.michelin.com/en/nouvelle-aquitaine/bouliac/restaurant/le-saint-james'),
    ('rest_1233', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/amicis'),
    ('rest_1234', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/le-pavillon-des-boulevards'),
    ('rest_1235', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/la-table-d-hotes-le-quatrieme-mur'),
    ('rest_1236', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/tentazioni'),
    ('rest_1237', 'https://guide.michelin.com/en/nouvelle-aquitaine/bordeaux/restaurant/ressources'),
    ('rest_1238', 'https://guide.michelin.com/en/occitanie/uzs/restaurant/la-table-d-uzes'),
    ('rest_1239', 'https://guide.michelin.com/en/occitanie/pujaut/restaurant/maison-chenet-entre-vigne-et-garrigue'),
    ('rest_1240', 'https://guide.michelin.com/en/occitanie/saint-hilaire-d-ozilhan_1503960/restaurant/la-belle-vie'),
    ('rest_1241', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/roubion/restaurant/auberge-quintessence'),
    ('rest_1242', 'https://guide.michelin.com/en/occitanie/villeneuve-ls-avignon/restaurant/le-prieure13557'),
    ('rest_1243', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/joucas/restaurant/la-table-de-xavier-mathieu'),
    ('rest_1244', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/l-isle-sur-la-sorgue/restaurant/le-vivier3857'),
    ('rest_1245', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/mane/restaurant/le-feuillee-le-couvent-des-minimes'),
    ('rest_1246', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/valdeblore/restaurant/auberge-de-la-roche-1203180'),
    ('rest_1247', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/barbentane_1504843/restaurant/ineffable'),
    ('rest_1248', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/bonnieux/restaurant/la-table-des-amis'),
    ('rest_1249', 'https://guide.michelin.com/en/occitanie/nimes/restaurant/duende'),
    ('rest_1250', 'https://guide.michelin.com/en/nouvelle-aquitaine/bommes/restaurant/lalique'),
    ('rest_1251', 'https://guide.michelin.com/en/occitanie/nimes/restaurant/rouge-1200806'),
    ('rest_1253', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/bonnieux/restaurant/ju-maison-de-cuisine'),
    ('rest_1254', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/manosque/restaurant/restaurant-pierre-grein'),
    ('rest_1256', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/moustiers-sainte-marie/restaurant/la-bastide-de-moustiers'),
    ('rest_1257', 'https://guide.michelin.com/en/nouvelle-aquitaine/ars/restaurant/nacre'),
    ('rest_1258', 'https://guide.michelin.com/en/occitanie/calvisson_1500992/restaurant/monique-1213895'),
    ('rest_1259', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/cucuron/restaurant/la-petite-maison-de-cucuron'),
    ('rest_1260', 'https://guide.michelin.com/en/occitanie/garons/restaurant/michel-kayser-restaurant-alexandre'),
    ('rest_1261', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/les-baux-de-provence/restaurant/l-oustau-de-baumaniere'),
    ('rest_1262', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/cadenet/restaurant/le-gout-du-bonheur-la-feniere'),
    ('rest_1263', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/ansouis/restaurant/garrigue'),
    ('rest_1264', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/les-baux-de-provence/restaurant/l-aupiho'),
    ('rest_1266', 'https://guide.michelin.com/en/nouvelle-aquitaine/moirax/restaurant/auberge-le-prieure'),
    ('rest_1267', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/le-puy-sainte-rparade/restaurant/la-table-de-l-orangerie-chateau-de-fonscolombe'),
    ('rest_1268', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/salon-de-provence/restaurant/villa-salone'),
    ('rest_1269', 'https://guide.michelin.com/en/occitanie/montpellier/restaurant/la-reserve-rimbaud'),
    ('rest_1270', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/menton/restaurant/mirazur'),
    ('rest_1271', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/saint-cannat/restaurant/le-mas-bottero'),
    ('rest_1272', 'https://guide.michelin.com/en/occitanie/montpellier/restaurant/reflet-d-obione'),
    ('rest_1273', 'https://guide.michelin.com/en/occitanie/montpellier/restaurant/pastis-restaurant'),
    ('rest_1274', 'https://guide.michelin.com/en/occitanie/montpellier/restaurant/jardin-des-sens'),
    ('rest_1275', 'https://guide.michelin.com/en/occitanie/montpellier/restaurant/ebullition'),
    ('rest_1278', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/saint-paul-de-vence/restaurant/la-table-de-pierre'),
    ('rest_1279', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/ze/restaurant/chateau-eza'),
    ('rest_1280', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/nice/restaurant/flaveur'),
    ('rest_1281', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/la-colle-sur-loup/restaurant/alain-llorca'),
    ('rest_1283', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/ze/restaurant/la-chevre-d-or'),
    ('rest_1284', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/aix-en-provence/restaurant/le-art-chateau-de-la-gaude'),
    ('rest_1285', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/nice/restaurant/racines-bruno-cirino'),
    ('rest_1286', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/nice/restaurant/le-chantecler'),
    ('rest_1287', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/beaulieu-sur-mer/restaurant/restaurant-des-rois'),
    ('rest_1288', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/nice/restaurant/epicentre-1218827'),
    ('rest_1289', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/nice/restaurant/les-agitateurs'),
    ('rest_1290', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/nice/restaurant/l-aromate233368'),
    ('rest_1291', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/nice/restaurant/onice'),
    ('rest_1292', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/aix-en-provence/restaurant/la-table-de-pierre-reboul'),
    ('rest_1294', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/aix-en-provence/restaurant/etude-1207141'),
    ('rest_1295', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/tourrettes/restaurant/faventia'),
    ('rest_1296', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/biot/restaurant/les-terraillers'),
    ('rest_1297', 'https://guide.michelin.com/en/occitanie/colombires-sur-orb/restaurant/granit'),
    ('rest_1299', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/mandelieu-la-napoule/restaurant/bessem'),
    ('rest_1301', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/cannes/restaurant/la-palme-d-or'),
    ('rest_1302', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/antibes/restaurant/les-pecheurs'),
    ('rest_1303', 'https://guide.michelin.com/en/occitanie/pzenas/restaurant/restaurant-de-lauzun'),
    ('rest_1304', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/antibes/restaurant/louroc'),
    ('rest_1305', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/lorgues/restaurant/bruno'),
    ('rest_1306', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/thoule-sur-mer/restaurant/mareluna'),
    ('rest_1307', 'https://guide.michelin.com/en/occitanie/payrin-augmontel/restaurant/villa-pinewood'),
    ('rest_1308', 'https://guide.michelin.com/en/occitanie/lavalette/restaurant/auberge-de-la-forge'),
    ('rest_1309', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/flassans-sur-issole_1505557/restaurant/chez-jeannette'),
    ('rest_1310', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/carry-le-rouet_1505150/restaurant/l-oursin'),
    ('rest_1311', 'https://guide.michelin.com/en/occitanie/toulouse/restaurant/l-ecorce-1243609'),
    ('rest_1313', 'https://guide.michelin.com/en/occitanie/toulouse/restaurant/acte-2-yannick-delpech'),
    ('rest_1314', 'https://guide.michelin.com/en/occitanie/toulouse/restaurant/michel-sarran'),
    ('rest_1315', 'https://guide.michelin.com/en/occitanie/toulouse/restaurant/stephane-tournie-les-jardins-de-l-opera'),
    ('rest_1316', 'https://guide.michelin.com/en/occitanie/quint-fonsegrives/restaurant/en-pleine-nature'),
    ('rest_1317', 'https://guide.michelin.com/en/occitanie/toulouse/restaurant/agapes'),
    ('rest_1318', 'https://guide.michelin.com/en/occitanie/toulouse/restaurant/sept-1207676'),
    ('rest_1319', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/marseille/restaurant/une-table-au-sud'),
    ('rest_1320', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/gmenos/restaurant/la-magdeleine-mathias-dandine'),
    ('rest_1321', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/marseille/restaurant/le-petit-nice'),
    ('rest_1322', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/marseille/restaurant/auffo'),
    ('rest_1323', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/marseille/restaurant/belle-de-mars'),
    ('rest_1324', 'https://guide.michelin.com/en/occitanie/bziers/restaurant/calice'),
    ('rest_1325', 'https://guide.michelin.com/en/occitanie/bziers/restaurant/l-alter-native'),
    ('rest_1326', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/marseille/restaurant/am-par-alexandre-mazzia'),
    ('rest_1327', 'https://guide.michelin.com/en/occitanie/pujaudran/restaurant/le-puits-st-jacques'),
    ('rest_1328', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/cassis/restaurant/la-villa-madie'),
    ('rest_1329', 'https://guide.michelin.com/en/occitanie/aureville/restaurant/en-marge'),
    ('rest_1330', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/saint-tropez/restaurant/la-vague-d-or-cheval-blanc-st-tropez'),
    ('rest_1331', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/saint-tropez/restaurant/arnaud-donckele-maxime-frederic-at-louis-vuitton'),
    ('rest_1332', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/saint-tropez/restaurant/la-terrasse-cheval-blanc-st-tropez'),
    ('rest_1333', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/la-ciotat/restaurant/la-table-de-nans'),
    ('rest_1334', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/la-ciotat/restaurant/couleurs-de-shimatani'),
    ('rest_1335', 'https://guide.michelin.com/en/nouvelle-aquitaine/mont-de-marsan/restaurant/la-table-mirasol'),
    ('rest_1336', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/ramatuelle/restaurant/la-voile'),
    ('rest_1338', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/la-croix-valmer/restaurant/la-palmeraie'),
    ('rest_1339', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/le-lavandou/restaurant/l-oursin-hotel-les-roches'),
    ('rest_1340', 'https://guide.michelin.com/en/provence-alpes-cote-dazur/toulon/restaurant/shanael'),
    ('rest_1341', 'https://guide.michelin.com/en/occitanie/puylausic_1498483/restaurant/la-maison-despoues'),
    ('rest_1342', 'https://guide.michelin.com/en/occitanie/carcassonne/restaurant/la-table-de-franck-putelat'),
    ('rest_1344', 'https://guide.michelin.com/en/nouvelle-aquitaine/eugnie-les-bains/restaurant/l-orangerie-1209337'),
    ('rest_1345', 'https://guide.michelin.com/en/occitanie/fontjoncouse/restaurant/auberge-du-vieux-puits'),
    ('rest_1346', 'https://guide.michelin.com/en/nouvelle-aquitaine/magescq/restaurant/relais-de-la-poste11709'),
    ('rest_1347', 'https://guide.michelin.com/en/nouvelle-aquitaine/seignosse/restaurant/villa-de-l-etang-blanc'),
    ('rest_1348', 'https://guide.michelin.com/en/nouvelle-aquitaine/saint-vincent-de-tyrosse/restaurant/le-hittau'),
    ('rest_1349', 'https://guide.michelin.com/en/occitanie/perpignan/restaurant/la-galinette'),
    ('rest_1350', 'https://guide.michelin.com/en/occitanie/saint-cyprien/restaurant/l-almandin'),
    ('rest_1351', 'https://guide.michelin.com/en/nouvelle-aquitaine/biarritz/restaurant/la-table-d-aurelien-largeau'),
    ('rest_1352', 'https://guide.michelin.com/en/nouvelle-aquitaine/biarritz/restaurant/l-impertinent'),
    ('rest_1353', 'https://guide.michelin.com/en/nouvelle-aquitaine/hasparren/restaurant/la-maison-de-pierre'),
    ('rest_1354', 'https://guide.michelin.com/en/nouvelle-aquitaine/arcangues/restaurant/moulin-d-alotz'),
    ('rest_1356', 'https://guide.michelin.com/en/nouvelle-aquitaine/guthary/restaurant/briketenia'),
    ('rest_1357', 'https://guide.michelin.com/en/nouvelle-aquitaine/bidart/restaurant/les-freres-ibarboure'),
    ('rest_1358', 'https://guide.michelin.com/en/nouvelle-aquitaine/espelette/restaurant/choko-ona'),
    ('rest_1359', 'https://guide.michelin.com/en/nouvelle-aquitaine/saint-pe-sur-nivelle/restaurant/la-table-de-cedric-bechade-l-auberge-basque'),
    ('rest_1360', 'https://guide.michelin.com/en/nouvelle-aquitaine/saint-jean-de-luz/restaurant/le-kaiku'),
    ('rest_1361', 'https://guide.michelin.com/en/nouvelle-aquitaine/ciboure/restaurant/ekaitza'),
    ('rest_1362', 'https://guide.michelin.com/en/occitanie/cret/restaurant/fario-1215907'),
    ('rest_1364', 'https://guide.michelin.com/en/corse/porticcio/restaurant/le-charlie'),
    ('rest_1365', 'https://guide.michelin.com/en/corse/porto-vecchio/restaurant/casadelmar'),
    ('rest_1366', 'https://guide.michelin.com/en/corse/sartene_1508622/restaurant/la-table-de-la-ferme'),
    ('rest_1367', 'https://guide.michelin.com/en/corse/bonifacio/restaurant/finestra-by-italo-bassi');

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
insert into _new values
    ('rest_1405', 'Le Clos des Sens', 3::smallint, 'Annecy', '13 rue Jean-Mermoz - à Annecy-le-Vieux, 74940 Annecy', 6.1445765, 45.9176317, 'https://guide.michelin.com/en/auvergne-rhone-alpes/annecy/restaurant/le-clos-des-sens', 'https://closdessens.com/', NULL),
    ('rest_1406', 'Les Morainières', 3::smallint, 'Jongieux', '1400 route de Marestel, 73170 Jongieux', 5.7983813, 45.7448198, 'https://guide.michelin.com/en/auvergne-rhone-alpes/jongieux/restaurant/les-morainieres', 'https://www.les-morainieres.com', '+33 4 79 44 09 39'),
    ('rest_1407', 'La Table du Castellet', 3::smallint, 'Le Castellet', '3001 route des Hauts-du-Camp, au Circuit Paul Ricard, 83330 Le Castellet', 5.7838874, 43.2499288, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/le-castellet/restaurant/la-table-du-castellet', 'https://www.hotelducastellet.net/fr/la-table-du-castellet.html', '+33 4 94 98 37 77'),
    ('rest_1408', 'Flocons de Sel', 3::smallint, 'Megève', '1775 route du Leutaz, Le Leutaz, 74120 Megève', 6.5969625, 45.8302404, 'https://guide.michelin.com/en/auvergne-rhone-alpes/megve/restaurant/flocons-de-sel', 'https://www.floconsdesel.com', '+33 4 50 21 49 99'),
    ('rest_1409', 'Troisgros - Le Bois sans Feuilles', 3::smallint, 'Ouches', '728 route de Villerest, 42155 Ouches', 3.99236, 46.01033, 'https://guide.michelin.com/en/auvergne-rhone-alpes/ouches/restaurant/troisgros-le-bois-sans-feuilles', 'https://www.troisgros.fr/', '+33 4 77 71 66 97'),
    ('rest_1410', 'Alléno Paris au Pavillon Ledoyen', 3::smallint, 'Paris', '8 avenue Dutuit, 75008 Paris', 2.3164993, 48.8660932, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/alleno-paris-au-pavillon-ledoyen', 'https://www.yannick-alleno.com/les-etablissements-du-groupe/alleno-paris', '+33 1 53 05 10 10'),
    ('rest_1411', 'Le Pré Catelan', 3::smallint, 'Paris', 'Route de Suresnes - bois de Boulogne, 75016 Paris', 2.2507182, 48.8639374, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/le-pre-catelan', 'https://leprecatelan.paris/', '+33 1 44 14 41 14'),
    ('rest_1412', 'Maison Benoît Vidal', 2::smallint, 'Annecy', 'Sur-les-Bois, 79 route de Thônes, 74940 Annecy', 6.171891, 45.9226978, 'https://guide.michelin.com/en/auvergne-rhone-alpes/annecy/restaurant/maison-benoit-vidal', 'https://www.maison-benoit-vidal.com', '+33 4 50 88 73 18'),
    ('rest_1413', 'Cyril Attrazic', 2::smallint, 'Aumont-Aubrac', '319 route du Languedoc, 48130 Aumont-Aubrac', 3.2877885, 44.7169426, 'https://guide.michelin.com/en/occitanie/aumont-aubrac/restaurant/cyril-attrazic', 'https://cyrilattrazic.fr/', '+33 4 66 42 86 14'),
    ('rest_1414', 'Frédéric Doucet', 2::smallint, 'Charolles', '2 avenue de la Libération, 71120 Charolles', 4.2751068, 46.4334609, 'https://guide.michelin.com/en/bourgogne-franche-comte/charolles/restaurant/frederic-doucet', 'https://maison-doucet.com/', '+33 3 85 24 11 32'),
    ('rest_1415', 'Le Pré - Xavier Beaudiment', 2::smallint, 'Clermont-Ferrand', '3 route de la Baraque, 63000 Clermont-Ferrand', 3.0519431, 45.7886787, 'https://guide.michelin.com/en/auvergne-rhone-alpes/clermont-ferrand/restaurant/le-pre-xavier-beaudiment', 'https://www.restaurant-lepre.com/', '+33 4 73 19 25 00'),
    ('rest_1416', 'Paul Bocuse', 2::smallint, 'Collonges-au-Mont-d''Or', '40 rue de la Plage, 69660 Collonges-au-Mont-d''Or', 4.8475623, 45.8156437, 'https://guide.michelin.com/en/auvergne-rhone-alpes/collonges-au-mont-d-or/restaurant/paul-bocuse', 'https://bocuse.fr/', '+33 4 72 42 90 90'),
    ('rest_1417', 'Slalom 1850', 2::smallint, 'Courchevel', 'Le Strato, Route de Bellecôte, Courchevel 1850, 73120 Courchevel', 6.6380783, 45.4102934, 'https://guide.michelin.com/en/auvergne-rhone-alpes/courchevel/restaurant/slalom-1850', 'https://www.hotelstrato.com/', NULL),
    ('rest_1418', 'Anne de Bretagne', 2::smallint, 'La Plaine-sur-Mer', 'Port de Gravette, 163 boulevard de la Tara, 44770 La Plaine-sur-Mer', -2.2133811, 47.1547821, 'https://guide.michelin.com/en/pays-de-la-loire/la-plaine-sur-mer/restaurant/anne-de-bretagne', 'https://www.annedebretagne.com', '+33 2 40 21 54 72'),
    ('rest_1419', 'La Villa Archange', 2::smallint, 'Le Cannet', 'Rue de l''Ouest, 06110 Le Cannet', 7.014556, 43.5716556, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/le-cannet/restaurant/villa-archange', 'https://www.bruno-oger.com', '+33 4 92 18 18 28'),
    ('rest_1420', 'Le Neuvième Art', 2::smallint, 'Lyon', '173 rue Cuvier, 69006 Lyon', 4.8564194, 45.767953, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/le-neuvieme-art', 'https://leneuviemeart.com/', '+33 4 72 74 12 74'),
    ('rest_1421', 'Mère Brazier', 2::smallint, 'Lyon', '12 rue Royale, 69001 Lyon', 4.8372034, 45.7714309, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/mere-brazier', 'https://lamerebrazier.fr/', '+33 4 78 23 17 20'),
    ('rest_1422', 'Takao Takano', 2::smallint, 'Lyon', '33 rue Malesherbes, 69006 Lyon', 4.8426431, 45.7704565, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/takao-takano', 'https://www.takaotakano.com/', '+33 4 82 31 43 39'),
    ('rest_1423', 'Rozó', 2::smallint, 'Marcq-en-Barœul', '34 rue Raymond-Derain, 59700 Marcq-en-Barœul', 3.0909516, 50.6752, 'https://guide.michelin.com/en/hauts-de-france/marcq-en-barul/restaurant/rozo-1202595', 'https://restaurant-rozo.fr', '+33 3 62 27 72 52'),
    ('rest_1424', 'La Grand''Vigne - Les Sources de Caudalie', 2::smallint, 'Martillac', 'Chemin de Smith-Haut-Lafitte, 33650 Martillac', -0.5571095, 44.7310086, 'https://guide.michelin.com/en/nouvelle-aquitaine/martillac/restaurant/la-grand-vigne', 'https://www.sources-hotels.com/bordeaux/restaurants/restaurant-grand-vigne/', '+33 5 57 83 83 83'),
    ('rest_1425', 'La Table Lionel Giraud', 2::smallint, 'Narbonne', 'Rond-point de la Liberté, 68 avenue du Général-Leclerc, 11100 Narbonne', 2.9918502, 43.1743172, 'https://guide.michelin.com/en/occitanie/narbonne/restaurant/la-table-lionel-giraud', 'https://maison.saintcrescent.com/', NULL),
    ('rest_1426', 'Blanc', 2::smallint, 'Paris', '52 rue de Longchamp, 75116 Paris', 2.2874808, 48.8651172, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/blanc-1211547', 'https://www.blanc-paris.com', '+33 1 70 60 12 00'),
    ('rest_1427', 'L''Oiseau Blanc', 2::smallint, 'Paris', 'The Peninsula Paris, 19 avenue Kléber, 75116 Paris', 2.2933134, 48.8707602, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/l-oiseau-blanc', 'https://www.peninsula.com/fr/paris/hotel-fine-dining/french-rooftop-loiseau-blanc', NULL),
    ('rest_1428', 'L''Orangerie', 2::smallint, 'Paris', 'Four Seasons George V, 31 avenue George-V, 75008 Paris', 2.3008263, 48.8687851, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/l-orangerie505878', 'https://www.fourseasons.com/fr/paris/dining/restaurants/l-orangerie/', NULL),
    ('rest_1429', 'Le Skiff Club', 2::smallint, 'Pyla-sur-Mer', 'Hôtel Ha(a)ïtza, 1 avenue Louis-Gaume, 33115 Pyla-sur-Mer', -1.20669, 44.606014, 'https://guide.michelin.com/en/nouvelle-aquitaine/pyla-sur-mer/restaurant/le-skiff-club', 'https://haaitza.com/', '+33 5 56 22 06 06'),
    ('rest_1430', 'Maison Ronan Kervarrec', 2::smallint, 'Saint-Grégoire', '1 impasse du Vieux-Bourg, 35760 Saint-Grégoire', -1.6804562, 48.153434, 'https://guide.michelin.com/en/bretagne/saint-grgoire/restaurant/maison-ronan-kervarrec', 'https://maisonkervarrec.com', '+33 2 99 68 79 35'),
    ('rest_1431', 'Jean Sulpice', 2::smallint, 'Talloires-Montmin', '303 route du Port, 74290 Talloires-Montmin', 6.2106864, 45.8393167, 'https://guide.michelin.com/en/auvergne-rhone-alpes/talloires-montmin/restaurant/jean-sulpice', 'https://www.perebise.com', NULL),
    ('rest_1432', 'L''Auberge de Montmin', 2::smallint, 'Talloires-Montmin', '1983 route de Talloires, Col de la Forclaz, 74210 Talloires-Montmin', 6.2486842, 45.8072811, 'https://guide.michelin.com/en/auvergne-rhone-alpes/talloires-montmin/restaurant/l-auberge-de-montmin', 'https://aubergedemontmin.com/', '+33 4 50 63 85 40'),
    ('rest_1433', 'Py-r', 2::smallint, 'Toulouse', '19 descente de la Halle-aux-Poissons, 31000 Toulouse', 1.4408583, 43.599313, 'https://guide.michelin.com/en/occitanie/toulouse/restaurant/py-r', 'https://www.py-r.com/', NULL),
    ('rest_1434', 'La Table de Yoann Conte', 2::smallint, 'Veyrier-du-Lac', '13 vieille route des Pensières, 74290 Veyrier-du-Lac', 6.1721868, 45.8889235, 'https://guide.michelin.com/en/auvergne-rhone-alpes/veyrier-du-lac/restaurant/la-table-de-yoann-conte', 'https://yoann-conte.com', '+33 4 50 09 97 49'),
    ('rest_1435', 'Georges Blanc', 2::smallint, 'Vonnas', 'Place du Marché, 01540 Vonnas', 4.9894987, 46.2201083, 'https://guide.michelin.com/en/auvergne-rhone-alpes/vonnas/restaurant/georges-blanc', 'https://www.georgesblanc.com', '+33 4 74 50 90 90'),
    ('rest_1436', 'Chalet Flachaire', 1::smallint, 'Abondance', '24 impasse du Cottage, 74360 Abondance', 6.7302501, 46.2854543, 'https://guide.michelin.com/en/auvergne-rhone-alpes/abondance_1509103/restaurant/chalet-flachaire', 'https://www.chaletflachaire.fr', '+33 4 50 72 64 09'),
    ('rest_1437', 'Lait Thym Sel', 1::smallint, 'Angers', '17 rue Boisnet, 49100 Angers', -0.5510094, 47.4745452, 'https://guide.michelin.com/en/pays-de-la-loire/angers/restaurant/lait-thym-sel', 'https://laitthymsel.com/', '+33 7 89 65 89 07'),
    ('rest_1438', 'L''Esquisse', 1::smallint, 'Annecy', '21 rue Royale, 74000 Annecy', 6.12235, 45.89973, 'https://guide.michelin.com/en/auvergne-rhone-alpes/annecy/restaurant/l-esquisse', 'https://esquisse-annecy.fr/', '+33 4 50 44 80 59'),
    ('rest_1439', 'La Rotonde des Trésoms', 1::smallint, 'Annecy', 'Les Trésoms, 15 boulevard de la Corniche, 74000 Annecy', 6.1366994, 45.8896367, 'https://guide.michelin.com/en/auvergne-rhone-alpes/annecy/restaurant/la-rotonde-des-tresoms', 'https://www.lestresoms.com/', '+33 4 50 51 43 84'),
    ('rest_1440', 'La Table - Christophe Hay', 1::smallint, 'Ardon', '200 allée des Quatre-Vents, au golf de Limère, 45160 Ardon', 1.9124177, 47.8220926, 'https://guide.michelin.com/en/centre-val-de-loire/ardon/restaurant/la-table-christophe-hay', 'https://www.latabledacote.fr/', '+33 2 38 61 48 07'),
    ('rest_1441', 'Pollen', 1::smallint, 'Avignon', '18 rue Joseph-Vernet, 84000 Avignon', 4.8035568, 43.9493415, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/avignon/restaurant/pollen1000267', 'https://www.pollen-restaurant.fr', '+33 4 86 34 93 74'),
    ('rest_1442', 'Auberge Pom''Poire', 1::smallint, 'Azay-le-Rideau', '21 route de Vallères, 37190 Azay-le-Rideau', 0.4450558, 47.2830529, 'https://guide.michelin.com/en/centre-val-de-loire/azay-le-rideau/restaurant/auberge-pom-poire', 'https://aubergepompoire.fr', '+33 2 47 45 83 00'),
    ('rest_1443', 'Le Gavrinis', 1::smallint, 'Baden', '1 rue de l''Île-Gavrinis, 56870 Baden', -2.8980542, 47.6232039, 'https://guide.michelin.com/en/bretagne/baden/restaurant/le-gavrinis', 'https://www.gavrinis.fr', '+33 2 97 57 00 82'),
    ('rest_1444', 'Le Manoir du Lys', 1::smallint, 'Bagnoles-de-l''Orne', 'Route de Juvigny-sous-Andaine, 61140 Bagnoles-de-l''Orne', -0.4443803, 48.5623198, 'https://guide.michelin.com/en/normandie/bagnoles-de-l-orne/restaurant/le-manoir-du-lys', 'https://www.manoir-du-lys.fr', '+33 2 33 37 80 69'),
    ('rest_1445', 'La Table de la Bergerie', 1::smallint, 'Bellevigne-en-Layon', '3 route de la Pierre, 49380 Bellevigne-en-Layon', -0.59238, 47.26803, 'https://guide.michelin.com/en/pays-de-la-loire/bellevigne-en-layon_7770388/restaurant/la-table-de-la-bergerie', 'https://www.latable-bergerie.fr', '+33 2 41 78 30 62'),
    ('rest_1446', 'Lore Ttipia - Auberge Ostape', 1::smallint, 'Bidarray', 'Domaine de Chahatoenia, 64780 Bidarray', -1.3619713, 43.2895753, 'https://guide.michelin.com/en/nouvelle-aquitaine/bidarray/restaurant/lore-ttipia-auberge-ostape', 'https://www.ostape.com', '+33 5 59 37 91 91'),
    ('rest_1447', 'La Table d''Asten', 1::smallint, 'Binic', '8 boulevard Clemenceau, 22520 Binic', -2.8251327, 48.5994572, 'https://guide.michelin.com/en/bretagne/binic/restaurant/la-table-d-asten', 'https://www.asten-restaurant.fr', '+33 2 56 44 28 42'),
    ('rest_1448', 'Assa', 1::smallint, 'Blois', '26 avenue du Maréchal-Maunoury, 41000 Blois', 1.3362149, 47.5916586, 'https://guide.michelin.com/en/centre-val-de-loire/blois/restaurant/assa', 'https://www.assarestaurant.com/', '+33 2 54 78 09 01'),
    ('rest_1449', 'La Bastide', 1::smallint, 'Bonnieux', '550 chemin des Cabanes, 84480 Bonnieux', 5.3174831, 43.821659, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/bonnieux/restaurant/la-bastide-10332', 'https://www.beaumier.com/fr/proprietes/hotel-capelongue/gastronomie/', '+33 4 90 75 89 78'),
    ('rest_1450', 'Lueurs', 1::smallint, 'Bouchemaine', '2 quai de Port-Boulet, 49080 Bouchemaine', -0.6177721, 47.4103362, 'https://guide.michelin.com/en/pays-de-la-loire/bouchemaine_1570563/restaurant/lueurs', 'https://lepetitserrant.com/lueurs/', NULL),
    ('rest_1451', 'Le Moulin de l''Abbaye', 1::smallint, 'Brantôme', '1 route de Bourdeilles, 24310 Brantôme', 0.6462835, 45.3631, 'https://guide.michelin.com/en/nouvelle-aquitaine/brantme/restaurant/le-moulin-de-l-abbaye', 'https://www.moulinabbaye.com/', '+33 5 53 05 80 22'),
    ('rest_1452', 'Jean-Marc Pérochon', 1::smallint, 'Brétignolles-sur-Mer', '63 avenue de la Grande-Roche, 85470 Bretignolles-sur-Mer', -1.87165, 46.61923, 'https://guide.michelin.com/en/pays-de-la-loire/brtignolles-sur-mer/restaurant/jean-marc-perochon', 'https://www.lesbrisants.com', '+33 2 51 33 65 53'),
    ('rest_1453', 'Nicolas Carro - Hôtel de Carantec', 1::smallint, 'Carantec', '20 rue du Kelenn, 29660 Carantec', -3.9127356, 48.6706639, 'https://guide.michelin.com/en/bretagne/carantec/restaurant/nicolas-carro', 'https://www.hotel-carantec.fr/', '+33 2 98 67 00 47'),
    ('rest_1454', 'La Table de Chaintré', 1::smallint, 'Chaintré', '72 place du Luminaire, 71570 Chaintré', 4.7601996, 46.2604162, 'https://guide.michelin.com/en/bourgogne-franche-comte/chaintr/restaurant/la-table-de-chaintre', 'https://www.latabledechaintre.com', '+33 3 85 32 90 95'),
    ('rest_1455', 'Radio', 1::smallint, 'Chamalières', '43 avenue Pierre-et-Marie-Curie, 63400 Chamalières', 3.0615915, 45.7699115, 'https://guide.michelin.com/en/auvergne-rhone-alpes/chamalires/restaurant/radio10778', 'https://www.hotel-radio.fr/', NULL),
    ('rest_1456', 'Albert 1er', 1::smallint, 'Chamonix Mont-Blanc', 'Hameau Albert-1er, 38 route du Bouchet, 74400 Chamonix Mont-Blanc', 6.8748108, 45.9245641, 'https://guide.michelin.com/en/auvergne-rhone-alpes/chamonix-mont-blanc/restaurant/albert-1er', 'https://www.hameaualbert.fr', '+33 4 50 53 05 09'),
    ('rest_1457', 'Ed.Em', 1::smallint, 'Chassagne-Montrachet', '4 impasse Chenevottes, 21190 Chassagne-Montrachet', 4.7307841, 46.9384854, 'https://guide.michelin.com/en/bourgogne-franche-comte/chassagne-montrachet/restaurant/ed-em', 'https://restaurant-edem.com/', '+33 3 80 21 94 94'),
    ('rest_1458', 'Guy Lassausaie', 1::smallint, 'Chasselay', '3 rue de Belle-Sise, 69380 Chasselay', 4.7705653, 45.8727314, 'https://guide.michelin.com/en/auvergne-rhone-alpes/chasselay/restaurant/guy-lassausaie', 'https://www.guy-lassausaie.com/', '+33 4 78 47 62 59'),
    ('rest_1459', 'Château Blanchard', 1::smallint, 'Chazelles-sur-Lyon', '36 route de Saint-Galmier, 42140 Chazelles-sur-Lyon', 4.385362, 45.63603, 'https://guide.michelin.com/en/auvergne-rhone-alpes/chazelles-sur-lyon/restaurant/chateau-blanchard', 'https://www.hotel-chateau-blanchard.com/', NULL),
    ('rest_1460', 'Le Favori - Les Sources de Cheverny', 1::smallint, 'Cheverny', '23 route de Fougère, 41700 Cheverny', 1.4322442, 47.4776029, 'https://guide.michelin.com/en/centre-val-de-loire/cheverny/restaurant/le-favori-les-sources-de-cheverny', 'https://www.sources-hotels.com/valdeloire/restaurants/restaurant-le-favori/', '+33 2 54 44 20 20'),
    ('rest_1461', 'La Table de Philippe Girardon', 1::smallint, 'Chonas-l''Amballan', 'Domaine de Clairefontaine, 105 chemin des Fontanettes, 38121 Chonas-l''Amballan', 4.8107351, 45.456987, 'https://guide.michelin.com/en/auvergne-rhone-alpes/chonas-l-amballan/restaurant/la-table-de-philippe-girardon', 'https://domaine-de-clairefontaine.fr/', '+33 4 74 58 81 52'),
    ('rest_1462', 'L''Impulsif', 1::smallint, 'Châtel-Guyon', '19 avenue Baraduc, 63140 Châtel-Guyon', 3.0660287, 45.9196471, 'https://guide.michelin.com/en/auvergne-rhone-alpes/chatel-guyon/restaurant/l-impulsif', 'https://www.limpulsif-restaurant.com', '+33 4 73 86 48 89'),
    ('rest_1463', 'Apicius', 1::smallint, 'Clermont-Ferrand', 'Place du Marché-Saint-Pierre (à l''étage), 63000 Clermont-Ferrand', 3.0827699, 45.7793794, 'https://guide.michelin.com/en/auvergne-rhone-alpes/clermont-ferrand/restaurant/apicius205570', 'https://www.apicius-clermont.com/', '+33 4 73 91 13 61'),
    ('rest_1464', 'Jean-Claude Leclerc', 1::smallint, 'Clermont-Ferrand', '12 rue Saint-Adjutor, 63000 Clermont-Ferrand', 3.0804584, 45.7788173, 'https://guide.michelin.com/en/auvergne-rhone-alpes/clermont-ferrand/restaurant/jean-claude-leclerc', 'https://restaurant-jcl.com/', '+33 4 73 36 46 30'),
    ('rest_1465', 'L''Ostal', 1::smallint, 'Clermont-Ferrand', '16 rue Claussmann, 63000 Clermont-Ferrand', 3.0879692, 45.7810567, 'https://guide.michelin.com/en/auvergne-rhone-alpes/clermont-ferrand/restaurant/l-ostal', 'https://www.lostal-restaurant.fr', '+33 4 73 27 77 86'),
    ('rest_1466', 'Le Chabichou by Stéphane Buron', 1::smallint, 'Courchevel', '90 rue des Chenus, Courchevel 1850, 73120 Courchevel', 6.629984, 45.41616, 'https://guide.michelin.com/en/auvergne-rhone-alpes/courchevel/restaurant/le-chabichou-by-stephane-buron', 'https://www.chabichou-courchevel.com', '+33 4 79 08 00 55'),
    ('rest_1467', 'Le Farçon', 1::smallint, 'Courchevel', 'Immeuble Kalinka, La Tania, 73120 Courchevel', 6.5938711, 45.4315173, 'https://guide.michelin.com/en/auvergne-rhone-alpes/courchevel/restaurant/le-farcon', 'https://www.lefarcon.fr/', '+33 4 79 08 80 34'),
    ('rest_1468', 'Pourquoi Pas', 1::smallint, 'Dinard', 'Hôtel Castelbrac, 17 avenue George-V, 35800 Dinard', -2.0490902, 48.6344213, 'https://guide.michelin.com/en/bretagne/dinard/restaurant/pourquoi-pas', 'https://www.castelbrac.com/', NULL),
    ('rest_1469', 'Ô Flaveurs', 1::smallint, 'Douvaine', 'Château de Chilly, 42 route du Crépy, 74140 Douvaine', 6.3139725, 46.3018121, 'https://guide.michelin.com/en/auvergne-rhone-alpes/douvaine/restaurant/o-flaveurs', 'https://oflaveurs.com/', '+33 4 50 35 46 55'),
    ('rest_1470', 'Toya', 1::smallint, 'Faulquemont', 'Avenue Jean-Monnet, 57380 Faulquemont', 6.627029, 49.0564967, 'https://guide.michelin.com/en/grand-est/faulquemont/restaurant/toya', 'https://toya-restaurant.fr/', '+33 3 87 89 34 22'),
    ('rest_1471', 'Le Jardin de Berne', 1::smallint, 'Flayosc', 'Château de Berne, chemin des Imberts, 83780 Flayosc', 6.3660986, 43.5164138, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/flayosc/restaurant/le-jardin-de-berne', 'https://www.chateauberne.com/', '+33 4 94 60 49 79'),
    ('rest_1472', 'Auberge du Cep', 1::smallint, 'Fleurie', '11 rue des Quatre-Vents, 69820 Fleurie', 4.6969883, 46.1921358, 'https://guide.michelin.com/en/auvergne-rhone-alpes/fleurie/restaurant/auberge-du-cep', 'https://aubergeducep.com', '+33 4 74 04 10 77'),
    ('rest_1473', 'Fontevraud L''Ermitage', 1::smallint, 'Fontevraud-l''Abbaye', '38 rue Saint-Jean-de-l''Habit, 49590 Fontevraud-l''Abbaye', 0.0524964, 47.1797597, 'https://guide.michelin.com/en/pays-de-la-loire/fontevraud-l-abbaye/restaurant/fontevraud-l-ermitage', 'https://www.fontevraud.fr/fontevraud-lermitage/le-restaurant-de-fontevraud-lermitage/', '+33 2 46 46 10 10'),
    ('rest_1474', 'L''O des Vignes', 1::smallint, 'Fuissé', '129 rue du Bourg, 71960 Fuissé', 4.74395, 46.2802, 'https://guide.michelin.com/en/bourgogne-franche-comte/fuiss/restaurant/l-o-des-vignes', 'https://lodesvignes.fr', '+33 3 85 38 33 40'),
    ('rest_1475', 'Maison Tiegezh', 1::smallint, 'Guer', '7 place de la Gare, 56380 Guer', -2.1238134, 47.9057936, 'https://guide.michelin.com/en/bretagne/guer/restaurant/maison-tiegezh', 'https://maisontiegezh.fr/', '+33 2 97 22 00 26'),
    ('rest_1476', 'Mont Blanc Restaurant & Goûter', 1::smallint, 'Hauteluce', '16 rue de la Voûte, 73620 Hauteluce', 6.5843326, 45.7498163, 'https://guide.michelin.com/en/auvergne-rhone-alpes/hauteluce/restaurant/mont-blanc-restaurant-gouter', 'https://www.montblanc-restaurant.com', '+33 4 79 37 01 61'),
    ('rest_1477', 'Le Cin5 - Au Cœur du Village', 1::smallint, 'La Clusaz', '26 montée du Château, 74220 La Clusaz', 6.42312, 45.90452, 'https://guide.michelin.com/en/auvergne-rhone-alpes/la-clusaz/restaurant/le-cinq', 'https://www.hotel-aucoeurduvillage.fr/restauration/le-cinq', '+33 4 50 01 50 01'),
    ('rest_1478', 'Château de la Treyne', 1::smallint, 'Lacave', '3135 route des Deux-Châteaux, 46200 Lacave', 1.5253884, 44.8494743, 'https://guide.michelin.com/en/occitanie/lacave/restaurant/chateau-de-la-treyne', 'https://www.chateaudelatreyne.com/', '+33 5 65 27 60 60'),
    ('rest_1479', 'L''Anthocyane', 1::smallint, 'Lannion', '25 avenue Ernest-Renan, 22300 Lannion', -3.4601755, 48.7329305, 'https://guide.michelin.com/en/bretagne/lannion/restaurant/l-anthocyane', 'https://www.lanthocyane.com', '+33 2 96 38 30 49'),
    ('rest_1480', 'Le Puits du Trésor', 1::smallint, 'Lastours', '21 route des Quatre-Châteaux, 11600 Lastours', 2.3787415, 43.3346453, 'https://guide.michelin.com/en/occitanie/lastours/restaurant/le-puits-du-tresor', 'https://lepuitsdutresor.com', '+33 4 68 77 50 24'),
    ('rest_1481', 'Atmosphères', 1::smallint, 'Le Bourget-du-Lac', '618 route des Tournelles, 73370 Le Bourget-du-Lac', 5.8522537, 45.6606861, 'https://guide.michelin.com/en/auvergne-rhone-alpes/le-bourget-du-lac/restaurant/atmospheres', 'https://www.atmospheres-hotel.com', NULL),
    ('rest_1482', 'Lamartine', 1::smallint, 'Le Bourget-du-Lac', '3132 route du Tunnel, Bourdeau, 73370 Le Bourget-du-Lac', 5.8531112, 45.6758342, 'https://guide.michelin.com/en/auvergne-rhone-alpes/le-bourget-du-lac/restaurant/lamartine', 'https://www.lamartine-marin.com', '+33 4 79 25 01 03'),
    ('rest_1483', 'Origines', 1::smallint, 'Le Broc', 'Rue du Clos-de-la-Chaux, 63500 Le Broc', 3.2436174, 45.5014095, 'https://guide.michelin.com/en/auvergne-rhone-alpes/le-broc/restaurant/origines', 'https://www.restaurant-origines.fr/fr/', '+33 4 73 71 71 71'),
    ('rest_1484', 'La Promenade - Maison Dallais', 1::smallint, 'Le Petit-Pressigny', '11 rue du Savoureulx, 37350 Le Petit-Pressigny', 0.9188379, 46.920786, 'https://guide.michelin.com/en/centre-val-de-loire/le-petit-pressigny/restaurant/la-promenade-maison-dallais', 'https://www.restaurantdallaislapromenade.com', NULL),
    ('rest_1485', 'Le Pavillon - Hôtel Westminster', 1::smallint, 'Le Touquet-Paris-Plage', 'Avenue du Verger, 62520 Le Touquet-Paris-Plage', 1.5914671, 50.5221852, 'https://guide.michelin.com/en/hauts-de-france/le-touquet-paris-plage/restaurant/le-pavillon9000', 'https://www.hotelsbarriere.com/le-touquet-paris-plage/le-westminster/restaurants-et-bars/le-pavillon', '+33 3 21 05 48 48'),
    ('rest_1486', 'Cheval Blanc', 1::smallint, 'Lembach', '4 rue de Wissembourg, 67510 Lembach', 7.7907053, 49.0032985, 'https://guide.michelin.com/en/grand-est/lembach/restaurant/cheval-blanc-4111', 'https://www.cheval-blanc-lembach.fr/', '+33 3 88 94 41 86'),
    ('rest_1487', 'Le Relais des Moines', 1::smallint, 'Les Arcs', 'Route de Sainte-Roseline, 83460 Les Arcs', 6.4905162, 43.4662157, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/les-arcs/restaurant/le-relais-des-moines', 'https://www.lerelaisdesmoines.com', '+33 4 94 47 40 93'),
    ('rest_1488', 'Le 1201 - Abbaye de Villeneuve', 1::smallint, 'Les Sorinières', 'Lieu-dit Villeneuve, 44840 Les Sorinières', -1.5338567, 47.1232859, 'https://guide.michelin.com/en/pays-de-la-loire/les-sorinieres/restaurant/le-1201-abbaye-de-villeneuve', 'https://www.abbayedevilleneuve.com/restaurant/', NULL),
    ('rest_1489', 'Likoké', 1::smallint, 'Les Vans', '33 route de Païolive, 07140 Les Vans', 4.133207, 44.4040212, 'https://guide.michelin.com/en/auvergne-rhone-alpes/les-vans/restaurant/likoke', 'https://likoke.fr/', NULL),
    ('rest_1490', 'Le Grand Cap', 1::smallint, 'Leucate', 'Chemin du Phare, 11370 Leucate', 3.0571854, 42.9114961, 'https://guide.michelin.com/en/occitanie/leucate/restaurant/le-grand-cap', 'https://www.restaurant-grand-cap.fr/', '+33 9 67 78 13 73'),
    ('rest_1491', 'L''Auberge de Lucinges', 1::smallint, 'Lucinges', '67 place de l''Église, 74380 Lucinges', 6.3184274, 46.1905123, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lucinges/restaurant/l-auberge-de-lucinges', 'https://www.laubergedelucinges.fr', '+33 4 50 39 64 74'),
    ('rest_1492', 'A Casa di Mà', 1::smallint, 'Lumio', 'Route de Calvi, 20260 Lumio', 8.8318859, 42.5813042, 'https://guide.michelin.com/en/corse/lumio/restaurant/a-casa-di-ma', 'https://www.acasadima.com/', NULL),
    ('rest_1493', 'Au 14 Février', 1::smallint, 'Lyon', '36 rue du Bœuf, 69005 Lyon', 4.8263815, 45.7622206, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/au-14-fevrier281900', 'https://www.ly-au14fevrier.com/', '+33 4 78 92 91 39'),
    ('rest_1494', 'Burgundy by Matthieu', 1::smallint, 'Lyon', '24 quai Saint-Antoine, 69002 Lyon', 4.8321372, 45.7628677, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/burgundy-by-mathieu', 'https://burgundybym.fr/', '+33 4 72 04 04 51'),
    ('rest_1495', 'Circle', 1::smallint, 'Lyon', '11 rue Chavanne, 69001 Lyon', 4.8324022, 45.7648991, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/circle', 'https://circlelyon.fr', '+33 4 78 27 86 93'),
    ('rest_1496', 'L''Atelier des Augustins', 1::smallint, 'Lyon', '17 rue Hippolyte-Flandrin, 69001 Lyon', 4.8308367, 45.7677374, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/l-atelier-des-augustins', 'https://latelierdesaugustins.com', '+33 4 72 00 88 01'),
    ('rest_1497', 'Les Loges', 1::smallint, 'Lyon', 'Cour des Loges, 6 rue du Bœuf, 69005 Lyon', 4.8274228, 45.7633598, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/les-loges', 'https://courdesloges.com', '+33 4 72 77 44 44'),
    ('rest_1498', 'Miraflores', 1::smallint, 'Lyon', '112 boulevard des Belges, 69006 Lyon', 4.8584873, 45.7684145, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/miraflores-1190862', 'https://www.restaurant-miraflores.com', NULL),
    ('rest_1499', 'Ombellule', 1::smallint, 'Lyon', '36 cours Franklin-Roosevelt, 69006 Lyon', 4.8469216, 45.7687695, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/ombellule', 'https://www.ombellule.fr/', '+33 4 51 68 08 90'),
    ('rest_1500', 'Prairial', 1::smallint, 'Lyon', '1 place Hubert-Mounier, 69002 Lyon', 4.8229022, 45.7415161, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/prairial', 'https://www.prairial-restaurant.fr', '+33 4 87 78 32 51'),
    ('rest_1501', 'Rustique', 1::smallint, 'Lyon', '14 rue d''Enghien, 69002 Lyon', 4.8262529, 45.7520806, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/rustique', 'https://www.rustiquelyon.fr', '+33 4 72 13 80 81'),
    ('rest_1502', 'Têtedoie', 1::smallint, 'Lyon', '4 rue Professeur-Pierre-Marion, 69005 Lyon', 4.8233917, 45.7590732, 'https://guide.michelin.com/en/auvergne-rhone-alpes/lyon/restaurant/tetedoie', 'https://tetedoie.com/', '+33 4 78 29 40 10'),
    ('rest_1503', 'Le Refuge des Gourmets', 1::smallint, 'Machilly', '90 route des Framboises, 74140 Machilly', 6.3282703, 46.2482745, 'https://guide.michelin.com/en/auvergne-rhone-alpes/machilly/restaurant/le-refuge-des-gourmets', 'https://refugedesgourmets.com/', '+33 4 50 43 53 87'),
    ('rest_1504', 'Séchex Nous', 1::smallint, 'Margencel', '2 route des Meules (Port de Séchex), 74200 Margencel', 6.4021869, 46.349025, 'https://guide.michelin.com/en/auvergne-rhone-alpes/margencel/restaurant/sechex-nous', 'https://www.sechex-nous.com/', '+33 4 50 72 48 81'),
    ('rest_1505', 'Le Cerf', 1::smallint, 'Marlenheim', '30 rue du Général-de-Gaulle, 67520 Marlenheim', 7.4936044, 48.6209681, 'https://guide.michelin.com/en/grand-est/marlenheim/restaurant/le-cerf', 'https://www.lecerf.com/', '+33 3 88 87 73 73'),
    ('rest_1506', 'Vous', 1::smallint, 'Megève', '36 rue Saint-François, 74120 Megève', 6.6183242, 45.8574776, 'https://guide.michelin.com/en/auvergne-rhone-alpes/megve/restaurant/vous', 'https://www.juliengatillon.fr/vous', '+33 6 59 55 95 83'),
    ('rest_1507', 'Timilìa', 1::smallint, 'Metz', '20 rue Vigne-Saint-Avold, 57000 Metz', 6.1829023, 49.1149433, 'https://guide.michelin.com/en/grand-est/metz/restaurant/timilia', 'https://www.ristorante-timilia.com', '+33 3 87 63 68 44'),
    ('rest_1508', 'Kasbür', 1::smallint, 'Monswiller', '8 route de Dettwiller, 67700 Monswiller', 7.3977237, 48.7419047, 'https://guide.michelin.com/en/grand-est/monswiller/restaurant/kasbur', 'https://restaurant-kasbur.fr', '+33 3 88 02 14 20'),
    ('rest_1509', 'La Robe', 1::smallint, 'Montaigu', '2 rue Neuve, 85600 Montaigu', -1.3117964, 46.9776592, 'https://guide.michelin.com/en/pays-de-la-loire/montaigu/restaurant/la-robe', 'https://www.restaurant-la-robe.com', '+33 2 51 47 79 27'),
    ('rest_1510', 'La Marande', 1::smallint, 'Montbellet', '1484 route de Lugny, hameau de Mirande, 71260 Montbellet', 4.872302, 46.4644829, 'https://guide.michelin.com/en/bourgogne-franche-comte/montbellet/restaurant/la-marande', 'https://www.hotel-restaurant-la-marande.com/', '+33 3 85 33 10 24'),
    ('rest_1511', 'Moulin de la Tardoire', 1::smallint, 'Montbron', '6 route du Bounit (Lieu-dit la Forge), 16220 Montbron', 0.5138297, 45.6768252, 'https://guide.michelin.com/en/nouvelle-aquitaine/montbron/restaurant/moulin-de-la-tardoire', 'https://www.moulindelatardoire.fr', '+33 5 45 66 41 46'),
    ('rest_1512', 'La Chapelle - Château Saint-Jean', 1::smallint, 'Montluçon', 'Avenue Henri-de-la-Tourfondue, 03100 Montluçon', 2.6049801, 46.3233297, 'https://guide.michelin.com/en/auvergne-rhone-alpes/montluon/restaurant/la-chapelle', 'https://www.chateau-saint-jean.com/restaurants-bar/restaurant-la-chapelle/', '+33 4 70 03 26 57'),
    ('rest_1513', 'L''Aparté', 1::smallint, 'Montrabé', '21 rue de l''Europe, 31850 Montrabé', 1.5107135, 43.6449305, 'https://guide.michelin.com/en/occitanie/montrab/restaurant/l-aparte', 'https://restaurant-laparte.fr/', '+33 5 34 26 43 44'),
    ('rest_1514', 'L''Ekrin by Laurent Azoulay', 1::smallint, 'Méribel', 'Le Kaïla, 124 rue des Jeux-Olympiques, 73550 Méribel', 6.5673633, 45.3940091, 'https://guide.michelin.com/en/auvergne-rhone-alpes/mribel/restaurant/l-ekrin-by-laurent-azoulay', 'https://www.lekaila.com', '+33 4 79 41 69 35'),
    ('rest_1515', 'Auberge Grand''Maison', 1::smallint, 'Mûr-de-Bretagne', '1 rue Léon-le-Cerf, 22530 Mûr-de-Bretagne', -2.9869249, 48.201112, 'https://guide.michelin.com/en/bretagne/mr-de-bretagne/restaurant/auberge-grand-maison', 'https://www.auberge-grand-maison.com', '+33 2 96 28 51 10'),
    ('rest_1516', 'Freia', 1::smallint, 'Nantes', '22 boulevard de Berlin, 44000 Nantes', -1.5364084, 47.216871, 'https://guide.michelin.com/en/pays-de-la-loire/nantes/restaurant/freia', 'https://www.freia-restaurant.com', '+33 9 72 10 10 44'),
    ('rest_1517', 'L''Atlantide 1874 - Maison Guého', 1::smallint, 'Nantes', '5 rue de l''Hermitage, 44100 Nantes', -1.5777426, 47.2012378, 'https://guide.michelin.com/en/pays-de-la-loire/nantes/restaurant/l-atlantide-1874-maison-gueho', 'https://www.atlantide1874.fr/', '+33 2 40 73 23 23'),
    ('rest_1518', 'Le Manoir de la Régate', 1::smallint, 'Nantes', '155 route de Gachet, 44300 Nantes', -1.5265172, 47.293636, 'https://guide.michelin.com/en/pays-de-la-loire/nantes/restaurant/manoir-de-la-regate', 'https://www.manoirdelaregate.com/', '+33 2 40 18 02 97'),
    ('rest_1519', 'Les Cadets', 1::smallint, 'Nantes', '15 rue des Hauts-Pavés, 44000 Nantes', -1.5633164, 47.2227059, 'https://guide.michelin.com/en/pays-de-la-loire/nantes/restaurant/les-cadets', 'https://www.restaurantlescadets.fr', '+33 9 86 57 01 46'),
    ('rest_1520', 'LuluRouget', 1::smallint, 'Nantes', '4 place Albert-Camus, 44200 Nantes', -1.562099, 47.2046854, 'https://guide.michelin.com/en/pays-de-la-loire/nantes/restaurant/lulurouget', 'https://www.lulurouget.fr/', '+33 2 40 47 47 98'),
    ('rest_1521', 'Omija', 1::smallint, 'Nantes', '54 rue Fouré, 44000 Nantes', -1.5472623, 47.210365, 'https://guide.michelin.com/en/pays-de-la-loire/nantes/restaurant/omija', 'https://www.omija.fr/', '+33 2 40 74 81 05'),
    ('rest_1522', 'JAN', 1::smallint, 'Nice', '12 rue Lascaris, 06300 Nice', 7.2848004, 43.6998945, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/nice/restaurant/jan', 'https://janonline.com/fr/restaurantjan/', NULL),
    ('rest_1523', 'Auberge du Pont d''Acigné', 1::smallint, 'Noyal-sur-Vilaine', '8 Le Pont-d''Acigné (lieu-dit), 35530 Noyal-sur-Vilaine', -1.5346294, 48.1305627, 'https://guide.michelin.com/en/bretagne/noyal-sur-vilaine/restaurant/auberge-du-pont-d-acigne', 'https://lepontdacigne.com/', '+33 2 99 62 52 55'),
    ('rest_1524', 'Jérôme Nutile', 1::smallint, 'Nîmes', '351 chemin Bas-du-Mas-de-Boudan, 30000 Nîmes', 4.3709411, 43.8208935, 'https://guide.michelin.com/en/occitanie/nimes/restaurant/jerome-nutile', 'https://www.jerome-nutile.com', '+33 4 66 40 65 65'),
    ('rest_1525', 'La Verrière', 1::smallint, 'Olmeto', 'Hôtel Marinca, lieu-dit Vitricella, 20113 Olmeto', 8.902559, 41.6913495, 'https://guide.michelin.com/en/corse/olmeto/restaurant/la-verriere', 'https://www.hotel-marinca.com/la-verriere', NULL),
    ('rest_1526', 'Château d''Origny', 1::smallint, 'Ouches', '2210 route de Roanne, 42155 Ouches', 4.0170014, 46.0235156, 'https://guide.michelin.com/en/auvergne-rhone-alpes/ouches/restaurant/chateau-d-origny', 'https://www.chateaudorigny.com', '+33 4 77 72 52 67'),
    ('rest_1527', 'AT', 1::smallint, 'Paris', '4bis rue du Cardinal-Lemoine, 75005 Paris', 2.3544763, 48.8496507, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/at', 'https://www.atsushitanaka.com/', '+33 1 56 81 94 08'),
    ('rest_1528', 'Amâlia', 1::smallint, 'Paris', '32 rue de la Fontaine-au-Roi, 75011 Paris', 2.371705, 48.8681622, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/amalia', 'https://amaliarestaurant.com', '+33 9 75 79 05 77'),
    ('rest_1529', 'Apicius', 1::smallint, 'Paris', '20 rue d''Artois, 75008 Paris', 2.3072835, 48.8732881, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/apicius6479', 'https://restaurant-apicius.com/', '+33 1 43 80 19 66'),
    ('rest_1530', 'ES', 1::smallint, 'Paris', '91 rue de Grenelle, 75007 Paris', 2.3211774, 48.856449, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/es', 'https://es-restaurant.fr/', '+33 1 45 51 25 74'),
    ('rest_1531', 'L''Atelier de Joël Robuchon - Étoile', 1::smallint, 'Paris', '133 avenue des Champs-Élysées, 75008 Paris', 2.2973168, 48.8728404, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/l-atelier-de-joel-robuchon-etoile', 'https://atelier-robuchon-etoile.com/', '+33 1 47 23 75 75'),
    ('rest_1532', 'La Grande Cascade', 1::smallint, 'Paris', 'Allée de Longchamp, Bois de Boulogne, 75016 Paris', 2.2404762, 48.8626663, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/la-grande-cascade', 'https://www.restaurantsparisiens.com/la-grande-cascade/', '+33 1 45 27 33 51'),
    ('rest_1533', 'Mavrommatis', 1::smallint, 'Paris', '42 rue Daubenton, 75005 Paris', 2.3511901, 48.8405528, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/mavrommatis', 'https://www.mavrommatis.com', '+33 1 43 31 17 17'),
    ('rest_1534', 'Nomicos', 1::smallint, 'Paris', '16 avenue Hubert-Germain, 75116 Paris', 2.2830545, 48.8702767, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/nomicos', 'https://www.nomicos.fr', NULL),
    ('rest_1535', 'Pur'' - Jean-François Rouquette', 1::smallint, 'Paris', 'Park Hyatt Paris-Vendôme, 5 rue de la Paix, 75002 Paris', 2.3303786, 48.868617, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/pur-jean-francois-rouquette', 'https://www.paris-restaurant-pur.fr', '+33 1 58 71 10 60'),
    ('rest_1536', 'Ōrtensia', 1::smallint, 'Paris', '4 rue Beethoven, 75016 Paris', 2.2875568, 48.8584133, 'https://guide.michelin.com/en/ile-de-france/paris/restaurant/ortensia-1202241', 'https://www.restaurantortensia.com', NULL),
    ('rest_1537', 'Les Jardins', 1::smallint, 'Parnac', '1533 route du Port-de-l''Angle, 46140 Parnac', 1.3154983, 44.4933522, 'https://guide.michelin.com/en/occitanie/parnac/restaurant/les-jardins', 'https://restaurant-lesjardins.fr/', '+33 5 65 23 58 24'),
    ('rest_1538', 'Le Charlemagne', 1::smallint, 'Pernand-Vergelesses', '1 route des Vergelesses, 21420 Pernand-Vergelesses', 4.8497698, 47.0772707, 'https://guide.michelin.com/en/bourgogne-franche-comte/pernand-vergelesses/restaurant/le-charlemagne', 'https://www.lecharlemagne.fr/', '+33 3 80 21 51 45'),
    ('rest_1539', 'La Table des Pères - Domaine du Château des Pères', 1::smallint, 'Piré-Chancé', 'Route de Boistrudan, 35150 Piré-Chancé', -1.4282385, 47.992376, 'https://guide.michelin.com/en/bretagne/pire-chance/restaurant/la-table-des-peres-domaine-du-chateau-des-peres', 'https://www.chateaudesperes.fr', '+33 2 23 08 40 80'),
    ('rest_1540', 'Nuance', 1::smallint, 'Plomeur', '35 roz An Tremen, 29120 Plomeur', -4.329514, 47.8372701, 'https://guide.michelin.com/en/bretagne/plomeur_1568548/restaurant/nuance-1215929', 'https://nuance-restaurant.fr/', '+33 2 30 14 02 74'),
    ('rest_1541', 'La Vieille Tour', 1::smallint, 'Plérin', '75 rue de la Tour, 22190 Plérin', -2.7261477, 48.5307941, 'https://guide.michelin.com/en/bretagne/plerin/restaurant/la-vieille-tour7741', 'https://www.la-vieille-tour.com', '+33 2 96 33 10 30'),
    ('rest_1542', 'AinTimiste', 1::smallint, 'Poncin', '4 rue de la Pompe, 01450 Poncin', 5.4078158, 46.0858481, 'https://guide.michelin.com/en/auvergne-rhone-alpes/poncin/restaurant/aintimiste', 'https://aintimiste.fr/', '+33 4 74 38 06 66'),
    ('rest_1543', 'Le Raisin', 1::smallint, 'Pont-de-Vaux', '2 place Michel-Poisat, 01190 Pont-de-Vaux', 4.9390332, 46.4340961, 'https://guide.michelin.com/en/auvergne-rhone-alpes/pont-de-vaux/restaurant/le-raisin', 'https://www.leraisin.com/', '+33 3 85 30 30 97'),
    ('rest_1544', 'Auberge du Pont', 1::smallint, 'Pont-du-Château', '70 avenue du Docteur-Besserve, 63430 Pont-du-Château', 3.2581585, 45.7973696, 'https://guide.michelin.com/en/auvergne-rhone-alpes/pont-du-chteau/restaurant/auberge-du-pont37415', 'https://auberge-du-pont.com/', '+33 4 73 83 00 36'),
    ('rest_1545', 'L''Or Q''idée', 1::smallint, 'Pontoise', '14 rue Marcel-Rousier, 95000 Pontoise', 2.0976083, 49.0501575, 'https://guide.michelin.com/en/ile-de-france/pontoise/restaurant/l-or-q-idee', 'https://www.lorqidee.fr', '+33 1 34 35 47 10'),
    ('rest_1546', 'Avel Vor', 1::smallint, 'Port-Louis', '25 rue de Locmalo, 56290 Port-Louis', -3.3474837, 47.7061536, 'https://guide.michelin.com/en/bretagne/fr-port-louis/restaurant/avel-vor', 'https://www.avelvor.com', '+33 2 97 82 47 59'),
    ('rest_1547', 'Restaurant de la Loire', 1::smallint, 'Pouilly-sous-Charlieu', '30 rue de la Berge, 42720 Pouilly-sous-Charlieu', 4.1007524, 46.1472011, 'https://guide.michelin.com/en/auvergne-rhone-alpes/pouilly-sous-charlieu/restaurant/restaurant-de-la-loire', 'https://www.restaurantdelaloire.fr', '+33 4 77 60 81 36'),
    ('rest_1548', 'Aumì', 1::smallint, 'Puymoyen', '6 chemin des Rochers, 16400 Puymoyen', 0.1816045, 45.6127512, 'https://guide.michelin.com/en/nouvelle-aquitaine/puymoyen/restaurant/aumi', 'https://www.aumirestaurant.com', '+33 5 45 70 76 19'),
    ('rest_1549', 'Ima', 1::smallint, 'Rennes', '20 boulevard de la Tour-d''Auvergne, 35000 Rennes', -1.684632, 48.106684, 'https://guide.michelin.com/en/bretagne/rennes/restaurant/ima', 'https://ima.restaurant/', '+33 2 23 47 82 74'),
    ('rest_1550', 'Racines', 1::smallint, 'Rennes', '4 passage Antoinette-Caillot, 35000 Rennes', -1.6828172, 48.1069922, 'https://guide.michelin.com/en/bretagne/rennes/restaurant/racines542026', 'https://www.racines-restaurant.fr/', '+33 2 99 65 64 21'),
    ('rest_1551', 'La Huchette', 1::smallint, 'Replonges', '1089 route de Bourg, 01750 Replonges', 4.8826914, 46.2987913, 'https://guide.michelin.com/en/auvergne-rhone-alpes/replonges/restaurant/la-huchette', 'https://la-huchette.com', '+33 3 85 31 03 55'),
    ('rest_1552', 'G.a. au Manoir de Rétival', 1::smallint, 'Rives-en-Seine', '2 rue Saint-Clair, 76490 Rives-en-Seine', 0.7348884, 49.5249389, 'https://guide.michelin.com/en/normandie/rives-en-seine_7770403/restaurant/g-a-au-manoir-de-retival', 'https://www.restaurant-ga.fr', '+33 6 50 23 43 63'),
    ('rest_1553', 'Nori', 1::smallint, 'Roscoff', 'Hôtel Le Britanny, 22 boulevard Sainte-Barbe, 29680 Roscoff', -3.9721423, 48.7246203, 'https://guide.michelin.com/en/bretagne/roscoff/restaurant/nori', 'https://www.hotel-brittany.com', NULL),
    ('rest_1554', 'L''Émulsion', 1::smallint, 'Saint-Alban-de-Roche', '57 route de Lyon, lieu-dit La Grive, 38080 Saint-Alban-de-Roche', 5.2312885, 45.598532, 'https://guide.michelin.com/en/auvergne-rhone-alpes/saint-alban-de-roche/restaurant/l-emulsion327218', 'https://www.lemulsion-restaurant.com', '+33 4 74 28 19 12'),
    ('rest_1555', 'Le Pressoir', 1::smallint, 'Saint-Avé', '7 rue de l''Hôpital, 56890 Saint-Avé', -2.7508368, 47.6966578, 'https://guide.michelin.com/en/bretagne/saint-av/restaurant/le-pressoir', 'https://www.le-pressoir.fr', '+33 2 97 60 87 63'),
    ('rest_1556', 'Aux Pesked', 1::smallint, 'Saint-Brieuc', '59 rue du Légué, 22000 Saint-Brieuc', -2.7632962, 48.5221338, 'https://guide.michelin.com/en/bretagne/saint-brieuc/restaurant/aux-pesked', 'https://www.auxpesked.com', '+33 2 96 33 34 65'),
    ('rest_1557', 'Les Trois Soleils de Montal', 1::smallint, 'Saint-Céré', '687 route de Montal, Saint-Jean-Lespinasse, 46400 Saint-Céré', 1.8642524, 44.8626981, 'https://guide.michelin.com/en/occitanie/saint-cr/restaurant/les-trois-soleils-de-montal', 'https://www.3soleils.fr', '+33 5 65 10 16 16'),
    ('rest_1558', 'Les Belles Perdrix de Troplong Mondot', 1::smallint, 'Saint-Émilion', 'Château Troplong Mondot, 33330 Saint-Emilion', -0.1407129, 44.8884848, 'https://guide.michelin.com/en/nouvelle-aquitaine/saint-milion/restaurant/les-belles-perdrix-de-troplong-mondot', 'https://www.troplong-mondot.com/restaurant', '+33 5 57 55 38 28'),
    ('rest_1559', 'L''Étape Dorée', 1::smallint, 'Saint-Genis-Laval', '137 chemin de Moly, 69230 Saint-Genis-Laval', 4.7828957, 45.7168754, 'https://guide.michelin.com/en/auvergne-rhone-alpes/saint-genis-laval_1515236/restaurant/l-etape-doree', 'https://etapedoree.fr', '+33 6 52 69 85 77'),
    ('rest_1560', 'La Table d''Armante', 1::smallint, 'Saint-Gervais-les-Bains', 'L''Armancette, 4088 route de Saint-Nicolas, 74170 Saint-Gervais-les-Bains', 6.7237494, 45.8526405, 'https://guide.michelin.com/en/auvergne-rhone-alpes/saint-gervais-les-bains/restaurant/la-table-d-armante', 'https://almae-collection.com/armancette/restaurants/la-table-darmante/', '+33 4 50 78 66 00'),
    ('rest_1561', 'Intuition', 1::smallint, 'Saint-Lô', '1 rue Alsace-Lorraine, 50000 Saint-Lô', -1.0985834, 49.1144055, 'https://guide.michelin.com/en/normandie/saint-l/restaurant/intuition', 'https://www.restaurant-intuition.fr', '+33 2 33 05 14 91'),
    ('rest_1562', 'La Pomme d''Api', 1::smallint, 'Saint-Pol-de-Léon', '5 rue Saint-Yves, 29250 Saint-Pol-de-Léon', -3.9871351, 48.6842867, 'https://guide.michelin.com/en/bretagne/saint-pol-de-lon/restaurant/la-pomme-d-api', 'https://www.lapommedapi.com', '+33 2 98 69 04 36'),
    ('rest_1563', 'La Table de Tourrel', 1::smallint, 'Saint-Rémy-de-Provence', '5 rue Carnot, 13210 Saint-Rémy-de-Provence', 4.8307716, 43.7891048, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/saint-rmy-de-provence/restaurant/la-table-de-tourrel', 'https://www.detourrel.com/fr/restaurant/', '+33 4 84 35 07 20'),
    ('rest_1564', 'Colette', 1::smallint, 'Saint-Tropez', 'Hôtel Sezz, 151  route des Salins, 83990 Saint-Tropez', 6.6697135, 43.2637243, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/saint-tropez/restaurant/colette-1192024', 'https://www.colettesainttropez.com', '+33 4 94 44 53 11'),
    ('rest_1565', 'Le Cercle Guiraud', 1::smallint, 'Sauternes', '14 rue Principale, 33210 Sauternes', -0.3425195, 44.5330491, 'https://guide.michelin.com/en/nouvelle-aquitaine/sauternes/restaurant/le-cercle-guiraud', 'https://www.lecercleguiraud.com/', '+33 5 56 76 60 87'),
    ('rest_1566', 'Kern', 1::smallint, 'Seytroux', '393 route de la Tassonnière, 74430 Seytroux', 6.6164302, 46.2496878, 'https://guide.michelin.com/en/auvergne-rhone-alpes/seytroux_1515695/restaurant/kern', 'https://restaurant-kern.fr', '+33 4 50 84 70 89'),
    ('rest_1567', 'L''Or Bleu', 1::smallint, 'Théoule-sur-Mer', '6 boulevard de l''Esquillon, 06590 Théoule-sur-Mer', 6.9453085, 43.4853664, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/thoule-sur-mer/restaurant/l-or-bleu', 'https://tiara-miramar-beach-resort.com', NULL),
    ('rest_1568', 'La Table de L''Incomparable', 1::smallint, 'Tresserve', '70 chemin de Belledonne, 73100 Tresserve', 5.8996575, 45.6710414, 'https://guide.michelin.com/en/auvergne-rhone-alpes/tresserve/restaurant/la-table-de-l-incomparable', 'https://hotel-lincomparable.com/', NULL),
    ('rest_1569', 'Manoir de Lan-Kerellec', 1::smallint, 'Trébeurden', '11 allée centrale de Lan-Kerellec, 22560 Trébeurden', -3.5847022, 48.7766651, 'https://guide.michelin.com/en/bretagne/trbeurden/restaurant/manoir-de-lan-kerellec', 'https://lankerellec.com/', NULL),
    ('rest_1570', 'Frédéric Molina à Forêt Ivre', 1::smallint, 'Vailly', '460 route des 3-Becs, 74470 Vailly', 6.5503051, 46.3084678, 'https://guide.michelin.com/en/auvergne-rhone-alpes/vailly/restaurant/frederic-molina-a-foret-ivre', 'https://foretivre.com', '+33 4 50 73 61 83'),
    ('rest_1571', 'Auberge de Clochemerle', 1::smallint, 'Vaux-en-Beaujolais', '173 rue Gabriel-Chevallier, 69460 Vaux-en-Beaujolais', 4.594029, 46.056618, 'https://guide.michelin.com/en/auvergne-rhone-alpes/vaux-en-beaujolais/restaurant/auberge-de-clochemerle', 'https://www.aubergedeclochemerle.fr/', '+33 4 74 03 20 16'),
    ('rest_1572', 'Dan B.', 1::smallint, 'Ventabren', '1 rue Frédéric-Mistral, 13122 Ventabren', 5.29218, 43.53894, 'https://guide.michelin.com/en/provence-alpes-cote-dazur/ventabren/restaurant/dan-b', 'https://www.danb.fr', '+33 4 42 28 79 33'),
    ('rest_1573', 'Le M - Domaine de Montagne', 1::smallint, 'Ventron', '5001 route de Frère-Joseph, 88310 Ventron', 6.8628817, 47.9252929, 'https://guide.michelin.com/en/grand-est/ventron_1536962/restaurant/le-m-domaine-de-montagne', 'https://domainedemontagne.com', '+33 3 29 28 20 01'),
    ('rest_1574', 'La Bòria', 1::smallint, 'Veyras', '105 avenue du Ruissol, 07000 Veyras', 4.5651805, 44.7292683, 'https://guide.michelin.com/en/auvergne-rhone-alpes/veyras/restaurant/la-boria-1200901', 'https://www.la-boria.com', '+33 4 75 66 84 04'),
    ('rest_1575', 'Maison Decoret', 1::smallint, 'Vichy', '15 rue du Parc, 03200 Vichy', 3.4192286, 46.1246273, 'https://guide.michelin.com/en/auvergne-rhone-alpes/vichy/restaurant/maison-decoret', 'https://www.maisondecoret.com', '+33 4 70 97 65 06'),
    ('rest_1576', 'Saisons', 1::smallint, 'Écully', '1A chemin de Calabert, 69130 Écully', 4.76787, 45.77744, 'https://guide.michelin.com/en/auvergne-rhone-alpes/cully/restaurant/saisons4469', 'https://www.saisons-restaurant.fr', '+33 4 26 20 97 57'),
    ('rest_1577', 'Les Fresques - Hôtel Royal', 1::smallint, 'Évian-les-Bains', '960 avenue du Léman, à Neuvecelle, 74500 Évian-les-Bains', 6.59945, 46.3966417, 'https://guide.michelin.com/en/auvergne-rhone-alpes/evian-les-bains/restaurant/les-fresques400460', 'https://hotel-royal.evianresort.com/', '+33 4 50 26 85 00');

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
