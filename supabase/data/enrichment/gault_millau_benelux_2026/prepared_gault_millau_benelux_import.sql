-- Gault&Millau Benelux (NL 2026, BE 2026, LU 2027) — prepared insert. NOT APPLIED.
--
-- Written 2026-10-31. Run only after review and an explicit go-ahead.
-- Generated from gault_millau_benelux_2026_staging.csv (decision = PROPOSE);
-- regenerate rather than hand-edit. Every value was read from the venue's
-- own profile page on gault-millau.nl / gaultmillau.be / gaultmillau.lu on 2026-10-31
-- (score from the page's score block, equal to its schema.org rating;
-- toques counted from the same block, never derived from the score).
-- Keyed on restaurant_code + country_code, never on name. INSERT only:
-- no UPDATE, no DELETE, no restaurant is created. Each section checks the
-- exact row count it expects and aborts the whole transaction if any
-- differs, so a changed production state can't be half-applied.
-- Delete a whole section to leave that tier out.
--
-- Run with: supabase db query --linked --file <absolute path to this file>

begin;

-- Tier A: 144 rows — address (street + number + postcode) AND website or phone agree.
do $$ declare n int; begin
  insert into public.gault_millau_awards
    (restaurant_id, guide_year, score, toque_count, recognition_type, gault_millau_url)
  select r.id, v.yr, v.score, v.toques, 'scored', v.url
    from (values
    ('rest_0857', 'BE', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/agnes-dilbeek-sint-martens-bodegem'),
    ('rest_0845', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/alter-tongeren-borgloon'),
    ('rest_0835', 'BE', 2026::smallint, 18.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/arabelle-meirlaen-marchin'),
    ('rest_0859', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/atelier-noun-leefdaal'),
    ('rest_0880', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/attablez-vous-namur'),
    ('rest_0870', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/au-gre-du-vent-seneffe'),
    ('rest_0887', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/aux-petits-oignons-jodoigne'),
    ('rest_0824', 'BE', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/bar-bulot-zedelgem'),
    ('rest_0860', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/barge-bruxelles'),
    ('rest_0817', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/benoit-bernard-dewitte-kruisem-ouwegem'),
    ('rest_0886', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/bistro-racine-braine-le-chateau'),
    ('rest_0891', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/bistrot-blaise-marche-en-famenne'),
    ('rest_0795', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/bistrot-du-nord-antwerpen'),
    ('rest_0825', 'BE', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/boo-raan-knokke-heist'),
    ('rest_0826', 'BE', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/carcasse-koksijde-sint-idesbald'),
    ('rest_0160', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/castor-waregem-beveren-leie'),
    ('rest_0803', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/centpourcent-sint-katelijne-waver'),
    ('rest_0876', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/chai-gourmand-gembloux'),
    ('rest_0838', 'BE', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/comme-chez-soi-bruxelles'),
    ('rest_1828', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/couvert-couvert-leuven-heverlee'),
    ('rest_0833', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/cuines33-knokke-heist'),
    ('rest_0861', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/da-mimmo-bruxelles-woluwe-saint-lambert'),
    ('rest_1829', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/de-bakermat-ninove'),
    ('rest_0847', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/de-kristalijn-genk'),
    ('rest_0848', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/de-mijlpaal-tongeren-borgloon'),
    ('rest_0804', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/de-pastorie-kasterlee-lichtaart'),
    ('rest_0827', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/de-zuidkant-damme'),
    ('rest_1830', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/eed-leuven'),
    ('rest_1831', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/essenciel-leuven'),
    ('rest_0858', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/est-leuven-heverlee'),
    ('rest_0797', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/fine-fleur-antwerpen'),
    ('rest_0818', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/fleur-de-lin-zele'),
    ('rest_0811', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/goffin-brugge-sint-kruis'),
    ('rest_0828', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/haut-oostende'),
    ('rest_0805', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/hert-turnhout'),
    ('rest_0849', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/hoeve-de-bies-voeren'),
    ('rest_0806', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/hof-ter-hulst-hulshout'),
    ('rest_0812', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/hostellerie-st-nicolas-ieper-elverdinge'),
    ('rest_0863', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/humus-x-hortense-bruxelles-ixelles'),
    ('rest_0851', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/innesto-zonhoven'),
    ('rest_0852', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/jer-hasselt'),
    ('rest_0864', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/kamo-bruxelles-ixelles'),
    ('rest_0809', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/kelderman-aalst'),
    ('rest_0815', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/komaf-wommelgem'),
    ('rest_0807', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/la-belle-geel'),
    ('rest_0853', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/la-botte-genk'),
    ('rest_0879', 'BE', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/la-grange-dhamois-emptinne'),
    ('rest_0888', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/la-grappe-dor-arlon'),
    ('rest_1833', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/la-roseraie-modave'),
    ('rest_0174', 'BE', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/la-table-de-maxime-paliseul'),
    ('rest_0865', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/la-villa-in-the-sky-bruxelles-ixelles'),
    ('rest_0834', 'BE', 2026::smallint, 19.0::numeric, 5::smallint, 'https://www.gaultmillau.be/en/restaurants/lair-du-temps-eghezee-liernu'),
    ('rest_0878', 'BE', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/le-beau-rivage-by-curtis-namur-dave'),
    ('rest_0157', 'BE', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/le-chalet-de-la-foret-bruxelles-uccle'),
    ('rest_0871', 'BE', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/le-coq-aux-champs-tinlot-soheit-tinlot'),
    ('rest_0819', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/le-julien-aalter-lotenhulle'),
    ('rest_0867', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/le-vieux-chateau-flobecq'),
    ('rest_0866', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/les-gourmands-quevy-blaregnies'),
    ('rest_0892', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/les-pieds-dans-le-plat-marenne'),
    ('rest_0881', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/lessentiel-namur-temploux'),
    ('rest_0171', 'BE', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/maison-colette-westerlo'),
    ('rest_0884', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/maison-marit-braine-lalleud'),
    ('rest_0856', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/melchior-tienen'),
    ('rest_1834', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/menssa-bruxelles-woluwe-saint-pierre'),
    ('rest_0799', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/misera-antwerpen'),
    ('rest_0854', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/modest-oudsbergen'),
    ('rest_0823', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/moscou-by-danny-horseele-gent-gentbrugge'),
    ('rest_0800', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/nathan-antwerpen'),
    ('rest_1835', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/nebo-antwerpen'),
    ('rest_0808', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/neon-lier'),
    ('rest_1836', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/oak-gent'),
    ('rest_0855', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/ogst-hasselt'),
    ('rest_1837', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/philippe-fauchet-saint-georges-sur-meuse'),
    ('rest_0885', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/philippe-meyers-braine-lalleud'),
    ('rest_0801', 'BE', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/pont-neuf-antwerpen'),
    ('rest_0877', 'BE', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/pre-de-chez-vous-namur-bouge'),
    ('rest_0820', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/publiek-gent'),
    ('rest_0873', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/quadras-saint-vith'),
    ('rest_0831', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/rebelle-kortrijk-marke'),
    ('rest_0832', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/sans-cravate-brugge'),
    ('rest_0810', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/sense-waasmunster'),
    ('rest_0170', 'BE', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/sir-kwinten-lennik'),
    ('rest_0168', 'BE', 2026::smallint, 18.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/slagmolen-oudsbergen'),
    ('rest_0844', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/subtiel-de-panne'),
    ('rest_0822', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/t-korennaer-sint-niklaas-nieuwkerken-waas'),
    ('rest_1827', 'BE', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/t-stoveke-strombeek-bever'),
    ('rest_0796', 'BE', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/the-butchers-son-antwerpen'),
    ('rest_0837', 'BE', 2026::smallint, 18.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/the-jane-antwerpen'),
    ('rest_0813', 'BE', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/tinelle-mechelen'),
    ('rest_0874', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/toma-liege'),
    ('rest_1839', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/un-max-de-gout-comblain-au-pont'),
    ('rest_0869', 'BE', 2026::smallint, 13.5::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/vicomte-domaine-darondeau-roucourt'),
    ('rest_0816', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/vintage-kontich'),
    ('rest_0850', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/vivendum-dilsen-stokkem'),
    ('rest_0841', 'BE', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/vol-ver-kortrijk-marke'),
    ('rest_0162', 'BE', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/vrijmoed-gent'),
    ('rest_0842', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/willem-hiele-oudenburg'),
    ('rest_0843', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/zetjoe-brugge'),
    ('rest_0875', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/zur-post-saint-vith'),
    ('rest_0292', 'LU', 2027::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.lu/en/restaurants/apdikt-steinfort'),
    ('rest_0294', 'LU', 2027::smallint, 14.5::numeric, 2::smallint, 'https://www.gaultmillau.lu/en/restaurants/archibald-de-prince-echternach'),
    ('rest_0288', 'LU', 2027::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.lu/en/restaurants/fani-roeser'),
    ('rest_0291', 'LU', 2027::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.lu/en/restaurants/la-villa-de-camille-et-julien-luxembourg'),
    ('rest_1368', 'LU', 2027::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.lu/en/restaurants/le-lys-luxembourg'),
    ('rest_0001', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/aan-de-poel-amstelveen'),
    ('rest_0007', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/amarone-rotterdam'),
    ('rest_1396', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/ambrozijn-valkenburg-aan-de-geul'),
    ('rest_0011', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/au-coin-des-bons-enfants-maastricht'),
    ('rest_1397', 'NL', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/azurite-delft'),
    ('rest_0780', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/basiliek-harderwijk'),
    ('rest_0794', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/bij-jef-texel-den-hoorn'),
    ('rest_0019', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/callas-den-haag'),
    ('rest_0021', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/central-park-voorburg'),
    ('rest_0024', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/choux-amsterdam'),
    ('rest_0783', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/daalder-amsterdam'),
    ('rest_0791', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/de-bloemenbeek-de-lutte'),
    ('rest_1399', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/de-cuijt-mierlo'),
    ('rest_0792', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/de-gieser-wildeman-noordeloos'),
    ('rest_0033', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/de-kas-amsterdam'),
    ('rest_0034', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/de-kromme-dissel-heelsum'),
    ('rest_0793', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/de-moerbei-warmond'),
    ('rest_0039', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/de-nederlanden-vreeland-aan-de-vecht'),
    ('rest_0789', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/de-swarte-ruijter-holten'),
    ('rest_0787', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/de-vlindertuin-zuidlaren'),
    ('rest_0046', 'NL', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/francois-geurds-restaurant-rotterdam'),
    ('rest_0051', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/inter-scaldes-kruiningen'),
    ('rest_0153', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/joann-enschede'),
    ('rest_0055', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/karel-5-utrecht'),
    ('rest_0785', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/latour-noordwijk-aan-zee'),
    ('rest_0784', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/merlet-schoorl'),
    ('rest_1401', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/nassau-groningen'),
    ('rest_0073', 'NL', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/novaela-delft'),
    ('rest_0150', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/olde-marckt-aalten'),
    ('rest_0022', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/restaurant-chateau-neercanne-maastricht'),
    ('rest_0788', 'NL', 2026::smallint, 13.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/restobar-de-woage-gramsbergen'),
    ('rest_0093', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/rijks-amsterdam'),
    ('rest_1402', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/rozewied-kortgene'),
    ('rest_0786', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/smink-wolvega'),
    ('rest_1404', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/wild-atelier-hoog-soeren'),
    ('rest_0118', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/wils-amsterdam'),
    ('rest_0119', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/yamazato-amsterdam'),
    ('rest_0121', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/zeezout-rotterdam'),
    ('rest_0152', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/zenith-apeldoorn'),
    ('rest_0782', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/zheng-den-haag')
    ) v(code, cc, yr, score, toques, url)
    join public.restaurants r on r.restaurant_code = v.code and r.country_code = v.cc
   where not exists (select 1 from public.gault_millau_awards g
                      where g.restaurant_id = r.id and g.guide_year = v.yr);
  get diagnostics n = row_count;
  if n <> 144 then raise exception 'tier A: expected 144, got %', n; end if;
end $$;

-- Tier A2: 57 rows — website AND phone agree; catalogue address differs from G&M (logged, not fixed).
do $$ declare n int; begin
  insert into public.gault_millau_awards
    (restaurant_id, guide_year, score, toque_count, recognition_type, gault_millau_url)
  select r.id, v.yr, v.score, v.toques, 'scored', v.url
    from (values
    ('rest_1832', 'BE', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gaultmillau.be/en/restaurants/heliport-brasserie-liege'),
    ('rest_1838', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/sensum-gent-sint-denijs-westrem'),
    ('rest_0084', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/1857-roosendaal'),
    ('rest_0085', 'NL', 2026::smallint, 18.5::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/212-amsterdam'),
    ('rest_0086', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/affect-zwolle'),
    ('rest_0009', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/apicius-bakkum'),
    ('rest_0087', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/atelier-gulpen'),
    ('rest_0012', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/beluga-loves-you-maastricht'),
    ('rest_0013', 'NL', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/bistro-de-la-mer-amsterdam'),
    ('rest_0014', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/bolenius-amsterdam'),
    ('rest_0016', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/bougainville-amsterdam'),
    ('rest_0017', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/brass-boer-thuis-zwolle'),
    ('rest_0088', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/calva-nootdorp'),
    ('rest_0023', 'NL', 2026::smallint, 13.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/cheval-blanc-heemstede'),
    ('rest_0026', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/codium-goes'),
    ('rest_0029', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/da-vinci-maasbracht'),
    ('rest_0089', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/de-burgemeester-linschoten'),
    ('rest_0032', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/de-juwelier-amsterdam'),
    ('rest_0036', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/de-leuf-ubachsberg'),
    ('rest_0050', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/herberg-onder-de-linden-aduard'),
    ('rest_0052', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/joelia-rotterdam'),
    ('rest_0054', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/kaatje-bij-de-sluis-blokzijl'),
    ('rest_0090', 'NL', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/kasteel-heemstede-houten'),
    ('rest_0056', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/la-provence-driebergen-rijsenburg'),
    ('rest_0057', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/lars-amsterdam'),
    ('rest_0064', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/maeve-utrecht'),
    ('rest_0065', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/marrees-weert'),
    ('rest_0066', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/ml-haarlem'),
    ('rest_0068', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/monarh-tilburg'),
    ('rest_0069', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/mos-amsterdam-amsterdam'),
    ('rest_0072', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/noor-groningen'),
    ('rest_0075', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/odille-sint-oedenrode'),
    ('rest_0076', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/one-roermond'),
    ('rest_0074', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/oo-sint-willebrord'),
    ('rest_0081', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/perceel-capelle-ad-ijssel'),
    ('rest_0082', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/pieters-restaurant-bergambacht'),
    ('rest_0083', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/ratatouille-food-wine-haarlem'),
    ('rest_0094', 'NL', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/rijnzicht-doornenburg'),
    ('rest_0096', 'NL', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/sabero-leende'),
    ('rest_0091', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/showw-amsterdam'),
    ('rest_0099', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/sinne-amsterdam'),
    ('rest_0100', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/spetters-breskens'),
    ('rest_0101', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/studio-maastricht'),
    ('rest_0103', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/t-amsterdammertje-loenen-aan-de-vecht'),
    ('rest_0790', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/t-lansink-hengelo'),
    ('rest_0105', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/t-raedthuys-duiven'),
    ('rest_0106', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/tante-koosje-loenen-ad-vecht'),
    ('rest_0107', 'NL', 2026::smallint, 14.0::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/the-millen-rotterdam'),
    ('rest_0108', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/the-white-room-amsterdam'),
    ('rest_0109', 'NL', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/tout-a-fait-maastricht'),
    ('rest_0111', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/triptyque-wateringen'),
    ('rest_0113', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/versaen-ravenstein'),
    ('rest_0117', 'NL', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/wiesen-eindhoven'),
    ('rest_0092', 'NL', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/wolfslaar-breda'),
    ('rest_0120', 'NL', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gault-millau.nl/en/restaurants/zarzo-eindhoven'),
    ('rest_0122', 'NL', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gault-millau.nl/en/restaurants/zoldering-amsterdam'),
    ('rest_0123', 'NL', 2026::smallint, 14.5::numeric, 2::smallint, 'https://www.gault-millau.nl/en/restaurants/zout-citroen-oosterhout')
    ) v(code, cc, yr, score, toques, url)
    join public.restaurants r on r.restaurant_code = v.code and r.country_code = v.cc
   where not exists (select 1 from public.gault_millau_awards g
                      where g.restaurant_id = r.id and g.guide_year = v.yr);
  get diagnostics n = row_count;
  if n <> 57 then raise exception 'tier A2: expected 57, got %', n; end if;
end $$;

-- Tier A3: 9 rows — website or phone agrees AND G&M map pin within 150 m of ours; address text differs (logged, not fixed).
do $$ declare n int; begin
  insert into public.gault_millau_awards
    (restaurant_id, guide_year, score, toque_count, recognition_type, gault_millau_url)
  select r.id, v.yr, v.score, v.toques, 'scored', v.url
    from (values
    ('rest_0821', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/hofke-van-bazel-beveren-kruibeke-zwijndrecht-bazel'),
    ('rest_0893', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/le-gastronome-paliseul'),
    ('rest_0172', 'BE', 2026::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/leau-vive-profondeville-arbre'),
    ('rest_0839', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/sel-gris-knokke-heist'),
    ('rest_0287', 'LU', 2027::smallint, 14.5::numeric, 2::smallint, 'https://www.gaultmillau.lu/en/restaurants/guillou-campagne-schouweiler'),
    ('rest_0286', 'LU', 2027::smallint, 17.5::numeric, 4::smallint, 'https://www.gaultmillau.lu/en/restaurants/louis-linster-frisange'),
    ('rest_0285', 'LU', 2027::smallint, 18.5::numeric, 4::smallint, 'https://www.gaultmillau.lu/en/restaurants/ma-langue-sourit-moutfort'),
    ('rest_0289', 'LU', 2027::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.lu/en/restaurants/mosconi-luxembourg'),
    ('rest_0290', 'LU', 2027::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.lu/en/restaurants/ryodo-luxembourg')
    ) v(code, cc, yr, score, toques, url)
    join public.restaurants r on r.restaurant_code = v.code and r.country_code = v.cc
   where not exists (select 1 from public.gault_millau_awards g
                      where g.restaurant_id = r.id and g.guide_year = v.yr);
  get diagnostics n = row_count;
  if n <> 9 then raise exception 'tier A3: expected 9, got %', n; end if;
end $$;

-- Tier B: 8 rows — address only (catalogue holds no website and no conflicting phone).
do $$ declare n int; begin
  insert into public.gault_millau_awards
    (restaurant_id, guide_year, score, toque_count, recognition_type, gault_millau_url)
  select r.id, v.yr, v.score, v.toques, 'scored', v.url
    from (values
    ('rest_0882', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/arden-rochefort'),
    ('rest_0814', 'BE', 2026::smallint, 15.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/bloesem-antwerpen-borgerhout'),
    ('rest_0862', 'BE', 2026::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.be/en/restaurants/eliane-bruxelles'),
    ('rest_0894', 'BE', 2026::smallint, 16.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/le-cor-de-chasse-durbuy-weris'),
    ('rest_0872', 'BE', 2026::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/le-roannay-stavelot-francorchamps'),
    ('rest_0829', 'BE', 2026::smallint, 16.0::numeric, 3::smallint, 'https://www.gaultmillau.be/en/restaurants/lenvie-zwevegem-sint-denijs'),
    ('rest_0293', 'LU', 2027::smallint, 17.0::numeric, 4::smallint, 'https://www.gaultmillau.lu/en/restaurants/fields-by-rene-mathieu-findel'),
    ('rest_0295', 'LU', 2027::smallint, 15.5::numeric, 3::smallint, 'https://www.gaultmillau.lu/en/restaurants/grunewald-chefs-table-luxembourg')
    ) v(code, cc, yr, score, toques, url)
    join public.restaurants r on r.restaurant_code = v.code and r.country_code = v.cc
   where not exists (select 1 from public.gault_millau_awards g
                      where g.restaurant_id = r.id and g.guide_year = v.yr);
  get diagnostics n = row_count;
  if n <> 8 then raise exception 'tier B: expected 8, got %', n; end if;
end $$;

commit;
-- 218 rows in total.
