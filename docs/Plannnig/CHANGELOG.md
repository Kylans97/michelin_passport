# Changelog

All notable changes to Mantelier will be documented in this file.

The format follows Keep a Changelog.

---

## Unreleased

---

## v1.8.0 (39) — 2026-11-21

Merged into main on 2026-11-21 from `claude/wine-regions` (wine regions rounds 1 to 7, the wine verdicts and wines kept without a visit, the wine-list search fixes), `claude/journey-visuals-2` (train and ship pages, round two) and `claude/relaxed-mirzakhani-0618b5` (stamp text inside its frame). Conflicts in this changelog only; both sides kept. `flutter analyze` clean and `flutter test` 3,075 passing on the merged tree. Order for the wine verdicts, as their migration requires: the privacy policy (`site-next/public/privacy.html`) published first, then `20261101640000_add_wine_verdicts_and_cellar_wines.sql`, then this build. Done that way on 2026-11-21 (product owner: "push main so the updated privacy policy goes live on mantelier.app, then apply the wine verdicts migration to production, run the schema diff, and archive 1.8.0 (39)"): main pushed and the site deploy succeeded, the live `/privacy` names the verdicts; then the migration, whose dry run listed only it: `visit_wines` gains its two columns, `cellar_wines` exists with RLS on and four policies, anon has no select and the REST read is refused (401); ledger 170/170, local and remote in agreement. Schema diff at the bump (`NEW_MACHINE_SETUP.md` §4): all 170 migrations replay cleanly on a fresh scratch stack; the `db dump` diff is the same single quoting line as at 1.7.0 plus blank lines, not drift; buckets, `storage`/`auth` policies, the `auth.users` trigger and storage RLS identical, production again having only the three platform triggers on `storage.buckets`. Archived with `flutter build ipa --release` (the export step fails without a command-line Apple account, as expected) and copied to `~/Library/Developer/Xcode/Archives/2026-11-21/Runner 1.8.0 (39).xcarchive` for upload from the Organizer.

### Added
- **Wine verdicts, and wines kept without a visit** (product owner, 2026-11-21: "Stel je kan bijhouden wat je echt lekker vond zou je later zelf die wijn kunnen bestellen"; plan with mockups at https://claude.ai/artifact/FR6GKmiV91PrSzmJ48XHJb, decisions the same day, then "jaa dat wine verdicts plan mag je bouwen"). Step 1 of three; step 2 links a wine to its estate's shop, step 3 is wine merchants.
  - **A verdict per wine:** Would drink again, It was fine or Not for me, and "A line to remember it by" (up to 280 characters), in the wine sheet on a visit and in the Cellar. All optional. Tapping the chosen verdict again clears it. Shown beside the wine as "Again" in claret, or a quieter "Fine" / "Not for me"; the note in italics under it. Never gold, never a score, never a stamp.
  - **Wines without a visit:** "Add a wine" in the Cellar asks where (At home, At an estate, Somewhere else, with an optional place) and when, then the usual fields. The estate link works as on a visit: picked by the member, never matched by name.
  - **The Cellar:** wines from visits and kept ones together, newest first; one filter at the top, All wines or Would drink again with its count (a filter, not a sort, by decision); every wine opens for editing.
  - **An estate's page:** "You'd drink 2 of their wines again" over the member's wines from that estate, with the count and the last day.
  - **Who sees it:** friends see the verdict and note wherever they see the wine (product owner: "dit mogen vrienden altijd zien inclusief notitie"): on a visit shared with friends, and every wine kept without a visit. A wine on a private visit stays private, or the visit itself would show.
  - **Migration `20261101640000_add_wine_verdicts_and_cellar_wines.sql`, applied 2026-11-21 after the privacy policy went live (see this version's notes).** Adds `visit_wines.verdict` and `tasting_note` (additive; 1.6.0 and 1.7.x select fixed columns and never see them) and a new `cellar_wines` table, not a nullable `visit_wines.visit_id`, since shipped builds cast every visit wine's `visit_id` to a string and would break on a row without one. RLS: the owner writes; the owner and accepted friends read. No function. Checked on a fresh scratch stack with all 169 migrations: the owner and a friend read a kept wine with its note, a stranger reads nothing, a friend updates nothing.
  - **Reads degrade step by step** (verdict and estate, then estate only, then the original columns), and `cellar_wines` is read only when it exists, so this build shows wines against a database without the migration; saving a verdict or a kept wine needs it. **Order:** the privacy policy first (`site-next/public/privacy.html`, the live one, and `site/privacy.html`, the fallback: verdicts and notes, wines kept without a visit, who sees them, and deletion), then the migration, then a build.
  - Tests: `test/wine_verdicts_test.dart` (verdict values, which columns go to which table, setting and day, the row with its verdict and note, the sheet's new parts, the estate line). `flutter analyze` clean, `flutter test` 3,053 passing. Seen in the simulator against production (read only, nothing saved): the Cellar with the filter and Add a wine, and the sheet for a kept wine. Fixed on the way: the taller sheet ran under the status bar; it now stops below it (`useSafeArea`).
- **Wine regions, round 7: more of the New World and Asia** (product owner, 2026-11-21: "oke kan je nog meer ontbrekende wijngebieden toevoegen?"). `supabase/data/enrichment/wine_regions/wine_regions_seed_round7_v1.sql`, generated by `world_batch/build_round7_batch.py`, adds 37 regions (wr_0239 to wr_0275), 34 drawn and 3 points, 9 grapes (gr_0178 to gr_0186: Bonarda, País, Durif, Muscat à Petits Grains Rouges, Colombard, Viognier, Barbera, Delaware, L'Acadie Blanc), 84 wine-list names and synonyms on four existing grapes (Steen for Chenin Blanc, Hanepoot, Carignane, Cabernet Gernischt for Carménère). No migration: every country is already in `countries`.
  - **Drawn:** Chile's Elqui, Limarí, Aconcagua, San Antonio (with Leyda), Maule, Itata and Biobío from the comunas Decreto 464 lists (BCN); Argentina's I.G.s Añelo and General Roca (one departamento each, where 90% and 70% of their provinces' vineyards are, not the whole Patagonian provinces) and San Juan (IGN Argentina); Altos de Pinto Bandeira (Embrapa's DO line, no licence stated); Eden Valley, Mornington Peninsula, Heathcote, Rutherglen, Beechworth, Orange, Mudgee, Great Southern and Canberra District (Wine Australia, CC BY 4.0); Hemel-en-Aarde inside Walker Bay, Durbanville, Tulbagh, Robertson, Cederberg and Breedekloof (SAWIS/VinPro, no licence stated); Santa Lucia Highlands, Anderson Valley, Lodi, Sierra Foothills and Monticello (TTB, CC0); Nova Scotia (StatCan, OGL Canada; its wine law takes the whole province); Yamagata and Osaka (MLIT N03, CC BY 4.0). **Points:** Prince Edward County, Nashik, Yantai.
  - **País** is its own grape (Listán Prieto, Mission, Criolla Chica), not an alias of Listán Negro, which a 2022 DNA study treats as distinct.
  - **Near-miss:** each group's geometry is copied into `outlines/geometry/` under its file name, and round 7's `sa_units.geojson` overwrote the Americas file of the same name; the build then failed on 90 missing units. Restored from git before anything was committed; round 7's files are now `sa7_units`, `au_za7_units` and `na_asia7_units`. The import now refuses to overwrite a geometry file holding other units.
  - Checked on a fresh scratch stack with all 170 migrations: every content file from the first seed loads in order (275 regions, 238 drawn, 186 grapes, 800 names, 990 links); the outlines already in production are unchanged. Then **loaded into production 2026-11-21** (product owner: "Load wine regions round 7 into production, then show them in the simulator"): before 238 regions (204 drawn), 177 grapes (to gr_0177), 716 names (to wa_0716), 836 links; after 275 regions (238 drawn), 186 grapes (to gr_0186), 800 names, 990 links, matching the scratch run; all 238 outlines in production equal `outlines.json`; anon reads Eden Valley and cannot insert a grape (401); ledger unchanged (content only), `20261101640000` still local only on purpose. Seen in the simulator: "Leyda" finding Valle de San Antonio and its Leyda zone, and San Antonio fitted on the globe below Casablanca.
- **Wine regions, round 6: Eastern Europe and the Eastern Mediterranean** (product owner, 2026-11-21: "Start round 6: Eastern Europe and the Eastern Mediterranean (Moravia, Romania, Bulgaria, Serbia, Moldova, Armenia, Israel, Cyprus, Turkey, more of Greece), same method as before"). `supabase/data/enrichment/wine_regions/wine_regions_seed_round6_v1.sql`, generated by `world_batch/build_round6_batch.py`, adds 26 regions (wr_0213 to wr_0238), 12 drawn and 14 points, 31 grapes (gr_0147 to gr_0177), 44 wine-list names and synonyms on eleven existing grapes (among them Rulandské bílé, šedé and modré, Ryzlink rýnský, Burgund Mare, Tămâioasă Românească, Moschoudi); Crete gains Mandilaria, held back in round 5 and now sourced twice.
  - **Drawn:** Morava (vyhláška 254/2010 Sb. as amended in 2025, its katastrální území resolved to obce through ČÚZK RÚIAN), Dealu Mare, Cotnari and Murfatlar (EU single documents, villages checked against INS SIRUTA), Rapsani, Mantinia, Goumenissa, Patras (the union of the four Patras PDOs, named as appellations; they overlap without nesting), Drama, Paros, Monemvasia (Greek technical files, ELSTAT 2021 settlements) and Commandaria (its 14 communities).
  - **Points:** Melnik and Krasochoria Lemesou (every unit only partly in), Sakar, Fruška Gora (a boundary line), Moldova's Codru, Ștefan Vodă and Valul lui Traian (not in eAmbrosia; their national delimitation is a 1:500,000 paper map), Samos (its text is unreadable), Vayots Dzor (no registered GI found), Israel's Galilee, Judean Hills and Negev, Turkey's Thrace and Cappadocia (no wine GI; Avşa, Turkey's one, is a 21 km² island, held).
  - **Israel, by the internationally recognised borders:** nothing is drawn or named beyond the pre-1967 lines. The Golan, the Samarian and Judean Mountains beyond the Green Line and Yatir are held back; each point was checked against OCHA's State of Palestine and Syria boundaries. The Judea and Negev appellation names wait until their registered maps can be seen.
  - Needs migration `20261101630000_add_md_am_il_cy_countries.sql` (Moldova, Armenia, Israel and Cyprus in `countries`; data only, no function).
  - Checked on a fresh scratch stack with all 170 migrations: every content file from the first seed loads in order (238 regions, 204 drawn, 177 grapes, 716 names, 836 links); the outlines already in production are unchanged.
  - **Applied to production 2026-11-21** (product owner: "Apply the MD/AM/IL/CY countries migration and load wine regions round 6 into production, then show them in the simulator"). The dry run listed the countries migration and the unapplied wine verdicts one; the verdicts file was set aside for the push (it waits for the privacy policy) and put back after, so the second dry run and the push listed only `20261101630000`. MD, AM, IL and CY absent before, present after. Before 212 regions (192 drawn), 146 grapes, 672 names, 726 links; after 238 regions (204 drawn), 177 grapes (to gr_0177), 716 names, 836 links, matching the scratch run; all 204 outlines in production equal `outlines.json`; anon reads Commandaria and cannot insert a grape (401). Ledger: 169 applied, local and remote in agreement; `20261101640000` (wine verdicts) local only, on purpose. Seen in the simulator: "Morava" finding Moravia with its grapes, and Moravia on the globe north of Austria's regions.
- **Wine regions, round 1: the classics, Lebanon and Uruguay** (product owner, 2026-11-21: "ja begin daar maar mee"). `supabase/data/enrichment/wine_regions/wine_regions_seed_classics_v1.sql`, generated by `world_batch/build_classics_batch.py`, adds 38 regions in round 1: Germany (Rheingau, Pfalz, Rheinhessen, Nahe, Franken, Baden, Ahr), Italy (Valpolicella, Soave, Prosecco, Alto Adige, Friuli, Etna, Franciacorta, Taurasi), Spain (Priorat, Rías Baixas, Jerez, Penedès, Rueda, Bierzo, Toro), Portugal (Vinho Verde, Dão, Bairrada, Madeira, Setúbal), France (Alsace, Beaujolais, Languedoc, Roussillon, Provence, Jura, Cahors, Savoie), Uruguay (Canelones, Maldonado) and Lebanon (Bekaa Valley, a point: Lebanon has no legally defined wine region). 41 grapes and 163 wine-list names. Grapes are matched across countries: Silvaner carries Sylvaner, Albariño Alvarinho, Carignan Cariñena, Samsó and Mazuelo. Boundaries from the municipalities each official text lists (EU product specifications, INAO commune lists, pliegos, disciplinari), on Eurostat LAU; Uruguay from INE Uruguay's departments. Held back with reasons in each region's notes: Württemberg, Alentejo, Colares, Friuli Colli Orientali (no commune list), Mount Lebanon.
  - **Real overlaps are kept.** The sliver fix now removes an overlap only when it is under 6% of the smaller region. Larger ones are real and stay: the Beaujolais crus are also inside AOC Bourgogne (26%), and the Valpolicella and Soave texts both list Verona and the eastern valleys (57%).
- **Wine regions, round 2: Europe wider** (product owner, 2026-11-21: "kunnen we al met 2: Europa breder?"), in the same seed so its grapes reuse round 1's. 16 regions: Hungary (Tokaj, Villány, Eger, Somló), Slovenia (Goriška Brda, Vipavska dolina: their texts draw a line, so they are approximated by the municipalities it crosses, marked partial), Greece (Santorini, Naoussa, Nemea), Belgium (Hagelandse, Haspengouwse and Heuvellandse wijn, Côtes de Sambre et Meuse), Luxembourg (Moselle Luxembourgeoise), England (Sussex: East and West Sussex from ONS, OGL v3, with Brighton and Hove, which the specification's map includes) and Georgia (Kakheti, its eight municipalities, from OCHA COD-AB / Geostat, CC BY-IGO). 13 more grapes (Furmint, Hárslevelű, Kadarka, Portugieser, Juhfark, Assyrtiko, Xinomavro, Agiorgitiko, Elbling, Saperavi, Rkatsiteli, Mtsvane Kakhuri, Kisi) and 53 more names, among them Kakheti's 20 appellations. Held back: Amyndeon, Badacsony, Štajerska Slovenija, Kent (no designation), Côtes de Grevenmacher and Côtes de Remich (no current official text). Needs the migration `20261101620000_add_ge_country.sql` (Georgia in `countries`; data only, no function).
  - **An overlap across a national border is always a sliver** (the Mosel against the Luxembourg Moselle, Brda against Friuli), whatever its share. The 71 outlines in production are unchanged.
  - Checked on a fresh scratch stack with all 168 migrations: every content file from the first seed loads in order (133 regions, 124 drawn, 104 grapes, 424 names, 465 links). Then **applied to production 2026-11-21**, rounds 1 and 2 together: the dry run listed only `20261101620000_add_ge_country.sql`; Georgia absent before, present after; before 79 regions, 50 grapes (to gr_0050), 208 names (to wa_0208); after 133 regions (124 drawn), 104 grapes, 424 names, 465 links, matching the scratch run; all 124 outlines in production equal `outlines.json`; anon reads Tokaj and cannot insert a grape (401); ledger 168/168. Seen in the simulator (welcome skipped on the product owner's say-so, which marks that account's welcome as seen): the new regions over Europe, Tokaj's page with Furmint and Hárslevelű and its outline against the Slovak border, and Kakheti fitted whole.
- **Wine regions, round 4: more of the Americas, Japan and China, and the European regions held back** (product owner, 2026-11-21: "oke laten we nog meer wijngebieden toevoegen"). `supabase/data/enrichment/wine_regions/wine_regions_seed_round4_v1.sql`, generated by `world_batch/build_round4_batch.py`, adds 26 regions (wr_0134 to wr_0159), 19 drawn and 7 points, 9 grapes (Vidal Blanc, Koshu, Muscat Bailey A, Kerner, Marselan, Kéknyelű, Schioppettino, Picolit, Malvasia de Colares) and 83 wine-list names. No migration: every country was already in `countries`.
  - **Drawn:** United States (Sta. Rita Hills, Santa Maria Valley, Russian River Valley, Columbia Valley, Walla Walla Valley inside it, Santa Cruz Mountains) from TTB's AVA polygons (CC0), checked against 27 CFR part 9; Long Island from the Census Bureau's Nassau and Suffolk outlines, since TTB's polygon runs into the water (7,312 km² against the regulation's ~3,030). Brazil: Vale dos Vinhedos from Embrapa's DO line (its dataset states no licence), Vale do São Francisco from five IBGE municipalities. Mexico: Querétaro, the country's one wine GI (IMPI, DOF 2025), the whole state from INEGI. Japan: the NTA's GIs Yamanashi, Hokkaido and Nagano are whole prefectures, from MLIT N03 2026 (CC BY 4.0); Hokkaido leaves out the islands Russia administers. Europe, earlier held back: Württemberg from the 274 Gemarkungen its specification numbers (LGL Baden-Württemberg, dl-de/by-2-0; Stetten, 761, not in the register, stays out) plus its Bavarian Bodensee Gemeinden; Vulkanland Steiermark per Weingesetz § 21; Badacsony from the amended specification; Amyndeon with its two renamed communities resolved; Friuli Colli Orientali from the new specification's 19 comuni "in tutto o in parte", all partial; Colares from DGT's pre-2013 freguesias.
  - **Points, with no official geometry:** Niagara Peninsula and Okanagan Valley (their official maps are PDFs only), Campanha Gaúcha (Embrapa's layer not obtainable, two districts only partly inside), Valle de Guadalupe (no GI), the Helan Mountain East Foothill (defined by 30 townships and state farms), Alentejo and Štajerska Slovenija (defined by boundary lines).
  - Checked on a fresh scratch stack with all 168 migrations: every content file from the first seed loads in order (159 regions, 143 drawn, 113 grapes, 507 names, 590 links); the 124 outlines already in production are unchanged in `outlines.json`. Then **loaded into production 2026-11-21** (product owner: "Load wine regions round 4 into production, then show them in the simulator"): before 133 regions (124 drawn), 104 grapes, 424 names, 465 links, all 13 countries present; after 159 regions (143 drawn), 113 grapes (to gr_0113), 507 names, 590 links, matching the scratch run; all 143 outlines in production equal `outlines.json`; anon reads Yamanashi and cannot insert a grape (401); ledger unchanged at 168/168 (content only). Seen in the simulator: Alentejo and Badacsony over Europe, Koshu found by the wine-list search, Yamanashi's page and its outline against Nagano's, and Columbia Valley with Walla Walla inside it and the Okanagan point above.
- **Wine regions, round 5: Europe filled in** (product owner, 2026-11-21: "Start round 5: fill Europe (Italy, Spain, the rest of Germany and Austria, Portugal, France's southwest and Corsica, Greece's Crete), same method as before"). `supabase/data/enrichment/wine_regions/wine_regions_seed_round5_v1.sql`, generated by `world_batch/build_round5_batch.py`, adds 53 regions (wr_0160 to wr_0212), 49 drawn and 4 points, 33 grapes (gr_0114 to gr_0146) and 165 wine-list names, and gives eight existing grapes the synonyms the research confirmed (Cannonau for Grenache, Chiavennasca for Nebbiolo, Pinot Bianco, Aragonez, Nielluccio, Malvoisie de Corse, Bouchy, Moschato Aspro). No migration.
  - **Italy (16):** Abruzzo, Verdicchio di Matelica, Primitivo di Manduria, Sardinia (the whole island: Cannonau di Sardegna's text says "regione Sardegna"), Gallura inside it, Marsala, Cerasuolo di Vittoria, Trentodoc, Lugana, Lambrusco di Sorbara and Grasparossa, Montefalco, Fiano di Avellino, Greco di Tufo, from the MASAF disciplinari; Castelli di Jesi and Valtellina are points (boundary lines only). **Spain (15):** Valdeorras, Ribeiro, Monterrei, Getariako and Bizkaiko Txakolina (whole provinces, as their texts say), Navarra, Cigales, Somontano, Calatayud, Campo de Borja, Jumilla, Montsant, Cava (157 municipios in ten provinces, drawn as the scatter it is) and the Canary Islands, from the pliegos; Ribeira Sacra a point (its parishes make 19 of 20 municipios partial). **Germany (4):** Mittelrhein, Saale-Unstrut, Sachsen, Hessische Bergstraße, so all 13 Anbaugebiete are in; Gemarkungen resolved to their Gemeinden through each Land's ALKIS register. **Austria (8):** Wien, Carnuntum, Thermenregion, Traisental, Weststeiermark, Rosalia, Mittelburgenland, Eisenberg, per Weingesetz § 21 and the DAC Verordnungen. **Portugal (3):** Lisboa (the IG; its DOs need pre-2013 freguesia parts), Tejo, and Açores as a point (land below 100 m). **France (6):** Jurançon, Madiran, Bergerac, Gaillac, Irouléguy and Corsica, from INAO's commune lists. **Greece:** Crete, from its seven PDO specifications.
  - **Baden gains Malsch** (Gemarkung 3260 resolved through LGL Baden-Württemberg's register to DE_08226046, Rhein-Neckar-Kreis; held back since round 1). Baden is the only existing outline that changes.
  - Held back with reasons in each region's notes, among them Zierfandler, Rotgipfler and Neuburger (no second readable source), Mandilaria and Kotsifali, the Lisboa DOs as their own outlines, and a handful of single places whose name and register disagree (Breitscheid, Graitschen, Glashütte, Sansoaín).
  - Checked on a fresh scratch stack with all 168 migrations: every content file from the first seed loads in order (212 regions, 192 drawn, 146 grapes, 672 names, 726 links). Then **loaded into production 2026-11-21** (product owner: "Load wine regions round 5 into production, then show them in the simulator"): before 159 regions (143 drawn), 113 grapes (to gr_0113), 507 names (to wa_0507), 590 links; after 212 regions (192 drawn), 146 grapes (to gr_0146), 672 names, 726 links, matching the scratch run; all 192 outlines in production equal `outlines.json`, Baden's with Malsch; Grenache reads `{Garnacha,Cannonau}`; anon reads Sardinia and cannot insert a name (401); ledger unchanged at 168/168 (content only). Seen in the simulator: the new regions over Europe (Sachsen, Sardinia, Corsica, Jumilla, Cerasuolo di Vittoria, the Castelli di Jesi point), "Cannonau" finding Sardinia and Cannonau di Sardegna, and Sardinia fitted whole with Gallura inside it and Corsica above.

### Fixed
- **The wine-list search no longer autocorrects wine names** (seen in the simulator, 2026-11-21: tapping a result turned "Kakheti" into "Katherine", which matched nothing). `CsSearchField` takes `autocorrect` (default true, so other searches are unchanged); the wine-list search turns it and suggestions off.
- **A region found by search is always fitted on the globe.** Flying to a region never zoomed out, so Kakheti, reached from a close-up of Tokaj, opened zoomed in past its own edges. A tapped region still stays as close as it was; one found by search now fits.

### Changed
- **Everyone sees the welcome flow once more** (product owner, 2026-11-21, after 1.6.0 went live in the App Store: "reset alles maar nu"). `profiles.has_seen_welcome` set back to false for all 23 profiles that had it (28 profiles; 0 seen afterwards), so members opening 1.7.x see the new six-page welcome. Accepted trade-off, named to the product owner beforehand: members still on 1.6.0 from the App Store see the old welcome again once, since that build reads the same flag. Data only, no migration.
- **The signed-in pages in the Keynote style** (product owner, 2026-11-21: "ik wil achter de login ook aanpakken, dat is nu heel matig"; after the designs, "je mag het bouwen"; after the preview, "Ja, zet de pagina's achter de login en de venues-tekst live op mantelier.app"). Branch `claude/site-visuals-20cbbb`, **merged into `main` on 2026-11-21**.
  - **Account home** (`/account`): a welcome with the member's Passport beside it (entries, countries and stars, read as the Passport page reads them), the next three evenings they are Going to or Interested in, and a tile for each section, with the unread count on Notifications.
  - **Sign in:** the form on an ivory card beside "Your Passport, on the web."; the steps, the two-step code and every message are unchanged.
  - **Lists** (wishlist, your events, following, friends, notifications, the globe's places, a friend's page, a visit): white rounded cards in a grid, group headings in light Spectral, tabs as one segmented control. Notifications stay one column, newest first. Wishlist, events and friends pages gain a one-line intro.
- **"Venues", not "kitchens"** (product owner, 2026-11-21: "Ik zie veel 'the kitchens you follow' maar dan gaat het over hotels, restaurants en events ... Dit gaat vaker mis, kan je dat overal veranderen?"): the home page, the features list on `/app` and the journey page say "Follow the venues you love"; the journey's first stop says "Lotte follows Ciel Bleu". A literal kitchen stays a kitchen ("a collaboration with another kitchen" for hosts, "who runs the kitchen" in the app). The app had no "kitchens you follow" copy.
- **The website in direction B, "Keynote"** (product owner, 2026-11-21: "Mantelier x Art gallery x Apple design"; from four concepts on the design canvas, "Werk richting B (Keynote) verder uit", then "Ja, bouw richting B in site-next/ op een eigen branch, eerst als preview op next.mantelier.pages.dev, nog niet naar main"; after the preview, "Ja dit is top, zet maar live"). Branch `claude/site-visuals-20cbbb`, **merged into `main` on 2026-11-21**, which publishes it to mantelier.app.
  - **Type:** the app's own fonts, Spectral and Hanken Grotesk, replace Cormorant Garamond and IBM Plex across `site-next/src`. Large headlines are Spectral Light. The static pages in `public/` (Privacy, Terms, Journey, the guides for hosts) keep their own styling for now.
  - **Navigation:** a slim glass bar that stays at the top while scrolling. The footer is the deepest green.
  - **Home:** a centred hero with three app screenshots from the lookbook (demo content), a sideways row of the next eight events as cards, a Passport story where the phone holds still while three steps scroll by, one restaurant across every guide (same rule as before), a claret wine section with a drawn globe, tiles for the wishlist, friends and the latest interview, the latest stories, and a closing call to the App Store.
  - **Events:** a centred hero, then a featured festival, chosen by rule (the next one not cancelled that hasn't begun, else one already running) and shown in type only, since we hold no photo of the event itself; event rows carry their type as a label. Unknown clock times stay unshown, as before.
  - **Section headers** on every other page are larger and lighter. `AppCta` gains a large size.
  - Copy without dashes: "four hands dinners" on the events page.
  - **Headlines rewritten after the preview** (product owner: "Shared, if you choose en die A wishlist, by place. Dat klinkt gek, de zinnen daaronder zijn prima"): clipped headlines with a comma read oddly, so they are plain sentences now, the text under them unchanged. Home: "Dinners that happen only once.", "Follow the kitchens you love.", "Plan it together.", "Keep every evening.", "See what every guide says.", "Know what is in your glass.", "Also in the app.", "Save places for later.", "Share only what you want."; the interview tile shows the story's opening lines instead of its date; the events page closes with "Going? Tell your friends.". The same titles in `src/lib/app-features.ts` (shown on `/app`) changed with them.
- **The new site becomes mantelier.app, with the app's features up to 1.7** (product owner, 2026-11-21: "Kan je in een aparte sessie de website updaten?"; then "We kunnen ook de nieuwe website pakken, daar wel gewoon alles al opzetten tot 1.7"; then "Ja, bouw het zo, inclusief automatisch publiceren naar mantelier.app elke drie uur"). The old `site/` still said the app was coming, asked for a waiting list and listed events that had passed, while Mantelier 1.6.0 has been on the App Store since 2026-11-20 (id6806217056). Branch `claude/website-update-790380`; **not merged and not live**: merging it into `main` is what publishes it.
  - **Launch switches** (`site-next/src/config.ts`): `HIDDEN = false`, so pages carry a canonical link instead of noindex; `public/_headers` no longer sends `X-Robots-Tag: noindex` and `robots.txt` allows everything; `APP_STORE_URL` is the store link without a country, so every "Get the app" and "in the app" call to action now links to the App Store.
  - **The static pages moved into `site-next/public/`** as they were: Privacy, Terms, Support, Hosts, Journey, the venue guide and the lookbook with their screenshots, `auth/` (the confirm and reset links the app sends), `.well-known/apple-app-site-association` (still served as JSON), `brand/`, `_redirects` (`/auth/confirmed`) and the share image. The footer links are relative now, with The app and The journey added.
  - **New page `/app`** and an **"In the app" band on the home page**: events, every guide in one place (with private chefs, trains, ships and the 50 Best Vineyards), wine regions on the globe, the wishlist by place with the planned month and the booking reminder, the Passport with journeys and estate visits, friends. One list in `src/lib/app-features.ts`, every line checked against this changelog; no counts.
  - **/journey** has the App Store button where its waiting-list form was. The venue guide's "Download Mantelier" links to the store.
  - **No dashes in the site's own copy** (product owner: they read as machine written): event dates read "19 to 22 Nov 2026" and times "19:00 to 23:00"; an empty guide score is a middle dot; page titles use "|"; the em dashes in Privacy, Terms, Support and the auth pages are rewritten as full stops, colons or brackets. Dashes inside venue names and venue-written event text are data and stay.
  - **Privacy, updated 21 November 2026**, for what the app already records and did not say: trains and ships you travelled on (since 1.6.0), wine estates you visited (1.7.0), the month you'd like to go to a wishlisted restaurant (owner only) and the booking reminder push; friends' visibility and account deletion name journeys and estate visits (both tables cascade from `profiles`); the waiting list is described in the past tense; Google Fonts is named for the website and app versions before 1.6.1, since the app bundles its fonts since then.
  - **Published automatically** (`.github/workflows/site-next.yml`): from `main` every three hours and on each push to `site-next/`, to the Pages production branch, which is mantelier.app; from any other branch still to the `next` preview. The "already deployed" cache key now includes the target, so an output sent to the preview is never mistaken for one already live.
  - `site/` stays in the repository as a fallback only; deploying it by hand would replace the new site until the next scheduled run.

### Fixed
- **A stamp's text ran out of its frame on the welcome flow's Passport page** (product owner, 2026-11-21, page 5 of the welcome flow). The third sample stamp, the double frame printing "Four hands" in Copenhagen with a dinner, put "COPENHAGEN · DK" on the top border and the date on the bottom one. Cause: a name of 10 characters or fewer gets the largest size (30pt on the double frame); "FOUR HANDS" is too wide for one line at that size, so it was balanced onto 2 lines, and the stack (city, 2 name lines, award, rule, date and the gaps) came out taller than the frame. `fitStampNameBalanced` capped every width and nothing capped the height. It now takes an optional `maxHeight` and steps down through the smaller sizes until the name fits it too; `DoubleFramePainter` and `OvalPainter` pass the height their border has left once every other line is in. The oval had the same fault with any short name that wraps; the welcome's own oval ("Stay") never did. Both are real Passport designs, so this also fixes members' own stamps with such names (a single long word like "Plénitude" overran the double frame the same way). Names that already fitted are drawn exactly as before.
  - **Near miss, why no test caught it:** the welcome flow tests at 320×640 to 440×956 look for Flutter overflow errors, and a `CustomPainter` drawing past its own shape never raises one; nor does phone size change anything, since every stamp is drawn at its fixed design size and scaled whole by a `FittedBox`. The painter tests only asserted that painting doesn't throw. New `test/passport_stamp_frame_fit_test.dart` renders the double frame and the oval with the welcome sample and five harder names and checks the band between each stamp's two borders holds no ink; on the old painters 4 of its 12 cases fail.
  - **Not fixed:** the lozenge design overruns its band the same way with a short name that wraps. It is not on the welcome page and is laid out differently; left for its own change.
  - **Checked:** `flutter analyze` clean on the changed files; the stamp, Passport and welcome flow tests pass (224); page 5 seen in the iOS simulator on the iPhone 17e with all three stamps inside their borders.
- **The lozenge stamp's date ran over its banderole** (the lozenge left open by the entry above). A short name that wraps, such as "MMMMM WWWW" with three stars in Copenhagen, was set on 2 lines at the largest size (19pt), and the name and date together stood taller than the banderole's inner rule: the date sat on the lower rule. Same cause as the double frame: the name's width was capped, its height was not. `LozengePainter` now passes `fitStampNameBalanced` the height the inner rule leaves once the date and the gap are in (3pt clear above and below), so such a name steps down to one line at a smaller size. Names that already fitted are drawn exactly as before: rendered before and after, the welcome sample, a middle length name, a long name and two single words come out byte for byte identical; only the two wrapping cases changed.
  - **Test:** `test/passport_stamp_frame_fit_test.dart` now checks the strip between the banderole's two rules on the lozenge too, with the same six names. On the old painter 2 of the 6 fail (the wrapping name with and without an award); all 18 pass now.
  - **Not fixed:** the city in the lozenge's upper point truncates ("COPENHA…", "HONG KO…") with any name, because the point is narrow where the city sits. It does not depend on the name and changes how every long city reads, so it is left for its own change.
  - **Checked:** `flutter analyze` clean on the changed files; the stamp, Passport and welcome flow tests pass (220).
- **Canonical links pointed at `.html` addresses** (`https://mantelier.app/app.html`, `/index.html`), which Pages redirects. Harmless while the site was hidden (it had noindex instead), wrong the moment it is indexed. `Base.astro` now drops `.html` and a trailing `index`. Near miss: it only showed because launching turned the canonical on.

### Checked
- Signed-in pages: `npm run build` passes. Sign in looked at in a local preview at 1440 wide and 375 pt with no horizontal scroll. The account home and wishlist were looked at with their scripts removed and sample content filled in by hand, since signing in to production is not something I may do: layout only. **Not checked:** any signed-in page with a real session, and the account home's data calls (they reuse the Passport, events and notification helpers the other pages already use).
- `npm run build` builds 3,766 pages from production. In a local preview at 1440 wide and at 375 pt: home and events show every section, no horizontal scroll, no console errors; the card row starts inside the page margin; the featured festival is Weinberg Arlberg (3 to 13 Dec). Guides looked at as a sample of the other section pages. **Not checked:** every other page one by one, the signed-in account pages, and the preview deploy itself (it runs on push).
- `npm run build` in `site-next/` builds 3,766 pages from production. Every root-relative link and image in `dist/` resolves to a file. In a local preview at 375 pt and desktop: home, `/app`, `/journey`, Privacy, the venue guide (12 images) and the lookbook (17 images) load with no horizontal scroll and no broken image; the journey script passes a syntax check after the form was removed. The workflow file parses as YAML; it has not run, since it only runs once it is on `main` or on push.
- **Not checked:** the workflow's first production deploy, and the live site; both happen on merge.

### Changed
- **Train and ship pages, round two** (product owner, 2026-11-21: "kan je met een paar visualisaties komen om deze pagina's van ships en trains nog mooier te maken? Die onboard cabins met die vierkantjes en rondjes doen ook niet zoveel voor mij"; on the canvas https://claude.ai/artifact/1CJcQx1zLaMjXSxMyPCAH5: "Bouw A (reisroute), B1 (manifest in plaats van de vierkantjes), C (de tafel aan boord) en D (de stempel). E laten we weg."). All from data the journeys already have; no schema or data change.
  - **The itinerary:** under the globe, the selected route stop by stop as a vertical rail (`JourneyItinerary`): Depart, every stop the operator names, Arrive or Return. Where a route crosses a border, a stop carries its country (from `countries`, one lookup, only when a route spans more than one). A journey with one drawn route no longer repeats it in a Routes list.
  - **The cabin manifest replaces the squares and portholes** (`JourneyCabinManifest`, `JourneyCabins` removed): when the cabins text names its types with counts, a menu card with dotted leaders and the total; any other cabins text stays the operator's sentence.
  - **The table aboard** (`JourneyDining`, was "Dining"): the dining text as an italic pull quote between two brass rules, and the dining partners as a short list with city and their own MICHELIN stars (gold, as everywhere a star is drawn), each opening the restaurant. `getDiningPartners` now reads name, city and stars from `restaurants_full`.
  - **The stamp you travel for** (`JourneyPassportStamps`): after a confirmed travel, the Passport's own stamp for it (same design, ink and tilt, all derived from the travel id); before, an uninked dashed outline with the journey's name and "Not yet in your Passport.", never a drawn stamp, since a real one carries a date there is none of yet.
  - A travel spanning two days now reads "19 Nov 2026 to 21 Nov 2026" instead of using a dash.
  Tests: `test/journey_visuals_test.dart` (manifest, itinerary borders and round trip, the table aboard, the uninked stamp). Checked in the simulator on the Andean Explorer (itinerary, inked stamp), the Royal Scotsman (round trip, three partner restaurants, uninked stamp) and the Venice Simplon-Orient-Express (border labels, manifest).

### Fixed
- **Manifest counts not flush right**, caught in the simulator before commit: the cabin name and the dotted leader were both flexible and split the line in half, so a long name ("L'Observatoire Suite") wrapped and every count sat at a different place. The name now takes its own width up to most of the line and the leader fills the rest.

---

## v1.7.1 (38) — 2026-11-20

Merged into main on 2026-11-20 from `claude/wine-regions` (the wine regions of South Africa, Australia, New Zealand, Croatia, Switzerland and Austria; neighbouring regions meeting edge to edge) and `claude/journey-visuals-f7b7ec` (visuals on the train and ship pages: figures, the route globe, cabins). One conflict, in this changelog only: both added entries under Unreleased; both kept. All database changes this build reads were applied to production before the build. `flutter analyze` clean and `flutter test` 3,038 passing on the merged tree. Schema diff at the bump (2026-11-20, per `NEW_MACHINE_SETUP.md` §4): all 167 migrations replay cleanly on a fresh scratch stack; ledger 167/167. The `db dump` diff is the same single quoting line as at 1.7.0, not drift; buckets, `storage`/`auth` policies, the `auth.users` trigger and storage RLS hash identical, production again having only the three platform triggers on `storage.buckets`.

### Added
- **Wine regions of South Africa, Australia, New Zealand, Croatia, Switzerland and Austria** (product owner, 2026-11-20: "can you add the wine regions of South-Africa, Australia and New zeeland?", then "Austra, Swiss and Croatia", and "let's try to draw the borders as good as possible"). `supabase/data/enrichment/wine_regions/wine_regions_seed_world_v1.sql`, generated by `world_batch/build_world_batch.py`, adds 43 regions, all drawn, 19 grapes (among them Pinotage, Semillon, Grüner Veltliner, Blaufränkisch, Zweigelt, Chasselas, Petite Arvine, Malvazija Istarska, Plavac Mali, Graševina) and 165 wine-list names (DAC levels and Ortsweine, Swiss Grand Crus, Dingač, Australian subregions, New Zealand GIs within a region). Grapes are matched to the catalogue by name and alias, never added twice: Welschriesling becomes an alias of Graševina, Austria's Blaufränkisch merges with Croatia's.
  - **Boundaries:** Australia from Wine Australia's own GI polygons (CC BY 4.0). New Zealand from Stats NZ territorial authorities and meshblocks (CC BY 4.0), exact for Central Otago, Hawke's Bay, Wairarapa and Gisborne, and approximating the registered GI for Marlborough (0.4% off), Nelson (0.5%) and North Canterbury (1.5%); IPONZ's registered polygons are not licensed for publication and were used only to measure the difference. Croatia (Pravilnik o vinogradarstvu NN 81/2022, Annex I), Switzerland (cantonal AOC rules) and Austria (Weingesetz 2009 § 21 and the DAC Verordnungen) from the municipalities their texts list, on Eurostat LAU. Graubünden is drawn as its official wine region, the Bündner Rheintal, not the whole canton its AOC covers. South Africa from the SAWIS/VinPro Wine of Origin layer, which matches the official list of districts and wards exactly but states **no licence**: permission from SAWIS/VinPro is still to be asked.
  - **Style:** only claims two independent sources support; every source in each country's `style.json`. Few regions got red-wine scales or pairings, since few had two agreeing sources.
  - Checked on a fresh scratch stack: every content file from the first seed to this one loads in order (79 regions, 71 drawn, 50 grapes, 208 names, 291 links), and renders on the real globe for the Alps and Croatia, New Zealand and the Cape. Then **loaded into production 2026-11-20**: before, 36 regions, 31 grapes (to gr_0031), 43 names (to wa_0043), nothing for the six countries; after, 79 regions (71 drawn; all 43 new ones drawn), 50 grapes, 208 names, 291 links; anon reads Wachau and cannot insert a name (401); ledger unchanged at 166/166 (content only). Seen in the simulator: the new regions over Europe, and "Stellenbosch" flying to the Cape with its neighbours drawn. Known detail: neighbouring regions are smoothed separately, so thin slivers show where shared borders overlap at close zoom (Paarl, Stellenbosch, Franschhoek).

### Fixed
- **Slivers between neighbouring wine regions** (product owner, 2026-11-20: "Fix the slivers where neighbouring wine regions overlap at close zoom"). Each region was simplified on its own, so neighbours overlapped along shared borders in thin bands (33 pairs, up to 62 km², e.g. Marlborough and North Canterbury, Paarl and Stellenbosch) that painted darker at close zoom. `scripts/build_wine_region_outlines.py` now removes each overlap from the later region, so neighbours meet edge to edge; a region more than half inside another (Vijlen in Mergelland, Valle de Uco in Mendoza, Lavaux in Vaud) is nesting and stays. What remains is under 1 km² per pair, from rounding coordinates to ~100 m. **Applied to production 2026-11-20**: all 71 outlines rewritten; production then matched `outlines.json` coordinate for coordinate, and its largest non-nested overlap was 0.77 km². Seen in the simulator: Paarl, Stellenbosch and Franschhoek meet along single lines.
- **Each outline's stored source named Eurostat LAU even where the boundary came from elsewhere.** `outline_source` now names the dataset the region's units actually come from: TTB, the US Census Bureau, Wine Australia, Stats NZ, IGN Argentina, BCN Chile, SAWIS/VinPro, PDOK, or Eurostat LAU. Near-miss: the note was written once for the European case and never revisited when other datasets joined.
- **Train and ship pages made visual** (product owner, 2026-11-20, looking at the Belmond Andean Explorer page: "can you do some visualisations ... for the train and ship page"; on the mockups, https://claude.ai/artifact/5zs3EfaBjditJgs62dzuR1: "if we do the route visualization then we do need to have the route, not just show a line"; then "build ... figures, globe with the real routes drawn, cabins. Routes without stops stay as text"). Three additions to `JourneyDetailScreen`, each drawn only from what the journey states:
  - **Figures:** a quiet row of serif numbers under the summary (routes, nights of a single route, cabins or suites, guests, countries), at most three, and none when fewer than two are known.
  - **Where it runs / sails:** the app's own globe (`GlobePainter`, the bundled Natural Earth outlines) in a static panel, the journey's countries lit. Where the route's stops are on record (`journey_route_stops`, now read by `JourneyRepository.getRouteStops`, one query per page), the route is drawn stop to stop along great circles, its start and end named, other routes faint behind it. Tapping a route in the list shows it on the globe and scrolls the globe back into view. Without stops the globe frames the countries: an archipelago whole, a country without its overseas territories. Routes without stops stay as text, with no marker.
  - **On board:** one window per cabin on a train, one porthole per cabin on a ship, grouped by cabin type where the text names them, only when the cabins text states its numbers (`parseCabins`); a text without numbers stays text.
  Tests: `test/journey_visuals_test.dart` (parsing every cabins text in production, the figures rules, drawable routes, globe framing, the route path, the cabin marks). Checked in the simulator on the Andean Explorer, the Orient Express (8 routes, tapping between them), the Royal Scotsman (drawn and text-only routes side by side) and Amandira (a ship with no routes).
- **Route stops for trains and ships, loaded into production 2026-11-20** (product owner, looking at the journey page mockups: "if we do the route visualization then we do need to have the route, not just show a line"; then "Yes, apply the countries prerequisite and the route stops to production"). 132 ordered stops with coordinates on 25 of the 38 routes, in the existing `journey_route_stops` table (public read was already in place; no schema change). Stops come only from each operator's own itinerary, coordinates from the named station or, where the operator names none, the town; every row's source URL, coordinate source and note is in `supabase/data/enrichment/journeys/journey_route_stops_20261120.csv`, loaded by `journey_route_stops_seed_20261120.sql`, which matches on `route_code` and refuses to run if a code does not resolve or a route already has stops. The app does not read the stops yet; drawing them on the journey page is the next step.
- **Migration `20261101610000_add_ro_bg_ba_countries.sql`, applied to production 2026-11-20.** Adds Romania, Bulgaria and Bosnia and Herzegovina to `countries`, which stops in Bucharest, Sinaia, Brașov, Sofia, Plovdiv, Sarajevo and Mostar need. No function created. Dry run listed only this migration; ledger 167/167 afterwards; the three rows read back.

- **Near-misses held back, not drawn** (`supabase/data/enrichment/journeys/journey_route_stops_HELD_BACK.md`). 13 routes have no stops because the operator's own pages disagree with each other or with our route row: the Orient Express Portofino and Amalfi Coast trains end at Santa Margherita Ligure and Pompeii; four Royal Scotsman and three Britannic Explorer routes have maps and day texts naming different stations; Tiger Express never names where the train ends; Napoléon's pages skip and repeat days. The Corinthian's Marseille to Rome route matches no voyage on sale (the only one sailed in July 2026), so that route row itself looks stale; logged, not changed. The stops file was first written against a `countries` table that lacked RO, BG and BA, which the scratch run caught as a foreign key failure before anything reached production.
- **Lines between stops are straight.** The stops are real, the track geometry is not stored, so a two-stop route (most Venice Simplon-Orient-Express routes, Mizukaze) can only ever draw as one arc.

---

## v1.7.0 (37) — 2026-11-20

Merged into main on 2026-11-20 from `claude/wine-regions` (the wine-regions globe, its outlines and content, the 1,000x zoom, the vineyard staging file) and `claude/welcome-flow-c0a99f` (the new first-launch welcome flow). One conflict, in this changelog only: both branches added entries under Unreleased; both kept. The database changes this build reads (`20261101580000`, `20261101590000`, `20261101600000` and the wine content) were applied to production before the build. `flutter analyze` clean and `flutter test` 3,020 passing on the merged tree. Schema diff at the bump (2026-11-20, per `NEW_MACHINE_SETUP.md` §4): all 166 migrations replay cleanly on a fresh scratch stack; ledger 166/166. The `db dump` diff is the same single line as at 1.6.1, `EXTRACT(day …)` against `EXTRACT("day" …)` in `wishlist_planned_month_check`, a pg_dump quoting difference, not drift. Buckets, `storage`/`auth` policies, the `auth.users` trigger and storage RLS hash identical; production again has only the three platform triggers on `storage.buckets` from the newer hosted storage service.

### Added
- **Wine regions on the globe** (product owner, 2026-11-20: "a wine variant of the globe... tap a region and see what grapes grow there and what taste that gives"; on the canvas https://claude.ai/artifact/DHKUpxQhmfhfu5bhAz61vp: "just build it and fine-tune"). My Map gets a "My places | Wine regions" toggle. It shows only on your own map, and only once published regions exist.
  - **Globe:** in wine mode it turns to Europe and draws each region as a soft claret patch around a point, with its name when zoomed in, never as a border. A ring marks regions you have logged a wine from (through the estate the wine is linked to; free-text producers are never matched by name).
  - **Region sheet:** tapping a region opens what it is, its grapes and what they become there, a red from here on a 1–5 body/acidity/tannin scale, what it goes with, the names a wine list uses for it, how its labels rank quality, and how many of your wines come from it.
  - **Grape page:** what you taste, how it feels, where it grows and what that changes, and "Like this? Try ...".
  - **Wine-list search:** "On the wine list? Search a region or grape" matches regions, list names (Meursault, Barolo) and grapes, including aliases such as Bourgogne and Spätburgunder, on stored names only.
  - Where else to reach this (Cellar, Explore) is left for later, by decision.
- **Migration `20261101580000_add_wine_regions.sql`, applied to production 2026-11-20.** Adds `wine_regions`, `grapes`, `wine_region_grapes` and `wine_appellations` as editorial reference content: RLS, world-readable once `publication_status = 'published'`, no client write, select-only grants. Also adds a nullable `vineyards.wine_region_id`. No function is created. Replayed with all earlier migrations on a scratch stack: it applies cleanly, and anon can read the tables but not write them. On production: the dry run listed only this migration, the four tables were empty before content was loaded, and the ledger reads 164/164 afterwards. Anon can read and cannot insert, an authenticated user cannot update, and RLS is on for all four tables (four policies).
- **First content, draft, loaded into production 2026-11-20** (product owner: "I'll fine-tune the texts in the app"): `supabase/data/enrichment/wine_regions/wine_regions_seed_v1.sql`, with 11 regions, 17 grapes, 23 region–grape links and 33 wine-list names. It is our own editorial text from general wine knowledge, with approximate region centres. Every row needs checking against a reference and a `source_url` before publishing. Loaded cleanly on the scratch stack after one fix (`similar` is a reserved word); production counts match (11/17/23/33, 6 similar-grape links). There is no in-app editor for these texts yet: changes go through SQL or the dashboard.
- **Wine regions drawn as their real shape** (product owner, 2026-11-20: "Can we draw the wine regions instead of having these red dots? ... more zoom on the globe too"; then "Build the outlines from each region's official list of communes, merged and simplified, with the source stored per region"). Each region is the union of the municipalities in its official specification (INAO for France; the MAPA pliegos for Rioja and Ribera del Duero; the EU technical file for the Douro; the Rhineland-Palatinate specification for the Mosel; the MASAF disciplinari for Piedmont and Tuscany), on Eurostat GISCO LAU 2024 boundaries, simplified to about 1 km by `scripts/build_wine_region_outlines.py`. Nothing traced by hand. 3,374 municipalities across the eleven regions, 25 KB of outlines in all. Sources, counts and every judgement call: `supabase/data/enrichment/wine_regions/outlines/README.md` and the per-region notes.
  - A municipality only partly in a zone is drawn whole and marked partial. One that a specification includes only as an enclave, a single village or a few named estates is left out (Miranda de Ebro, Burgo de Osma, four Douro freguesias). Two Piedmont names that match no comune are held back, not guessed.
  - **Globe:** a region with an outline is drawn as its claret shape with a fine edge once it is 8 px across, as the patch below that. Its name sits on its point. Taps hit the shape. Tapping a region, or choosing one in the wine-list search, flies in until the whole region fills the view (up to 40×).
  - **Migration `20261101590000_add_wine_region_outlines.sql`, applied to production 2026-11-20, with all eleven outlines:** nullable `outline` (jsonb polygons), `outline_source` and `outline_source_url` on `wine_regions`, with checks that an outline is an array and always carries its source. Covered by the existing RLS and select grant. No function. Replayed with every earlier migration on a scratch stack: applies cleanly, all eleven outlines load (28 KB), both checks refuse bad rows, anon reads them and cannot write (401). The app reads `outline` and, until the migration is applied, falls back to loading without it (42703), so nothing breaks in between. On production: the dry run listed only this migration; the columns existed and were empty before loading; afterwards all eleven regions carry an outline and a source, both checks are in place, the ledger reads 165/165, and anon reads an outline but cannot write it (401). Seen in the simulator: all eleven shapes over Europe, and Tuscany filling the view after a tap. The outlines are more detailed than the globe's own Natural Earth 1:50m coastline, so small islands the globe doesn't draw (Elba and the Tuscan islands) show as claret on open sea.
- **The nine Dutch wine regions** (product owner, 2026-11-20: "can we add the Dutch wine regions?"; then "All 9 separately"). From each BOB product dossier on RVO's official list: `supabase/data/enrichment/wine_regions/wine_regions_seed_nl_v1.sql` adds the regions (summaries keep to what the dossier says about soil, climate and style; no pairing or red-wine scale, which the dossiers don't give) and ten grapes they grow (Solaris, Johanniter, Souvignier Gris, Regent, Auxerrois, Müller-Thurgau, Pinot Gris, Cabernet Cortis, Pinotin, Cabernet Blanc; their texts are our draft), each region linked only to grapes its dossier permits. Six are drawn: Achterhoek-Winterswijk, Twente and Schouwen-Duiveland exactly; Mergelland, Vijlen and Oolde from official units finer than a municipality where the text called for it (BAG woonplaats, CBS buurt and wijken, PDOK open data), still somewhat larger than the zone. Maasvallei Limburg, Rivierenland and Voerendaalse Bergen are published with a point only: no official unit draws them without misstating them 3–7x. Checked on a scratch stack, then **loaded into production 2026-11-20**: before, production had 11 regions, 17 grapes and no Dutch rows; after, 20 regions (17 with an outline), 27 grapes (9 with a "like this? try" link), every Dutch region with its grapes, anon reads all nine and cannot insert a grape (401), and the migration ledger unchanged at 165/165 (content only, no migration). Seen in the simulator: the Mergelland page with its grapes, then Mergelland filling the view with Vijlen inside it and Voerendaalse Bergen and Maasvallei Limburg as patches. A patch now shrinks to 5 pt (was 14) so the small Dutch regions don't merge into one blur at the Europe view; taps keep their 44 pt target.
  - **The globe zooms to 1,000×** (was 60×), so a region a few km across can be seen: Vijlen's 3 km is about 80 pt wide at full zoom. A cluster of the member's own places still separates at the old 60× (`globePlacesMaxZoom`), so My places behaves as before. Smaller regions are painted, and hit, on top of larger ones (Vijlen inside Mergelland). The globe's own 1:50m country borders read coarse at that zoom.
- **Wine regions of the USA, Argentina and Chile** (product owner, 2026-11-20: "I want to add the wine regions in North and South-America"; first batch "USA" and "Argentina + Chile"). `supabase/data/enrichment/wine_regions/wine_regions_seed_americas_v1.sql` adds eleven regions, all drawn from official areas: Napa Valley, Willamette Valley, Paso Robles and the Finger Lakes from TTB's own AVA polygons (27 CFR part 9); Sonoma County as the county, since a county is a legal US appellation and no AVA matches it; Mendoza (the whole province, as its IG), Valle de Uco and Cafayate (labelled Valle de Cafayate) from INV's indications by departamento; Valle del Maipo (the whole Metropolitan Region, by decree), Colchagua and Casablanca from Chile's Decreto 464 by comuna. IG Valles Calchaquíes is held back: no official text gives it a boundary. Also four grapes (Zinfandel, Malbec, Carménère, Torrontés) and ten wine-list names (Oakville, Russian River Valley, Luján de Cuyo and others). The official texts say nothing about style, so summaries, grape notes, pairings and names are our draft. Checked on a scratch stack, then **loaded into production 2026-11-20**: before, 20 regions, 27 grapes, 33 names and nothing for the three countries; after, 31 regions (28 drawn), 31 grapes, 43 names, 107 region-grape links; anon reads Oakville and cannot delete a region (401); migration ledger unchanged at 165/165 (content only). Seen in the simulator: searching "Oakville" finds Napa Valley and flies across the globe to it, Sonoma County alongside. The wine-list search card now separates colour and note with a dot ("Red · Cabernet: rich, polished"), not a second colon.
- **Wine style text checked against sources** (product owner, 2026-11-20: "can you search online for style? Use multiple source"). Every drafted style claim in the atlas was checked against at least two sources from different organisations (regional wine bodies such as Inter Rhône, InterLoire, the Rioja and Ribera consejos, Napa Valley Vintners, Wines of Chile, Wines of Argentina; references such as Wine Folly, The Wine Society, Wine Spectator; VIVC and Deutsches Weininstitut for the disease-resistant grapes): 218 European region fields, 139 Americas region fields and 237 grape fields. 150 change, in `supabase/data/enrichment/wine_regions/style_review/wine_style_update_v1.sql`, generated by `build_style_update.py` from the four reviews beside it (the .md files carry every field, verdict and source). Among them: the Spanish ageing terms now follow the official rules; five wine-list "aliases" that are really separate appellations are removed (Chianti, Graves, Haut-Médoc, Mâcon, Barbera d'Asti); grape order follows plantings (Merlot before Cabernet in Bordeaux, Chardonnay first in Burgundy, Pinot Noir first in Champagne, Cabernet first in Colchagua); Tempranillo goes from 3/3/3 to 4/4/4; Pinotin's DNA points to Cabernet Sauvignon x Regent, not Pinot Noir; Regent has firm tannins, not soft. Claims no two sources supported were rewritten or dropped. The nine Dutch region summaries come from their dossiers and were not part of this check. Checked on a scratch stack, then **applied to production 2026-11-20**: Tempranillo reads 4/4/4 and Regent tannin 4, Bordeaux leads with Merlot and Colchagua with Cabernet, the five aliases are gone; region-grape links 107 to 110 (3 added, 1 removed).
- **Wine regions of Morocco and Ethiopia** (product owner, 2026-11-20). `wine_regions_seed_africa_v1.sql` adds five regions, all as points: no official text defines a Moroccan appellation by units that can be mapped, and Ethiopia has no wine appellation. Morocco: Guerrouane, Beni M'Tir, Les Coteaux de l'Atlas (its grapes from the official text) and Zenata, from the 1977 and 1998 arrêtés (ONSSA). Ethiopia: the Rift Valley vineyard near Ziway (Castel). The research corrected the brief: Ethiopia has two grape-wine producers, not one, and neither vineyard is about an hour from Addis (Ziway is ~160 km, ~2.5 h; Awash makes its wine in Addis from a farm in Arsi 115–180 km away, held back as unsourced). No pairings: no two sources gave one. Needs the new migration `20261101600000_add_et_country.sql` (Ethiopia in `countries`; data only, no function). Research in `wine_regions/africa_research/`. Checked on a scratch stack, then **applied to production 2026-11-20**: the dry run listed only `20261101600000_add_et_country.sql`; Ethiopia was absent from `countries` before and present after; then 36 regions (5 new, as points), 121 region-grape links; ledger 166/166. Seen in the simulator: searching "Ziway" opens the Rift Valley page with its four grapes. The simulator was shared with the welcome-flow session, whose build had replaced this one; this build was reinstalled to show it.
- **Vineyards: an editorial staging file** (product owner, 2026-11-20: "start with a database whilst we think how vineyards come back in the app"; "Staging file first"). `supabase/data/enrichment/vineyards_editorial/` holds verified estates outside The World's 50 Best, not in production, since any row in `vineyards` shows at once in search, + Add and wine logging. Five estates, every field sourced, address points from BAG via PDOK: De Apostelhoeve (Maastricht), then the product owner's four picks from the evidence shortlist ("let's add those 4"): Wijnhoeve De Kleine Schorre (Dreischor), Wijngoed Thorn (Thorn; no coordinates, its published shop address is not in BAG), Domein De Wijngaardsberg (Ulestraten; takes no visitors, address likely partly a home) and Wijngaard St. Martinus (Vijlen; no BOB stated anywhere). Two claims from the shortlist were opened and corrected: the Oxford Companion quote on Kleine Schorre is real but from 2015, and Thorn's 2020 Kassa win was not a blind tasting.
- **Near-miss: the globe was zero wide in wine mode on the device**, though widget tests passed. The empty overlay in wine mode was a `SizedBox.shrink()` as a non-positioned child of the globe's `Stack`, which sized the whole Stack, and the globe with it, to zero width. Now `SizedBox.expand()`. Any non-positioned child of that Stack decides its size; keep it filling. Also: region names show only from zoom 2.5 and never overlap each other or another region's dot, and wine mode opens at zoom 5 on Europe. The notes in the region and grape cards ("Chinon: a light, fragrant red") now sit under the name instead of right-aligned beside it, where they wrapped into a ragged column with one word hanging alone.

- **A new first-launch welcome flow** (product owner, 2026-11-20: "Ik wil dat als je de app opent voor het eerst echt denk van wow dit is gaaf en dat je tegelijkertijd snapt wat je allemaal met de app kan doen"; direction agreed on the "First-launch welcome flow" canvas, https://claude.ai/artifact/Dy38PFjN4rKraqHpwS3fBv). Six pages instead of four text-only ones, each pointing at a real part of the app:
  1. **Arrival**: My Map's own globe, turning slowly, with the Benelux lit.
  2. **Events**: the event line drawings cross-fading (gala, dinner, festival) under the shape of an event card with "Friends going".
  3. **Explore**: three tilted cards (wine estate, Key hotel, three-star restaurant) naming MICHELIN, The World's 50 Best, Gault&Millau and our own Selection.
  4. **Wishlist and Trips**: a dotted route over the train drawing, "Saved to Wishlist" and a trip day.
  5. **Passport**: the Passport opened on a stamp page with three of its real stamp designs (round seal, oval, double frame) drawn by the Passport's own painters, and a small turning globe for My Map. Replaced a plain ivory page with drawn seals after the first simulator pass (product owner: "I don't really like that white passport page").
  6. **Your Passport**: the member's own leather cover with their member number, "Your Passport is ready, {first name}", and Begin.
  - Every picture is the app's own (`GlobePainter`, `CsHeaderDrawing`, `StarRow`/`KeyRow`, `stampPainterFor`, `PassportCoverFace`); no venue, person or date is invented. The sample stamps print a city, a kind of visit and today's date, never a venue's name. Gold only where it already is: stars, the Key and the cover's foil.
  - No dashes in any copy (product owner: "this is really AI like"); a test guards it. Page 6's line is the product owner's own: "Start exploring your culinary journey. Find new spots, enjoy new experiences, and remember them forever."
  - Motion stops when the system asks for reduced motion. The cross-fade runs only while its page is on screen; the stamp presses in once.
  - `OnboardingGate` fetches the first name (first word of `display_name`) and `member_number` through the new `ProfileRepository.getWelcomeGreeting`, only once the flow is known to be needed. Best effort: on failure page 6 says "Your Passport is ready" and the cover keeps its own "NO. —". No database change.
- **A calmer Wishlist, with wine estates, trains and ships** (product owner, 2026-11-20, from the "Wishlist, calmer" canvas, https://claude.ai/artifact/9Z5VnN2hMZ44UfNXm7QzZC: "Build A, with B (Everything, by place) as the first item in the selector").
  - The chip row and the large "YOUR WISHLIST" title are gone; the Wishlist tab above already says where you are. One line, "Restaurants 18 ▾", opens a sheet listing each kind with its count: Everything by place, Restaurants, Hotels, Events, Wine estates, Trains, Ships. A kind with nothing saved stays out of the sheet. The + sits on the same line.
  - **Everything, by place** (the default): one card per region (else town), within its country, listing everything saved there with a kind icon. Places with the most saved come first. Trains and ships close the list together as "On the move", since they cross borders. Grouping uses the stored region, town and country only; nothing is matched by name.
  - The per-kind lists keep their cards, including the planned month on restaurants. Wine estates use `VineyardCard`; trains and ships use `JourneyCard`, now split by kind instead of one "Journeys" list.
  - **+ Add** gains Wine estate, Train and Ship chips. These small catalogues are read once and searched on the device.
  - **Wine estates can be saved** from the estate page (a heart in `VineyardDetailHero`, like the journey hero) and from + Add. Wishlist rows use the new `entity_type = 'vineyard'`.
- **Estate visits in the Passport.** "I visited this estate" on the estate page, and a Wine estate chip on the Passport's "Where did you go?", open a short sheet: the date (never in the future), what you did (tasting, cellar tour, lunch, walk in the vines, stayed the night), a note and friends visibility. Saving presses a stamp with "WINE ESTATE" where an award would be. The World's 50 Best Vineyards rank is never drawn on a stamp, so gold stays MICHELIN-only. The estate page lists your visits under In your Passport, and the Passport's browse-by-type has a Wine estates filter.
  - Wines tasted at the estate are not part of this change: `visit_wines.visit_id` points at `visits`, and shipped builds read an estate's `visit_wines` rows expecting a visit id. Linking them is a separate change.
  - `JourneyKindAward` is renamed `KindLabelAward`, since estates use it too.
- **Wine estates move from Explore into Collections**, as Vineyards under The World's 50 Best, after Hotels (product owner, 2026-11-20). Every estate in the catalogue comes from that list. The Explore row and its `hasAny()` check are gone. Vineyards is always listed in Collections, since the estates are live in production. Explore search still finds estates.
- **Hero drawings sit above the title** (product owner, 2026-11-20: "the drawing in the large hero sometimes sits relatively low"). In the restaurant, hotel, private chef, event, wine estate and journey heroes the scene filled everything below the toolbar, so its subject (the pass, the table, the house on the hill) fell behind the name and awards. `CsHeaderDrawing` takes a `bottomInset`, and the heroes pass `heroTextBand` (120 pt). The scene is then fitted into the band between the toolbar and the text, and its ground may run 30% of the way under the title. Fitted narrower than the hero, it is painted in its own layer with its sides and foot faded into the background, so its planes don't end in a hard box. Cards and thumbnails are unchanged. Checked in the simulator on Venta Moncalvillo: the pass and its dishes now sit above the stars.
- **Polish after the simulator check** (product owner, 2026-11-20).
  - Estates and journeys in Explore search are now the same ivory cards as restaurant and hotel results (`VineyardTile`, `JourneyTile`), not green picker rows.
  - Estates show "🇪🇸  Laguardia, Spain" instead of "Laguardia · ES", with their 50 Best Vineyards rank in claret, never gold. The add sheets' estate rows use the same label (`Vineyard.cardPlaceLabel`).
  - On "Everything, by place", a place known only from an event now shows its country name ("Lech am Arlberg · Austria"), looked up once from `countries`. Events carry only a code.
  - Checked in the simulator.
- **Explore search filters for Wine estates, Trains and Ships**, after Events in the chip row. "All" now also returns matching estates and journeys. Estates match on name, region and town ("Bordeaux" finds the Bordeaux estates). Trains and ships match on name, operator and where they run. The country filter for these kinds lists the catalogue's own countries.
- **Migration `20261101570000_add_vineyard_wishlist_and_visits.sql`, applied to production on 2026-11-20** (product owner: "first the polish and then the database change"). Before the push, `supabase migration list --linked` showed 162/162 in agreement and the dry run listed only this file. After it, the ledger is 163/163. Checked on production: anon has no SELECT on `vineyard_visits`, RLS is on with four policies, and the wishlist check lists `'vineyard'`. No rows were written to test it. It adds `'vineyard'` to `wishlist.entity_type` and creates `vineyard_visits`: RLS on, owner writes, an accepted friend reads a `friends` row, anon nothing; no function, so no grant to revoke.
  - **Why `vineyard_visits` is its own table and not a third `visits.entity_type`:** every shipped build reads `visits` as hotel-else-restaurant (`visited_repository.dart`), so a vineyard row would be misread as a restaurant by 1.6.0 and 1.6.1. That is the call trains and ships made with `journey_travels`.
  - Shipped builds read the wishlist filtered by `entity_type`, so they ignore vineyard rows.

### Checked
- `flutter analyze` is clean and `flutter test` passes all 3,010 tests, with new tests for the search, grapes per region, top-level regions and the region sheet.

- Welcome flow: `flutter analyze` is clean and `flutter test` passes all 3,008 tests on the welcome-flow branch. New tests cover all six pages, Next, Skip and Begin, the name and number on page 6 and their absence, the no-dash rule, motion on, four phone sizes from 320×640 to 440×956 without overflow, and the gate's greeting fetch (same user, failure, never fetched when already seen). Checked in the iPhone 17 simulator through a throwaway preview entry point with sample values, not signed in; the real gate path with a fresh account was not run.
- `flutter analyze` is clean and `flutter test` passes all 2,997 tests. New tests cover the selector and by-place grouping, the add sheet's estate, train and ship chips, estate visit rows and stamps, and the Explore filters.
- The migration was replayed with all 162 earlier ones on a scratch `supabase start` stack, and applied cleanly. On that stack: anon has no SELECT on `vineyard_visits`, RLS is on with its four policies, the wishlist check lists `'vineyard'`, and an unknown activity is refused (23514).
- `test/wishlist_default_venue_type_test.dart` is removed, with the default-kind rule it tested: the Wishlist now opens on Everything. The shell test now mirrors the selector line.
- **Not checked on a device or in the simulator.**

---

## v1.6.1 (36) — 2026-11-20

Merged into main on 2026-11-20 from `claude/trip-map-positions`, `claude/booking-windows` (log only) and `claude/release-next` (log only), on top of the sold-out/expected labels, the new typefaces, the stamp rework, the wine-on-stays change, vineyards and the missing-photo drawings already in main. No merge conflicts. `flutter analyze` clean, `flutter test` 2,981 passing on the merged tree. The migrations this build reads (`20261101510000_add_event_announcement_status`, the vineyards migrations) were already applied to production before the build. Schema diff at the bump (2026-11-20, per `NEW_MACHINE_SETUP.md` §4): all 162 migrations replay cleanly on a scratch stack; ledger 162/162. The `db dump` diff is one line, `EXTRACT(day …)` against `EXTRACT("day" …)` in `wishlist_planned_month_check`, which is a pg_dump quoting difference, not drift. Buckets, `storage`/`auth` policies and storage RLS hash identical. Production has three extra platform triggers on `storage.buckets` (`protect_active_lifecycle_states`, `wake_lifecycle_on_policy_write`, `wake_lifecycle_on_versioning_enable`), which come from the newer hosted storage service, not from a migration.

### Added
- **Line drawings for wine estates, trains and ships** (product owner, 2026-11-20: "I don't have drawings for vineyards and we have just added those"; from the header-drawings canvas, "use all three wine-estate drawings, alternating, plus the train and the ship").
  - **Five new `CsHeaderDrawing` scenes:**
    - Wine estates: rows over the hills (the original estate header), the house on the ridge, the cellar. `HeaderDrawing.vineyard(id)` alternates between them by id.
    - `HeaderDrawing.journey(id, kind)`: a carriage on a viaduct for a train, a small ship at sea for a ship.
    - The id also lights a few carriage and saloon windows, as it does on the hotel façade.
  - **Where:** `VineyardDetailHero` and `JourneyDetailHero` keep their own widgets (settled: the heroes stay separate). Each now draws its scene behind the text, under the same vignette as the restaurant and hotel heroes, and is at least 300 pt tall below the status bar, with the name at the bottom.
    - `VineyardCard` gets a 64 pt drawing beside the name.
    - `JourneyCard` gets a 16:9 drawing above the eyebrow.
    - Before this, all four were text-only, with no image slot.
  - Neither table has a photo column yet, so for now every estate, train and ship shows its drawing.
  - **Fixed in passing:** `_onePerScene` in `test/cs_header_drawing_test.dart` loops until it has found every scene. With five scenes no constructor in it produced, `flutter test` hung instead of failing. It now builds estates and journeys too.
  - Checked: `flutter analyze` clean; `flutter test` all 2,977 pass, with new tests for the estate pool and the journey kinds. All five scenes were rendered to an image and compared with the canvas.
    - In the simulator against production: the Wine Estates list (Schloss Johannisberg, Bodegas Ysios, Montes and others alternating), the Montes page, the Trains & Ships list (Belmond Andean Explorer) and the Amandira page.
    - Seen there: Amandira is a sailing yacht (a phinisi), but the ship drawing had a funnel.
  - **Sailing yachts get their own scene** (product owner, 2026-11-20, after that check): two masts, gaff sails and a jib, on the same sea as the ship. `HeaderDrawing.journey` takes the `ship_type`; only `sailing_yacht` gets sails, and every other ship type keeps the motor ship.
    - **Near-miss:** the yacht has three cabin windows, but the lit-window count could be up to four. Picking distinct windows would then never finish, and `flutter test` hung on it. The count is now capped at the number of windows a scene has.
    - Checked: `flutter test` all 2,978 pass, including a test for the ship-type mapping. In the simulator, Amandira shows the yacht and the other ships keep the motor ship.
- **Line drawings in place of a missing photo** (product owner, 2026-11-20, after the vineyard estate header: similar drawings for restaurants, hotels and events without photos; on the design canvas, "of willen we gewoon alle verschillende tekeningen gebruiken en dat het gewoon wisselt, anders wordt het ook zo eentonig"). Canvas: https://claude.ai/artifact/891UF37f9npbsWwYFzrXE5.
  - **What:** `CsHeaderDrawing` (`lib/core/widgets/cs_header_drawing.dart`), one `CustomPainter` with fifteen scenes in the vineyard's style: two deep-green planes, ivory line at low opacity, one faint round light. No gold, no text, nothing that reads as a fact about the place. Restaurants rotate through a table setting, the pass and an arched dining room; hotels through a façade, a garden allée and a front door (no key, which would read as a MICHELIN Key); private chefs through a board and knife and a home table. Events are drawn by type: Dinner also draws from the three restaurant scenes, and Market, Experience and untyped events draw from all seven event scenes.
  - **Seeded by id:** the venue's or event's id picks the scene, mirroring (only where the mirror image is still right, so not the table setting or the knife), where the light sits and, on the façade, which windows are lit. FNV-1a plus the MurmurHash3 finaliser, never `String.hashCode`, so one place looks the same on every screen, device and release. The hash is pinned in a test.
  - **Where:** the no-photo and failed-load states of `VenueDetailHero` (Restaurant/Hotel), `PrivateChefHero` and the event detail hero, plus the event cards, Explore discovery cards and event tile, Community events preview, Passport event card, event wishlist card, chef discovery card, and `VenueThumbnail` on the Explore tiles, Guides, Rankings, Passport and Wishlist cards. The three heroes stay separate widgets; they share only the painter. Loading still shows the plain gradient, and a broken photo inside a gallery still falls back to it. Lists that don't pass a drawing (friend activity, trips, pickers) keep the monogram, as do the empty states.
  - **Scaling:** cover-fitted and centre-cropped like a photo, with lines kept at 1.2 logical px at every size. Closed venues get a grey version.
  - `path_parsing` (already resolved through `flutter_svg` at 1.1.0) is now a direct dependency for parsing the path data.
  - **In the detail-page heroes the scene starts below the status bar and toolbar** (`CsHeaderDrawing.belowToolbar`). The hero runs up behind both, so the first simulator check showed Rosewood Hong Kong's moon behind the back button and Kadeau's pendant lamp under the camera cutout. The scene is now top-aligned under that band, any crop falls on the ground under the vignette, and cords and chains run up to the top edge, so a lamp never hangs from nothing. Cards are unchanged.
  - Checked: `flutter analyze` clean; `flutter test` all 2,957 pass, including new tests for pools, determinism, mirroring and the cleared toolbar band, and painting all fifteen scenes at hero, card and thumbnail size. Six tests that expected the monogram now expect the drawing. All scenes were rendered to an image and compared with the canvas. In the simulator against production: Explore's event, restaurant and hotel cards, and the Rosewood Hong Kong, Kadeau and Pair'd Margaret River pages, before and after the toolbar fix. Not checked: a private chef without a photo (the only one live has a photo), and the greyed version on a closed venue.
- **Vineyards (wine estates), starting with The World's 50 Best Vineyards** (product owner, 2026-11-20, after reviewing the design canvas "Wijngaarden in Mantelier": vineyards get their own table; start with the 50 Best Vineyards; wines already logged stay as they are; no gold for wine; a stamp only from a confirmed visit or event, never from a bottle). Branch `claude/vineyards`.
  - **Migration `20261101550000_add_vineyards.sql`, applied to production on 2026-11-20** (product owner's go-ahead that day). It adds:
    - `vineyards`, its own table and not a kind of venue: generated `id`, `vineyard_code` (`vine_0001`…, unique), name, country, region, city, address, a nullable `location` that is never geocoded, `google_place_id`, `website_url` and `status`. It has no description or photo column, because those come from the estate after review.
    - `worlds_50_best_vineyards`, one row per estate per edition, shaped like `worlds_50_best_hotels`. The rank is not stored in `award_history`: that table holds MICHELIN stars and Keys, which sort the other way (DATABASE_ARCHITECTURE.md §3.6).
    - The `vineyards_full` view (security_invoker). Current rank means the latest edition, so an estate that left the list shows no rank.
    - A nullable `visit_wines.vineyard_id` (`on delete set null`), with no backfill. Existing wines stay unlinked and nothing is ever matched by name.
    - `event_vineyards`, with the same shape as the other event links. A check keeps `is_host` and `is_venue` false, so an estate is only ever a participant for now.
    - RLS on every new table, with public read and no client write; grants are narrowed to `select`. The event links follow the visibility of the other event links, and admins can also read draft-event links. No function is created, so no `revoke execute` is needed.
  - **App:**
    - Explore gains a "Wine Estates" row, which opens the collection in rank order. The row shows only when estates exist.
    - Each estate has its own page. `VineyardDetailHero` is a separate hero, per the settled rule. The page shows the rank in claret, the member's own wines from that estate ("In your Passport"), the events it pours at, the location and the website. The About section stays empty until the estate supplies text.
    - Logging a wine: typing a Producer suggests matching estates, with "Keep '…' as written" always offered. Picking an estate links the wine. Editing the producer away from the estate name, or tapping Unlink, removes the link.
    - The Passport has a new Cellar tab, between Passport and Wishlist. It shows wines, estates and regions, groups wines by region and estate, and keeps unlinked wines apart, exactly as they were written.
    - An event page lists its wine estates.
    - `AppColors.claret` is new, a muted accent for light surfaces only.
  - **Rollout:** this build works against a database without the migration.
    - Wine reads ask for the estate link and fall back to the old columns.
    - An unlinked wine never sends `vineyard_id`.
    - Estate lookups on events and in the wine sheet fail quietly to empty.
    - The Explore row appears only once at least one estate can be read, so before the migration and the reviewed data are applied it simply isn't there.
  - **Applied to production on 2026-11-20:**
    - The product owner agreed to apply all three pending migrations with one `db push`: `20261101510000` (announcement status, below), `20261101550000` and `20261101560000_add_lb_uy_countries.sql`. The last adds Lebanon and Uruguay, needed for Château Kefraya and Bodega Garzón.
    - The estates were then loaded with `prepared_worlds_50_best_vineyards_2026.sql`: 44 estates (22 verified, 22 partial) and their 44 ranks for 2026. The 6 held-back rows stay out. 23 estates have a location, and none was geocoded.
    - Read back afterwards: 44 vineyards, 44 ranks for 2026, no held-back code present, and the ledger shows 162/162 with local and remote in agreement.
    - Over the real API with the anon key: `vineyards_full` reads, and a write to `vineyards` is refused (401). The `visit_wines → vineyards(…, countries(name))` and `visits(visited_on)` embed resolves: anon gets 42501 (permission), while a made-up relationship gets PGRST200.
  - **Data:** `supabase/data/enrichment/worlds_50_best_vineyards/`. The 2026 edition (announced 18 November 2026) comes from the official list. worldsbestvineyards.com now redirects to the50.com/vineyards, which is where the data was read.
    - Every row has its source URLs. There are 22 verified rows, 22 partial and 6 held back; ranks 51–100 sit in a separate file and are unverified.
    - Location comes only from the estates' own sites, and nothing was geocoded.
    - Open issues are logged as QA-520..QA-529 in `qa_issues.csv`. Four estates sit behind age gates that were not clicked through, one gives no location, one prints conflicting street numbers, and several give no coordinates or street address.
    - The names and regions for ranks 1–50 were re-checked against the official list page after staging.
  - **Checked:**
    - `flutter analyze` is clean, and all 2,966 tests in `flutter test` pass. New tests are in `test/vineyards_test.dart`; the Passport shell test now covers five tabs at 320–430 px.
    - The migration was replayed on a scratch PostgreSQL 17 on top of a minimal prelude (countries, profiles, visits, events, `is_admin`/`is_friend` stubs) and `20261101330000`. PostGIS was not available there, so `location` was stubbed as `point`. Fifteen checks passed:
      - the current rank comes only from the latest edition;
      - the code format and duplicate rank/code are refused;
      - the host flag is refused;
      - anon can read but cannot write, and sees only published-event links;
      - an admin sees draft links;
      - a member can link their own wine;
      - removing an estate leaves the wine unlinked;
      - no function is created.
  - **Not checked:** the full Supabase stack replay (no Docker on this machine), the geography column itself, PostgREST's embed of `vineyards(…, countries(name))` against a real API, and the screens in the simulator.
- **The regional 50 Best lists and Guía Repsol as guides, app and hidden site** (product owner, 2026-11-17: "die nieuwe repsol guide ... en die 50 best van verschillende werelddelen. Die wil ik ook op de nieuwe website kunnen vinden en in de app"). Until now these showed only as a line on a restaurant's page; there was no way to browse a list.
  - **App:** Guides gains Asia, Latin America and North America under The World's 50 Best, and a Guía Repsol family with Restaurants. One new screen, `SharedGuideRestaurantScreen`, reads any guide from the shared tables (`guide_awards_current`, `guides.tier_labels`, `guide_coverage`) by `guide_code`, with the same search and country filter as the other guide lists. Ranked lists sort by rank, Repsol by Soles then name; each card reads "#1 · 2026" or "3 Soles · 2026". The coverage note shows above the list, so a partial list never reads as the whole guide.
  - **Hidden site:** `/guides/asia-50-best`, `/guides/latin-america-50-best`, `/guides/north-america-50-best` and `/guides/guia-repsol`, with the edition year in the title and the coverage note under the intro. The guides index lists all eight.
  - Guía Repsol's coverage note is stored per country (ES), the regional notes guide-wide; both the app and the site now take the guide-wide note first, else the single country note. Before, the site only read guide-wide notes, so Repsol's would never have shown.
  - **Repsol's coverage note shortened in production, 2026-11-17** (product owner: "haal die laatste zin bij Repsol: Restaurants with 1 sol follow maar weg"): one row in `guide_coverage` updated by `supabase/data/enrichment/guia_repsol_2026/prepared_guia_repsol_2026_coverage_note.sql`, which refuses unless exactly the old text matches. Read back after: the note ends at "113 of 173 with two."
  - Checked: `flutter analyze` clean, `flutter test` all 2,895 pass (new tests for the ordering and for a restaurant missing from the resolved rows); the site builds with 159 / 51 / 28 / 32 restaurants on the four pages, matching production. Seen in the simulator against production: Guía Repsol opens on the 3 Soles, Asia on The Chairman #1. Not checked: the site pages at phone width.
- **"Sold out" and "Expected" labels on events** (product owner, 2026-11-05):
  - **Where they show:** event cards (Events, the Explore result tile, the
    Explore discovery card, the Community preview) and the event detail page.
    One shared definition lives in `event_status_badges.dart`. A cancelled
    event shows only CANCELLED.
  - **Sold out** reads the existing `events.availability_status`
    (`sold_out`), which no build had shown until now. It needs no migration.
  - **Expected** reads the new `events.announcement_status`: an event known
    from a secondary source that the venue has not announced yet.
  - **Migration `20261101510000_add_event_announcement_status.sql`**,
    applied to production on 2026-11-20 in the same `db push` as the
    vineyards migration, on the product owner's go-ahead (first prepared on
    2026-11-05 as `20261101320000`; renamed on 2026-11-19 to follow the
    highest migration):
    - adds `announcement_status` (`official`/`expected`, default `official`)
      and `expected_source_url`, with a check that an expected event has a
      source;
    - extends the host-edit column lock to both columns.

    It was tested on scratch PostgreSQL 16 against a minimal `events` table,
    not the full stack.
  - **Rollout:** this build reads both columns safely when they are absent.
    A build without this change shows an expected event with no label, so
    no event may be set to `expected` until this build has shipped.
  - Brought onto main on 2026-11-19 from `claude/event-expected-soldout`:
    `flutter analyze` clean, `flutter test` all 2,909 pass. Not re-checked
    on a device. The migration is still not applied.

### Changed
- **New typefaces: Spectral and Hanken Grotesk** (product owner,
  2026-11-19, choosing direction A "Salon" from the type study: "oke ik ben
  het ook wel eens met het veranderen van de fonts naar Salon dus die optie
  A"). Spectral replaces Cormorant Garamond and Playfair Display for
  titles, names, numbers and long reading text; Hanken Grotesk replaces
  Inter for interface text. The goals were legibility and a more refined
  look; gold is untouched and still only marks MICHELIN stars and Keys.
  - **Bundled, not fetched.** Seven font files (Spectral 300/400/400
    italic/500, Hanken Grotesk 400/500/600, 688 KB) live in `assets/fonts/`
    with their SIL Open Font License texts, registered with
    `LicenseRegistry` in `main.dart`. They are byte for byte the files
    google_fonts would have downloaded (sha256 checked against its
    manifest). `google_fonts` is removed: until now the app downloaded
    about 2.6 MB of fonts at runtime and showed a system font until they
    arrived, or for good when offline.
  - **One place for families and weights:** `lib/core/theme/cs_fonts.dart`.
    `CsTypography` and `AppTypography` read from it, and all 214 direct
    `GoogleFonts` calls (passport stamps included) now go through
    `CsFonts.serif`/`CsFonts.sans`. Requested weights snap to the nearest
    bundled one, so nothing renders as a synthesized bold. A style without
    a line height gets 1.21, the line box the layouts were built for;
    Spectral's own is 1.52 and would have made every serif line ~25%
    taller.
  - **Sizes were converted, not copied.** Spectral is ~12% wider per point
    than Cormorant, so serif sizes went down by ~9% (a card title from 22
    to 20, the venue hero from 30 to 27.5) and still read larger: its
    x-height is 45% of the size against 38.6%. Hanken Grotesk is ~6%
    narrower than Inter but with a smaller x-height, so interface sizes
    from 11 to 15 went up half a point and anything below 11 now starts at
    11. The passport booklet pages and stamps keep their small print, since
    it is part of a fixed book layout, and get only the half point.
    Letter-spacing written as a multiple of the old size follows the new
    one.
  - **Reading text is serif.** A new `CsTypography.reading` role (Spectral
    16.5/26) sets venue and event "About" texts and news article bodies.
  - Obsolete: the `lnum` lining-figure workarounds for Cormorant on the
    passport pages and in the add-a-visit flow (Spectral's figures are
    lining by default). The passport's machine-readable line moved from
    Roboto Mono to the system monospace (Menlo on iOS).
- **Passport stamps: the wave stamp is gone, four new designs, four
  stamps per page** (product owner, 2026-11-19: "die met die 3 golven ...
  moet weg", "makkelijk 4 stempels op 1 pagina zonder dat ze overlappen",
  "nog 4 stempeldesigns bovenop die 4 die blijven"):
  - **Designs:** the postmark (a circle with three wavy cancellation
    lines) is removed. Four new ones join round seal, double frame, oval
    and octagon: a cartouche with concave corners, a round-topped arch,
    a heater shield with a ruled chief, and a lozenge crossed by a
    banderole. They were shown as renders of the real painters first and
    approved by the product owner before they went in. Gold ink is
    unchanged, which the product owner chose for now.
  - **Which stamp gets which design:** nothing stores it. It is
    `hash(visit id) % number of designs`, so going from five designs to
    eight re-deals every stamp once, deterministically. No stamp can land
    on the removed design. The product owner chose this one-time re-deal
    over pinning existing stamps to their old design.
  - **Four per page, never overlapping:** the free placement (a greedy
    8-direction search plus pairwise relaxation) is replaced by a 2×2
    grid. Each stamp owns one cell and is scaled down, uniformly, until
    its rotated footprint fits the cell; the jitter only uses the room
    that is left over. The bottom-left cell stops short of the year
    corner. Tests check every design, the verified stamp and the
    next-stamp placeholder at every rotation and jitter, on screens from
    262 to 562 pt wide (320 pt included), plus a rendered 320 pt page.
    On the smallest phones the stamps are drawn at about half their
    design size.
  - **Built on the new typefaces:** the four new painters set their text
    in Spectral and Hanken Grotesk through `CsFonts`. Their serif name
    sizes went down about 9%, as the type change did for the others: the
    cartouche from 24/19/15 to 22/17/14, for example.
  - **Checked on a device:** `flutter analyze` clean and `flutter test`
    all 2,948 pass. Checked in the iOS simulator (iPhone 18 Pro Max,
    2026-11-20) on a real account with four stamps. Page 2 shows all four
    in their own cells with no overlap: oval, octagon, arch and shield, the
    shield in green ink for a train. The year corner is clear. Page 3
    holds only the next-stamp placeholder, in the top-left cell. Not
    checked on a device: the stamp ceremony, because it would need logging
    a real visit on that account; any screen under 440 pt wide, since no
    simulator at 320 pt exists, so that width is covered by tests and a
    rendered page only; and the cartouche and lozenge, which this account
    has no stamp drawn in. Those two were checked in renders of the real
    painters.
- **No wine on a hotel stay** (product owner, 2026-11-19: "dat je wijn kan
  toevoegen bij hotel review ... dat is gek"). "What we drank" is now
  restaurant-only, like the Wine rating already was: the add-a-stay form no
  longer shows it, wines staged before switching the form from Restaurant to
  Hotel are not saved onto the stay, and the stay detail page no longer
  shows the section. Production had no wine on any hotel stay (checked
  2026-11-19: the one logged wine is on a restaurant visit), so nothing
  already saved is hidden by this. The `visit_wines` table is unchanged.
  `flutter analyze` clean and `flutter test` all 2,909 pass; there is no
  widget test for the add-a-stay form, and it was not checked on a device.

### Fixed
- **Trip map: places at one address hid each other.** Reported
  2026-11-20 as restaurants and hotels not always appearing in the right
  place. The pins themselves were placed correctly (latitude/longitude
  order, centre anchor and tile size all checked), but production holds
  119 pairs of venues within 10 m of each other, mostly a restaurant inside
  its hotel. A planned place never folded into a cluster, so it was drawn
  straight over the hotel it sits in and hid it at every zoom; two
  unplanned ones became a "2" that tapping zoomed into forever without
  ever splitting. Places within 15 m now always share one marker, ivory
  when one of them is planned or an event, and tapping it — or any
  cluster at the closest zoom — opens a short list to pick from. The
  other half of the report is data, not code: the earliest catalogue rows
  carry coordinates hundreds of metres to 3 km from their own address.
  Those were verified and 101 of them corrected in production the same
  day, recorded in the Michelin_Database changelog (QA-530); 18 are held
  back.
- **Tests measured text in a font no user sees.** `flutter test` sets
  every family in its own "FlutterTest" font, where each glyph is one em
  wide, and the runtime-fetched fonts never loaded in tests. So every width
  and overflow check in the suite measured text about 1.6× too wide. The
  new `test/flutter_test_config.dart` loads the real bundled fonts before
  each test file. It reads them with `dart:ui`, because initialising a test
  binding there would stub all HTTP and break the live-view tests that
  query production on purpose. Measuring the real fonts caught three real
  layout problems in this change, all fixed:
  - the Explore restaurant and hotel rails overflowed at 1.6× and 2.0×
    text, so their text-scaled height grew by 4;
  - the score header's stacked-fallback test had only ever stacked
    because the test font was so wide. Its `width` set the reported screen
    size, not the layout width, so it now boxes the header to 320 pt at
    2.0× text;
  - the passport data page masthead overflowed until the booklet pages
    were exempted from the 11 pt minimum.
  - A new `test/typography_narrow_phone_test.dart` renders the event card,
    restaurant and hotel tiles and the Explore rails at 320 pt (the
    narrowest iPhone on iOS 15) at 1.0×, 1.35× and 2.0× text, with the
    longest real event, restaurant and hotel names in the catalogue.
- The Explore section titles ("WORTH THE JOURNEY", "MANTELIER'S
  LATEST", "STAY A LITTLE LONGER") now scale down to fit instead of
  ending in "…". At 320 pt the longest needs 295 pt of the 280 available.
  Two of the three were already cut off there with Cormorant.
- Checked for the type change: `flutter analyze` clean, `flutter test`
  all 2,919 pass with the real fonts loaded. Seen in the simulator, signed
  in (iPhone 17, iOS 27): Explore, an event page, a restaurant page with
  three stars and one without, the Passport cover, data page and a stamp
  page, and a news interview. Not checked: Dynamic Type sizes on a
  device, and a 320 pt phone other than in widget tests. Nine sizes set from a variable
  were left as they are (the stamp painters fit their own text, the
  passport field and avatar initials were adjusted by hand), and 102
  one-line and 31 two-line text spots were not each looked at.
- **A stamp placement crash at 320 pt, caught before it shipped:** when
  a stamp's scale is set by one axis, the room left on that axis is zero
  only up to rounding, and a value like `-7e-15` made `clamp()` throw.
  Every page on a 320 pt screen rendered as an error box in the preview.
  The leftover is now floored at zero, and the 320 pt page test covers it.

---

## v1.6.0 (35) — 2026-11-17

Archived from the main checkout on 2026-11-17 (`flutter build ipa`, archive 1.6.0 / 35, `FLUTTER_TARGET=lib/main.dart`, `MAPTILER_KEY` present in its `.env`) and uploaded to App Store Connect by the product owner the same day.

A new version, not another 1.5.7 build: it brings Trains & Ships, the wishlist month with booking-window reminders, the regional 50 Best lists and Guía Repsol in the app, and the database-side hardening of four app-only rules. Merged into main on 2026-11-17 from `claude/w50b-2026`, `claude/compassionate-diffie-ce76ef`, `claude/guide-inventory`, `claude/booking-windows` and `claude/trains-and-ships`; the one code conflict, in `wishlist_screen.dart`, joins both sides (planned months and journeys load side by side, each failing on its own). `flutter analyze` clean, `flutter test` 2,891 passing on the merged tree.

**Ledger: 159, local and remote in agreement.** Before the merge, production held 8 migrations main didn't have (`20261101390000` to `20261101500000`), all applied from their own branches; the merge closes that. Schema diff before the push, on all 159 migrations replayed on a scratch stack (own project id and ports, so the other sessions' local stacks were untouched): the replay came up clean, and the dumps differ in one line only, `EXTRACT(day …)` against `EXTRACT("day" …)` in `wishlist_planned_month_check`, the same expression quoted differently by two Postgres versions. Storage and auth: the buckets, the `storage`/`auth` policies and RLS hash identical; production has three triggers on `storage.buckets` the replay doesn't (`protect_active_lifecycle_states`, `wake_lifecycle_on_policy_write`, `wake_lifecycle_on_versioning_enable`), which come from the platform's newer storage service, not from a migration, like `enforce_versioning_status_transition` before them.

### Changed

- **Plainer copy on the hidden site** (product owner, 2026-11-16: "de teksten die jij hebt geschreven minder AI achtig maakt, zoals die \"-\" verwijderen"). Page titles now use "|" instead of an em dash. The em dash is gone from the one notification sentence that used it. Intros, descriptions and the Off the beaten track prototype now say plainly what is there, without phrases like "worth travelling for", "behind the pass" or "seen from the kitchen and from the table". Date ranges, flight routes and the "—" shown for an empty score keep their dashes; there they are typography, not style. Only copy we wrote changed: article bodies, venue text and guide data are untouched. Checked by a full build and by reading the titles and the planner page in the output.

### Added
- **Off the beaten track on the hidden site** (product owner, 2026-11-16: "kunnen we op de nieuwe website al wel die off the beaten track clickable maken en dan wat we net gemaakt hebben al laten zien"). The footer compass now links to `/off-the-beaten-track`, the clickable prototype of the trip planner: a five-step intake and an example Peru proposal with a real map (Natural Earth 1:50m outlines, embedded), animated route legs, an altitude profile, flights, a booking checklist, "what's in this proposal", saving and editing, adding places not in Mantelier, and sharing by WhatsApp or email. No AI and no booking: it is advice-only by decision, tested with friends and family first, and a candidate Pro feature. The hotels (MICHELIN Keys) and restaurants (World's 50 Best 2026) are real catalogue rows; the six restaurants link to their site pages, resolved at build time by `restaurant_code`, never by name. Its styles are scoped under `.otbt` so they can't touch the rest of the site. Saved trips and ticks stay in the visitor's browser (`localStorage`) until it becomes part of Trips in the app. Travel-advice colours on it are illustrations, said on the page. Checked locally: the compass link, the whole intake-to-proposal flow, the six restaurant links, no script errors, no sideways scroll at phone width. Nothing in the database changed.
- **The 50 Best Restaurants 2026 in the data, complete** (product owner, 2026-11-16: "voeg eerst de 8 ontbrekende restaurants toe, zodat 2026 compleet is", then approved the apply). Migration `20261101390000_add_w50b_2026_cities` (city Kasauli) applied to production, ledger 152/152 local and remote; the catalogue data (8 new restaurants, the 100 ranks for 2026, Maido as hall of fame, 2025's missing No. 94 Meet the Bund) went in as one prepared transaction, `supabase/data/enrichment/worlds_50_best_2026/`. No app or site code changed: `restaurants_full.worlds_50_best_rank` follows the newest ranked year, so 2026 is current in the app as of the apply, and the hidden site's "2025" and its "Not in our data yet" row for 94 go on its next build. Data detail and evidence are in the Michelin_Database changelog.
  - **Near-miss:** `supabase db push` was first run through `timeout`, which doesn't exist on macOS; the command failed before the CLI started. Production was checked (no city row, no ledger row) before the push was run again, rather than assuming either outcome.
- **Shared tables for every further guide, and the three regional 50 Best lists, applied to production 2026-11-16** (product owner, 2026-11-16: "begin met de drie regionale 50 Best-lijsten en de gedeelde tabellen"). `20261101410000_add_shared_guide_tables.sql` adds `guides`, `guide_awards` (rank, score and tier as separate typed columns, since they sort in opposite directions), `guide_venue_links` (each match with its evidence, reused every edition), `guide_coverage` (the note the site shows about what we hold) and the view `guide_awards_current`; public read, no client write, no functions. `award_history`, `worlds_50_best` and `gault_millau_awards` are untouched. The data file holds Asia's 50 Best 2026 (51 of 100 in our catalogue), North America's 50 Best 2026 (32 of 50) and Latin America's 50 Best 2025 (28 of 100; 2026 follows on 1 December). Inventory and design: `docs/Architecture/GUIDE_INVENTORY.md`; import: `supabase/data/enrichment/regional_50_best/`.
  - **Why not in `worlds_50_best`:** its unique `(restaurant_id, year)` and `(year, rank)` would collide with the global list, and `restaurants_full` reads the maximum ranked year as the current rank, so regional rows would replace the global rank in installed builds.
  - **Held back, not guessed:** three Asian entries whose address disagrees with, or cannot be checked against, the catalogue (QA-490); eight matched restaurants whose catalogue address looks out of date (QA-491).
  - Checked on a local stack replaying every migration: the import commits, a second run is refused, the rows read back equal the staging CSV, and `anon` can read but not write. Applied the same day at the product owner's request; production then held 51 / 32 / 28 rows, identical to the CSV, ledger 154/154.
- **Regional 50 Best rankings on restaurant pages, app and hidden site** (product owner, 2026-11-16: "toon de regionale rankings op de restaurantpagina's van de app en de verborgen site, met de coverage-noot"). The app's Restaurant Detail shows a secondary hero badge per current ranking ("Asia's 50 Best Restaurants · #1"), read from `guide_awards_current` (`GuideAwardRepository`, `GuideAward`); Award History gets one section per guide with every edition and that guide's coverage note, and its "Award history" action now also appears for a restaurant whose only history is a regional list. On the hidden site, "Every guide" lists each current regional ranking under the four guides with its coverage note, and "Over the years" a column per guide. Ivory, never gold; a failed lookup hides the badge rather than showing "no award". Installed builds don't read the new tables and are unaffected.
  - **Guía Repsol 2026, 2 and 3 Soles, in the same tables** (product owner, 2026-11-16: "pas Guía Repsol 2 en 3 Soles toe op productie"): 159 restaurants (all 46 with three Soles, 113 of 173 with two), shown in the guide's own words ("Guía Repsol · 3 Soles") through `guides.tier_labels`; no migration. 1 Sol follows. `supabase/data/enrichment/guia_repsol_2026/`.
  - Checked: `flutter analyze` clean, new model tests pass; the site builds (3,758 pages) with the ranking on exactly the 111 restaurants that hold one, seen on The Chairman at desktop width and 375 px, no sideways scroll. **Not seen:** the app screens running on a device or simulator.
- **Trains & Ships: luxury trains and small ships as a new kind of place** (product owner, 2026-11-16: "Akkoord met het plan en de 4 beslispunten zoals aanbevolen. Begin met de aanbevolen set voor de eerste slice."). Plan and the four decisions in `docs/Architecture/JOURNEYS_PLAN.md`: one `journeys` table with `kind` train or ship; never gold, and not in the Mantelier Selection (the plan's decision 2 proposed the Selection label; the product owner reversed it the same day: "die treinen en ships zijn niet mantelier selection", so the label, `journey_selections` and the seed's selection rows were taken out before anything was applied); a fourth, separate hero (`JourneyDetailHero`), the other three untouched; no photos until operators supply them, so the cards and hero are typographic.
  - **Database, applied to production 2026-11-16** (product owner in chat: "Yes, apply the journeys migration and seed to production."): `20261101500000_add_journeys.sql` adds `journey_operators`, `journeys`, `journey_routes`, `journey_route_stops`, `journey_restaurants` (dining partners, by restaurant id) and `journey_travels`, the view `journeys_full`, and `'journey'` as a fourth `wishlist.entity_type`. Catalogue tables are select-only for anon and authenticated and hide drafts; `journey_travels` follows `event_confirmed_attendance` (own rows, friends see `friends` rows, anon nothing). No function, so nothing to revoke. A travel's route must be one of its own journey's routes (a composite foreign key). Shipped builds filter every wishlist read on `entity_type`, so they ignore journey rows.
  - **Seed, applied to production 2026-11-16, right after the migration:** `supabase/data/enrichment/journeys/journeys_seed_first_slice.sql`, the approved 9 trains and 11 ships, 38 routes with a published start and end, and 5 dining-partner links by restaurant code plus country (it refuses to finish if one doesn't match). Each value comes from the staged candidate lists, which give an operator source per row.
  - **App:** a "Trains & Ships" row in Explore opens the collection (All / Trains / Ships). A journey's page has its routes, what is on board, dining and dining partners (opening the restaurant), the wishlist heart and "I travelled on this". Confirming a travel is the only way a journey enters the Passport: one stamp per travel, its kind ("TRAIN", "SHIP") in the award row, then the usual stamp ceremony. Passport and Wishlist each get a Journeys filter.
  - **Near-misses, held back rather than guessed:** Jean Imbert is named on the Venice Simplon-Orient-Express but not linked, because `rest_0972` is now "La Grande Table du Plaza Athénée" in production and it wasn't checked whether he still cooks there. Golden Eagle gives its lengths in days, so they are stored as published (`duration_text`, "8 days") and never converted into nights. The Corinthian's Lisbon–Barbados crossing and Aqua Mekong's country are left out, because BB and KH are not in `countries`. The ships' MICHELIN claims for their chefs are the operators' own words, so no stars appear in any dining text.
  - **Fixed before release, found in the simulator run:** the route picker in "I travelled on this" opened on Material's default pink-white menu instead of the sheet's ivory (`dropdownColor` was never set; the one other `DropdownButton`, in the venue event form, doesn't set it either and was left alone). And a wishlist holding only trains and ships opened on an empty Restaurants tab, because `defaultWishlistVenueType` only knew three tabs; it now falls through to Journeys after Events, with tests for both orders.
  - Checked: every migration replayed from scratch on a local stack, then the seed. `supabase/tests/journeys_rls_test.sql` passes all 16 checks (drafts hidden, no anon access or writes, own travels only, friends see only `friends` rows, no travel on a draft, the route must belong to the journey, dates in order). `test/journeys_test.dart` is new; the full suite passes (2,865 tests). Run in the iOS Simulator against the local stack, not production.
  - Checked in production after the apply: 10 operators, 20 journeys (9 trains, 11 ships), 38 routes, 5 dining partners (each code resolving to the restaurant the seed names), 20 rows in `journeys_full`; RLS on every journey table, no anon write grant and no anon-executable journey function; over REST with the public key, anon reads the 20 journeys, is refused on `journey_travels` and gets 401 on an insert. Beforehand: every country the seed uses exists, the five restaurant codes sit in the expected countries, and `wishlist_entity_type_check` was still the three-type check the migration replaces.
  - **Near-miss, the push:** `supabase db push --linked` from this branch refused, because production already held seven migrations from other branches (`20261101390000` to `20261101450000`) that this branch does not have. The CLI's own suggestion, `migration repair --status reverted` on those seven, would have marked applied migrations as never run. Instead the push ran from a scratch copy of `supabase/` with those seven files taken verbatim from their own commits; the dry run listed only `20261101500000`. None of the seven touches the journey objects or `wishlist_entity_type_check` (`20261101400000` adds `wishlist.planned_month` with its own check and column grants, all of which the journey wishlist calls stay inside). With that copy, `supabase migration list --linked` shows local and remote in agreement, 159 of 159; from this branch alone the seven show as remote-only until it is merged with theirs.
- **The new public site, step 1 of 4: its foundation, hidden** (product owner, 2026-11-16: "begin met stap 1, het fundament van de nieuwe site in een eigen map, op een verborgen testadres"). `site-next/` is an Astro 7.4.4 project that builds to plain static HTML, so every page is readable by search engines without a script. This step has the house style (ivory, forest green, the display serif; gold kept for stars and Keys), the navigation (News, Guides, Behind the pass, Events, Trends), the homepage laid out as agreed, one page per section, a 404, and a footer with the off-the-beaten-track compass: no link and no explanation until that part exists. Every block whose content comes later is a dashed placeholder naming its step, so it can't be mistaken for finished content. "In the app" buttons are one component that reads `APP_STORE_URL` in `src/config.ts`: while that is null they are a label, never a dead link. Nothing reads Supabase yet, and nothing in the database changed.
  - **Hidden:** deployed with `npx wrangler@3 pages deploy dist --project-name mantelier --branch next` to the `next` preview of the existing Pages project, at https://next.mantelier.pages.dev. Every response carries `X-Robots-Tag: noindex, nofollow` (`public/_headers`), every page has a `noindex` meta (`HIDDEN` in `src/config.ts`), and `robots.txt` disallows everything; all three were checked on the live preview. mantelier.app was checked afterwards and still serves `site/`, which is untouched.
  - **Not done, on purpose:** footer links to Privacy, Terms, Support and For hosts point at the live `site/` pages; they move over at launch, together with `auth/` and `.well-known/`, when the three noindex switches go off. The preview has no password; that is Cloudflare Access, set in the dashboard.
- **The new public site, step 2 of 4: news and interviews from Supabase** (product owner, 2026-11-16, "begin met stap 2, nieuws en interviews uit Supabase op de verborgen site"). Every published article gets its own page at `/news/<card title as a slug>` (`/news/fine-dining-wherever-you-are`, `/news/why-i-built-mantelier`), read at build time with the public anon key through RLS, so only what the app can show is shown. The body follows the app's own rules (`lib/models/news_article.dart`): paragraphs on blank lines, "Q: " a question with its short green rule, "> " a pull quote, photos placed after paragraph n with a place past the end moving to the end, small photos as a row of squares. The chefs, restaurants and hotels an article links to sit under it with a "Follow … in the app" or "Add to wishlist in the app" button. The homepage leads with the newest interview, `/news` lists every article, `/behind-the-pass` the interviews. Guide news and Trends stay a dashed placeholder that says no article exists yet, rather than an example.
  - **Photos never come from Supabase for a reader:** each is fetched once at build time and served from the site as resized WebP (for example the portrait, 214 kB stored, 25–53 kB served), cropped around its stored focus point. Photo egress is this project's main cost risk; a reader's visit adds none.
  - **A build is a snapshot.** A new or changed article appears only after the next build and deploy; a failed Supabase read fails the build rather than publishing a site with articles missing. Two articles whose card titles give the same address also fail the build. Changing a card title changes the article's address.
  - Checked on the deployed preview: every page answers 200 with `X-Robots-Tag: noindex, nofollow`, all photos load, no page scrolls sideways at 375 px; mantelier.app still serves `site/`.
- **The new public site, step 3 of 4: every restaurant, every guide** (product owner, 2026-11-16, "begin met stap 3, restaurantpagina's met alle gidsen op de verborgen site"). All 3,629 restaurants in `restaurants_full` (none expired) get a page at `/restaurants/<name>-<city>`, with the restaurant code appended only when two would share an address. Each page sets MICHELIN, The World's 50 Best, Gault&Millau and the Mantelier Selection side by side, then each guide's years (`award_history`, `worlds_50_best`, the latest `gault_millau_awards` edition as `latestGaultMillauAwardPerRestaurant` does), the articles that mention it, the verified address and the guides' own pages. `/guides` lists the four guides and "Where the guides agree", every open restaurant three or more of them recognise; each guide has its own list, MICHELIN split into one page per country. The homepage's "One restaurant, every guide" shows the open restaurant the most guides recognise (today Plénitude, Paris), chosen by rule rather than by hand. Article pages now link a mentioned restaurant to its page. Gold stays on MICHELIN stars only. Nothing in the database changed.
  - **Only data we hold, said plainly.** A guide with no row for a restaurant shows a dash. Gault&Millau says "Not in our data" rather than "Not listed", since 259 scores cover only some markets, and its list says so. `michelin_stars = 0` shows as "No star" in the MICHELIN cell, never as no award: the other guides sit beside it. Placeholder or malformed guide URLs are never linked, as `GaultMillauAward.profileUrl` in the app.
  - **Near-miss, logged rather than fixed: the 2025 World's 50 Best list has no rank 94 in production.** `worlds_50_best` holds 100 rows for 2025, 99 ranked plus one Hall of Fame, so `restaurants_full` has 99 ranks. The list page first read "1 to 100" over 99 rows; it now shows 94 as its own row, "Not in our data yet", rather than closing the gap. Which restaurant is 94 is a data question for the Michelin_Database log, not this page. The 2026 list (announced 2026-11-05) isn't in the data either, so the site says "2025".
  - **The first build took 3 minutes:** every restaurant page re-read the news links from Supabase, 3,629 identical requests. Cached once per build like the rest, it takes about 3 seconds.
  - Checked on the deployed preview: every guide page, a restaurant with and without a star, and an article answer 200 with `X-Robots-Tag: noindex, nofollow`; no page scrolls sideways at 375 px; mantelier.app still serves `site/`.
- **The new public site, step 4 of 4: events** (product owner, 2026-11-16, "begin met stap 4, het evenementenblok en de Events-pagina op de verborgen site"). `/events` lists every published event that hasn't ended, by month; each event has a page at `/events/<name>-<start date>` with when, where, admission, its own description, tickets and website, and the restaurants and hotels at it as host, venue or "taking part". The homepage's green band now lists the next four events, and a restaurant's page lists the events coming up there. 57 events at the time of the build. Nothing in the database changed.
  - **Dates follow the app exactly** (`formatEventDateAndTime`, `moderation_status = 'published'`, the one-day widened window of `eventBrowseWindowBounds`): the event's own calendar dates and local clock times, never the reader's; a time that isn't known isn't shown and isn't labelled as missing. Where a time is shown, the page says it's local to the event's city. Checked against a date-only event, a start-only event and one running from 19:00 to 00:00 the next day ("24–25 Dec 2026 · 19:00–00:00", as the app shows it).
  - **A build no longer goes stale on dates:** each listed event carries its end date and timezone, and a small inline script hides it once that date has passed where the event takes place; a month left empty disappears with it. Without script the page shows what the build saw. Seen working on the day itself: a festival in Saint-Barthélemy that ended on 15 November was in the build and hidden on the page.
  - **Not yet:** hotels at an event are named without a link, since hotels have no pages yet; private chefs linked to events (`event_chefs`, empty today) aren't read.
  - Checked on the deployed preview: the pages above answer 200 with `X-Robots-Tag: noindex, nofollow`; no page scrolls sideways at 375 px; mantelier.app still serves `site/`.
- **The hidden site rebuilds itself** (product owner, 2026-11-16, "zorg dat de verborgen site automatisch opnieuw gebouwd wordt, zodat nieuwe artikelen en evenementen vanzelf verschijnen"). `.github/workflows/site-next.yml` builds `site-next/` from live Supabase data every three hours, on a manual run and on every push that touches it, and deploys to the `next` preview only, never `main`. A run whose output is byte-identical to the last deployed one skips the deploy, so the Pages history (500 deploys a month on the free plan) only grows when something changed; every three hours is at most 240 a month. Resized photos are cached between runs, so a photo is fetched from Supabase storage once.
  - **Not working yet, on purpose:** it needs a `CLOUDFLARE_API_TOKEN` repository secret, a Cloudflare API token limited to Pages edit, which only the product owner can create; until then a run builds as a check and says so. Schedules and manual runs need the workflow on `main` (GitHub runs those only from the default branch), so they start once the site branch is merged.
  - Checked: the first run (on the push to the branch) built all 3,746 pages in 15 seconds on GitHub's runner and skipped the deploy with the "no token" notice. The product owner then added the secret (2026-11-16, an account token with only Pages Write, valid one year, no IP filter since GitHub's runners change address); a re-run deployed to https://next.mantelier.pages.dev, and a second re-run of the same output skipped the deploy with "Output unchanged". mantelier.app still served `site/` afterwards. The token can deploy any Pages project in the account, mantelier.app included; Cloudflare has no narrower permission, so the workflow's `--branch next` is what keeps it on the preview.
- **The hidden site in layout B, and no more empty ivory** (product owner, 2026-11-16, after seeing the site: "heel veel beige vlakken en links en rechts is een heel groot beige vlak met niks"; chose option B of three, and said the tops of News, Guides and Behind the pass looked odd). The homepage now opens on the lead story as a green panel beside its photo, which runs to the right edge of the screen; below it, the next five events beside the latest stories, then "One restaurant, every guide". The navigation and footer are deep green on every page. News, Behind the pass, Guides, each guide list, Events and Trends open on a full-width green band with the page's name, and a section's newest article is a full-width feature, photo beside text, instead of one narrow card. The page width went from 1,120 to 1,320 px; long lists (the guides, a MICHELIN country, the World's 50 Best) read down two columns on wide screens. The dashed "not written yet" placeholders are gone: a block with nothing to show is left out, and Trends says the first stories are being written.
  - **Near-miss:** the first version of the feature block let the photo decide its height, so a portrait made the lead 930 px tall with empty space beside the text. The photo now fills its half without setting the height.
  - Checked locally at 1,440 and 375 px: no page scrolls sideways, photos fill their halves. The hidden site picks it up through the automatic build on the push.
- **Signing in on the hidden site, with the app's own accounts** (product owner, 2026-11-16: "Akkoord met het plan: inloggen incl. tweestaps, Wishlist en Mijn evenementen. Wachtwoord vergeten via de app."). `/account/sign-in` takes the email and password of a Mantelier app account and then, for an account with two-step sign-in on, the authenticator code, trying each linked authenticator as `TwoStepRepository.verifySignIn` does; until the code is right nothing personal is shown, as `AuthGate` does. An unconfirmed email gets the app's "send a new confirmation link", landing on the existing `/auth/confirmed`. No sign-up and no password reset on the site, by decision: accounts are made in the app, and a reset link only works on the device that asked for it, so the site points to the app's "Forgot password?". The header shows "Sign in" beside "Get the app", and the member's name once signed in (on a phone, its first letter in a circle, so the app button still fits).
  - **Two features behind it.** *Wishlist* (`/account/wishlist`): restaurants, hotels and events, newest first, each removable; restaurant and event pages get a real "Add to wishlist" button for a signed-in reader. *Your events* (`/account/events`): upcoming events marked Interested or Going; event pages get the Interested and Going buttons, tapping the chosen one again removes it (`resolveIntentTap`). Same tables, columns and writes as `WishlistRepository` and `EventAttendanceRepository` (visibility `friends` for both, as `visibilityForIntent`), always filtered on the member's own `user_id`; only published events, and Interested/Going only while the event hasn't ended (`eventHasEnded`: the exact end when known, else the end of its last local day) and isn't cancelled. Confirming attendance, and so every Passport stamp, stays in the app. Nothing in the database changed: no new policy, RPC or migration.
  - **Nothing personal is ever in the HTML.** Every page stays static; the signed-in parts run in the browser with the public anon key the app already ships, and RLS decides every read and write. `/account` pages are `noindex` even after launch. supabase-js (about 55 kB compressed) loads only on `/account` and when a stored session is found; other pages read the stored session without it. The session is kept where supabase-js keeps it (localStorage, key `mantelier-auth`).
  - **Near-miss: signing out would have signed the member out of the app too.** supabase-js signs out every session of the account by default, the phone's included; the Flutter client's default is this device only. The site signs out with `scope: 'local'`. Checked: with a second session open for the same member, signing out on the site left that one in `auth.sessions`.
  - **Names of saved things come from the build**, in 16 small files by the id's first digit (`/account/catalogue/<0-f>.json`, about 17–19 kB compressed each), so a name links to the page this build made; anything newer than the build is read live by id. All of it in one file was 263 kB compressed.
  - Checked on a local Supabase stack (`supabase start` from a scratch copy, with two test members made by `site-next/scripts/local-sign-in-test.mjs` and three events copied from production's public read): wrong password, sign-in, two-step with a wrong and a right code, the account pages refusing an aal1 session, Going then switching to Interested (the update path), wishlist add and remove for a restaurant and an event, and the listing and removal of a hotel (added in the local database by hand, since hotels have no page to add one from), sign-out, at 1,440 and 375 px with no sideways scroll. **Not checked against production**: no production account was used. Hidden: the noindex switches are unchanged.
- **The hidden site shows the member's Passport, globe and visits, read-only** (product owner, 2026-11-16: "Akkoord met de indeling. Begin met fase 1: Passport, wereldbol en bezoeken, alleen bekijken."; earlier: "het paspoort en de wereldbol alleen als visualisatie … nieuwe stempels … alleen als je in de app venues als bezocht bestempeld"). Three pages behind sign-in, linked from `/account`; nothing on them writes.
  - **`/account/passport`:** the app's booklet on the green of the app: the leather cover with the member number, the data page (initials, holder, member number, valid from the first year, entries, countries and stars as two-digit counts, the countries as boxed codes, the machine-readable line, the diagonal guilloché), then the stamp pages: ivory with the concentric guilloché, "ENTRIES · VISAS" and the page number, the year of entry in the corner, three stamps a page and every year on a fresh page, placed by the same eight-anchor search as `_StampField` so they overlap as they do in the app. Pages sit side by side on a wide screen and are swiped on a phone. The stamps are built as `buildPassportVolumes` does: one stamp per visit, stay and confirmed event attendance (never per venue, never from Interested/Going), the last five calendar years, published events only. The five stamp designs (round seal, double frame, oval, octagon, postmark) and three inks are drawn as SVG from `passport_stamp_painters.dart`, and each stamp's design, ink, angle and offset come from the same FNV-1a hash of its row id as `passport_stamp_style.dart`, so a visit looks the same on the site as on the phone. Not ported: the verified-venue stamp and venue stamp artwork; such a visit gets an ordinary stamp. A stamp opens its visit; an event stamp opens the event's page when the build has one.
  - **`/account/visit?id=…`:** one visit or stay: the date, the award then, the overall and per-aspect ratings, menu, price paid, notes, wines and photos, the member's own only (`user_id` filter beside RLS). Photos come from the private `visit-photos` bucket as one-hour signed URLs, the 1600 px originals, as the app does while member-photo transforms are off. Editing, deleting, adding photos and changing who sees a visit stay in the app.
  - **`/account/globe`:** My Map's globe on a canvas, ported from `lib/features/map/globe/`: the app's own `assets/globe/countries.bin` (served at build time from that file, not a copy), the same projection, colours, horizon clipping, fit-to-places camera and pin clustering. It opens on the whole globe, large (up to 86% of the screen's height; square on a phone), turned towards the member's places, with a slow spin until touched (none with reduced motion); zoom in, zoom out and "Whole globe" buttons sit beside it. Drag to spin, scroll or pinch to zoom. A pin flies in and opens the place's visits; pins that never separate open together. Below it, every place as a list. A first version opened zoomed in on the places as the app does, which on a wide screen showed a flat crop of Europe rather than a globe (product owner: "is die nu ook mooi en groot te zien?").
  - **Data:** the build's per-id catalogue files now also carry each restaurant's and hotel's country, city and verified coordinates (about 22–25 kB compressed per file); anything newer than the build, or no longer listed, is read live by id. No new table, policy or RPC.
  - **Found on the way, not fixed here:** several rules the app enforces only in Dart aren't enforced by the database, so any client with a member session could break them, the web's own code doesn't: an event stamp for an event that hasn't ended, a venue manager's about text saved as already approved, a hotel or chef claim inserted with any status. Proposed separately as migrations for approval; "read-only on the web" is a property of the web code, not of the database.
  - **Near-miss: the first version looked nothing like the app** (product owner, 2026-11-16: "het paspoort met de stempels lijkt heel lelijk gevisualiseerd"): small stamps in a strip on a flat card, with an SVG noise filter that ate so much ink the stamps looked faded and dotted. Rebuilt against the app's own lookbook screenshots (`site/lookbook/09_passport.jpg`, `10_passport_page.jpg`, `15_stamps.jpg`): the booklet pages above, stamps at their own size, crisp ink at 90% multiplied into the paper, no noise filter, the stamp fonts at the app's weight 600.
  - Checked locally against a `supabase start` stack with a test member given four restaurant visits, a hotel stay, a confirmed event, wines and a photo (`site-next/scripts/local-passport-test.mjs`), at 1,440 and 375 px with no sideways scroll; the stars total (10) and countries (4) match the stamps. **Not checked:** a member with no stamps (the empty states), a stamp more than five years old, a production account.
- **The hidden site: following, friends and notifications behind sign-in** (product owner, 2026-11-16, phase 2 of the agreed list: "ja doe maar"). Same tables, RPCs and rules as the app; nothing in the database changed.
  - **Following:** a "Follow" button beside "Add to wishlist" on every restaurant page for a signed-in reader, and `/account/following` with the restaurants, hotels and private chefs the member follows, each to unfollow (`follows_restaurants`/`_hotels`/`_private_chefs`, own rows, as `FollowRepository`).
  - **Friends** (`/account/friends`): friends, requests received (accept, decline) and sent (cancel), finding members by name or username, and the people blocked (unblock). Every change goes through the app's RPCs (`send_friend_request`, `accept_`/`decline_friend_request`, `block_user`, `unblock_user`, `search_profiles`, `get_friends` and the rest), which hold the rules on discoverability, blocking and re-requests; the one direct write is the owner-only `friendships` delete the app also uses to cancel or end a friendship. Member photos are signed through `get_member_avatar_paths`, else initials.
  - **A member's page** (`/account/friend?id=…`): photo or initials, @username, member number, where the two of you stand (add, accept, cancel, remove friend, block, each with the app's wording), and for a friend what they share: stamps, countries, stars and average score over the visits they made visible to friends, those visits, the events they're Going to and their wishlist. RLS returns only what's shared: checked with a friend's private visit, which doesn't appear and doesn't count. "Suggest going together" stays in the app.
  - **Notifications** (`/account/notifications`): the app's list through `get_notifications_v5` (falling back as the app does), fifty at a time, the app's wording per type, a friend request accepted or declined in place, all marked read on opening as the app does; venue and trip invitations say to answer in the app. Below it the two phone-push settings (`notification_preferences`, defaults on as in the app). `/account` shows the unread count.
  - Checked locally with three more test members made through the app's RPCs (`site-next/scripts/local-friends-test.mjs`): accepting a request from the list, sending one from search, a friend's page with a shared and a private visit, follow and unfollow on Koan's page, the push setting saved, at 1,440 and 375 px with no sideways scroll. Following needs the restaurant to exist locally (`follows_restaurants` has a foreign key), so the script copies Koan and its city from production's public read. **Not checked:** blocking and unblocking end to end, a member photo (none of the test members has one), venue, trip or event notifications (none in the local data).

### Security
- **Four migrations that move app-only rules into the database, applied to production 2026-11-16** (from the 2026-11-16 audit for web sign-in: with the public anon key and a member's session, anyone can do what RLS allows, not just what the app does). Product owner, 2026-11-16: "Akkoord: pas alle vier migraties toe op productie (20261101420000 t/m 20261101450000)." Pushed with `supabase db push --linked` from a scratch copy that also held 20261101390000–410000 (applied earlier from `claude/guide-inventory` and `claude/booking-windows`, not on this branch), so the dry run listed exactly these four. Verified afterwards in production: the six insert policies read as written, `authenticated` can update only `rating`, `comment`, `visibility` and `would_recommend` on `event_confirmed_attendance`, the visits trigger exists, `anon` cannot execute its function, and `supabase migration list --linked` shows local and remote in agreement through 20261101450000. Each migration is independent:
  - `20261101420000_force_pending_on_venue_submissions` — an about text or photo submission can only be created `pending`, with no reviewer, review time or review note. Before, an active manager could insert `approved` and `venue_about_current` showed the text without review.
  - `20261101430000_harden_claims_hotels_and_chefs_insert` — hotel and private-chef claims get the restaurant-claim rule from `20260928120000`; `review_note is null` is added to all three. A self-approved claim granted no edit rights (that is `venue_managers_*`), but it sent no admin email, escaped the one-pending-per-venue index and showed "my venue" in the app.
  - `20261101440000_enforce_event_attendance_eligibility` (*needs a product decision*) — a confirmed attendance, the only source of an event stamp, can only be inserted for a published, uncancelled event that has ended, by the app's own `eventEndReferenceInstant`; editing stays allowed after a later cancellation, as the app does. Update is narrowed to the four columns the app edits, so an attendance can't be moved to another event.
  - `20261101450000_freeze_visit_award_and_date` (*needs a product decision*) — a trigger sets `stars_at_visit`/`keys_at_visit` from the venue's current award on insert, exactly what the app sends, and keeps them on update; a visit can't move to another venue or be dated after today anywhere on earth (Pacific/Kiritimati, so a visit logged at 00:30 in Amsterdam still counts as today).
  - Production checked read-only first: zero about/photo submissions, zero hotel claims, one private-chef claim (approved, reviewed), zero confirmed attendances, 37 visits none of which would have been changed. Every shipped build sends only what the new rules allow; the visit trigger overwrites instead of rejecting so no build breaks.
  - **Near-miss:** requiring `duplicate_of_submission_id is null` on photo submissions, as the team-submission policy does for its own columns, would have rejected every duplicate the `BEFORE INSERT` trigger flags, since `WITH CHECK` sees the row after that trigger. Left out, and tested.
  - Tested on a local stack (all migrations replayed from scratch plus these four): 42 cases as `authenticated` with a member's claims, covering each app payload, each forged value, the edit paths and `has_function_privilege('anon', …)` on the new trigger function, all as expected. **Not tested:** the app itself against the local stack, and production.
  - **Not covered:** `secure_password_change` on the hosted project could not be read (the dashboard needs the owner's sign-in); `supabase/config.toml` has it `false`, which only affects local stacks.

- **When do you want to go, and a reminder the day before bookings open** (product owner, 2026-11-16: the restaurants people dream of open their books months ahead and fill at once). A restaurant on the wishlist may carry the month and year someone would like to go: asked once, right after the heart, always skippable ("Not sure yet"), and set, changed or cleared later from its wishlist card. When the restaurant's booking window is known, the card says when that month opens ("Bookings for May open 2 March at 10:00 (Paris time). We'll remind you the day before.") or that it is already open, and at 10:00 in the member's own time on the day before, they get an in-app notification and a push. A claimed restaurant's manager sets the window under Venue → Booking window. Migration `20261101400000_add_wishlist_month_and_booking_windows.sql`; `send-push` gains the type. **Live on production 2026-11-16** (product owner, in chat: "first deploy send-push, then apply migration 20261101400000 to production, and check the revokes and the cron job"): `send-push` deployed first (it still answers its own `Unauthorized` without the webhook secret, so `verify_jwt = false` held), then the migration with `supabase db push --linked` after a dry run showed it as the only pending one. Checked on production: none of the 16 new or renamed functions is executable by `anon`, and `booking_reminders_enabled`, `member_timezone`, `send_booking_window_reminders` and `get_notifications_v6_rows` not by `authenticated` either; `booking-window-reminders` is scheduled `5 * * * *` and active; one manual run returned 0 (no months or windows exist yet); `authenticated` can select `wishlist.entity_id` but not `planned_month`; the ledger agrees. The hidden site's wishlist reads and writes (`site-next/src/lib/account/data.ts`) name their columns, so the column grants leave it working. Members need the next build to set a month; installed builds see nothing new. **First researched windows on production 2026-11-17** (product owner, in chat: "Yes, apply import_booking_windows_20261117.sql to production and confirm the result"): 37 restaurants (4 NL, 15 World's 50 Best 2026, 18 three-star) whose own site or booking page states the rule, every one re-fetched and matched word for word, written as `source_kind = 'research'` by the prepared, single-transaction `supabase/data/enrichment/booking_windows/import_booking_windows_20261117.sql` (aborts unless each code + country resolves to exactly one restaurant; skips any restaurant with a manager or an existing window). Production afterwards: 37 windows, all research, all with a source URL, plus Mirazur's 3 dated releases; spot-checked openings for May 2027 match the stated rules (DiverXO 31 Jan 00:00, Odille 1 Feb 10:00, Mirazur 4 Jan 09:00, Eleven Madison Park 1 Apr). Research, coverage and the rows held back: `supabase/data/enrichment/booking_windows/RUN_LOG.md`.
  - **Decided by the product owner, 2026-11-16:** a manager's window goes live at once, like opening hours; the month is private to the member (friends read the rest of the wishlist, not this); 10:00 member time, from their home country's timezone, else Amsterdam; a known date with no known time still reminds, naming no time.
  - **Never an estimate.** Four shapes: rolling (day X opens X + N days or months, at a local time), monthly (on day D, the month M ahead opens), seasonal (one-off releases) and unknown. Unknown, or no row, means no reminder and no status line. An unknown time stays NULL. The timezone must be one of the restaurant's country's. Every restaurant has no window today: collecting them for the top restaurants is planned in `supabase/data/enrichment/booking_windows/README.md`, nothing researched or imported.
  - **One implementation of the dates.** `booking_window_opening`, `booking_window_status` and `booking_reminder_due` are pure SQL functions used by both the hourly pg_cron job (`booking-window-reminders`) and the app's `get_my_wishlist_plans()`, so the card and the push cannot disagree. 73 checks in `supabase/tests/booking_window_test.sql` (rolling, monthly, seasonal, month already open, unknown, day 31 in short months, leap years, Tokyo/New York/Amsterdam, both European DST changes, an opening in the skipped hour) plus an end-to-end run: privacy, manager permission, the job never reminding twice, the switch-off. Run on a local stack; all pass. `send-push` copy: 6 new Deno tests, 25 pass.
  - **Later a Pro feature:** `booking_reminders_enabled(user)` is the one server-side switch the job and the app ask; today it is true for everyone. A member can turn the push off under Notifications → Booking reminders; the in-app notification stays.
  - **Privacy by column, not row.** RLS cannot hide a column, so `authenticated` lost table-level SELECT/INSERT/UPDATE on `wishlist` and got them back per column, without `planned_month`. Every reader in the app names its columns and the SECURITY DEFINER reports run as the owner; a test as a friend gets `permission denied` on the month and still reads the row.
  - **Installed builds:** the type follows the v-pattern: this build reads `get_notifications_v6`; v5 and the older unread counts leave `booking_window_opening` out.
  - **Near-miss:** the month sheet overflowed in the 800×600 test window and its four year chips overflowed narrow phones; it now scrolls and wraps. Caught by its own widget test before any device. In the simulator the wrapped year chips then each stretched across the whole sheet (a centred container fills whatever width a Wrap offers); they now fit their label, held by a test that fails without the fix.
  - Not done here: the add-to-wishlist sheet on the Wishlist screen saves without asking the month (it stays open for several saves; the month is set from the card). Hotels get no month. A push tap opens Notifications, where the row opens the restaurant.
---

## v1.5.7 (34) — 2026-11-06

(33) is already in App Store Connect. This build adds the new look of interview questions; no backend change since (33).

**Ledger: 151, local and remote in agreement.** Schema diff before the push, on all 151 migrations replayed on a scratch stack: the dumps (18,013 lines production, 18,019 local) differ only in 6 blank lines; storage and auth compared directly, identical apart from the three Supabase platform storage triggers already noted under (30).

### Changed
- **Interview questions stand apart from the answers** (product owner, 2026-11-06, option C of three): a question now has more room above it, a short green rule and a larger size (21 instead of 19), so it no longer reads as one more paragraph. Every interview at once; needs the next build. A test holds that each question, and no answer, has its rule.

---

## v1.5.7 (33) — 2026-11-06

(32) is already in App Store Connect. This build adds the short card title on news articles and "In the news" on a private chef's page; their migration, `20261101380000`, and Lucas de Jager's interview went live the same day, before this build.

**Ledger: 151, local and remote in agreement.** Schema diff before the push, on all 151 migrations replayed on a scratch stack: the dumps (18,013 lines production, 18,019 local) differ only in 6 blank lines; storage and auth compared directly, identical apart from the three Supabase platform storage triggers already noted under (30).

### Added
- **A lookbook for conversations with venues** (product owner, 2026-11-04): `site/lookbook.html`, real app screens filled with invented venues, events and members on a local stack (`scripts/seed_lookbook.py`, never for production) and Unsplash photos, so a venue can see the app as it will look once venues have added their own content. Reachable by link only: not linked from the site, `noindex`. Says at the top and in the footer that everything on it is fictional. Sources in `docs/Design/LOOKBOOK.md`.
- **A weekly email about sign-ups that look automated** (product owner, 2026-11-04): `20261101360000_add_signup_watch.sql` and the `notify-signup-watch` Edge Function. Mondays at 07:00 UTC, also in a quiet week, so that no mail means the watch itself is broken. Flags many sign-ups, a burst in one hour, many unconfirmed accounts, an uncommon domain with 3 or more accounts, and 3 or more accounts on one mailbox. Reports only: blocks nothing, stores nothing, and carries counts and at most an uncommon domain, never an address or user id. It can't see a patient bot on different real mailboxes.
- Migration `20261101370000_add_eg_2026_country_and_cities.sql`: country EG and
  7 towns (data only) for MICHELIN's 13 Key hotels in Egypt. Applied to
  production on 2026-11-04 from `claude/michelin-eg-2026` with plain
  `supabase db push --linked`. The ledger went from 149 to 150, and local and
  remote agree. The catalogue data is in
  `supabase/data/enrichment/michelin_eg_2026/`.
- **A short card title for news articles, and "In the news" on a private chef's page** (product owner, 2026-11-06, for the first real interview): migration `20261101380000_add_news_card_title.sql` adds an optional `news_articles.card_title`. The News tab's cards, the band an article's photo shrinks to and the chef's page show it; the article itself still opens with the full title, and without one everything shows the title as before. A private chef's page now lists, after Events, the published articles linked to the chef in `news_article_chefs`, the reverse of the article's own "In this interview". This build reads `card_title`, so the migration has to be on production before it ships, or the News tab and the chef's news list fail to load. Applied 2026-11-06 from `claude/lucas-interview` with plain `supabase db push --linked`; the column is there. **Ledger: 151, local and remote in agreement.**
- **The first real interview, and the placeholders gone** (product owner, 2026-11-06): "Fine Dining, Wherever You Are: A Conversation with Private Chef Lucas de Jager", card title "Fine Dining, Wherever You Are", published on production by `supabase/data/news/lucas_de_jager/` (`APPLY.md`): five photos in `news-images/lucas-de-jager/`, the article with four of them in the text, and its link to the chef. The same transaction deleted the three "Example …" articles (`cccccccc-…-0001` to `…0003`), and with them, by cascade, their 4 photo rows and 20 opens. Checked after the run: each photo URL answers 200 with the uploaded bytes, the stored body's md5 matches the prepared file, and the anon key sees exactly two articles, the interview's four photos and the chef link. Builds before this one show the full title on the card, cut short; the chef page's "In the news" needs this build.

### Changed
- **New text for "Why I Built Mantelier"** (product owner, 2026-11-06): body and title (capital B, as in the new heading) replaced on production with `supabase/data/news/prepared_why_i_built_mantelier_body_20261106.sql`, the previous body kept in `why_i_built_mantelier_body_before_20261106.txt`. Data only, live in every build. Checked after the run: the stored body's md5 matches the prepared file, the anon key reads the new title and body, and the header, the four small photos and both venue links are unchanged.

### Fixed
- **Links in sign-up and password-reset mails now use our own domain** (product owner, 2026-11-04): `auth.mantelier.app` is active as a Supabase custom domain, with a CNAME and a TXT record in Cloudflare (DNS only). The mails came from mantelier.app while their button pointed to `wcmxugunvwsrulcpeyrc.supabase.co`. Resend warned about that mismatch, and on 2026-11-02 a company mail server refused a confirmation mail as "Blocked due to content"; the mismatch is the likely cause, not a proven one, since that mail also still had Supabase's bare default text. No code or build needed: the old address keeps working, so installed builds, the site and Studio are unchanged. Checked on 2026-11-04 with a real mail: the link starts with `auth.mantelier.app`, the mail has the Mantelier style and the step completes. Not yet checked: delivery to a strict company mail server, the only test that shows the refusal itself is gone.

---

## v1.5.7 (32) — 2026-11-04

The build meant for App Review; (31) went to TestFlight first.

### Changed
- **Deleting a trip takes your own plans with it** (product owner, 2026-11-04, reversing the original "detach, never delete" from `20260810120000`): left behind they read as plans nobody made. Others' plans on a shared trip stay with them, through the column's ON DELETE SET NULL, and leaving a trip still keeps yours. No migration. The 14 standalone plans already on production are not touched: there is no way to tell leftovers from plans made without a trip.
- **A visible button on planned visits**: edit, cancel and delete were behind a long press nobody could find.

### Fixed
- Near-miss while changing trip deletion: RLS refuses a delete by returning no rows, not an error, so a refused trip would still have lost its plans. The plans now go only after the delete returns the trip's row.

---

## v1.5.7 (31) — 2026-11-04

The build meant for App Review, with these changes on top of (30). The fixes for the status bar, back arrows, Explore cards and Hottest Places were seen in the screenshots for the venue lookbook.

### Changed
- **A calmer map everywhere** (product owner, 2026-11-04): MapTiler's `basic-v2` instead of `streets-v2`, which drew its own restaurants, hotels and cafés beside our pins, where they read as places Mantelier recommends. One setting, so every MapTiler map changes with it.
- **The trip map says what is where** (product owner, 2026-11-04): a 13-pixel dot, square and diamond with no legend became 28-pixel pins with the icons of the visited map: cutlery, a key, a calendar, a check for what is on the trip. Zoomed in, a pin shows its name, places on the trip and events from zoom 12, the rest from zoom 14. A name moves to the left of its pin when the right is taken and stays hidden when neither side is free (`pickTripMapLabels`).
- **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`), decided by the product owner 2026-11-04: the app had declared iPad support without ever being looked at on an iPad, which would also ask for iPad screenshots. iPhone apps still run on an iPad in compatibility mode.

### Added
- **That Mantelier is independent, at the foot of Profile**, in the same words as `site/terms.html`, which a test holds them to. Until now it was only on the website, while the app shows MICHELIN stars and Keys throughout.

### Fixed
- **The time and battery were dark on green and photo app bars**: the venue, event, chef and news heroes and the Events screen took the theme's dark status bar, which is meant for its ivory app bars. They now set it light themselves.
- **The back arrow on Events was nearly invisible**: `foregroundColor` loses to the theme's dark `iconTheme`, so the arrow was dark on dark green.
- **Explore's cards had a blank third**: the rails were a fixed 340 and 176 points, sized for 1.6x text. They are now worked out from the text scale, and a test holds a two-line name at 1x to 2x. Near-miss caught by the tests: the "Mantelier Selection" line is taller than a row of stars, so the first height was a few points short.
- **The back arrow disappeared on light photos**: on venue, event and chef heroes it was a bare ivory glyph, while the wishlist button beside it had a dark circle. It now has the same circle over a photo (`EditorialBackButton.onPhoto`), and stays bare on flat canvases.
- **Hottest Places showed a letter instead of the venue's photo**: its thumbnail was hard-coded to none, and the query never asked for one.
- Near-miss on the map names, seen in the simulator: `Text` inherited the theme's letter spacing while `TextPainter` measured without it, so names came out wider than their marker and were cut short ("Canal T…"). The style now sets its spacing outright.

---

## v1.5.7 (30) — 2026-11-04

Build 29 was made from `014b73f`. This build carries the wines on a visit,
the computed overall with Atmosphere and the overall alone on venue and
visit pages, and the first map on the trip screens since build 24: their
backend was already live. Schema diff against production run before this
bump: the dumps differ by blank lines only, and storage and auth match apart
from the Supabase platform triggers under Fixed.

### Added
- **Atmosphere, and overall as the average of the scores given** (product owner, 2026-11-04): hand-picked whole numbers tied at the top of every ranking. A new Atmosphere score on restaurants; `visits.rating` is now computed by the database from the scores filled in, blanks left out, so food alone makes the overall that food score. The overall control is gone from the form, which shows the result as you score. Everywhere an overall appears it shows one decimal. Migration `20261101340000_add_atmosphere_and_computed_overall.sql`, applied 2026-11-04; it recomputed the 18 existing rated visits, 7 of which moved by half a point or more, overwriting what members picked by hand. An export of the scores from before it was taken first and kept outside the repository. The app side comes with the next build. Shipped builds keep working: what they send as overall is ignored when any score is present, and they show 8.7 as 8 until they are gone.
- **The overall alone on venue and visit pages** (product owner, 2026-11-04): one number, with what it is made of opening beneath it on a tap, highest first and blanks left out. `VenueOverallScore` replaces the row of rings, which at six on a restaurant read as a dashboard and cut "Atmosphere" short.
- **"What members score you on" in Studio's Pro tab** (product owner, 2026-11-04): per restaurant and hotel, the average per score and how often it is filled in or left blank. Each member once, on their latest visit. Shown from 5 members, and when filled in or blank is under 5 both are hidden, since they add up to the total and the small one could be worked out by subtraction. Live on 2026-11-04: the privacy policy in `site/privacy.html` first, then migration `20261101350000_add_studio_venue_scores.sql`, then `studio/`. **Ledger: 148, local and remote in agreement.** `20261101320000` on `claude/event-expected-soldout` is still unapplied and must be renamed past these before it is.
- **Wines on a visit or stay** (product owner, 2026-11-04): an optional "What we drank" in the review and on the visit page, reading like a wine list. Producer, wine, year or "No year", and size (Glass, Half, Bottle, Magnum, Other), each optional. Suggestions come from the member's own earlier wines. A wine is exactly as visible as its visit. Live on 2026-11-04: the privacy policy first, then migration `20261101330000_add_visit_wines.sql`; the app side comes with the next build. **Ledger: 146, local and remote in agreement.** The unapplied `20261101320000` on `claude/event-expected-soldout` now sorts before an applied migration, so it needs renaming to follow the highest before it is applied.

### Fixed
- The trip map and the event location picker said "The map can't be shown right now" in builds 25 to 29: the main checkout's gitignored `.env`, which archives are made from, had no `MAPTILER_KEY`, and `MapTilerConfig.key` returns null silently. Added 2026-11-04; the key names in that file are now checked at every version bump.
- Near-miss in this build's schema diff: production's `storage.buckets` has three triggers the replay does not (`protect_active_lifecycle_states`, `wake_lifecycle_on_policy_write`, `wake_lifecycle_on_versioning_enable`). Not drift: Supabase's own storage migrations added them on 2026-11-04 at 07:51 UTC (`lifecycle-writer-coordination` and neighbours in `storage.migrations`), and their functions belong to `supabase_storage_admin`. The storage half of the diff will show them until the CLI's local storage image catches up.
- Near-miss on the new scores report: hiding only the small one of filled in and left blank would still have given it away, because the two add up to the members total shown beside them. Both are hidden when either is under 5.
- Near-miss on the new wines, seen in the simulator: `.order()` in `supabase_flutter` defaults to descending, so wines showed last-first until `ascending: true`. Would recur on any new ordered list; tests with a fake repository don't catch it.

### Added
- **67 events in production** (data, no migration, no build), 2026-11-04: world event batch 1, 30 to 97 events, 80 venue links, no photos, no pushes (the hosts had no followers). `docs/Architecture/Events/WORLD_EVENT_BATCH_1_PRODUCTION_APPLY.md`.
- Migration `20261101310000_add_bh_ky_mu_countries.sql` applied 2026-11-04 (BH, KY, MU), then Cayman Cookout 2027: 98 events. **Ledger: 145, local and remote in agreement** on the branch carrying the migration; not on main yet.
- Migration `20261101290000_add_gr_cities.sql`: 20 Greek towns (data only,
  `cities` rows) for the MICHELIN Greece pass. Applied to production on
  2026-11-04 from `claude/michelin-gr-2026` with plain
  `supabase db push --linked`. The ledger went from 142 to 143, and local
  and remote agree. The catalogue data that goes with it is in
  `supabase/data/enrichment/michelin_gr/`.
- Migration `20261101300000_add_europe9_2026_countries_and_cities.sql`:
  countries CZ, EE, LT and LV and 35 towns (data only) for the MICHELIN pass
  over nine European countries. Applied to production on 2026-11-04 from
  `claude/michelin-europe9-2026` with plain `supabase db push --linked`. The
  ledger went from 143 to 144, and local and remote agree. The catalogue data
  that goes with it is in `supabase/data/enrichment/michelin_europe9_2026/`.
- Contact data on production, 2026-11-05: Greece (QA-431) and the 41-country
  world round, by `APPLY_2026-11-05.md`. 386 Place IDs, 465 phones and 327
  websites, written only into empty fields. Data SQL, no migration, so the
  ledger is unchanged. Details in the Michelin_Database changelog.

### Fixed
- `prepared_gr_2027.sql` was tested only on scratch PostgreSQL with
  PostGIS stubbed, because Docker isn't installed on this machine. Its
  first real run was production. Its opening checks and the row-by-row
  comparison afterwards found no difference. The risk recurs on any
  machine without Docker.
- `prepared_europe9_2026.sql` was also tested only on scratch PostgreSQL
  with PostGIS stubbed, so its first real run was production too. The row-by-
  row comparison afterwards found no difference.
- The first run of that pass's `test_scratch.sh` printed "ok" on every guard
  while the server wasn't running: it counted any failed `psql` call as a
  correct abort, and Postgres won't start on this Mac without `LC_ALL`. The
  script now requires a real SQL error and stops if the server or the seed
  fails. A test that treats failure as success recurs wherever a guard is
  only ever expected to fail.

---

## v1.5.7 (29) — 2026-11-02

Build 28 went to TestFlight from `1364bb2`. This build carries the News
work that came after it: the tab in three parts, the photo band, photos
inside articles (large and small), interviews with questions and pull
quotes, and the light status bar on the green tabs. Their backend —
migrations `20261101270000` and `20261101280000`, the example articles
and the new photos for "Why I built Mantelier" — went live the same day,
before this build.

**Ledger: 142, local and remote in agreement.** Schema diff before the
push, on all 142 migrations replayed on a scratch stack: the dumps
(17,680 lines production, 17,686 local) differ only in the 6 known blank
lines; storage and auth compared directly, 30 rows each, identical.

### Added
- **Small photos in articles** — `news_article_photos.size` ('large',
  the default, or 'small'; migration
  `20261101280000_add_news_photo_size.sql`). Small
  photos at one place sit as a row of squares, four across, that open
  full size on a tap, with their captions said once under the row.
  Asked for by the product owner for the credits at the foot of "Why I
  built Mantelier". Applied 2026-11-02. **Ledger: 142, local and remote
  in agreement.**
  The same day, on the product owner's request, that article got new
  photos in production: five files under `news-images/why-mantelier/`,
  the team photo as its header (focus 0.5/0.2, replacing
  `news-images/moments-barcelona.jpg` at 0.5/0.1, which stays in the
  bucket) and four dishes as small photos at its foot, credited "Photos
  from my internship, by chef Raul Balam Ruscalleda." The header shows
  in every build at once; the small row needs the next one.
- **News in three parts, and richer articles** (product owner,
  2026-11-02, options B and 3):
  - the News tab opens with a quiet "Why Mantelier" card, then a row of
    Interviews with portrait photos, then Stories as before;
  - an article's photo now stays on screen: as you scroll it shrinks to
    a band under the status bar with the title in it, instead of
    scrolling away;
  - photos inside the text: one shows full width with its caption, two
    or more at the same place as a gallery to swipe through;
  - interviews read "Q: " paragraphs as questions and "> " as a pull
    quote, open with a larger introduction, and list their venues as
    "In this interview".
  Migration `20261101270000_add_news_sections_and_photos.sql`
  (`news_articles.section`, `news_article_photos`, the current article
  set to "about" by id). Applied 2026-11-02. **Ledger: 141, local and
  remote in agreement.**
  On the product owner's request, three clearly marked placeholder
  articles went to production the same day, to fill the new sections
  until real interviews exist: two "Example interview: …" and one
  "Example story: …", ids `cccccccc-0000-0000-0000-000000000001` to
  `…003`, photos from picsum.photos. They are visible to every build,
  including the App Store one. To remove them:
  `delete from news_articles where id in ('cccccccc-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000003');`
  (their photos go with them).

### Fixed
- **The status bar's time and battery were dark on the green tabs.**
  Explore, News, Passport, Community and Profile open on deep green, but
  the tab shell set no status bar style, so it took the theme's dark
  default and the icons were nearly invisible. The shell now sets the
  light style, the same AnnotatedRegion the green pushed screens already
  used. Would recur on any new green screen without its own AppBar.

---

## v1.5.7 (28) — 2026-11-02

A new version number because 1.5.6 is already live in the App Store.
Build 27 (1.5.6) went to TestFlight from `aa9e0e3`. This build carries the app
side of the venue insight tracking below: the open sources, ticket and
website taps, Explore's search and filter signals, cards seen in lists
and gallery photos seen. Its backend — migrations `20261101250000` and
`20261101260000`, `send-push`, Studio and the privacy policy — went live
the same day, before this build.

**Ledger: 140, local and remote in agreement.** Schema diff before the
push, on all 140 migrations replayed on a scratch stack: the dumps
(17,624 lines production, 17,630 local) differ only in the 6 known blank
lines; storage and auth compared directly, 30 rows each, identical.

### Added
- **Venue insight tracking** — nine data points for Studio's Basic and
  Pro tiers, asked for by the product owner on 2026-11-02 (plan §5,
  analytics contract §5 "Venue insights"):
  - event Tickets and website taps;
  - where a venue or event page was opened from (`AnalyticsOpenSource`,
    passed explicitly at every route into a detail page), and for a venue
    opened from a news article or an event, which one;
  - what Explore searches named (cuisine family, country, city, venue —
    never the text) and which filters were chosen;
  - cards shown in lists (`ImpressionBuffer`, `record_impressions()`);
  - push delivery of new-event notices (`notifications.push_sent_at`,
    set by `send-push`);
  - searches that found nothing;
  - every Interested/Going change, including taking it back, and whether
    a friend had already marked the event (server-side trigger);
  - gallery photos looked at.
  Live on 2026-11-02, in this order: the updated privacy policy
  (`site/privacy.html`) first, since the Interested/Going trigger records
  from the moment the migration applies; then migration
  `20261101250000_add_venue_insight_tracking.sql`; then `send-push`;
  then Studio, whose Basic and Pro tabs show all of it (the two panels
  that were examples now read real data). The app side ships with the
  next build. **Ledger: 139, local and remote in agreement.**

- **Usage retention** — raw usage rows are now kept 24 months, cards
  seen in lists 13 months; then only anonymous monthly totals remain
  (`usage_monthly_totals`, rows and distinct members, no user id),
  written by a monthly pg_cron job, `prune_usage_records()`, just before
  it deletes the raw rows. On production the oldest usage row is from
  2026-09-19, so nothing is deleted before October 2028. Live on
  2026-11-02: the privacy policy's "How long we keep it" first, then
  migration `20261101260000_add_usage_retention.sql`. **Ledger: 140,
  local and remote in agreement.**

### Fixed
- Near-miss, caught on a replay before anything shipped: a CHECK that a
  ticket or website tap names its event would have refused **deleting
  the event**, because `app_usage_events.event_id` is `on delete set
  null`. The rule stays in the app instead. Would recur for any shape
  CHECK on a column a foreign key nulls.
- Near-miss: the first impression buffer flushed on a 20-second
  `Timer`, which failed every widget test that built a tracked card
  ("A Timer is still pending"). It now flushes on the next card after
  20 seconds, at 200 waiting, and when the app goes to the background —
  no timer, so no test needs a workaround.

---

## v1.5.6 (27) — 2026-11-02

Build 26 went to TestFlight from `6773d37`. This build carries what came
after it:
- the admin-only Studio row in Profile (`claude/admin-studio-link`);
- the always-location purpose string that Apple's scan of 26 asked for
  (`claude/location-purpose`).

Everything else below is backend, website or Studio, and went live on
its own the same day:
- admins need two-step sign-in;
- Studio, with its Basic and Pro tabs;
- the new auth email templates.

**Ledger: 138, local and remote in agreement.** Three migrations went to
production after 26:
- `20261101220000_admins_require_two_step`;
- `20261101230000_add_admin_studio_report`;
- `20261101240000_add_studio_tier_reports`.

Builds 26 and older already work with all three. 26 asks for the code at
sign-in. The other two serve only Studio.

**Schema diff (2026-11-02, before the push): clean.** All 138
migrations were replayed on a scratch stack.
- `db dump --linked` against `--local`: 16,917 and 16,923 lines, which
  differ only by the 6 known blank lines (pg_net's filtered grants).
- Storage and auth, compared directly: 30 rows each side, identical.

### Added
- **A Studio row in Profile, for admins only** (`claude/admin-studio-link`,
  2026-11-02). It sits under Review and Insights and opens
  `studio.mantelier.app` in Safari. Like the other external rows
  (Website, Privacy policy), it never opens an in-app webview. It shows
  only when `is_admin()` is true, which needs the code since
  `20261101220000`. Studio keeps its own sign-in with the code; the
  app's session doesn't carry over. Seen in the simulator against a
  local replay. There, and only there, `is_admin()` was relaxed so the
  preview could sign in by password; that database was deleted
  afterwards. There is no widget test, as for Review and Insights:
  `ProfileScreen` reads Supabase directly, with no seam for the
  admin check. Goes out with the next build.
- **Plan: "Multiple venues and groups"** (plan §7, open). An account can
  already manage several venues. A chain needs a group above venues,
  roles in it, a decision on who pays, and suppression that survives
  adding venues up. What it is worth is for the phase 3 pilot to find
  out.

- **Studio: Basic and Pro tabs** (`claude/studio-tiers`, migration
  `20261101240000_add_studio_tier_reports`, written, applied and
  deployed 2026-11-02; ledger 138, local and remote in agreement).
  Checked on production after the push: anon can't execute any of the
  four functions. `studio.mantelier.app` serves the three tabs with no
  console errors. Not signed in there: that's the product owner's
  account. They show what one venue would see on each
  subscription, for conversations with venues about the future state
  (plan §4). Nothing here is visible to venues yet.
  - **Basic** (one venue):
    - visitors, followers, wishlist saves, members who recorded a
      visit, members who tapped through, and the rating;
    - visitors, new followers and saves per month over 12 months;
    - taps by kind;
    - the venue's own events: viewed, Interested, Going, attended.
  - **Pro**, everything in Basic plus:
    - the audience by home country and by age group;
    - "Venues like yours": you next to the median and the top quarter
      of the same city, or else the same country and stars, from 5
      peers;
    - members planning a trip to the venue's city, by month;
    - the market across all of Mantelier: popular cuisines; event kinds
      and tags; who looks where (member country × restaurant country);
      cuisines by member country; trip destinations; event interest by
      country.
  - **Numbers as a venue would see them.** Every count of people under
    5 is null, shown as "fewer than 5" (a hairline in charts). The
    rating shows from 3 raters, as Rankings does. Peers are only ever a
    median, never another venue's own number. Months, not days.
  - **Example venue.** A fictional venue with example data, under a
    banner saying so, is the default in both tabs. In a conversation
    with one venue, no other real venue's numbers are on screen; a
    searched real venue carries "Show them to this venue only".
  - **Not measured yet**, shown with an "Example" badge for every venue:
    how members found the venue, and what they search for (as matched
    cuisines, cities and venues — decision 1). Both wait for the
    tracking in plan §5, with its privacy policy update.
  - Three admin-only RPCs: `admin_studio_find_venues`,
    `admin_studio_venue_report`, `admin_studio_market_report`, plus the
    helper `studio_suppress`. All go through `is_admin()` (aal2), and
    execute is revoked from public and anon in the same migration.
  - Tested on a local replay of all 138 migrations with fictional
    venues and 80 members:
    - anon can't execute any of the three; a member and a code-less
      admin get `not_admin`; an unknown venue raises "venue not found";
    - a real venue's report shows suppressed months as null and the
      rating from 3 raters;
    - in the browser: Basic and Pro with example data and with a
      searched real venue;
    - phone width: the market tables first stretched the page to 518px
      (grid children default to `min-width: auto`). Fixed in the CSS,
      and now 375px with the tables scrolling inside their panels.
  - Fixed before release: an upcoming event's Attended showed "fewer
    than 5"; it now shows "–".

- **Mantelier Studio, the admin dashboard on the website** (phase 1 of
  `docs/Architecture/VENUE_INSIGHTS_AND_SUBSCRIPTIONS_PLAN.md`, written,
  applied and deployed 2026-11-02; ledger 137, local and remote in
  agreement). A separate static site in `studio/`, in its own
  Cloudflare Pages project `mantelier-studio`. It is live at
  `mantelier-studio.pages.dev`, and `studio.mantelier.app` follows once
  the product owner adds it as a custom domain.
  - Sign-in uses the app account. Before the code, `is_admin()` is false
    for everyone (`20261101220000`), so the studio asks
    `admin_two_step_pending()`, new in this migration, whether this is
    an admin still owing a code. A member who isn't an admin sees "No
    access" and is never asked to set up an authenticator. An admin then sets up two-step sign-in
    (TOTP) the first time, and enters a code every time after. The
    session lives in the tab only (`sessionStorage`).
  - Migration `20261101230000_add_admin_studio_report` (renumbered from
    `20261101220000` before ever being applied, since
    `20261101220000_admins_require_two_step` took that number on main):
    `admin_studio_report(p_days)` returns one jsonb document with
    headline numbers, weekly members and active members, screens,
    Explore searches and filters (never the text), top venues with taps
    and new followers, events with opens, Interested, Going and
    attended, and upcoming trips by destination country. It refuses
    unless the caller is an admin **and** the session passed two-step
    sign-in (`aal2`); it checks the code first, so a password-only
    session gets `mfa_required`, not `not_admin`. Execute is revoked from public and anon in the
    same migration. Members by country and age come from the existing
    `admin_get_member_insights()`.
  - Counts only, never a person. Admin numbers are not hidden below 5;
    that rule is for what leaves Mantelier, which is phase 2.
  - Charts are plain SVG and all text goes in with `textContent`.
    `_headers` sets noindex, a strict Content-Security-Policy, and
    blocks framing.
  - `supabase/config.toml` turns TOTP on for local stacks, so a local
    replay can sign in to the studio the way production will.
  - Tested again after `20261101220000`, on a local replay of all 137
    migrations, in the browser:
    - an admin without an authenticator is sent to set one up, and the
      code opens the dashboard;
    - signing in again asks for the code;
    - a member gets "No access" with no set-up step.

    Checked on production after the push: anon can't execute either
    function. The live page sends noindex, the CSP and `DENY` for
    framing, and loads with no console errors.
  - First tested on a local replay of all 136 migrations with seeded
    fictional venues and members: anon has no execute; an admin
    without two-step is refused (`mfa_required`); a member with
    two-step is refused (`not_admin`); an admin with two-step gets the
    report; `p_days` is clamped to 1–365. In the browser: first sign-in
    sets up the code and opens the dashboard, a wrong code shows an
    error, signing in again asks for the code, a non-admin lands on "No
    access", and phone width has no sideways scroll.
  - Production's TOTP setting was confirmed on by the product owner in
    the Supabase dashboard. Not tested: signing in on production (the
    product owner's account, the product owner's to do), and the studio
    on `studio.mantelier.app`, which doesn't exist yet.
### Changed
- **Admins need two-step sign-in** (`claude/admin-two-step`, migration
  `20261101220000_admins_require_two_step`, written and applied
  2026-11-02, after build 26; ledger 136, local and remote in
  agreement). Checked on production after the push: `is_admin()`
  requires `aal2`, anon has no execute, and the one admin has a
  verified authenticator. `is_admin()` is now true only when the session's token
  says `aal2`, so a stolen admin password opens nothing admin. It stays
  the single source of that permission, and every admin path goes
  through it, evaluated as the caller, so this one change covers them
  all:
  - `get_review_queue` and the 16 `admin_*` RPCs;
  - the admin read policies on `events`, `event_restaurants`,
    `event_hotels`, `event_chefs`, and on storage for
    venue-photo-submissions;
  - `publish-venue-photo`'s admin path;
  - the app's Review and Insights rows.

  That list was taken from production with a query over `pg_proc` and
  `pg_policies`, not from memory. The service_role dashboard fallback
  never calls `is_admin()` and is unaffected. No app change: build 26
  asks for the code at sign-in, and the only admin is on 26 with an
  authenticator. An admin on an older build, or without an
  authenticator, is no longer an admin, which is the point. CLAUDE.md
  records the rule under "Venue permissions".
  - Tested on a local replay of all 136 migrations:
    - admin, password only (`aal1`): `is_admin()` false; a submitted
      event is hidden by `events_admin_read`; `get_review_queue` raises
      "Not an admin".
    - admin with no `aal` claim at all: false.
    - admin with `aal2`: true; the event shows, the queue returns its
      row, and member insights return.
    - member with `aal2`: false.
    - anon still has no execute.
  - **Studio:** its own branch (`claude/venue-insights-plan`) also had a
    migration named `20261101220000`. It becomes `20261101230000` there,
    and its sign-in check changes with it: `is_admin()` is false before
    the code, so Studio can no longer use it to pick the screen before
    two-step.

### Fixed

- **Studio's tabs slid sideways when switching to Basic or Pro**: hiding
  the Period selector narrowed the right of the bar. It is now made
  invisible but keeps its space.

- **Studio's Basic and Pro tabs did nothing when clicked** (2026-11-02,
  right after they went live). A browser that had loaded Studio earlier
  kept the old `studio.js` for up to four hours, next to the new
  `index.html`. The new tab buttons were there, but no script handled
  them.
  - First fix, not enough: `studio/_headers` sends `Cache-Control:
    no-cache` for `studio.js`, `studio.css` and `config.js`. That works
    on `mantelier-studio.pages.dev`, but on `studio.mantelier.app` the
    header still read `max-age=14400`. The mantelier.app zone's Browser
    Cache TTL (4 hours) overrides it on the custom domain; checked by
    comparing both hosts.
  - Real fix: `index.html` names its assets with a version
    (`/studio.js?v=<commit>`), so each deploy is a new URL that no
    browser holds yet. `scripts/deploy-studio.sh` stamps the commit in
    and deploys; that is now the way to deploy Studio. `index.html`
    itself is served with `max-age=0`, so it always names the current
    version. The `_headers` rule stays for the `pages.dev` host.
  - Alternative left to the product owner: setting the zone's Browser
    Cache TTL to "Respect Existing Headers" in Cloudflare would also
    make the header work on mantelier.app.
  - A hard reload (⌘⇧R) fixes an affected browser at once.
- **A sign-up confirmation was refused as suspicious content**
  (2026-11-02). Resend showed it as "Blocked due to content" by the new
  member's company mail server. The mail was Supabase's bare default:
  one line and a link to `wcmxugunvwsrulcpeyrc.supabase.co`, sent from
  `hello@mantelier.app`. A sender domain that differs from the link's
  domain, in a mail with almost no text, is what phishing looks like to
  a company filter.
  - That member's email was confirmed by hand (`email_confirmed_at`,
    run by the product owner in the SQL Editor), after they reported
    the missing mail themselves.
  - New templates are in `supabase/templates/`: `confirmation.html`
    (sign-up, and new links) and `recovery.html` (forgot password).
    They say who sends the mail and why, what Mantelier is, and what to
    do if it wasn't you. They use plain tables and inline styles, with
    no images or web fonts. They take effect once pasted into the
    dashboard (Authentication → Email Templates); `config.toml` points
    local stacks at the same files.
  - Not fixed by this: the link still points to the supabase.co domain.
    A Supabase custom domain (`auth.mantelier.app`) would make the link
    match the sender. That's a paid add-on and changes the URL the app
    signs in against, so it is a decision, not part of this fix.

- **App Store Connect warned ITMS-90683 on 1.5.6 (26)**: "Missing
  purpose string" for `NSLocationAlwaysAndWhenInUseUsageDescription`.
  Delivery still succeeded. `geolocator_apple` contains a
  `requestAlwaysAuthorization` call, and Apple's static scan flags any
  app that links it. It never runs here: `PermissionHandler.m` asks
  when-in-use whenever `NSLocationWhenInUseUsageDescription` is present,
  which it is. Compiling that call out (`BYPASS_PERMISSION_LOCATION_
  ALWAYS`) only works through a CocoaPods Podfile, and this project uses
  Swift Package Manager. So `Info.plist` now carries the missing key,
  with honest text ("only while you use the app … never in the
  background"). It is never shown, because the app never asks for
  always. Checked in a release build's `Info.plist`; Apple's own scan
  of the next upload is the real confirmation.

---

## v1.5.6 (26) — 2026-11-02

Build 25 was archived at 14:18 from `2a84104`. This build adds two-step
sign-in (`claude/app-two-step`). It is optional and never part of
creating an account: a member turns it on from inside the account, and
only then does sign-in ask for a code (product owner, 2026-11-02).

**Ledger: 135, local and remote in agreement.** No migration since 25.

**Schema diff (2026-11-02, before the push): clean.** All 135
migrations were replayed on a scratch stack.
- `db dump --linked` against `--local`: 16,190 and 16,196 lines, which
  differ only by the 6 known blank lines (pg_net's filtered grants).
- Storage and auth, compared directly: 30 rows each side, identical.

### Added
- **Two-step sign-in with an authenticator app** (`claude/app-two-step`,
  2026-11-02). Authenticator app only: no SMS and no email, by decision.
  It's free, stores nothing extra about the member, and on iPhone the
  Passwords app fills the code in. Uses Supabase Auth MFA (TOTP), which
  is enabled on production. No migration.
  - **Profile → Privacy → Two-step sign-in**
    (`TwoStepSettingsScreen`):
    - Off: what it is, and Turn on.
    - On: each linked authenticator with its date, Add a backup
      authenticator, and Remove.
    - Setting one up opens the `otpauth://` link in the authenticator
      app (Passwords on iPhone), with the key shown to copy or type as a
      fallback. The first code confirms it.
    - Removing one asks for a code from any linked authenticator.
      Removing the last turns two-step sign-in off.
    - Supabase wants a different name per factor, so they are
      "Authenticator", "Authenticator 2", and so on.
  - **The code step after the password** (`TwoStepSignInScreen`).
    `AuthGate` shows it while the session is `aal1` and the account has a
    verified authenticator; it reads this from the session itself
    (`sessionNeedsTwoStep`). A right code raises the session to `aal2`,
    and the gate moves on from the `mfaChallengeVerified` event. A code
    from any linked authenticator works. The screen also offers Sign out
    and points a member who lost their phone to hello@mantelier.app.
  - Code fields take digits only, six at most, and continue on the sixth
    digit, which suits iOS filling the code in. `CsTextField` gained an
    optional `inputFormatters` for this.
  - `docs/Engineering/VENUE_CLAIM_OPERATIONS.md` has the procedure for a
    member who lost their only authenticator: check it's them, then
    remove their factors in the dashboard.
  - `site/privacy.html` (deployed with this build's merge) says the authenticator key is
    stored by Supabase Auth and no phone number is, and lists two-step
    sign-in under "Your choices".
  - **Not yet enforced on the server.** A password-only (`aal1`) token
    still reads the member's own data through the API, as before. The
    app hides everything behind the code step, and production's "Limit
    duration of AAL1 sessions" ends such sessions after 15 minutes for
    accounts with an authenticator. Next steps, in order:
    1. Admin review RPCs require `aal2`, once the product owner's phone
       runs this build.
    2. Studio goes live.
  - Tested on a local replay with TOTP on, in the simulator:
    - turning it on through the `otpauth://` link (Passwords opens) and
      a confirming code;
    - a fresh password sign-in shows the code step, where a wrong code
      shows an error and the right one signs in on the sixth digit;
    - turning it off with a code removes the factor from
      `auth.mfa_factors`;
    - a backup is added as "Authenticator 2", and signing in with the
      backup's code works.

    Plus 18 widget and unit tests.
  - **Not tested before release:** iOS filling a code in from Passwords
    on a real iPhone, since the simulator's Passwords app is locked
    without a passcode. Confirmed afterwards by the product owner on
    their own iPhone with build 26, where they also turned two-step
    sign-in on for the admin account.

### Fixed
- The first code field in the simulator took eight digits after a
  partial delete ("00372453"), and sending it could only fail. Seen
  while testing before release, and fixed with the six-digit limit
  above.

---

## v1.5.6 (25) — 2026-11-02

Build 24 went onto the product owner's own phone from `c2981a1`, so this
build carries what came after it:
- team portraits, the sommelier and Instagram for venues
  (`claude/venue-team-photos`);
- opening hours and closed days for restaurants
  (`claude/venue-opening-hours`);
- venues keeping their own website and phone, and a review queue
  grouped by topic that now takes in member reports and missing
  listings (`claude/venue-contact-and-review-tabs`);
- an optional birthday and sign-up country, a birthday greeting, and
  member insights for admins (`claude/birthday-and-insights`).

The last three were merged before 25 was archived. The mantelier.app copy
change and the privacy page's "Your choices" section below went live on
their own the same day.

**Ledger: 135, local and remote in agreement.** Five migrations went to
production after 24, all applied before this build:
- `20261101170000_add_venue_team_photos_and_instagram`;
- `20261101180000_add_restaurant_opening_hours`;
- `20261101190000_add_venue_contact_edits_and_review_inbox`;
- `20261101200000_add_cuisine_dutch_search_terms` (Dutch cuisine words in
  search; no app change, so 24 and older pick it up too);
- `20261101210000_add_birthdays_signup_country_and_insights` (also
  enables pg_cron for the daily greeting; `send-push` was redeployed
  first, so it accepts the `birthday` type).

**Schema diff (2026-11-02, before the push): clean.** Run again after
`20261101210000`: all 135 migrations were replayed on a scratch stack.
(The first run, on 134, was also clean: 15,944 and 15,950 lines.)
- `db dump --linked` against `--local`: 16,190 and 16,196 lines, which
  differ only by the 6 known blank lines (pg_net's filtered grants).
- Storage and auth, compared directly: 30 rows each side, identical.

### Added

- **Birthday, sign-up country and member insights**
  (`claude/birthday-and-insights`, migration
  `20261101210000_add_birthdays_signup_country_and_insights`, written
  and applied 2026-11-02).
  - Sign-up has an optional Country field. `handle_new_user` keeps it
    only when the code is in `countries`, so a bad value can never make
    sign-up fail.
  - Edit profile has an optional Birthday with a Birthday greeting
    switch. It lives in the new `profile_private` table, which only the
    member can read (own-only RLS); friends and admins can't see it. A
    trigger refuses ages under 16.
  - On the day, `send_birthday_greetings()` sends one `birthday`
    notification and a push saying "Happy birthday from all of us at
    Mantelier." It is scheduled daily at 07:00 UTC with pg_cron (the
    migration enables the extension), runs on Amsterdam's date, at most
    once a year. A 29 February birthday is greeted on 28 February in
    other years. There is no email, by decision.
  - Admins have an Insights screen under Profile, backed by
    `admin_get_member_insights()` (checks `is_admin()`). It shows
    members and new-in-30-days by country and by age group. Any group
    under 5 shows "fewer than 5" instead of a number; only the total is
    always shown.
  - The privacy policy now explains why we collect the birthday and the
    country, that both are optional, and that they are removed with the
    account.
  - New notification versions are `get_notifications_v5` and
    `get_unread_notification_count_v5`. v4 and older exclude `birthday`,
    so builds that don't know the type never receive it.
  - Every new `SECURITY DEFINER` function revokes execute from public
    and anon in the same migration. `send_birthday_greetings` also
    revokes it from authenticated.
  - Tested on a local replay: the country is kept or dropped; under-16
    is refused; RLS keeps other members out; the greeting goes out once
    and a second run sends nothing; v5 shows the greeting, while v4,
    v3 and the old counts don't; with the switch off nothing is sent; a
    non-admin is refused; small groups are withheld; anon has no
    execute; the cron job exists.

- **A venue keeps its own website and phone number.** Decided by the
  product owner on 2026-11-02: they change during the year, and keeping
  them current by hand would be a lot of work. A "Website and phone" row
  on a venue's landing page ("Website" for a private chef, who has no
  phone column) opens `VenueContactScreen`. Save puts them on the page at
  once, with no review, and a blank field takes one off. The screen
  checks first with the same rules as the database (a full `http(s)://`
  address; digits, spaces and `+ ( ) . / -` with at least six digits).
  Each change puts a "Website or phone changed" item in the admin review
  queue with the old and new value, to mark as seen.
  - **Revises an older rule in the code, not a settled decision:**
    `VenueManagementScreen`'s doc comment and two tests (from
    `56a37e8`, 2026-09-29) listed phone and website as verified
    catalogue data a manager must never overwrite. CLAUDE.md's settled
    list of verified data (stars, Keys, World's 50 Best, Gault&Millau,
    the verified location fields) never included them. The comment and
    tests now record the change, and the previous value stays on each
    edit row.
- **The review queue is grouped by topic, with one filter**: Claims,
  Profiles (about texts, team, Instagram), Photos, Events (new and
  changed), Contact (website and phone changes), Reports. Each topic is
  a heading with its count, so no topic disappears under a long list of
  another. One compact "All topics · 12 ▾" control narrows the list to a
  single topic. Its sheet shows per topic whether anything is waiting:
  a green dot and "2 waiting", or a muted "Nothing waiting".
  - A tab per topic was tried first, but six tabs didn't fit on a phone
    (the product owner saw "Contact" and "Reports" cut off), so it
    became the filter.
  - The filter's seven-row sheet then overflowed the default sheet
    height; the widget test caught that, and the sheet now grows with
    its content and scrolls.
- **Everything that needs an admin is now in the review queue.** Two
  things weren't:
  - **member reports** (a photo, rating, profile or event) reached
    admins only by email (`notify-content-report`) and the dashboard;
  - **missing-listing reports** from Explore reached them only through
    the dashboard, with no email at all.

  Both now sit under Reports. A report is marked resolved, with an
  event or profile one tap away. A missing listing shows the reporter's
  details if they work there, and is marked handled; one already added
  to the catalogue leaves the queue by itself. The emails stay as a
  heads-up. Production had none of either on 2026-11-02.
- **Migration `20261101190000_add_venue_contact_edits_and_review_inbox.sql`:**
  - `venue_contact_edits`, with no client access;
  - `set_venue_contact` (`is_active_venue_manager` only, validates,
    writes only what changed, logs each changed field with old and new
    value);
  - `admin_mark_venue_contact_edit_seen`;
  - `resolved_at`/`resolved_by` on `content_reports` with
    `admin_resolve_content_report`;
  - `handled_at`/`handled_by` on `missing_listing_reports` with
    `admin_mark_missing_listing_handled`;
  - `get_review_queue` gains the three kinds and their columns at the
    end. Installed builds skip kinds they don't know.

  Every new SECURITY DEFINER function revokes `public, anon`. Replayed
  from scratch locally and exercised:
  - a manager's website change is logged with old and new value, and
    clearing the phone is logged too;
  - an unchanged save logs nothing;
  - another user is refused, as are `www.` without a scheme,
    `javascript:` and a five-digit or worded phone number;
  - a manager can't read the edit log;
  - the admin sees all three kinds in the queue and clears each, and a
    non-admin can't;
  - anon has execute on none of the functions.

  **Applied 2026-11-02**, before this build. Production then showed RLS
  on `venue_contact_edits` with no `authenticated` read, the new
  columns on both report tables, and no anon execute on any of the five
  functions. **Ledger: 133, local and remote in agreement.** The queue
  was checked in the simulator as an admin against production, before
  the migration (nothing waiting in any topic).

- **Opening hours and closed days on a restaurant's page, kept by the
  restaurant.** A claimed restaurant adds and changes them itself, live
  at once with no admin review. Decided by the product owner on 2026-11-02: hours are
  practical facts a venue changes often, and waiting for review would
  leave the page wrong in the meantime.
  - **On the page:** "OPENING HOURS" under Directions · Website · Call,
    one line per run of days with the same hours ("Tue – Fri
    12:00–14:00 · 19:00–22:00"). Closed days are included so the week
    reads whole. Times are the restaurant's own, never converted to the
    viewer's clock. Under the week, up to three closed days still to come
    ("Closed 25 – 26 Dec 2026"). Nothing at all without either.
  - **For managers:** an "Opening hours" row on a restaurant's landing
    page opens `VenueOpeningHoursScreen`: per day open or closed, one or
    two times (24-hour picker). Opening a day copies the nearest earlier
    open day. Save is checked first with the same rules as the database,
    and a "Remove opening hours from page" action is there too.
    Restaurants only: a hotel's own hours say little. Below the week,
    "Closed days" (asked for by the product owner on 2026-11-02 for
    Christmas, New Year's Day and the like): a date range picker adds a
    single day or a run of days, a cross removes one, each live at once,
    and the list shows those not yet passed.
  - **Migration `20261101180000_add_restaurant_opening_hours.sql`:** the
    `restaurant_opening_hours` table (weekday 1–7, slot 1–2, `time`
    opens/closes, a range closing before it opens runs past midnight,
    plus `updated_at`/`updated_by`). It's world-readable, without
    `updated_by`, and has no client write. `set_restaurant_opening_hours`
    (SECURITY DEFINER, `is_active_venue_manager` only, `revoke ... from
    public, anon`) validates and replaces the whole week in one go.
    - Replayed from scratch locally and exercised: a manager's week is
      stored in slot order; someone else is refused; an overlap, three
      ranges, an overnight range that isn't last, weekday 8, equal
      times and a non-time are each refused, and leave the week
      unchanged; direct inserts and deletes are refused; anon reads the
      hours but neither `updated_by` nor the function; an empty week
      clears it.
    - The first local run caught a wrong column reference in the
      function (`h.opens_at` for `t.opens_at`), fixed before anything
      was applied.
    - Closed days, in the same migration since it hadn't been applied:
      `restaurant_closures` (`starts_on`/`ends_on`, dates only, at most
      a year), world-readable without `created_by`, no client write;
      `add_restaurant_closure` (not wholly in the past) and
      `remove_restaurant_closure`, both `is_active_venue_manager` only
      with `revoke ... from public, anon`. Exercised locally: a manager
      adds and removes; another user can't do either; past, reversed and
      over-a-year ranges are refused; anon reads the dates only and has
      no execute on any of the three functions.

    **Applied 2026-11-02**, before this build. Production then showed
    RLS on both tables, no anon insert and no anon read of
    `created_by`, and the three functions executable by `authenticated`
    only. **Ledger: 132, local and remote in agreement.**
  - Checked in the simulator with a throwaway preview entry point and
    made-up hours, not committed: the page section, the editor and its
    24-hour picker. Also walked end to end on an in-memory week, from an
    empty page through the editor, setting Tuesday's times, switching
    Wednesday to Saturday on and saving, to a page reading "Tue – Sat
    12:00–14:00 · 18:00–22:00". Then closed days: added 25–26 December
    with the date range picker, and the page read "Closed 25 – 26 Dec
    2026" under the week.

- **The team gets portraits and a sommelier, and venues get Instagram.**
  Decided by the product owner on 2026-11-02, after mock-ups.
  - **On the page:** "THE TEAM" is now one row of up to three portraits
    (chef, manager, sommelier, in that order), each with its role and
    name. Tapping one opens a sheet with the full text (option B, chosen
    over a separate Team tab, so a venue with all three doesn't get a
    longer page). Without a photo, a calm panel of initials. Roles not
    filled in leave no slot, and no one at all leaves no section.
    Instagram is a fourth action in the Directions · Website · Call row
    (a drawn mark, no brand colours), shown only with an approved
    account. On a private chef's page, an approved account takes over
    from the catalogue's own `instagram_url`.
  - **For managers:** Team gains the sommelier and an optional portrait
    per person (picked with `photo_manager`, checked and EXIF-stripped
    like a venue photo, uploaded to the private bucket). The text limit
    goes from 280 to 600 characters. Profile gains an Instagram field
    that accepts `@name`, a name or a profile link. Everything is
    reviewed before it shows. Taking a person or the account off happens
    at once. "Preview my page" shows a waiting portrait.
  - **Review:** a team item shows its new photo and is approved through
    `publish-venue-photo` (new `team_submission_id` body: copy to
    `catalogue-media/<type>/<id>/team/`, verify, then
    `approve_venue_team_photo`). One without a photo still uses
    `admin_approve_venue_team`, which now refuses one with a photo. An
    Instagram item opens the profile to check before approving.
  - **Migration `20261101170000_add_venue_team_photos_and_instagram.sql`:**
    - sommelier role; `photo_path`/`remove_photo`/`photo_url` on
      `venue_team_submissions`; the insert policy keeps a photo in the
      submitter's own folder;
    - `venue_team_current` gains `photo_url`; a text-only resubmission
      keeps the current photo;
    - `venue_instagram_submissions` with RLS, the
      `venue_instagram_current` view, `remove_venue_instagram`, and the
      admin approve/reject functions;
    - `get_review_queue` gains three trailing columns and the
      `venue_instagram` kind.

    Every new SECURITY DEFINER function revokes `public, anon`, and
    `approve_venue_team_photo` is service-role only. Replayed from scratch
    locally and exercised as manager, admin and anon:
    - a photo outside the manager's own folder is refused, and setting
      `photo_url` directly is refused;
    - a photo submission can't be approved without publishing;
    - a photo is kept on a text-only resubmission and dropped on a
      removal;
    - a pending Instagram is invisible to anon, and visible once
      approved;
    - anon can't read upload paths or execute any of the new functions.

    **Applied 2026-11-02**, after `publish-venue-photo` was deployed with
    the team path. Production then showed the sommelier role check,
    `photo_url` on the view, RLS on the Instagram table, no anon execute
    on any new function, and `approve_venue_team_photo` closed to
    `authenticated` too. Production has no team rows yet.
    **Ledger: 131, local and remote in agreement.**
    - **Checked in the simulator** with a throwaway preview entry point
      and made-up data, not committed: the strip, the sheet, initials
      without a photo, the Instagram action and the Team screen. This
      account manages no venue, and no venue has team rows, so it could
      not be seen on a real page yet.
  - Not here: an email to the admins on a new team or Instagram
    submission (`notify-venue-submission` doesn't know these kinds yet,
    as with team texts before).

### Changed

- **mantelier.app/privacy has a "Your choices" section** (`#choices`,
  2026-11-02, live on its own). It lists where a member changes each
  thing we hold, by its in-app label: being found, birthday and country,
  who sees a visit, friends and blocks, push, location, and deleting the
  account. It is the page behind App Store Connect's User Privacy
  Choices URL. Checked against the code before going live: blocking
  happens on a member's own profile, while Privacy → Blocked users only
  unblocks; an early draft said both happen under Privacy. There is no
  in-app switch for sharing Interested/Going, so the page promises none.

- `bounded_lists_test.dart` now expects `get_notifications_v5` as the
  newest version, and v2 as the fallback once v5 to v3 are missing.

- **mantelier.app home page copy** (product owner, 2026-11-02): "A wine
  cellar opening its doors for one night"; "tells you in time to book a
  table, catch a flight, and inform your friends"; and the list heading
  is now "Events we are watching".

### Fixed

- The Birthday greeting switch was invisible when on: Edit profile is a
  green sheet, and the switch used the app's usual forest-green track,
  the same colour as the sheet. Seen in the simulator before release. On
  this sheet the switch is now inverted: an ivory track when on, an
  outline when off. The other switches sit on light screens and keep
  the forest-green track.

- **Searching "Frans" found nothing; only "French" worked.** The product
  owner found this on 2026-11-02 while preparing 1.5.6 (25) for testers.
  Free search matched only MICHELIN's English cuisine labels.
  - **Migration `20261101200000_add_cuisine_dutch_search_terms.sql`**
    adds `search_terms` to `cuisine_families` (a Dutch name for each of
    the 25: Frans, Japans, Italiaans…) and to `cuisines` (44 whose Dutch
    differs from their family's: Duits, Grieks, Thais, Baskisch…, so
    "Duits" finds German and not all of Central Europe). It also
    redefines `restaurants_full` with those terms added to
    `cuisine_search` alone; every other column is unchanged and in
    order. What's shown stays MICHELIN's English label.
  - **No app change:** installed builds, 25 included, pick it up as soon
    as it's applied.
  - **Checks:** the 44 cuisine names were checked against production
    first (all matched). They aren't asserted in the migration, because
    the cuisines are loaded as data and a fresh replay has none. Replayed
    locally: a restaurant labelled Alsatian searched as "Alsatian
    Elzassisch French Frans" and was found by "frans", "elzassisch" and
    "french", but not by "japans".
  - **Applied 2026-11-02**, before 25 was archived: production then had
    25 families and 44 cuisines with terms, "frans" found 396
    restaurants (exactly as many as "french"), "japans" 298 and "duits"
    2, and `restaurants_full` still held all 3555 rows. **Ledger: 134,
    local and remote in agreement.**

- **"Add a second time" after a range closing at 22:00 proposed
  22:00–22:00**, which saving then refused. Found walking the editor in
  the simulator. `suggestSecondRange` now proposes dinner after lunch
  (four hours on, until 22:00), or else a two-hour range from an hour
  after the first closes, past midnight if need be. It never proposes an
  empty range, and a test checks that each suggestion passes the week's
  own validation. The time picker also opens on the clock dial rather
  than typed entry, which proved clumsy.
- **A failed opening-hours load on the landing page could surface as an
  unhandled error** when a reload replaced the pending future. The
  future is now marked handled, and the row's summary just stays blank.
  The landing tests also inject a fake repository instead of reaching a
  real server.

---

## v1.5.6 (24) — 2026-11-02

1.5.5 (23) was archived at 19:57 on 2026-11-01 from `6a762f7` and is
with the testers, so this build carries what came after it:
- the host welcome (`claude/venue-host-welcome`);
- the MICHELIN Poland + Türkiye pass (`claude/michelin-pl-tr-2026`);
- Passport as the centre tab (`claude/passport-center-tab`);
- the hosts link on mantelier.app (`claude/site-hosts-link`);
- the trip map (`claude/trip-map`);
- restaurant cuisines (`claude/restaurant-cuisines`), merged in
  `release/1.5.6`.

**Ledger: 130, local and remote in agreement.** Four migrations went to
production after 23, all applied before this build:
- `20261031180000` (Poland/Türkiye towns, data only);
- `20261031190000` (the host welcome email trigger);
- `20261101150000` and `20261101160000` (restaurant cuisines).

**Schema diff (2026-11-02, before the push): clean.** All 130
migrations were replayed on a scratch stack and compared with
production.
- `db dump --linked` against `--local`: 15,108 and 15,114 lines, which
  differ only by the 6 known blank lines (pg_net's filtered grants).
- Storage and auth, compared directly (buckets, `storage`/`auth`
  policies, triggers on `auth.users`/`storage.objects`/
  `storage.buckets`, RLS on the storage tables): 30 rows each side,
  identical.
- The local-only `enforce_versioning_status_transition` trigger seen
  in the last diff did not appear this time.

### Changed

- **Passport is the centre tab.** The order is now Explore · News ·
  Passport · Community · Profile, so Passport sits in the middle of the
  bar as the heart of the app; Explore stays the start tab. It has its
  own drawn icon, `PassportBookletIcon`: a passport booklet with a globe
  emblem in place of Material's book. It is an outline when idle; when
  selected it fills ivory with the emblem cut out in the bar's green.
  No gold. Chosen by the product owner on 2026-11-02 from five options
  (option B). `FloatingNavDestination` takes an `iconBuilder` for it.
  Nothing else addressed tabs by position, and analytics tracks screens,
  not positions, so both are unaffected.
- **mantelier.app links to the hosts page.** Every page's footer now
  ends with "For hosts" (/hosts). Before this, the page was reachable
  only from the welcome email. Deployed 2026-11-02.

### Added

- **A map inside every trip.** A map button on the trip page opens
  `TripMapScreen`, built on tester feedback that travellers want to see
  where Mantelier's places are. It shows every restaurant and Key hotel
  in a leg's place (its city, or the whole country for a country leg),
  the trip's events in that leg, and what's already planned, on the
  existing MapTiler street map.
  - **Markers:** a dot for a restaurant, a square for a hotel, a diamond
    for an event, and an ivory disc with a check for anything already on
    the trip. Nearby dots fold into numbered clusters until you zoom in
    (`clusterTripMapItems`, a screen-space grid). Planned places and
    events never fold.
  - **Tapping a marker** opens a card with stars or Keys (no gold on the
    map itself), "Add to trip" (planned on that leg's dates) and "View
    venue". A trip with several destinations switches leg from chips.
  - **No migration:** `MapRepository.loadVenuesInPlaces` reads the
    existing `latitude`/`longitude` columns of `restaurants_full`/
    `hotels_full`, scoped by city id or country code, never by name.
    Expired pop-ups and permanently closed venues are left out.
  - **Checked in the simulator** on a real Andorra → Australia trip:
    hotels, a planned stay, the card and switching legs. Not tried
    there: "Add to trip" (it would have written to that trip; the widget
    tests cover it) and clustering in a dense city (the unit tests cover
    it).

- **Restaurant cuisines.** Up to two cuisines per
  restaurant, per source, grouped into 25 families for search and
  filtering. `20261101150000_add_restaurant_cuisines.sql` adds
  `cuisine_families` (seeded), `cuisines.slug` (generated) and
  `family_id`, `restaurant_cuisines` (restaurant, cuisine, position 1–2,
  source `michelin`/`worlds_50_best`/`legacy`, source URL and raw label as
  evidence), the view `restaurant_cuisines_effective` (MICHELIN, else
  50 Best, else legacy) and four columns appended to `restaurants_full`
  (`cuisine_names`, `cuisine_slugs`, `cuisine_family_slugs`,
  `cuisine_search`). All catalogue: world-readable, no client write.
  `restaurants.cuisine_id` stays and a trigger keeps it equal to the
  effective position-1 cuisine; no shipped build reads it, but it is on
  `restaurants_full`, so it goes only under the three-step rule. The data
  load, `supabase/data/enrichment/restaurant_cuisines_2026/prepared_restaurant_cuisines.sql`,
  replaces the mixed Dutch/English/self-written vocabulary (159 rows)
  with MICHELIN's own 148 English labels and links 3501 of 3555
  restaurants (was 720). `20261101160000_cuisines_slug_unique.sql` goes
  after it. Replayed from scratch and tested end to end locally on a
  copy of production's restaurant ids and cuisine ids (QA-420–QA-426).
  **Applied to production 2026-11-02**, in that order: 5053 links, 0
  restaurants with `cuisine_id` out of step, unique slug index in place.
  **Ledger: 130, local and remote in agreement.**
- **Cuisine in the app.** Explore's Restaurants search gets a second
  compact control beside the country one, "All cuisines ▾", opening a
  sheet of cuisine families to tick (any number); the control itself is
  the active-filter summary ("Japanese +1"), so there is no new chip row.
  It offers only families some restaurant has (`getCuisineFamilies`) and
  filters with an overlap on `cuisine_family_slugs`. Free search also
  matches `cuisine_search`, so "sushi" or "japanese" finds restaurants the
  way a city does; each word may still match a different field ("sushi
  tokyo"). The restaurant page shows the cuisine as MICHELIN names it
  ("Japanese · Sushi") under the city line, and nothing when none is
  known. `restaurantFullColumns` now selects `cuisine_names` and
  `cuisine_family_slugs`, which are live since 2026-11-02, so this build
  has no ordering hazard. Tests: `test/restaurant_cuisines_test.dart`
  (13), the live view-columns test, and the full suite (2745) pass.

- **A welcome for venue hosts**, in three places that share one text:
  Mantelier is international, so write in English; events are
  evenings that happen once (a special tasting, a collaboration with
  another kitchen, an exceptional setting); why that helps the
  community and the venue; and the Passport stamp a venue will design
  with us (coming soon).
  - In the app: `VenueHostWelcomeScreen`. It opens on a host's first
    visit to their venue's management page (once per user per device,
    `VenueHostWelcomeSeen`, SharedPreferences). Its button leads
    straight to Events. Tapping the claim-approved notification opens
    it too, and "Hosting on Mantelier" on the management page opens it
    any time.
  - By email: `notify-venue-claim` now also takes `event: 'approved'`
    and sends the welcome to the claim's business email. Migration
    `20261031190000_add_venue_host_welcome_email.sql` adds the update
    trigger on the three claims tables (pending → approved only). It
    reuses the existing webhook secret and has its own exception
    handler, so it can never block an approval. The function went out
    first (v14, 2026-11-02), because the old one would have read the
    approved envelope as a new claim and emailed the admins. **Applied
    2026-11-02.** Production then showed 3 triggers, no anon execute,
    and the vault secret present. **Ledger: 128, local and remote in
    agreement**, counting `20261031180000` (Poland/Türkiye towns,
    applied from `claude/michelin-pl-tr-2026`, not yet on main).
    - Tested first on a scratch local stack with every migration
      replayed. Approving a claim queued exactly one request. A later
      update of the approved claim and a rejection queued none.
    - Near-miss: that local test's pg_net requests went to the
      production function URL hard-coded in the trigger. Its fake
      secret meant production refused both with 401, so nothing was
      sent, but a replay with the real secret would email real
      addresses. Use a test-only secret, or stub `net.http_post`, when
      testing these triggers locally.
  - On the site: `site/hosts.html`, live at mantelier.app/hosts since
    2026-11-02, deployed with wrangler and linked from the email.

- Migration `20261031180000_add_pl_tr_2026_cities.sql`: 14 Polish and
  Turkish towns (data only, `cities` rows) for the MICHELIN Poland +
  Türkiye 2026 pass. Applied to production on 2026-11-01 from
  `claude/michelin-pl-tr-2026` with plain `supabase db push --linked`.
  The ledger went from 126 to 127, and local and remote agree. The
  catalogue data that goes with it is in
  `supabase/data/enrichment/michelin_pl_tr_2026/`.

### Fixed
- **The trip map came up empty after switching destination.** One
  `MapController` was shared by the map of each leg, but a controller
  belongs to one map. The widget test for switching legs caught it
  before it shipped. Each leg now gets its own controller, like its own
  map.

- The first push attempt never reached the database: `timeout` does not
  exist on macOS, and the retry was blocked by the permission check until
  the product owner allowed it. Before retrying, the ledger and the PL/TR
  city counts (8/2) were re-read to confirm nothing had been applied, so
  the migration was not pushed twice. A push wrapped in a command that
  fails before the CLI starts looks the same as one that hangs. Check the
  real state first, as CLAUDE.md says.

---

## v1.5.5 (23) — 2026-11-01

1.5.4 (22) was archived at 17:03 on 2026-10-31 from `a557eeb` and sent
to Apple, so this build carries what came after it:
`claude/edit-visits`, fast-forwarded into `release/1.5.5`, and the 2026
MICHELIN Key refresh (`claude/epic-lumiere-18d5b4`, catalogue data plus
one migration, applied to production before this build).

**Ledger: 126, local and remote in agreement.** Three migrations went
to production after 22, all data-only (`cities` rows):
`20261031150000` (Key-refresh towns, applied from
`claude/epic-lumiere-18d5b4`), and `20261031160000` / `20261031170000`
(Portugal towns, applied 2026-11-01 by runbook
`supabase/data/enrichment/APPLY_2026-11-01.md` from
`claude/lucid-rubin-us4we5`). Before this build, main also took
`claude/lucid-rubin-us4we5` (the 2026-11-01 catalogue apply and the
Aloë decision, QA-363/QA-401), `claude/gault-millau-benelux` (PR #8,
Gault&Millau Benelux batch 1, already in production, QA-377–QA-382) and
`claude/michelin-coverage-gaps` (the per-country coverage report). The
only conflicts were in `qa_issues.csv` and the Michelin_Database
CHANGELOG; both sides kept, QA-370–QA-403 in order.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), 2026-11-01, after all three migrations: a
fresh full-stack replay of all 126 migrations; `supabase db dump`
identical to production apart from blank lines; storage and auth
identical apart from the expected local-only
`enforce_versioning_status_transition` trigger.
`flutter analyze` clean and all 2,728 tests pass on this tree.

### Added
- **Portugal, and Place IDs across Europe, in the catalogue** (applied to
  production 2026-11-01 by runbook
  `supabase/data/enrichment/APPLY_2026-11-01.md`, product owner's
  request). Two migrations: `20261031160000_add_pt_2026_star_cities.sql`
  (24 towns) and `20261031170000_add_pt_key_hotel_cities.sql` (25 towns),
  plain `supabase db push --linked`; ledger 124 → 126, local and remote in
  agreement. Then, by `supabase db query --linked --file`, in order: 69
  Portuguese Key hotels, 52 Portuguese starred restaurants, the CH/AT/
  Nordics Place ID fill, 27 Europe gap-fill files and the location
  corrections — none aborted. Details and QA-392–QA-403 in the
  Michelin_Database CHANGELOG. No app change needed. The data-only
  migrations add `cities` rows; this build's schema diff (above) covers
  them.

- 2026-10-31 — Catalogue: MICHELIN Key hotels 2026 for Italy, Spain,
  Germany, Belgium, the Netherlands and Luxembourg, applied to production
  after 1.5.4 (22). No app change needed: the Michelin Hotels guide
  already lists only hotels with a current Key (`keysOnly`), and Explore's
  search already includes hotels without one. Details are in the
  Michelin_Database CHANGELOG.
  - **Migration:** `20261031150000_add_it_es_de_benelux_key_hotel_cities.sql`
    (27 towns), plain `supabase db push --linked`.
  - **Ledger:** 123 → 124/124, local and remote in agreement.
  - **Data:** `michelin_keys_it_es_de_benelux_2026/prepared_keys_it_es_de_benelux_2026.sql`,
    one guarded transaction: 109 Key hotels added, 17 Key changes, 15 Key
    import errors corrected, 18 lost Keys kept as history. Every country now
    equals MICHELIN's 2026 Key list.
  - **Schema diff:** none run here — this is a data-only migration (city
    rows); the next version bump's diff covers it.

- **Edit a visit or stay** (tester feedback, 2026-10-31). A saved visit
  could only be deleted and logged again. Visit Detail and Stay Detail
  now have "Edit visit" / "Edit stay" in their menu, opening the same
  stamp screen as logging one (`showAddVisitFlow(existingVisit: …)`),
  filled in with the date, scores, menu, visibility and note, headed
  "EDIT YOUR VISIT"/"EDIT YOUR STAY" and saved with "Save changes" via
  new `VisitedRepository.updateVisitDetails` (owner-scoped like every
  write there; RLS `visits_update` is the boundary). The venue and the
  award frozen at the visit never change; a new date is checked against
  another visit on that day. Photos stay where they're managed, on the
  detail page, so the edit sheet has no picker. Leaving an edited
  detail screen returns `true`, as a delete does, so the visit list
  behind it refreshes. Checked in the simulator on a real visit: the
  sheet opens filled in; cancelled without saving.

### Changed
- **A hotel that loses its MICHELIN Key stays in the catalogue** (product
  owner, 2026-10-31, QA-387), the same as a restaurant that loses its
  stars: `michelin_keys` NULL, a current `award_history` row with NULL,
  the earlier Key kept as history, so members keep their stays. Hotel-scope
  rule 1 in `CLAUDE.md` revised to match.

- **Notes placeholder: "Add a note about your experience…"** (was "A
  note for your passport…"; the tester's "Add a note about your
  evening…" was the old venue-page sheet, removed in 1.5.2 (20)).

### Fixed
- **Near-miss:** the runbook's `supabase db query --linked --file
  <relative path>` from `supabase/data/enrichment/` fails with
  "failed to read SQL file: NotFound": the CLI resolves the path against
  the project root, not the shell's directory. Nothing ran; the files
  were then given by absolute path. Run these from the repository root,
  or with absolute paths.

- **Near-miss:** the shared QA-id note was stale (it said QA-377 was free;
  QA-377–382 were already taken), and MICHELIN overwrote its Spanish and
  Benelux 2025 Key articles with the 2026 list. A first build relabelled a
  Spanish hotel's launch row to 2024 for want of a 2025 list; that fallback
  was removed and the 2025 list recovered from MICHELIN's own archived
  page. Without that, launch rows would have been labelled with an edition
  they didn't hold.

---

## v1.5.4 (22) — 2026-10-31

1.5.3 (21) was archived at 11:44 on 2026-10-31 from `307afb2`, so this
build carries what came after it: `claude/wishlist-polish`, fast-forwarded
into `release/1.5.4`, then `claude/follow-and-trips` (follow state, Plan visit's trip list,
the globe button) `claude/guide-chip-contrast` (the guides' filter
chips) and `claude/notifications-tidy` (the notifications list), each
fast-forwarded into main before 22 was archived. App code only — no migration, Edge Function or site change
since 21; ledger still 123, local and remote in agreement,
so the schema diff run for 21 (full replay of all 123 migrations,
identical to production) still stands. `flutter analyze` clean and all
2,728 tests pass on this tree.

### Changed

- **Notifications: one row shape, lined up** (product owner, 2026-10-31:
  "messy, not quite in one line"). Rows drifted by a few points each —
  `IdentityRow` adds 4pt of padding only when tappable, the invite and
  trip descriptions were indented a fixed 56pt against a 60pt name,
  icon-only rows used a bare 20pt icon — and friend requests put their
  status beside the name while invites put it below. Every type now uses
  one `_NotificationTile`: a fixed unread-dot column, a 44pt avatar or
  an icon in the same 44pt circle, then name / what happened / status
  or Decline–Accept, always from the same x; hairlines between rows
  start at the text. Friend requests say what they are ("Sent you a
  friend request", "Accepted your friend request") and answer with the
  same buttons as invites. @usernames are dropped from this list (the
  profile shows them). `IdentityAvatar` is the shared 44pt avatar. No
  behaviour changed: same actions, same taps. This screen has no test
  harness (it builds its own repositories); checked in the simulator
  against the real notifications on one account, before and after.

- **The Passport's map button is a globe.** It opens the spinning globe
  of your places (My Map), so `Icons.map_outlined` became
  `Icons.public_outlined`, the globe the stats panel already uses. The
  tooltip stays "My Map", the screen's own title (product owner,
  2026-10-31).

- **Plan visit only offers trips that fit the venue** (tester feedback,
  2026-10-31). It listed every trip: a Dutch restaurant could go into a
  trip abroad, and every trip that had ended was there too. New
  `tripsForPlanning` keeps trips with a destination in the venue's
  country (the trip's own country or any leg), still to come or under
  way, soonest first — plus only the most recently ended one there,
  marked "Ended", for adding to a trip just after it. The trip a plan is
  already in always stays. When trips exist but none fits: "No upcoming
  trip in this country". Four unit tests. Checked in the simulator on De
  Librije: of four trips (NL ended, two GB, AD) only "Maastricht · Ended"
  shows. Adding a venue to a trip already lived in Plan visit; nothing
  else about it changed.

- **Wishlist → "+": rows open the place, events can be saved too.**
  Tester feedback on the new add sheet, 2026-10-31:
  - Tapping a result toggled the heart, so there was no way through to
    the restaurant or hotel. A row now opens its page (Restaurant, Hotel
    or Event Detail); the heart is its own button ("Save to wishlist" /
    "Remove from wishlist" for VoiceOver).
  - Events couldn't be found. An Event chip searches upcoming and
    running events (`loadEvents(query, from: now)` — a first try without
    `from` also listed September's and October's past dinners). The "+"
    now shows on the Events tab as well, and opens on events there.
  - The tap highlight hugged the thumbnail and looked cut off at its
    left edge. Picker rows (`PickerRow`, used by Passport → + as well)
    now have a rounded highlight with 10pt of room on each side, and
    `PickerRowList` lets that room bleed past the column so thumbnails
    still line up with the search field.
  Two new tests (events; opening on the Events tab); 2,724 pass.
  Checked in the simulator: the Event chip, upcoming-only results, and
  a row opening Event Detail; nothing saved.

### Fixed

- **Near-miss: `cuisines.slug` could not be unique in one step.**
  Production's legacy labels contain two pairs that slugify alike
  ("French / Asian" and "French-Asian", "French / Classic" and "French
  Classic"), so a unique index in the same migration as the column would
  have failed on production while passing a fresh replay. The index is a
  second migration that runs after the data load merges them; tested
  that it refuses on uncleaned data.
- **Near-miss: MICHELIN's JSON-LD drops the second cuisine.**
  `servesCuisine` holds only the first; the page's "Cuisine:" label holds
  both (1498 of 3234 restaurants have two). Earlier passes' caches were
  not reused for that reason. Also, 111 stored MICHELIN URLs use a Dutch
  or French locale, whose pages give translated labels ("Eigentijds");
  pages are now fetched under `/en/` (QA-422, QA-423).
- **Near-miss: production moved between export and apply.** The
  PL/TR pass added 23 restaurants after the 2026-11-01 export, so the
  load's row-count guard would have refused. Re-exported on 2026-11-02,
  fetched the 23 new restaurants and the 5 whose `michelin_url` had
  changed, and rebuilt before applying.

- **The selected star or Key filter vanished in the MICHELIN guides**
  (tester, 2026-10-31: "when something's off it's gone entirely"). The
  guides' body is ivory, but their filter chips used `CsFilterChip`'s
  dark-canvas default, so the selected chip was ivory on ivory and the
  unselected ones were solid green — the reverse of what reads as
  selected. Both guide screens now pass `surface: CsSurface.light`
  (selected: deep green; unselected: light with a hairline). Checked in
  the simulator with ★ selected. The same report about unrated score
  bars was looked at too; the product owner judged those fine as they
  are.
- **Follow (and the wishlist heart) could show the wrong state on a
  venue page** (tester: "I follow a restaurant, go back, and I'm not
  following it any more"). Follows were saved — three new ones in
  production that day — so the page's reading of them was at fault, in
  two ways that both fit: Restaurant and Hotel Detail awaited visits,
  wishlist and follow as one unit, so any one failing left all three at
  "not yet"; and a tap made before that load returned was overwritten by
  its stale answer. Each value now loads on its own, and a tap on Follow
  or the heart wins over a load that started before it. Private Chef
  Detail gets the same follow handling. Not reproduced on a device — the
  normal follow, leave, return path showed Following correctly before
  and after; this closes the two ways it can go wrong.

---

## v1.5.3 (21) — 2026-10-31

Built from `main` after merging `claude/launch-readiness` into
`release/1.5.3`, then `claude/launch-hardening` (the two items the audit
left open) and `claude/wishlist-add` (adding to the Wishlist from the
Wishlist), both fast-forwarded into main before 21 was archived. The work of a pre-launch audit, 2026-10-31: three
read-only checks — security (production catalogs and the repo), App
Store Review risks and links, and the privacy policy against what the
app and backend actually do.

Two migrations went to production after 1.5.2 (20) and before this
build, both 2026-10-31: `20261031130000_tighten_photo_ownership.sql` and
`20261031140000_block_client_writes_on_spatial_ref_sys.sql`. The
`delete-account` Edge Function was redeployed (version 14). Ledger at
the build: 123 migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), 2026-10-31, after the apply:
- **Replay:** all 122 migrations applied cleanly from scratch on a fresh
  full stack.
- **`supabase db dump`:** identical on both sides apart from blank
  lines.
- **Storage and auth, compared directly:** buckets, `storage.objects`
  policies, triggers and RLS on both storage tables are identical, apart
  from the expected local-only `enforce_versioning_status_transition`
  trigger.
- **Before the build:** `flutter analyze` was clean and all 2,718 tests
  passed on the merged tree.
- **Again after `20261031140000` and the last two branches:** a fresh
  replay of all 123 migrations, `supabase db dump` identical to
  production, storage/auth identical apart from the same local-only
  trigger; `flutter analyze` clean, all 2,722 tests pass.

**Outside the app, done 2026-10-31:** `site/` deployed with `npx
wrangler@3 pages deploy site --project-name mantelier --branch main`;
`/privacy` (dated 31 October 2026), `/terms` and `/support` checked live
with their own titles, and `/`, `/journey`, `/auth/confirm` and
`/auth/confirmed` still served.

### Added
- **Add to Wishlist from the Wishlist itself.** A tester asked where to
  quickly save restaurants and hotels. Passport → Wishlist now has a
  "+" beside YOUR WISHLIST (labelled "Add to wishlist" for VoiceOver;
  Restaurants and Hotels tabs; events are
  saved from the events). It opens the same green picker as Passport → +
  — Restaurant/Hotel chips, one search field, the same result rows — with
  a heart at the end of each row: tap to save, tap again to remove, the
  sheet staying open for several. Optimistic, flipping back with a
  message if the write fails; the list reloads on Done when anything
  changed. The row and chip moved out of `add_visit_flow.dart` into
  `venue_picker_parts.dart` (`VenuePickerRow`, `VenueTypeChip`) so both
  sheets share them. New `test/add_to_wishlist_sheet_test.dart`; checked
  in the simulator (2026-10-31) by searching without saving.

- **Terms and Support pages** (`site/terms.html`, `site/support.html`).
  `/terms` and `/support` returned 200 but were the home page served as a
  fallback. Terms carries the "no tolerance for objectionable content or
  abusive users" clause App Review asks for under 1.2, the 24-hour report
  promise the report sheet already makes, and a line that Mantelier is
  not affiliated with Michelin, The World's 50 Best or Gault&Millau.
  Support gives the contact address and how to delete an account. All
  three site pages and the home page footer link to each other.
- **Sign-up states the agreement:** "By creating an account you agree to
  the Terms and the Privacy Policy", both linked, above Create account.
  Profile gains Terms and Support rows beside Privacy policy.
- **Migration `20261031130000_tighten_photo_ownership.sql` — applied to
  production 2026-10-31**, after it was checked: both constraints exist
  and are validated, and `photos_update` carries the visit check. `photos_update` checked only the owner, so a member
  could repoint their own photo at someone else's visit or attendance,
  or at someone else's storage object, and have it served to that
  person's friends; the update check now matches `photos_insert`.
  `photos.storage_path` and `profiles.avatar_path` must sit in the
  owner's own folder, closing the same trick for avatars through
  `can_view_member_avatar_object`. Production has 0 rows that break
  either rule (checked read-only), so both constraints are VALID. Tested
  on a full local replay of all 122 migrations. A revoke of anon writes
  on PostGIS's `spatial_ref_sys` was in the first draft and taken out:
  on the replay anon kept INSERT, because those grants come from another
  grantor — moving PostGIS out of `public` is its own change.

### Changed

- **Privacy policy rewritten to match what the app does** (dated 31
  October 2026). It now covers: username, member number and member
  search (on by default); what friends see (friends-visible visits with
  ratings, notes and photos; Interested/Going shared by default; the
  wishlist, which has no toggle); profile photos for friends, pending
  requests and members who find you (`20261031120000`); trips; venue
  invites; push notifications and tokens; every usage record
  (page opens, website/booking/phone/directions taps, screens, that a
  search or filter happened — never the query); private ratings counting
  anonymously towards Rankings above three members; venue team names
  being public; claim notification emails; Resend, MapTiler, Apple push
  and Google Fonts in the app as processors; and an honest account of
  what deletion removes and what stays. The stale "until the app
  launches" waiting-list retention is gone.
- **Dining Together hidden for launch.** Its page is a "Possible future
  concepts… Coming soon" placeholder, which App Review can reject as
  incomplete (2.1/2.2). Behind `showDiningTogether` (false); the screen
  itself is untouched.

### Removed

- `lib/data/mock/mock_user.dart`, an unused mock carrying the product
  owner's real name and an old email address. Imported nowhere.

### Fixed
- **Deleting an account left its venue photo submissions in Storage.**
  `delete-account` purged the `{user_id}/` prefix in `visit-photos` and
  `profile-photos`, but `venue-photo-submissions` keeps objects at
  `{venue_type}/{venue_id}/{user_id}/…`, which no prefix purge reaches.
  The function now reads the caller's `venue_photo_submissions` paths
  and removes those objects before `deleteUser` (whose cascade deletes
  the rows that hold the paths), under the same hard-precondition rule
  as the other buckets: any failure leaves the account intact. Approved
  photos already copied to `catalogue-media` stay, as the privacy policy
  says. Four new Deno tests (19 pass, run in `denoland/deno:2.1.4`).
  The real client is passed through a cast in `Deno.serve`: matching it
  structurally against the new `from().select().eq()` chain hit TS2589.
  **Deployed 2026-10-31** as version 14 (ACTIVE, verify_jwt on). Checked
  live without deleting anything: no Authorization header → 401, the
  anon key as bearer → 401 "Invalid or expired session". A real account
  deletion end to end has not been run.
- **Clients could write PostGIS's `spatial_ref_sys`.** Migration
  `20261031140000_block_client_writes_on_spatial_ref_sys.sql` adds
  statement-level triggers that refuse INSERT/UPDATE/DELETE/TRUNCATE
  from anon and authenticated; a REVOKE can't work because supabase_admin
  owns the table and made the grants. Tested on a full local replay of
  all 123 migrations: both roles are refused, reads and geography
  distance still work, postgres still writes. **Applied 2026-10-31**
  (ledger 123/123): both triggers exist on production, anon can't
  execute the trigger function, SRID 4326 is intact, and through the
  public REST API with the anon key a DELETE matching nothing is refused
  with 42501 "spatial_ref_sys is read-only for clients" while a read
  still returns 200.

---

## v1.5.2 (20) — 2026-10-31

1.5.1 (19) was archived at 16:25 on 2026-10-30 from `a00d3e8`
("Prepare 1.5.1 (19)", committed three minutes earlier) and is live.
Everything after it ships here. Built from `main`, after merging six
branches into `release/1.5.1` on 2026-10-31:
- `claude/neutral-username-hint`: a neutral username example on sign-up;
- `claude/friend-avatars`: friends' profile photos;
- `claude/passport-search-contrast`: a readable Passport search,
  swipeable scores, and one visit/stay screen from every entry point;
- `claude/visit-venue-link`: from a visit or stay to its venue;
- `claude/stranger-profile`: the profile of someone who isn't a friend
  yet;
- `claude/nl-venue-contacts`: the record of the NL websites and phones
  apply (QA-375, QA-376; the data itself was written to production on
  2026-10-31 and needs no build).
Main had also gained the website journey page (PRs #6, #7, #9, #10);
those site-only entries are listed here because they reached main before
this build, though they ship with the site, not the app.

One migration went to production after 1.5.1 (19) and before this
build: `20261031120000_share_member_avatars.sql` (2026-10-31). Ledger at
the version bump: 121 migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), 2026-10-31, after `20261031120000` was
applied:
- **Replay:** all 121 migrations applied cleanly from scratch on a
  fresh full stack.
- **`supabase db dump`:** identical on both sides apart from blank
  lines.
- **Storage and auth, compared directly:** buckets, `storage.objects`
  policies (including the new `profile_photos_read_visible_members`),
  triggers and RLS on both storage tables are identical, apart from the
  expected local-only `enforce_versioning_status_transition` trigger.
- **`anon` execute:** false on production (and for PUBLIC), true for
  `authenticated`, on `can_view_member_avatar`,
  `get_member_avatar_paths` and `can_view_member_avatar_object`,
  checked with `has_function_privilege`.
- **Re-checked after the last four branches merged:** none adds a
  migration, and a fresh production dump plus the storage/auth query
  are identical to the ones that matched the replay.
- **Before the build:** `flutter analyze` was clean and all 2,719 tests
  passed on the merged tree.

**Near-miss, 2026-10-31.** This work was first folded into the 1.5.1
(19) section, on the assumption that 19 had not been archived yet. It
had: the archive in `~/Library/Developer/Xcode/Archives` is dated
2026-10-30 16:25, and 19 is live. Build 19 can't be reused, and its
changelog section must say only what it carried, so everything after
`a00d3e8` moved here and the 1.5.1 (19) section is back to that
commit's own text. Check the archive list before treating a version as
still open. Along the way main was once pushed at `d65f4fb`, one commit
before its changelog text was written: a failed text replacement
stopped the commit but not the push chained after it with `;`. The code
was complete and tested there. Chain a push to the commit it depends on
with `&&`.

### Added
- **A journey page on the website.** `site/journey.html`, served at
  `https://mantelier.app/journey`: a scroll story in which a fictional
  traveller crosses a slowly spinning globe from Amsterdam to San
  Sebastián, Florence and Tokyo, a friend joins at each stop, and a stamp
  lands in a leather passport that turns its page along the way. It ends
  on "Start your own journey." with the home page's waitlist form (same
  `waitlist` table, same 409 handling), since the iPhone app isn't in the
  App Store yet. The globe is a plain canvas drawing of the app's own
  Natural Earth outlines (`assets/globe/countries.bin`, simplified to
  ~5,400 points and inlined), so the page loads no library and fetches
  no data. With `prefers-reduced-motion` it shows one still frame: the
  whole route, every stamp, and the story as a plain list. The four
  venues (Ciel Bleu ★★, Arzak ★★★, Four Seasons Firenze, 3 Keys,
  Sézanne ★★★) were checked against production on 2026-10-31, not
  only the 24 August export; the people and their dates are fictional
  and the page says so.
- **A way to the journey page from the home page.** A card under the
  waitlist form, "Explore your journey with us", links to `/journey`
  with a small drawn globe whose route slowly runs (still under
  `prefers-reduced-motion`). It is the home page's only link out, so it
  sits above "Nights we're watching" rather than in the footer, in place
  of the curved divider that stood there.
- **From a visit or stay to its venue** (2026-10-31, product owner). On
  Visit Detail and Stay Detail, opened from Friends' Activity, a friend's
  verdicts or Passport, the venue name is now tappable, with a quiet taupe
  chevron and no button chrome. A tap opens the real
  `RestaurantDetailScreen` / `HotelDetailScreen` for the restaurant or
  hotel the screen already holds, which was resolved by id from
  `restaurants_full` / `hotels_full`, never by name. The link is turned
  off (`linkToVenue: false`) when the visit was opened from that venue's
  own page ("Your visits" / "Your stays"), so a tap never stacks the same
  page twice. Event rows in Friends' Activity already open Event Detail
  directly, so they needed nothing. No migration.
  Checked in the simulator: Friends' Activity → "Test visited Flore" →
  "Flore ›" → Flore's restaurant page. There is no widget test, because
  both detail screens read the Supabase session at build time, as before.
  Analyze and all 2,710 tests pass.
- **Friends' profile photos** (2026-10-31, product owner). Until now
  only your own photo ever showed: every other member was initials,
  because the `profile-photos` bucket was owner-only on purpose
  (20260825170000, PROFILE_AVATAR_V1.md "Storage read visibility"), and
  the identity RPCs only return the never-populated `avatar_url`. Real
  photos, with initials as fallback, now show in the friends list, Your
  Circle, friend requests (incoming and sent), Find friends search
  (photo, name and @username, as `IdentityRow` already lays out),
  notifications, Friends' Activity, a friend's profile header, trip
  members, friends going/interested on events, and "friends who've
  been". Blocked users keep initials.

  How it works: the new `MemberAvatarRepository` asks
  `get_member_avatar_paths` which of the listed members have a photo you
  may see, signs those paths (with the same size transform as your own
  photo), and caches the URLs for 50 minutes. `FriendshipRepository`,
  `NotificationsRepository` and `loadTripMembers` merge them in;
  `Friendship`, `FriendRequest` and `ProfileIdentity` gained
  `withAvatar`. None of the existing RPCs changed, so build 1.5.0/1.5.1
  are untouched.

  **Migration `20261031120000_share_member_avatars.sql` — applied to
  production 2026-10-31**, before this build (its header still reads
  "NOT YET APPLIED": it was written before the apply, and an applied
  migration is not edited). The photo rule is the identity rule
  `search_profiles` already uses: you can see a member's photo when
  there is no block between you AND (they are discoverable, OR you are
  friends, OR a request is pending either way). A non-discoverable
  member's photo stays hidden from strangers. The migration adds
  `can_view_member_avatar(uuid)`, `get_member_avatar_paths(uuid[])` and
  `can_view_member_avatar_object(text)` (all SECURITY DEFINER, each with
  `revoke execute ... from public, anon` and a grant to `authenticated`),
  plus an extra storage SELECT policy on `profile-photos` covering
  exactly a visible member's current photo. The owner-only policy stays.
  The visibility rule's SQL ran read-only against production without
  error before the apply. After it: `has_function_privilege` is false
  for `anon` and PUBLIC and true for `authenticated` on all three
  functions, and `profile_photos_read_visible_members` sits beside the
  three owner policies. Before the apply the app was checked in the
  simulator with the RPC missing: Community → Friends, the feed and the
  lists all load as before, with initials. The photos themselves have
  not been seen on a device yet — only one member in production has a
  profile photo.
  Analyze and all 2,710 tests pass (new model tests; the paged
  notifications test now asserts only on the notifications call, since
  the photo lookup follows it).

### Changed
- **Profile of someone who isn't a friend yet, redesigned** (2026-10-31,
  approved by the product owner from a simulator screenshot). It is
  reached from Find friends, a request or a notification. The old screen
  was half green and half ivory, with the identity sitting high and
  left. It is now one deep-green page with everything centred (new
  `NonFriendProfile`): the member's photo or initial in a hairline ring,
  the name in the editorial serif, @USERNAME in small caps, a short rule,
  an italic invitation line, one sentence on what friends share, and one
  calm action.
  - No relationship yet: "Start enjoying the Mantelier journey
    together." and Add friend.
  - Request sent: "Your invitation is on its way." and a quiet "✓ Request
    sent".
  - Request received: "{First name} would like to share the journey with
    you." with Accept, and a quieter Decline beneath it.
  - Your own profile: no invitation and no action.

  Report and Block stay in the "⋯" menu. Only the minimal identity a
  non-friend could already see is shown (photo, name, username); the
  copy describes what friends share in general, never this member's
  activity. The old `_NonFriendBody`/`_Hero`/`_RelationshipAction` are
  removed. A new widget test covers the states and 320 pt; the navigation
  test now expects `@KYLAN` and the invitation line. Analyze and all
  2,715 tests pass.
- **One screen to log a visit or stay, wherever you start.** Restaurant
  and Hotel Detail's "Add your first visit" / "Add a stay" opened their
  own older white sheets (`add_visit_sheet.dart`, `add_stay_sheet.dart`),
  which looked nothing like Passport → + and, on their white card, left
  an unrated score meter's segments invisible. Both pages now open the
  Passport flow (`showAddVisitFlow(initialVenue: …)`) straight at its
  stamp step, with "Cancel" and "LOG YOUR VISIT"/"LOG YOUR STAY" instead
  of "‹ Back" and "STEP 2 OF 2". Nothing was dropped: the flow gained
  what only the old sheets had — menu type (restaurants), "Visible to
  friends" (off by default, as before) and photos (uploaded after the
  visit saves, a failure reported and never undoing the visit) — so the
  Passport route now records those too. It now returns a `SavedVisit`.
  The two old sheets are removed; `MenuTypeSelector` moved to its own
  file. The notes field is unfilled, like the search field, so it sits
  between its hairlines instead of in a white box. Checked in the
  simulator from De Librije (2026-10-31), cancelled without saving.
- **Scores can be swiped.** Every 1–10 score in the visit and stay
  sheets (`RatingMeter`: overall, food, service, wine, value, room,
  experience) took a tap per segment only. A horizontal drag now works
  too: start on the "—" pill or anywhere on the meter, the score follows
  the finger, and dragging back over the pill returns to "Not rated",
  with a light selection haptic per step. Tapping is unchanged. New
  `test/rating_meter_swipe_test.dart` covers the position-to-score
  mapping, a swipe out and back, and that a tap still scores. Checked in
  the simulator (2026-10-31): a swipe from "—" gave 8/10.

### Fixed
- **The journey page's passport ran off the right edge at medium
  widths.** Between the phone layout (≤860px) and roughly 1180px the
  side column is narrower than the full-size open booklet (2 × 196px),
  so its right page was cut off, as seen on mantelier.app/journey right
  after it went live on 2026-10-31. Pages, stamps and cover lettering
  now scale with the viewport in that range; checked at 900px and
  1100px.
- **The Arzak stamp's city line ran outside its oval.** "SAN
  SEBASTIÁN · ES" was set at 6.6 units with wide letter-spacing near the
  top of the inner ellipse, where the oval is narrowest, so it crossed
  the rings. It is now smaller, tighter and lower, with the stars,
  name and date moved down to match; measured inside the inner ring.
- **Passport → + → "Where did you go?": what you typed was nearly
  invisible.** The search field sits on the green step with ivory text,
  but the app theme fills every `TextField` with ivory, so the text was
  ivory on an ivory box. The field now sets `filled: false` and reads as
  the underline on green it was designed as. Checked in the simulator
  (2026-10-31); no widget test covers this sheet.
- **Create your account showed the product owner's own username as the
  example.** The Username field's placeholder was `kylan.s`, a real
  person's handle, left in from development. It is now `jane.doe`,
  matching the Name field's `Jane Doe`. Nothing else in the shipped app
  carries a real name: the only other hit, `lib/data/mock/mock_user.dart`,
  is imported nowhere in `lib/`, and the test fixtures never ship.

---

## v1.5.1 (19) — 2026-10-30

Built from `main`, after merging three branches into `release/1.5.1`:
- `claude/venue-follow-team`: the Follow pill, one wishlist heart, one
  notification flow after a follow, and the venue team;
- `claude/friends-activity-globe`: Friends' Activity, a friend's globe,
  friends who've been on venue pages, unclipped friend-profile avatars,
  and Community Rankings for restaurants, hotels and events with one
  Filters button;
- `claude/venue-guide-links`: the guide pages moved out of the venue
  action row.

Numbered 1.5.1 at the product owner's request, though it carries new
features. Three migrations went to production on 2026-10-30, after
1.5.0 (18) and before this build: `20261030160000`, `20261030170000` and
`20261030180000`. Ledger at the version bump: 120 migrations, local and
remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay
of all 120 migrations, 2026-10-30:
- **Replay:** all 120 migrations applied cleanly from scratch, so the
  `20261030170000` rename (it was first written to sort before
  `20261030160000`, see its own entry) replays in the same order
  production ran.
- **`supabase db dump`:** identical on both sides apart from blank
  lines.
- **Storage and auth, compared directly:** buckets, `storage.objects`
  policies, triggers and RLS on both storage tables are identical, apart
  from the expected local-only `enforce_versioning_status_transition`
  trigger.
- **`anon` execute:** false on production for all three new
  `SECURITY DEFINER` functions (`remove_venue_team_member`,
  `admin_approve_venue_team`, `admin_reject_venue_team`), checked with
  `has_function_privilege`.
- **Before the build:** `flutter analyze` was clean and all 2,707 tests
  passed on the merged tree.

No manual steps outside the repo for this build.

### Added
- **The team on a venue's page.** A restaurant or hotel can show its
  chef and its manager ("Restaurant manager" / "Hotel manager"), each a
  name and an optional short text (80 / 280 characters), under "THE
  TEAM" below the about text. A manager edits them in Manage venue →
  Team (`VenueTeamScreen`); like an about text, a new name or text waits
  for an admin before it shows (decided 2026-10-30: it is new
  descriptive copy from the venue, not presentation of something already
  reviewed), and the outcome, with a rejection's note, shows on the Team
  screen. Taking someone off the page needs no review and happens at
  once; it also withdraws anything still waiting for that role, so it
  cannot reappear on approval. Admins review it in the existing queue
  (new kind `venue_team`, heading TEAM), with Preview page. Private
  chefs have no Team row: their page is the chef. "Preview my page"
  shows pending team changes through a new `teamOverride` on
  `RestaurantDetailScreen`/`HotelDetailScreen`, same as the about text.
- **Migration `20261030170000_add_venue_team.sql` — applied to
  production 2026-10-30.** `venue_team_submissions` (RLS on; insert only by an active
  venue manager via `is_active_venue_manager()`, only as pending — the
  insert grant covers the content columns alone; no client update or
  delete; `anon` may read only the columns the view needs, never who
  submitted), the `venue_team_current` view, `remove_venue_team_member`,
  `admin_approve_venue_team` / `admin_reject_venue_team`, and
  `get_review_queue()` recreated with the `venue_team` kind and
  `team_role`/`team_name`/`team_bio` appended (installed builds skip
  kinds they don't know). Every new `SECURITY DEFINER` function has its
  own `revoke execute ... from public, anon`. Checked 2026-10-30 on a
  fresh full-stack replay of all 118 migrations: `anon` has no execute
  on any of the four functions (`has_function_privilege`), a manager can
  insert pending but not approved rows and cannot update, a non-manager
  cannot insert or remove, a non-admin cannot approve or read the queue,
  approve/reject/remove behave as described, and `anon` sees only
  approved, not removed rows and cannot read `user_id`. Not in this
  migration, on purpose: a notification to the venue on approval or
  rejection (new notification types need a new `get_notifications_vN`
  pair), and the admin email on a new submission (`notify-venue-
  submission` rejects submission types it doesn't know, so it needs a
  function change and deploy first).
  Written as `20261030150000`; renamed to `20261030170000` before the
  apply because `20261030160000_add_hotel_and_event_rankings.sql`
  (branch `claude/friends-activity-globe`) reached production first,
  and a migration is named after the highest one. The two touch no
  shared object, so replay order cannot change the result. Verified on
  production after `db push`: table with RLS on, view present, `anon`
  has no execute on the four functions and no select on `user_id`,
  `authenticated` has execute, `get_review_queue()` returns the team
  columns, zero rows. `supabase migration list --linked` showed 119/119
  in agreement with `20261030160000` present locally; on this branch
  alone that file is missing until `claude/friends-activity-globe`
  lands, so the list shows it remote-only until then.
- **Friends' Activity on Community → Friends** (2026-10-30). The section
  was a placeholder line; it now shows what friends have shared, merged
  across friends and newest first: a visit or stay (each one a Passport
  stamp, with its 1–10 score when given), Interested or Going for an
  event that hasn't ended and isn't cancelled, and confirmed attendance
  ("collected a Passport stamp at"). Milestones sit on the visit that
  reached them, in small caps: first venue in a new country (not the
  very first stamp), the 10th/25th/50th/100th/… distinct MICHELIN-starred
  restaurant (stars at the visit, repeat visits don't count), and the
  first three-star restaurant. Five items preview, "All activity" opens
  the full list. Rows open the friend's visit, or the event. Visit dates
  are calendar dates and render as dates only; event dates use
  `formatEventDateRange`, in the event's own timezone.

  **No migration, no new visibility.** `FriendActivityRepository` reads
  `visits`, `event_attendance` and `event_confirmed_attendance` directly,
  filtered to the caller's friends, so the existing RLS decides what
  comes back: only rows the friend marked `friends`, nothing after an
  unfriend or a block. Milestones are counted over those same visible
  visits only, so a private visit can't surface as "10th starred". Five
  queries in all, regardless of how many friends
  (`VisitedRepository.loadPassportVenuesForUsers` is the batched
  version of `loadPassportVenues`). Personal community-ranking scores
  (`venue_ratings`) are deliberately left out: they are owner-only by
  design (`20260828120000`), and showing them would reverse that
  decision.
- **A friend's globe** (2026-10-30). Friend Profile → Overview has a
  "N countries on {Name}'s globe · Map →" line that opens the same
  `VisitedMapScreen` as My Map, given the friend's `userId`: their
  friends-visible visits, stays and confirmed event attendance. Titles
  and empty states name the friend, and it records no `screenOpened`
  (that event stays "my map").

- **Friends who've been, on Restaurant and Hotel Detail** (2026-10-30).
  Under the city line, a few overlapping friend faces and one line ("Anna
  & Bas have been here", "Anna, Bas & 2 other friends have been here").
  **No scores, by product-owner decision:** the venue page stays calm,
  and a friend's verdict is one tap further, on their profile. One friend
  opens their profile directly; several open a short list first. Only
  visits a friend marked `friends` count. The query reads `user_id` alone
  (`FriendActivityRepository.loadFriendsWhoVisited`), with no migration.
  The row renders nothing until at least one friend has been, and is left
  out of a manager's "Preview my page" because it is personal state.

### Changed
- **Restaurant and Hotel Detail: guide pages moved out of the action
  row.** On a venue with every recognition (De Librije, 2026-10-30) the
  `VenueUtilityActions` row had grown to six icons side by side —
  Directions, Website, Call, Michelin, 50 Best and Gault&Millau — with
  the last label shrunk to fit. The row is now only the practical
  Directions · Website · Call; the venue's own MICHELIN Guide, World's
  50 Best and Gault&Millau pages are quiet text links (new
  `VenueGuideLinks`, north-east arrow for "leaves the app") directly
  under Award history, with the awards they describe. Each still appears
  only when its URL is real. No link was removed and no tracking
  changed (guide-page taps were never tracked; Website and Call still
  are).
- **Follow is a labelled pill.** The hero's Follow control was a
  person-add glyph that only went from outline to filled, which on a
  photo did not read as a change, so people couldn't tell whether they
  followed a venue. It is now "+ Follow" (translucent, ivory outline) or
  "✓ Following" (solid ivory, forest green), on Restaurant, Hotel and
  Private Chef pages. Following is optimistic: the pill flips on tap and
  flips back, with an error snackbar, if the write fails. The success
  snackbars ("Following X" / "Unfollowed X") are gone — the pill is the
  feedback — and so is `followSnackMessage`.
- **One wishlist heart everywhere.** The wishlist and Passport cards
  showed a bookmark to remove (or add) what the Detail pages add with a
  heart. `PassportCardBookmark` now draws the same heart: filled means on
  the wishlist, a tap takes it off. Event Interested keeps its bookmark.
- **Notifications after a follow: one sheet, in sync with Settings.**
  The first follow on a device where iOS has never been asked now shows
  one sheet ("You follow X — want a notification when they announce an
  event?") instead of a snackbar plus a sheet. Saying yes there, and
  then yes to iOS, also switches on "Events from venues you follow" in
  Notification settings (and "Friend requests" for the friends prompt),
  so the two can't disagree. In Notification settings the switches now
  show what actually reaches the phone (off until iOS allows it), and
  turning one on before iOS was asked is what asks iOS — the separate
  "Turn on notifications" button above already-on-looking toggles is
  gone. A no in iOS saves nothing.
- **Community Rankings redesigned: restaurants, hotels and events,
  beyond stars** (2026-10-30, product owner). The screen (Community → "See
  full ranking") was restaurants-only, filtered by star count, in the old
  dark-and-gold style. It now has one row of kinds (Restaurants · Hotels ·
  Events) and, for restaurants and hotels, one quiet recognition row: All,
  ★/★★/★★★ (Keys for hotels) or World's 50 Best. Each row is the ivory
  `RankingEditorialCard` with the venue's card photo, the stars or Keys
  (the only gold), a "50 Best #n" when it has one, the community score in
  forest green, and "· N members". Hotel rows open Hotel Detail and event
  rows open Event Detail. Decided by the product owner: the score is the
  overall score members give a visit, stay or confirmed event, each
  member's latest per venue, and a venue appears from 3 members (the
  rule `restaurant_rankings` already used). The separate, unused
  `venue_ratings` system is untouched.

  **Migration `20261030160000_add_hotel_and_event_rankings.sql`, applied
  to production on 2026-10-30 at the product owner's request.** It
  appends `worlds_50_best_rank` and the card-photo columns to
  `restaurant_rankings`, leaving its rows and order the same. Build 1.5.0
  (18) selects named columns from that view, so appending is invisible
  to it. It also adds `hotel_rankings` and `event_rankings` with the same
  shape and threshold: owner-privileged views that return aggregates
  only, never a user id. Until a build with this screen ships, nothing
  reads the new views.
  - **Before the apply:** there was no Docker for a local replay. The
    three view SELECTs ran read-only against production without error
    (0 rows each: no venue clears 3 members yet), and the ledger showed
    117/117 with only this file pending.
  - **After the apply:** checked directly. `restaurant_rankings` keeps
    its anon + authenticated select and now has 13 columns.
    `hotel_rankings` (13) and `event_rankings` (9) are selectable by
    `authenticated` and not by `anon`. `supabase migration list --linked`
    shows 118/118, local and remote in agreement.
  - **Ordering:** `claude/venue-follow-team` renamed its unapplied
    `20261030150000_add_venue_team.sql` to `20261030170000` (content
    unchanged) so that it sorts after this one, and applied it. The
    production ledger is now 119/119. This migration's header still
    says it was "named after 20261030150000_add_venue_team.sql". That
    file no longer exists, and the header stays as it is, because an
    applied migration is not edited.

  Until a build with this screen ships, the app falls back on its own if
  a view is missing, so it is safe in either order. Analyze and all 2,699
  tests pass. In the simulator only the chips and empty state are
  checked, because no venue clears the threshold yet.

- **Community Rankings, layout B: one Filters button** (2026-10-30,
  chosen by the product owner from four visual options). This replaces
  the earlier two permanent chip rows, following CLAUDE.md's UI
  principle. The page now has one quiet "Filters" pill ("Filters · 2"
  when something narrows the list) and a one-line summary beside it
  ("Restaurants · Italy · ★★"). The list itself is calm editorial rows
  with hairlines between them: a serif rank, a small framed photo, the
  name, the city with stars or Keys (the only gold), any World's 50 Best
  rank, and the score over "N members". The ivory sheet holds TYPE,
  COUNTRY (only countries the list actually contains), RECOGNITION
  (stars, Keys or World's 50 Best; not shown for events), Reset, and a
  full-width "Show N places". Closing the sheet changes nothing. Each
  type's list loads once and is filtered in the app
  (`applyCommunityFilters`), because it only holds venues with 3+
  members. A failed load offers Retry.

  **Migration `20261030180000_add_country_to_rankings.sql`, applied to
  production on 2026-10-30 at the product owner's request.** It appends
  `country_code` to `restaurant_rankings` and `hotel_rankings`
  (`event_rankings` already had it). Rows, order and grants are
  unchanged. A period filter (last 12 months) is left out on purpose: it
  needs an RPC rather than a view.
  - **Before the apply:** both view SELECTs ran read-only against
    production without error (0 rows: nothing clears 3 members yet).
    Production already had `20261030170000` (venue team), which this
    branch doesn't carry. Its file was copied unchanged from
    `claude/venue-follow-team` for the push only, then removed; it is not
    committed here.
  - **After the apply:** checked directly. `restaurant_rankings` (14
    columns) is selectable by anon and authenticated, as before.
    `hotel_rankings` (14) and `event_rankings` (9) are selectable by
    authenticated only. All three have `country_code`. `supabase
    migration list --linked` shows 120/120, local and remote in
    agreement.

  Checked in the simulator with temporary demo rows (not committed),
  because no venue in production clears the threshold yet.
  Analyze and all 2,700 tests pass.

- **Friend verdicts and visit/stay detail in the green-and-ivory design**
  (2026-10-30, at the product owner's request).
  - Friend Profile → "{NAME}'S VERDICTS" (and its "All →" list) were a
    dark tile with a gold border and a 40pt score. They are now the same
    ivory `RankingEditorialCard` that My Rankings uses, without a rank.
    Each card shows the photo, name, stars or Keys, city, then "8/10 ·
    Visited 23 Sep" (the year only when it isn't this year). An unrated
    visit shows no score. `RankingEditorialCard` now takes an optional
    `rank` and an optional `scoreText` for this; every existing caller
    passes both, so nothing else changes.
  - Visit Detail and Stay Detail (reached from a verdict, Passport and
    the activity feed) used ten-segment gold bars and a gold "8/10". They
    are now ivory with the forest-green score rings the venue page
    already shows (`VenueScoreStrip`). The headings are taupe eyebrows,
    the title uses the editorial serif, and the spinner and snackbar are
    no longer gold. These are the viewer's own visits too, so their
    Passport detail changes the same way. `RatingDisplayRow`, the
    gold-bar widget, had no other users and is removed.

### Fixed
- **Friend Profile avatars were clipped.** The box holding the two
  overlapping avatars was 54pt high, but each avatar sits in a 3pt ring,
  so the Stack cut 3pt off the bottom and right of both circles at every
  screen size. The box now includes the ring, and the Stack no longer
  clips. A widget test checks both avatars sit inside it at 320, 390 and
  1024pt wide; it fails against the old header.

---

## v1.5.0 (18) — 2026-10-30

Built from `main`, after merging six branches into `release/1.5.0`:
- `claude/usage-tracking`: usage tracking;
- `claude/push-notifications` (PR #5): push notifications;
- `claude/fix-signup-confirmation`: the sign-up confirmation fix;
- `claude/passport-stamp-ceremony-e750d7` (PR #4): the Passport stamp
  ceremony;
- `claude/launch-egress`: the download-traffic work;
- `claude/jolly-engelbart-47d9a4`: the Yi Long Court data fix.

A minor version bump, because push notifications and the stamp ceremony
are visible new features. Three migrations went to production on
2026-10-30, after 1.4.0 (17) and before this build: `20261023200000`,
`20261030130000` and `20261030140000`, plus the Yi Long Court
correction. Ledger at the version bump: 117 migrations, local and remote
in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 117 migrations, 2026-10-30:
- **Before the apply:** the only difference was the pending
  `20261030140000`: `get_visit_cover_photos`, its grants and the new
  `photos` index.
- **After the apply:** `supabase db dump` is identical on both sides
  apart from the same 6 blank lines.
- **Storage and auth, compared directly:** buckets, `storage.objects`
  policies, triggers and RLS on both storage tables are identical, apart
  from the expected local-only `enforce_versioning_status_transition`
  trigger.
- **Before the build:** `flutter analyze` was clean and all 2,681 tests
  passed on the merged tree.

**Manual steps outside the repo, already done:**
- the Supabase Auth Site URL and redirect URLs, and the mantelier.app
  site deploy, for sign-up;
- the APNs key "Mantelier Push" (team-scoped, Sandbox & Production);
- Push Notifications enabled on the `app.mantelier` App ID;
- the five `send-push` secrets.

### Added
- **Usage tracking for venue actions and feature use** (2026-10-30;
  migration applied to production the same day, at the product owner's
  request, ahead of the build that sends the new events). Migration
  `20261023200000_add_venue_action_and_app_usage_tracking.sql`:
  `venue_link_clicks` accepts `phone` and `directions` destinations and a
  `private_chef_detail` source screen; new `venue_page_opens` (with
  internal and k≥5 shareable stats views) and `app_usage_events` (an
  allowlist of `screen_opened`, `explore_search_performed`,
  `explore_filter_applied`, `event_opened`, with an internal stats
  view). Same ownership model as `venue_link_clicks`: insert-only for the
  user themself, never readable by any client role. App side:
  - new events `venuePhoneTapped`, `venueDirectionsOpened`,
    `venueDetailOpened`, `screenOpened`, `exploreSearchPerformed` and
    `exploreFilterApplied`;
  - Restaurant, Hotel and Private Chef Detail record page opens, Call and
    Directions; Private Chef Detail now also records website taps;
  - Event Detail records `eventOpened` on landing, so opens from any
    surface count (EventsScreen's own feed-tap call stays Noop, so
    nothing is counted twice);
  - the tab bar and the Events, Guides, Map, Friends, Friend profile,
    Notifications and Trip screens record `screenOpened`;
  - Explore counts one search for each query typed into an empty field,
    and each filter change. The query text and filter values are never
    stored.

  Replayed from scratch on a local stack (all 115 migrations), with RLS
  and CHECKs exercised there: own-user insert accepted, another user's
  id, unknown destination/event and screen-shape violations rejected,
  authenticated reads return 0 rows, both views denied, anon insert
  denied. After the apply, production was checked directly: both tables
  with RLS on and only their insert policy, all three views present and
  not selectable by `authenticated`, no anon insert, the widened CHECKs
  in place, the 3 existing click rows intact, and `supabase migration
  list --linked` at 115/115 local = remote.

- 2026-10-30 — Push notifications (iOS, APNs directly, no Firebase), with
  per-type toggles. Two kinds push: a friend request received, and a new
  event from a restaurant, hotel or private chef the person follows.
  **Applied to production 2026-10-30**, after build 1.4.0 (17), so the
  server side is live but no shipped build registers devices or shows the
  settings yet. That needs the next build.
  - **Secrets:** the five function secrets (`APNS_KEY_P8`, `APNS_KEY_ID`,
    `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `SEND_PUSH_WEBHOOK_SECRET`) and the
    vault secret `send_push_webhook_secret` were set by the product owner.
    The key is team-scoped, Sandbox & Production.
  - **Deploy:** `send-push` deployed. A probe without the secret returns 401,
    and a GET returns 405, so `verify_jwt = false` took effect.
  - **Apply:** one plain `supabase db push --linked`, which applied only
    `20261030130000`. The ledger now has 116 rows, local and remote in
    agreement.
  - **Ledger note:** production already had `20261023200000` (from
    `claude/usage-tracking`, applied but not merged), and `db push`
    refuses to run while a remote migration has no local file. That file
    was copied into this branch byte for byte from its own branch first;
    it changed nothing in production.
  - **Checked on production:** RLS is on both new tables, and all five
    triggers exist. `has_function_privilege('anon', …)` is false for all
    eight new functions. `authenticated` can't call the fan-out but can
    register. The vault secret is present. v1–v4 and the unread counts all
    execute.
  - **Migration `20261030130000_add_push_notifications.sql`:**
    - `push_devices` (APNs tokens): RLS lets the owner read and delete
      only. Writes go only through `register_push_device` /
      `unregister_push_device`, because a device signing in to another
      account has to take over a token row that RLS would never let it
      touch.
    - `notification_preferences`: one row per person, owner-only RLS. No
      row means both toggles on (iOS's own prompt is the real opt-in).
      The toggles affect push only, never the in-app list.
    - A new notification type, `followed_venue_event`. Deferred constraint
      triggers on `events` and the three link tables call
      `fan_out_followed_venue_event` at commit, so the host link always
      exists by then:
      - recipients are the followers of the event's **host** venue
        (decided 2026-10-30), through approved host links only;
      - the host's own active managers and past or cancelled events are
        skipped;
      - a partial unique index stops a republished event from notifying
        anyone twice;
      - the 28 already-published events never fire.
    - `notifications_push_on_insert`, a statement-level trigger, hands
      push-worthy ids to `send-push` through pg_net, 500 per call. It is
      best-effort, the same as `notify-venue-claim`, and reads its webhook
      secret from vault (`send_push_webhook_secret`, set out of band).
    - `get_notifications_v4` / `get_unread_notification_count_v4` return
      the new type. v4 is v3's body copied verbatim (diffed). v3, v2, v1
      and their counts now filter the type out, so 1.4.0 and older never
      see a row they can't render or count.
    - Every new `SECURITY DEFINER` function has its own
      `revoke execute … from public, anon`. The fan-out is revoked from
      `authenticated` too.
  - **Edge Function `send-push`** (`verify_jwt = false`, x-webhook-secret):
    - reads the notifications, preferences and tokens with service_role;
    - signs its own ES256 APNs token from the `.p8` key;
    - deletes tokens APNs reports as gone, and retries a BadDeviceToken
      once on the other APNs environment, correcting the stored one.
  - **App:**
    - `PushNotificationsPlugin` in `AppDelegate.swift` (no push SDK);
    - the `aps-environment` entitlement;
    - `PushService`, which registers the token whenever iOS allows it and
      unregisters it before sign-out;
    - a pre-prompt sheet shown once, after the first venue follow or
      friend request sent or accepted. iOS's prompt only follows
      "Turn on", and "Not now" is remembered (`shared_preferences`, now a
      direct dependency);
    - Profile → Notification settings with the two toggles;
    - a tapped push opens the event or the Notifications list;
    - the in-app list shows the new type.
  - **Tested:**
    - 18 Deno tests for `send-push`, including signing a JWT and verifying
      it.
    - New Flutter tests for `PushService`, the settings screen and the
      model. The full suite passes: 2,613 tests.
    - Sections 1–5 of the migration ran against a scratch Postgres 17 with
      stub tables: 29 scenario checks pass (fan-out paths, dedupe,
      managers, past and cancelled events, pending host links, missing
      secret, token takeover, RLS, `has_function_privilege('anon', …)`
      false for all six new functions).
  - **Not tested:**
    - a full-stack replay (Docker was not running);
    - section 6 with a signed-in user (it executes on production with none);
    - a real APNs delivery, including whether the Edge runtime's fetch
      speaks HTTP/2 to APNs. That is the first thing to check after the
      deploy.

- **A confirmation landing page and a way back from an expired link.**
  `site/auth/confirm.html`, served at `https://mantelier.app/auth/confirm`
  and (through `site/_redirects`) at `/auth/confirmed`, in the same branded
  style as `reset-password.html`. It says the account is confirmed when the
  link worked. When the link has expired or was already used, it says so
  and tells the person what to do next. `/auth/confirm` is now a Universal
  Link (AASA, and the Android intent filter), so with the app installed the
  link opens Mantelier, which signs the person in with the PKCE code and
  shows the welcome flow. `/auth/confirmed` is deliberately web-only (see
  Fixed).

- **A `mantelier://` URL scheme** (iOS `CFBundleURLTypes`, Android intent
  filter on host `auth`). The "Open Mantelier" buttons on
  `/auth/confirm` and `/auth/reset-password` now use it. On
  `/auth/confirm` the button links to `mantelier://auth/confirm?code=…`.
  On `/auth/reset-password` it links to the same path, query and fragment
  on the new scheme. supabase_flutter's PKCE handling reads `?code=`
  whatever the scheme. Checked in the iOS simulator: `simctl openurl
  "mantelier://auth/confirm?code=…"` asks "Open in Mantelier?" and
  brings the app to the front with no crash. The probe code was bogus
  and the simulator was already signed in, so this showed the scheme
  works, not a sign-in through it. Builds up to 1.4.0 (17) don't
  register the scheme, so on those Safari reports an invalid address.

- **"Send a new confirmation link" on sign-in.** When sign-in is refused
  with `email_not_confirmed`, LoginScreen offers to resend the confirmation
  (`AuthRepository.resendSignupConfirmation`).

- **Stamp ceremony.** When a member earns a new Passport stamp, their own
  Passport opens full screen over the screen they are on. The real cover
  swings open, and the book turns one page to where the stamp lands. A
  small wooden rubber stamp appears over an ink pad beside the book. It
  dips into the pad, and its rubber face takes on the stamp's own ink
  colour. It then lifts, arcs over the page and presses down. On contact,
  the real impression appears at full strength, one medium haptic fires,
  and the ink settles to 90%. The stamper lifts away, the book closes, and
  the member is back where they were. The whole ceremony takes about
  3.1s, and a tap skips it. Under reduce motion there is no flip and no page turn: the
  open book fades in already on the right page, and the stamp fades in.
  - It is one entry point, `celebrateNewStamp`
    (`lib/features/passport/stamp_ceremony.dart`), called from all five
    places a stamp is earned:
    - Log visit on the restaurant page;
    - Log stay on the hotel page;
    - the Passport's "Add your next stamp" flow;
    - the event page's attendance confirmation (both "Yes" and "Add to
      Passport");
    - the Events feed's post-event prompt.
  - For events it runs after the confirmation, before the optional rating
    sheet.
  - It runs on the real booklet (`PassportFlipBook`, cover, pages and
    stamp painters), not a replica. The stamp being pressed hands its
    entrance to a `StampCeremonyScope`, and it reports its position and
    ink to the stamper through that scope. The stamper and pad
    (`stamp_ceremony_stamper.dart`) are the only new artwork. They are
    decoration around the impression; the impression itself is still the
    stamp's own painter.
  - Trigger rules:
    - An `EarnedStamp` can only be built from a saved `Visit` or a saved
      `EventConfirmedAttendance`, so Interested/Going and failed saves
      have nothing to pass.
    - The stamp must be in the freshly loaded booklet, so a back-dated
      visit outside the 5-year window gets no ceremony.
    - It shows once per stamp per app session.
    - It never throws, because the stamp is already saved by the time it
      runs.
  - The Passport tab no longer replays its own "just stamped" entrance for
    a stamp the ceremony already pressed.
  - The two Add sheets and the Passport add flow now return the saved row
    (`SavedVisit`, `Visit?`) instead of a bare outcome or bool.
  - `loadOwnPassport` (`own_passport_loader.dart`) is the Passport tab's
    load, moved out of `PassportCollectionBody` so the ceremony and the
    tab read exactly the same booklet.
  - No schema or Supabase changes.

### Changed
- `SupabaseAnalyticsService.ofInstance()` resolves the Supabase client
  only inside each insert's own try, so a screen can track from
  `initState` where Supabase isn't initialised (widget tests) without
  failing. Every insert now reads the signed-in user inside that try
  too.

- 2026-10-30 — **Download traffic cut before the App Store launch.**
  Supabase bills egress, and it is the binding cost at launch. The
  database itself has room for thousands of daily users. Measured figures
  come from read-only requests against production on 2026-10-30; the
  others are estimates.

  | | Before | After |
  |---|---|---|
  | Explore, each mount (measured) | 985 KB gzipped (all 3,480 restaurants + 1,830 hotels) | ~5 KB (9 + 9 rows) |
  | Venue photo on a card (one 1536x2048 original, measured) | 1.6 MB | 69 KB at 512, 274 KB at 1024 |
  | Visit-photo tile (estimated) | the 1600 px upload, ~300–400 KB | unchanged until the switch below is on, then a 512 px copy, ~40–70 KB |
  | Own avatar (measured, one avatar) | 285 KB | unchanged until the switch is on, then a 384 px copy, 33 KB |
  | Flore's card photo / a news card (measured in the simulator) | 353 KB / 279 KB | 28 KB at 512 / 168 KB at 1536 |
  | The same photo seen again | downloaded again (new signed URL each time) | from disk, for 30 days |
  | Notifications | whole history | 50 per page |

  Rough per active user per day: about 1 MB of catalogue per app start
  plus several MB of photos before, against tens of KB of catalogue and a
  few hundred KB of photos, mostly first views, after. That should be
  about an order of magnitude more users per GB. It is an estimate, not a
  measurement of real sessions.
  - **Explore** fetches only the rows its sections can show. The server
    sorts on stars or Keys, then World's 50 Best rank. It returns the whole
    tie group when that group runs past eighth place, so the existing
    selectors still choose by name, and what Explore shows is unchanged.
    Fresh Finds reads only reported rows. `getAll()` is gone from both
    repositories.
  - **Every image goes through `AppNetworkImage`**
    (`lib/core/widgets/app_network_image.dart`) instead of `Image.network`.
    A public Storage photo comes from the render endpoint, sized to its slot
    times the pixel ratio and framing zoom, in six shared sizes. It is
    contain-fit: width alone keeps the original height and distorts the
    photo, measured on production. Focus-point framing still crops on the
    device. The full-screen viewers, the framing editors and admin review
    keep the original. The project is on Pro (the product owner confirmed
    it on 2026-10-30), which the render endpoint needs.
  - **Member photos are not transformed yet.** Visit, stay and attendance
    photos and avatars have signed transformed copies built and tested,
    but they are behind `memberPhotoTransformsEnabled`, which is off. The
    product owner hasn't decided, and the comparison below argues against
    it. While the switch is off, those photos show the cached original,
    exactly as before.
  - **Cost comparison for member photos** (Pro pricing from Supabase's
    docs, 2026-10-30): transformations are $5 per 1,000 distinct origin
    images per billing cycle after 100. Storage is $0.0213 per GB after
    100 GB, and egress is $0.09 per GB after 250 GB. The usage figures are
    assumptions, not data: each active member logs 3 visits a month with
    4 photos each, and views about 30 distinct member photos a month.
    Each tile view saves about 300 KB once per device, since caching
    covers repeats.

    | 5,000 monthly members | Transforms | Small copy uploaded alongside |
    |---|---|---|
    | Running cost | ~150,000 origin images: **~$750/month** | +0.6 MB storage per member a month (3 GB/month in all), inside the 100 GB quota: **~$0** |
    | Egress saved | ~75 GB/month, ~$7 | the same ~75 GB, ~$7 |
    | Build work | none (built, behind the switch) | resize at upload, a second object per photo, delete both together, older photos fall back to the original |

    At 1,000 members, transforms cost about $150 a month. Either way the
    egress saved is a few dollars, because caching already removes the
    repeat views. Transforms would cost about 100 times what they save. A
    small copy costs almost nothing, but it is real work for little gain.
    For avatars, setting the picker's existing `maxWidth` from 1024 to
    512 gets most of the saving with no new mechanism. Venue photos stay
    on transforms: they are a catalogue, not per member (6 today; 5,000 of
    them would be about $25 a month).
  - **Disk cache** (`cached_network_image`). A signed URL is keyed on its
    bucket and path, plus the `transformations` claim of its token, so a
    thumbnail never stands in for an original. Storage answers
    `private, no-cache`, which would have made every view revalidate. Its
    paths are never reused, so cached entries stay valid for 30 days.
  - **Notifications** load 50 at a time, newest first, and the rest as the
    list reaches its end. The ordering and range are applied to the
    existing RPC result, so no server change is needed. The unread badge
    still comes from its own count.
  - **Friend Profile** loads covers for the three verdicts it shows, and
    All visits loads 20 rows' covers at a time as they appear.
  - **Profile** derives its Journey Stats from the Passport load it already
    makes, instead of downloading the visits and restaurants twice.
  - **Checked in the iOS simulator against production, read-only**
    (2026-10-30, signed in by the product owner):
    - Worth the Journey and Stay a Little Longer show three-star
      restaurants and three-Key hotels in World's 50 Best rank order.
    - Search, a restaurant detail page and Profile (4 places, 4 countries,
      2 friends) load.
    - Flore's card photo renders from the 512 variant.
    - The image cache's index stored a real signed avatar under
      `…/render/image/sign/profile-photos/…#height:384,width:384,resize:undefined`,
      which confirms the token claim the key reads.
    - After a relaunch, the avatar (re-signed with a new token) and the
      news image came from disk: the same cached files were touched, and
      nothing was downloaded again.
    - Not exercised: Notifications (opening it marks everything read, a
      write), Friend Profile's All visits, and venue photo upload (a
      write).
  - **Not paged, on purpose:** Passport venues and events, friends, and
    event attendance. Their totals and the "friends going" logic need every
    row.

- `20261030140000_add_get_visit_cover_photos.sql` (written as `20261030120000`, renamed before it was applied, see Fixed): one cover per visit
  (`DISTINCT ON`, `SECURITY INVOKER` so `photos_read` RLS still applies,
  `revoke ... from public, anon`), plus an index on
  `photos (visit_id, taken_at desc nulls last)`, which `photos` had none
  of. It was written and checked against a scratch PG 17. It picks the
  same cover as the old query, which postgrest-dart sends as
  `taken_at.desc.nullslast`, not Postgres' own DESC default, and anon
  cannot execute it. **Applied to production 2026-10-30**, with this build's version bump,
  at the product owner's request; the client still falls back to the old
  query on PGRST202 for any server without it.

### Fixed
- A manager's "Preview my page" no longer records a website tap on
  Restaurant/Hotel Detail. It previously did, since `isPreview` only
  gated personal state, so a manager could inflate their own venue's
  click counts.

- 2026-10-30 — Near-miss: the migration was first named `20261023210000`,
  after `claude/usage-tracking`'s `20261023200000` as briefed. A check of
  every remote branch found `claude/launch-egress` already at
  `20261030120000`, so it was renamed `20261030130000` before any commit.
  "The highest migration" has to be checked across all branches, not taken
  from a brief.

- **mantelier.app's "Nights we're watching" list is current again.** The
  three hard-coded events, from August and September 2026, were replaced
  on 2026-10-30 with the next three published, uncancelled events in
  production, read with the anon key: 9 Nov (Amsterdam), 22 Nov (Schoorl)
  and 24–25 Dec (Eijsden). The 1 Nov dinner in Aalten was left out
  because it was two days away. Names, dates and cities are exactly as
  stored. The list is still static, so it goes stale again after 9 Nov.
  On screens narrower than 480px the date now sits above the name, since
  the real names wrapped to five lines beside it.

- **New users saw "server not available" after tapping the confirmation
  link, although the account had been created and confirmed.**
  `AuthRepository.signUp()` passed no `emailRedirectTo`, so GoTrue sent the
  user to the project's Site URL after confirming. In production that was
  still Supabase's default `http://localhost:3000`. This was verified on
  2026-10-30 with a read-only probe: a GET to production's
  `/auth/v1/verify` with an invalid token returns a `303` to
  `http://localhost:3000#error=…`. The same probe with
  `redirect_to=https://mantelier.app/auth/reset-password`, which is on the
  allow-list, returns a `303` to that URL. GoTrue confirms the email
  *before* it redirects, so the account was always fine. The phone was
  sent to `localhost`, where nothing answers. `signUp()` now passes
  `https://mantelier.app/auth/confirm`. This needed the production Auth
  changes and site deploy below, both done on 2026-10-30.
  - **Near-miss:** gotrue-dart's `resend()` sends no PKCE code challenge,
    so a resent confirmation comes back with implicit-flow tokens. In PKCE
    mode, supabase_flutter ignores those tokens. Sent to the Universal
    Link, the resent link would have opened the app to a silent sign-in
    screen. Resends therefore go to the web-only `/auth/confirmed`.
  - **Near-miss:** the "Open Mantelier" buttons on the confirm and
    reset-password pages did nothing. The product owner found this while
    testing on 2026-10-30. Both linked to the page's own https URL, and
    iOS never hands a Universal Link to the app when it is tapped on its
    own domain, so the tap only reloaded the page. `reset-password.html`
    has done this since 2026-09-24, where its comment claimed the
    opposite. Both buttons now use `mantelier://` (see Added).
  - **Near-miss:** supabase_flutter reports a failed link only as an error
    on `onAuthStateChange`. AuthGate's subscription had no `onError`, so
    an expired link left a silent sign-in screen. AuthGate now shows a
    notice for the two link failures it can identify (`otp_expired`, and a
    missing PKCE verifier or flow state). It deliberately ignores every
    other stream error, such as a failed session refresh, because the
    same stream carries errors that have nothing to do with a link.
  - **Production Auth settings, for the product owner** (Dashboard →
    Authentication → URL Configuration): set **Site URL** to
    `https://mantelier.app/auth/confirm`, which also fixes 1.4.0 (17) and
    older builds because they send no redirect. Add
    `https://mantelier.app/auth/confirm` and
    `https://mantelier.app/auth/confirmed` to **Redirect URLs**. Then
    deploy `site/` (`auth/confirm.html`, `_redirects` and the updated
    `.well-known/apple-app-site-association`) to mantelier.app.
    `supabase/config.toml` lists the same redirect URLs for the local
    stack only.
  - **Done, 2026-10-30.** The product owner changed both dashboard
    settings. The `/verify` probe now redirects to
    `https://mantelier.app/auth/confirm`, and accepts `/auth/confirmed`.
    `site/` was deployed with `wrangler pages deploy … --project-name
    mantelier --branch main`. mantelier.app serves `/auth/confirm`,
    `/auth/confirmed` (through the rewrite) and the new AASA, and Apple's
    AASA CDN already has the `/auth/confirm` entry. A full sign-up on a
    device has not been run yet.

- **Near-miss: the ceremony route rendered every booklet label with
  Flutter's yellow-underlined debug text style.** A pushed route has no
  Scaffold, and therefore no `Material`, above it. The Passport tab
  inherits one, so the shared booklet widgets had never needed their own.
  The widget tests passed; it was the simulator that showed it. The
  overlay now provides its own `Material`, and a test checks the
  inherited text style. That test fails without the fix. This would recur
  for any booklet widget shown from a new route.

- **Near-miss: the stamper drew nothing on the device.** Its `CustomPaint`
  was given the Stack's own `Size` object, which trips Flutter's "size
  assigned inappropriately" layout assertion. Nothing painted, while the
  impression underneath still landed on time, so it looked like a timing
  problem. `Positioned.fill` already sizes the layer, and the argument is
  gone. A test now checks that the stamper is on screen during its run.

- 2026-10-30 — **A PNG venue photo was stored as `.jpg` with
  `image/jpeg`, and could exceed the 5 MiB limit.** The pipeline
  re-encoded every photo at full resolution, so a file that passed the
  5 MiB check could come out larger. That limit is also the bucket's own.
  `prepareVenuePhoto` now returns the bytes together with their real
  extension and content type. It caps the long edge at 2560 px and steps
  down 15% at a time while the file is still too big, never below the
  1200 px short side. Only a PNG that cannot fit even then becomes a JPEG,
  and it is labelled as one. `publish-venue-photo` copies the object, so
  the published photo keeps the right type.

- 2026-10-30 — **Near-miss: two migrations reached production out of
  filename order.** `20261030130000` (push notifications) was named after
  launch-egress's `20261030120000` but was applied first, from its own
  branch. Applied as named, a fresh replay would have run them in the
  opposite order from production. They touch no common object, but
  filename order is replay order, so the unapplied one was renamed
  `20261030140000` before it went anywhere. The push migration's header,
  already applied, still says it was named after `20261030120000`; it is
  left as it is.

- 2026-10-30 — **Merging launch-egress's notification paging with push
  notifications' `get_notifications_v4`.** Each branch rewrote
  `NotificationsRepository.getNotifications`, and git could not combine
  them. The merged version pages the result and asks for v4 first, then
  falls back through v3, v2 and v1. Two paging tests still expected v3
  first and were updated.

- 2026-10-30 — **Near-miss: Yi Long Court's website and phone were
  confirmed after the China import was applied**, so merging the data
  branch alone would never have reached production. Written as its own
  guarded correction and applied with this build (Michelin_Database
  CHANGELOG, QA-299).

### Known limits
- "Once per stamp" is per app session. Re-confirming an event that was
  already confirmed in an earlier session would show the ceremony again,
  because `confirmAttendance` returns the existing row. Neither event
  surface offers confirmation once attendance exists, so this was not
  guarded against further.
- The five call sites were not pumped in widget tests: they build their
  repositories against `Supabase.instance.client`, the same limitation as
  `add_visit_sheet_shell_test.dart`. They were checked by reading. The
  simulator check used a throwaway preview with fixture stamps rather
  than a real save, so nothing was written to production.

---

## v1.4.0 (17) — 2026-10-30

Built from `main`, after merging `claude/passport-globe` into
`release/1.4.0`. The app change is the 3D globe for My Map, plus MapTiler
tiles for the event location picker. A minor version bump, because the
globe is a visible new feature. The five MICHELIN imports below were
applied to production before this build. Ledger at the version bump: 114
migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 114 migrations, 2026-10-30:
- **The replay:** all 114 files applied with no error, giving 114 ledger
  rows.
- **`supabase db dump`, both sides:** identical apart from the same 6 blank
  lines (platform statements the CLI filters out).
- **Storage and auth, compared directly:** all 5 buckets, 13
  `storage.objects` policies, triggers and RLS on both storage tables are
  identical.
- **Expected noise:** the only extra row is the local-only
  `enforce_versioning_status_transition` trigger.
- **Before the build:**
  - `flutter analyze` was clean and all 2,595 tests passed on the merged
    tree.
  - My Map was checked in the iOS simulator against production: the globe
    spins with inertia, the visited countries are highlighted, and pins
    cluster.
  - The build's `.env` carries `MAPTILER_KEY`.

### Added
- 2026-10-30 — Catalogue: five MICHELIN imports, applied to production.
  None needs an app change; build 1.3.0 (16) pages past PostgREST's
  1000-row cap, so it shows them in full. Details are in the
  Michelin_Database CHANGELOG.
  - **Migrations:** `20261023150000` (CN), `20261023160000` (US/CA/MX,
    adds the `countries` row for Canada), `20261023170000` (HK/MO/TW),
    `20261023180000` (CH/AT/Nordics, adds the `countries` row for Iceland)
    and `20261023190000` (FR Key hotel towns). All five went in one plain
    `supabase db push --linked`, in filename order.
  - **Ledger:** 109 → 114/114, local and remote in agreement.
  - **Data:** one guarded file per import, applied in the same order, then
    Monaco's Key hotel file. None aborted.
  - **Totals:** the catalogue now holds 3,439 starred restaurants, 1,830
    hotels and 317 hotel links.
  - **Not filled:** none of the new rows has a Google Place ID (QA-289,
    QA-300, QA-350 and the CH/AT/Nordic equivalent).
  - **Schema diff:** covered by this release's version-bump diff above.

### Changed
- **My Map is now a 3D globe.** The map behind Passport's top-right corner
  was a flat `flutter_map` view. It is now a globe drawn in Flutter
  (`lib/features/map/globe/`). It shows the same places as before (visited
  restaurants, hotel stays, events with confirmed attendance) with the same
  All / Restaurants / Hotels / Events filters, and a pin tap still opens
  the preview sheet that leads to the venue or event detail.
  - Drag spins it with inertia, and pinch zooms from the whole world down
    to about 250 km across.
  - It turns slowly while idle. Any touch stops it, and it starts again
    after 12 seconds untouched, but only when zoomed out. Reduced motion
    turns it off.
  - Tapping a pin flies the globe to it, then opens the preview sheet.
  - Pins within a finger's width of each other merge into a numbered
    marker. Tapping it flies in until they separate. When zooming can't
    separate them (one address, or one city at maximum zoom), it opens a
    short list of those places, and each one opens its preview sheet.
  - Countries with at least one pin under the current filter are drawn in
    full ivory and the rest are muted. This keys on the stored
    `country_code`, never on the coordinate. All 59 codes in production
    `countries` exist in the outline data (checked 2026-10-30).
  - The first view shows the whole globe turned towards the user's places.
    Choosing a filter flies in to frame them.
- **No map tiles, no API key, works offline.** The outlines are Natural
  Earth 1:50m countries (public domain, v5.1.2), simplified and bundled as
  `assets/globe/countries.bin` (212 KB) by
  `scripts/build_globe_outlines.py`. My Map no longer requests tiles from
  `tile.openstreetmap.org`. OpenStreetMap's tile usage policy doesn't allow
  a published app to load its tiles directly at volume, so this also
  removes a compliance risk. `flutter_map` stays as a dependency because
  the event location picker still uses it.
- **The event location picker now uses MapTiler tiles.** It was the last
  screen loading tiles straight from `tile.openstreetmap.org`, and it showed
  none of the credit those tiles require. It keeps `flutter_map` and works
  exactly as before (tap to drop the pin, "Use this location"), now with
  MapTiler's Streets map (`streets-v2`, sharp tiles on high-density
  screens) and the required "© MapTiler © OpenStreetMap contributors"
  credit, each name linking to its copyright page.
  - The key is a MapTiler client key, read from `MAPTILER_KEY` in `.env`
    (`MapTilerConfig`, `lib/core/maps/`). It is public by design, like the
    anon key. On MapTiler's free plan a copied key can only use up the
    monthly allowance, after which tiles stop: there is no bill.
  - With no key, the picker says the map can't be shown and offers no pin.
    It never falls back to OpenStreetMap's servers. **`MAPTILER_KEY` must
    be in the `.env` of whatever build ships this**, or managers can't set
    an event location on the map.
  - The key is restricted on MapTiler's side to the user-agent the picker
    sends, `flutter_map (app.mantelier)` (set by `userAgentPackageName`),
    with no HTTP origins listed, since a native app sends none. This is a
    deterrent, not real security: the header is easy to copy. Checked
    2026-10-30: a tile request with that user-agent returns 200, the same
    request as `curl` returns 403.
  - Checked in the iOS simulator through a throwaway entry point that opens
    the picker directly, since the test account manages no venue: street
    tiles of Amsterdam load sharp, with the credit visible.

### Fixed
- **Near-miss: a merge script committed conflict markers.** While merging
  the import branches, a helper script checked that each branch only
  appended rows to `qa_issues.csv`. When that check failed for one branch
  it raised, but the shell carried on, staged the file with conflict
  markers still in it, and committed the merge. It was caught before
  anything was pushed, and the file was rebuilt from the branch's own
  appended rows.
  - **Why it would recur:** a script that raises doesn't stop the commands
    after it unless the shell is told to, so any merge helper should stop
    on its first error.
  - **Also found:** the CH/AT/Nordic branch cited QA-360–374 in its README
    but had not added those rows to `qa_issues.csv`. That branch added them
    afterwards (b566df8), and they are carried here.

---

## v1.3.0 (16) — 2026-10-29

Built from `main`, after merging `release/1.3.0`, `data/de-it-2026`, and the
two data branches `claude/kind-rubin-d65c44` (Key hotel contacts) and
`claude/stoic-austin-e5e924` (UK and Ireland). This is 1.3.0 (15) plus two
app changes: the 1000-row catalogue fix and "Invite friends" on Trip Detail.

It goes out alongside three catalogue imports, all applied to production
before this build:
- MICHELIN Germany and Italy 2026;
- MICHELIN UK and Ireland 2026;
- the contact fields for Key hotels in ten countries.

They added two migrations (`20261023130000`, `20261023140000`), so the
ledger at the version bump is 109 migrations, local and remote in
agreement. The data is live on 14 and 15 too, but only this build shows
past the first 1000 places, and the catalogue now holds 2,611 starred
restaurants.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 109 migrations, 2026-10-29, after the UK and Ireland migration was
applied:
- **The replay:** all 109 files applied with no error, giving 109 ledger
  rows.
- **`supabase db dump`, both sides:** identical apart from the same 6 blank
  lines (platform statements the CLI filters out).
- **Storage and auth, compared directly:** all 5 buckets, 13
  `storage.objects` policies, triggers and RLS on both storage tables are
  identical.
- **Expected noise:** the only extra row is the local-only
  `enforce_versioning_status_transition` trigger.
- **Earlier run:** the same diff on 108 migrations, before the UK and
  Ireland migration, was equally clean.
- **Before the build:** `flutter analyze` was clean and all 2,572 tests
  passed on the merged tree.

### Added
- 2026-10-29 — Catalogue: MICHELIN United Kingdom and Ireland 2026.
  - **Migration:** `20261023140000_add_gb_ie_2026_star_and_key_cities`
    adds the `countries` row for Ireland (`IE`, `{Europe/Dublin}`), then
    132 GB and 24 IE towns. Applied with plain `supabase db push --linked`.
  - **Ledger:** 108 → 109/109, local and remote in agreement.
  - **Data:** then `michelin_gb_ie_2026/prepared_gb_ie_stars_2026.sql`.
    It adds 214 restaurants and 139 Key hotels, with 39 hotel links.
  - **Not filled:** the new rows have no Google Place IDs yet (QA-280).
  - **Details:** in the Michelin_Database CHANGELOG.
- 2026-10-29 — Catalogue: phone, website and MICHELIN link for Key hotels
  in ES, IT, DE, JP, AT, CH, BE, HU, PL and HR.
  - **Files:** ten fill-only data files in `michelin_key_hotel_contacts/`.
    No migration.
  - **Result:** all 646 Key hotels in those countries now have a MICHELIN
    link; 29 phones and 20 websites are still blank.
- 2026-10-29 — Catalogue: MICHELIN Germany 2026 and Italy 2026.
  - **Migration:** `20261023130000_add_de_it_2026_star_cities` (330 DE/IT
    towns), applied with plain `supabase db push --linked`.
  - **Ledger:** 107 → 108/108, local and remote in agreement.
  - **Data:** then `michelin_de_it/prepared_de_it_stars_2026.sql` and
    `prepared_aqua_closure.sql`. Details are in the Michelin_Database
    CHANGELOG.
  - **No app change** is needed to show the new rows. However, the
    catalogue now holds 2,397 starred restaurants, so builds without the
    row-cap fix below (14 and 15) still show only the first 1000 in Guides.

### Changed
- Trip Detail: a trip with nobody else on it or invited now shows
  "Invite friends" (with an add-person icon) where it said "Just you so
  far", and the ⋯ menu item reads "Invite friends" until someone else is
  on the trip. On a real phone the old line didn't read as the way to
  invite, so the feature went unfound.

### Fixed
- **Guides' MICHELIN catalogue said "1000 places" while production holds
  1,797 starred restaurants.**
  - **Cause:** PostgREST returns at most `max_rows` (1000) rows per
    request and says nothing when it truncates. `RestaurantRepository.search`
    read the whole catalogue in one request, so it stopped at row 1000
    once the Spain and Belgium imports took the catalogue past 1000.
  - **Fix:** every unbounded catalogue read now pages through
    `fetchAllRows`, 1000 at a time, with `id` as a unique last sort key so
    pages can't skip or repeat rows. That covers `search`, `getAll`,
    `searchInPlaces` and `getCountries` on both repositories.
  - **Hidden side effect:** the country pickers had the same bug. They
    read one `country_code` per row, so any country whose rows fell
    after row 1000 dropped out of the picker.
  - **Hotels:** 811 rows, under the cap for now. They are paged the same
    way before Germany and Italy push them closer.
  - **Verified:** on the simulator against production, the catalogue shows
    "1797 places". `test/fetch_all_rows_test.dart` runs against a fake
    server that caps at 1000 like PostgREST; its country test fails
    without the fix. Analyze clean, 2,572 tests pass.
  - **Why it would recur:** any new query over the catalogue that skips
    `fetchAllRows` works in testing and breaks silently once the table
    passes 1000 rows.

---

## v1.3.0 (15) — 2026-10-29

Built from `release/1.3.0`: 1.3.0 (14) plus one app fix. No database change;
the ledger is still 107 migrations, local and remote in agreement. No
migration was added since (14)'s schema diff, so that diff still stands.

### Fixed
- **Splitting a trip into destinations could be refused with "Each
  destination's dates must fall within the trip".** Create Trip's default
  dates kept the current time of day (`now + 30 days`), and the
  destination check compared full timestamps. A destination lining up with
  a default trip date therefore counted as outside the trip. Dates in the
  sheet are now calendar days and compared by day. If a destination really
  is outside the trip, the message names it and both date ranges. A
  database refusal shows the database's own text. Reported on 1.3.0 (14)
  with a 10 Nov – 1 Dec trip split in two. Those exact steps weren't
  reproduced; the failing path is covered in
  `test/create_trip_leg_dates_test.dart`. (Cherry-picked from
  `feature/trips-redesign`, `8ae87c5`.)

---

## v1.3.0 (14) — 2026-10-29

Built from `release/1.3.0`. Every database change below was applied to
production before this build, so the build only adds the screens that use
them. Installed 1.2.0 (13) builds keep working against the same database:
the trips migration keeps `planned_trips.country_code`/`city` in step for
them, and the Selection and 50 Best columns are additions they don't read.
Ledger at the version bump: 107 migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 107 migrations, 2026-10-29:
- **The replay:** all 107 files applied with no error, giving 107 ledger
  rows.
- **`supabase db dump`, both sides:** identical apart from 6 blank lines,
  the platform statements the CLI filters out.
- **Storage and auth, compared directly:** all 5 buckets, 13
  `storage.objects` policies, 8 triggers and RLS on both storage tables
  are identical.
- **Expected noise:** the one extra local trigger,
  `enforce_versioning_status_transition`, comes from the newer local
  storage service, not from drift.
- **Before the bump:** `flutter analyze` was clean and all 2,560 tests
  passed, on `main` after merging `feature/trips-redesign` and
  `feature/editorial-selection`.

**In this release, for testers:**
- **Trips, restyled and multi-destination.**
  - **Destinations:** a trip can cover several countries and cities, each
    leg with its own stays, dining and events.
  - **Shared trips:** invite friends onto a trip.
  - **Pickers:** "Add stay" and "Add restaurant" offer only venues in that
    leg's destination.
- **Mantelier Selection.** Our own picks, as "Mantelier's latest" on
  Explore and a Selection guide on Guides. Tacite and Petit Péché are the
  first two.
- **Guide links.**
  - **World's 50 Best:** a "50 Best" link to the venue's own page.
  - **Gault&Millau:** the restaurant's awards and a link to its page.
  - **Award History:** shows MICHELIN, World's 50 Best and Gault&Millau
    side by side.
- **Catalogue:**
  - MICHELIN Spain 2026 (296 starred), Belgium & Luxembourg 2026 and
    Monaco;
  - more World's 50 Best history, including 51–100 ranks;
  - QA fixes: Kjolle's location, the Plaza Athénée rename and Peru hotel
    phones.

### Added

- 2026-10-28 — The editorial Selection ("Mantelier Selection"), a fourth
  way into the catalogue next to a MICHELIN star, World's 50 Best and the
  hall of fame, decided by the product owner so restaurants we choose
  ourselves can be listed without an award. **Applied to production
  2026-10-28**, with Tacite (`rest_1840`) and Petit Péché (`rest_1841`),
  Amsterdam, as its first two entries.
  - Verified in production after the apply: ledger row present; the check
    constraint lists all six values; RLS on `editorial_selections`; `anon`
    can read but not write, `authenticated` can't write. Both restaurants
    inserted in one statement (`prepared_insert.sql` step 1), and
    `restaurants_full` returns both: Amsterdam, NL, `michelin_stars` NULL,
    `open`. Google Place IDs left NULL until found.
  - Checked on the simulator against production: "Mantelier's latest"
    below What's On with both restaurants; "Mantelier Selection" first on
    Guides, opening a two-restaurant catalogue; Tacite's detail page with
    no empty star row. The Explore "Collections" line now names the
    Selection first.
  - **`20261023120000_add_editorial_selection.sql`:** widens
    `restaurants.inclusion_reason` with `editorial_selection`, and adds
    `public.editorial_selections` (one row per entry, `removed_on` instead
    of deleting, at most one current entry per restaurant). Public read,
    select-only grant to `anon`/`authenticated`, no client write. Replayed
    on a throwaway local Postgres 17 against a stub `restaurants` table:
    the constraint, the one-current-entry index, the date check and the
    grants behave as intended; not replayed on the full Supabase stack.
  - First two entries prepared in
    `supabase/data/enrichment/editorial_selection/`: Tacite and Petit
    Péché, Amsterdam. Google Place IDs still to be found before apply.
  - Scope rule updated in `DATABASE_ARCHITECTURE.md`, `START_HERE.md` and
    `CLAUDE.md`. The product owner then dropped the restriction outright
    (2026-10-28: the catalogue is no longer limited to MICHELIN, World's 50
    Best and Gault&Millau restaurants); `CLAUDE.md` now says so.
  - Renumbered to `20261023120000` before apply: `20261019140000`,
    `20261019150000`, `20261021120000` and `20261022120000` were applied in
    between. Re-tested on a full local replay of production's exact
    migration set, seeded with restaurants carrying every
    `inclusion_reason` value in use: the constraint accepts every existing
    row, the prepared insert gives `rest_1840` Tacite and `rest_1841`
    Petit Péché, and `restaurants_full` shows both.
  - **App:** "Mantelier's latest" on Explore, directly below What's On (the
    eight newest Selection restaurants), and a "Mantelier Selection" family
    on Guides above MICHELIN, opening a catalogue of every Selection
    restaurant with on-device search and a country filter. The label is
    forest green, never gold; a starred Selection restaurant still shows
    its stars. Reads `editorial_selections` (`removed_on is null`), never
    `inclusion_reason`, and leaves the Selection out when the table doesn't
    exist yet.
- 2026-10-28 — Catalogue: MICHELIN Spain 2026 and Belgium & Luxembourg 2026.
  - **Migrations:** `20261019140000_add_es_2026_star_cities` (123 ES towns)
    and `20261019150000_add_be_2026_star_cities` (7 BE cities).
  - **Applied 2026-10-28,** after the v1.2.0 (13) build, so they are
    recorded here rather than in that section. Both went out in one
    `supabase db push --linked`, Spain sorting first; the ledger went from
    102 to 104/104, with local and remote in agreement. The data files
    (`michelin_es_stars/`, `michelin_be_lu_stars_2026/` and the Belgian
    Place IDs) were then run. Details are in the Michelin_Database CHANGELOG.
  - **No app change:** installed builds read the new rows as they are.

- Restaurant Detail shows the latest Gault&Millau award as a hero badge
  and links to the restaurant's own Gault&Millau page from the utility
  row. Award History gains a Gault&Millau section beside MICHELIN and
  World's 50 Best. App only, no schema change. A plan for World's 50 Best
  page links (no URL is stored yet) is in
  `docs/Architecture/GUIDE_SOURCE_LINKS_PLAN.md`.
- 2026-10-28 — World's 50 Best links. Restaurant and Hotel Detail get a
  "50 Best" action that opens the venue's own the50.com page.
  - **Migration:** `20261021120000_add_worlds_50_best_urls` adds
    `worlds_50_best_url` to `restaurants`/`hotels` and appends it to both
    `_full` views.
  - **Applied 2026-10-28,** after the v1.2.0 (13) build. Ledger 104 → 105,
    local and remote in agreement. Then
    `guide_source_links/apply_guide_source_links.sql` filled 113
    restaurant and 123 hotel URLs, plus the Gault&Millau fixes below.
  - **Order matters:** a build carrying the new column lists must not ship
    to a database without the migration. The migration is live, so any
    build from here on is safe.
  - **Not replay-tested:** no Docker on this machine. The view columns
    were checked against production instead.
- **Multi-destination trips.** Create/Edit Trip holds a list of destinations:
  a catalogue country, optionally narrowed to a catalogue city (new city
  picker, by `cities.id`), with Arrive/Leave dates required once there's more
  than one. Saved atomically through `save_trip_destinations`.
- **Trip Detail by leg.** A multi-destination trip shows one section per
  leg with its own stays and dining, and an "Elsewhere" section for plans
  outside every destination. A leg's "Add stay"/"Add" pickers are scoped to
  that leg (city id or country code), and new plans default to its dates.
- **Events per leg** (decision 2). Events are fetched for every destination
  country and matched on each leg's own dates and country, in Trip Detail,
  on the featured trip card and in discovery ranking's trip signal, which now
  names the matching leg's city.
- **Shared trips.** A "Travelling with" row and sheet on Trip Detail.
  Any member invites their own friends; the owner removes anyone; whoever
  sent a pending invite can withdraw it; members can leave. Other members'
  plans show read-only with "Added by …". Open invitations appear at the top
  of Trips and in Notifications (Join trip / Decline), read through
  `get_notifications_v3`.
- Catalogue venues now carry `city_id` (`Restaurant.cityId`/`Hotel.cityId`).
  The scoped `searchInPlaces` sorts A→Z.
- **Works before the migration too.** Against a server without
  20261022120000, Trips behaves exactly as the single-
  destination, owner-only build: the repository falls back on PostgREST's
  "not found" errors and hides destinations and sharing. Verified against
  production on the simulator.
- Verified end to end on the simulator against a local stack with the
  migration (`docs/Engineering/checks/trips_local_fixtures.sql`: local-only
  test accounts and fake venues). Checked: accept an invitation, create a
  two-leg trip with a city, legs, Elsewhere, per-leg events (an Italian
  event during the French dates correctly excluded), the leg-scoped picker,
  another member's read-only plan, the members sheet, and Edit pre-fill.

### Changed

- **Trips restyled** (Passport → Trips, Trip Detail, Create/Edit Trip, the
  venue pickers). The sections follow Explore's header pattern, and planned
  stays and visits are now the same ivory photo cards Passport uses
  (`CsPlaceCard` with the venue's card photo). Trip Detail gets a display-scale
  header with the destination and a pull-quote for notes. Dialogs, action
  sheets and snackbars are shared across Trips (`trip_chrome.dart`). Gold
  appears only on stars and Keys: removed from the Add/Change actions, the
  focus underline, spinners and the forest-green snackbars.
- **Pickers scoped to the trip's destination.** "Add stay"/"Add restaurant"
  offer only venues in the trip's own country, filtered server-side on
  `country_code` (never a name, never `property_name`). In Create Trip they
  stay disabled until a destination is chosen, and changing the destination
  drops picks from another country.
- A stay's date eyebrow uses the shortest unambiguous range
  ("27–30 Nov 2026") so it fits on one line; Trip Detail's start label
  ("IN 30 DAYS") is uppercase like the other eyebrows.
- `CsPlaceCard` gains an optional `onLongPress` (null by default, so
  existing cards are unchanged).

### Database

- **Applied 2026-10-28: `20261022120000_add_trip_destinations_and_members.sql`.**
  Several destinations per trip (`planned_trip_destinations`: a catalogue
  country plus an optional catalogue city, with leg dates required once
  there's more than one) and shared trips (`planned_trip_members`, plus
  invite/respond/leave/remove RPCs). Any member can invite their own
  friends. Unfriending or blocking removes the other person from your trips
  that haven't ended yet; past trips are untouched.
  Installed 1.2.0 builds keep working: `planned_trips.country_code`/`city`
  stay in step with the first destination, and they never see shared trips
  or the new notification types (`get_notifications_v3`/`_count_v3` are the
  only readers that include them).
  A plan can now only be attached to a trip you're on; before, any trip id
  was accepted.
  Verified in production after the apply:
  - ledger row present; both tables exist with RLS on;
  - all 5 existing trips have a first destination; the 16 planned venues are untouched;
  - anon can execute none of the 16 new functions;
  - the 8 client RPCs are callable by `authenticated`, the internal helpers are not;
  - all 7 triggers are present.
  `supabase migration list --linked` agrees, 106/106. That's measured with
  main and `feature/guide-sources`' applied `20261021120000`; this branch
  alone lacks those three files until it's merged.
  Checks: `docs/Engineering/checks/trip_destinations_and_members_checks.sql`,
  44/44 on a fresh replay of production's exact migration set, and again on
  a replay seeded with five pre-existing trips.
  Plan: `docs/Architecture/TRIPS_MULTI_DESTINATION_AND_SHARING_PLAN.md`.

### Fixed

- 2026-10-28 — Near-miss, caught before anything was applied. The
  Belgian update had picked `rest_1405`–`1417` for its new restaurants
  while France 2026 took the same codes on production. Its Place ID file
  checked only that each code existed, so it would have written Belgian
  Google records onto 13 French starred restaurants (Paul Bocuse among
  them).
  - **Renumbering:** Belgium was renumbered to `rest_1827`–`1839`.
  - **New guard:** every prepared Place ID file, and the Spanish file,
    now stops unless each code is the restaurant it was researched for,
    identified by its MICHELIN page.
  - **Why it would recur:** codes are picked as "the next free one" on a
    branch, while other branches pick from the same range. Only an
    identity check at apply time catches a code that someone else has
    taken since.
  - **Checked after the apply:** `rest_1405`–`1417` are still 13 French
    rows.

- Near-miss: 8 `gault_millau_awards.gault_millau_url` values in production
  are the import's `"not found"` placeholder text, not NULL. Linking the
  column directly would have opened a broken URL. The app now links only
  absolute http(s) values (`GaultMillauAward.profileUrl`). The data was
  then corrected on 2026-10-28 (QA-244): placeholders to NULL, 7 real
  pages filled.

- **"Change hotel" deleted every stay on the trip.** Trip Detail assumed one
  hotel per trip, but `planned_venues` allows several, and a second stay
  planned from the venue's own Plan sheet was silently removed. "Add stay"
  now only adds; each stay is removed on its own.
- **Countries listed Z→A in Create Trip, and the pickers listed venues Z→A.**
  postgrest-dart's `.order()` defaults to descending: `loadAllCountries`
  now passes `ascending: true`, and the pickers sort by name. The shared
  `RestaurantRepository.search`/`HotelRepository.search` still order
  `name` descending for every other caller (left alone here, logged as a
  follow-up), the same trap their own comment already warns about.

- **Migration filename collision, caught before apply.** This migration was
  written as `20261021120000`, but `feature/guide-sources` independently took
  the same version (`add_worlds_50_best_urls`) and applied it first; the
  ledger keys on the version alone. Renamed to `20261022120000` before it
  ever ran. It would recur whenever two branches pick "the next" timestamp
  without checking the remote ledger and every branch first.
- **First production apply failed and rolled back; no data or schema
  changed.** The backfill (one destination per existing trip) ran before
  the RLS section, so each inserted row queued a deferred date-check trigger,
  and Postgres refuses `ALTER TABLE … enable row level security` on a table
  with pending trigger events (SQLSTATE 55006). Local replays had passed
  because they had no trips to backfill; production had 5.
  Rollback verified in production: no new tables, functions or triggers;
  no ledger row; the `planned_trips` policy unchanged. Fixed by moving the
  backfill to the end of the migration, then re-tested on a replay seeded
  with five trips before re-applying. The lesson: a local replay with empty
  user tables doesn't exercise a migration's backfill path. Seed
  representative rows before applying anything that backfills.

---

## v1.2.0 (13) — 2026-10-28

Built from `release/1.2.0`. Every database change below was applied to
production before this build, so the build only adds the screens that use
them; installed 1.1.0 (12) builds keep working against the same database.
Ledger at the version bump: 102 migrations, local and remote in agreement.

**Schema diff at the version bump** (CLAUDE.md; method in
`NEW_MACHINE_SETUP.md` §4), production against a fresh full-stack replay of
all 102 migrations, 2026-10-28:
- `supabase db dump`, both sides: identical apart from 6 blank lines, the
  platform statements the CLI filters out.
- Storage and auth, compared directly: all 5 buckets, 13 `storage.objects`
  policies, 8 triggers and RLS on both storage tables identical. The one
  extra local trigger, `enforce_versioning_status_transition`, comes from
  the newer local storage service: expected noise, not drift.

**In this release, for testers:**
- **Venue events.** A venue's managers create, edit and cancel their own
  events from My venues → a venue → Events. New events are reviewed first;
  edits to a live event go live straight away and are recorded for the
  admins.
- **A landing page per managed venue** with Profile, Photos and Events.
- **In-app review for admins**: claims, about texts, photos, events and
  changes to live events, with a real preview.
- **Photo framing and a separate card photo** for venue managers.
- **Friend requests** have their own Requests tab.
- **Catalogue:** MICHELIN Netherlands 2026, France 2026 (652 starred),
  Peru's 15 Key hotels, the completed World's 50 Best lists, phone numbers
  and Google Place IDs.
- **Minimum iOS raised to 15.0.**

### Added

- 2026-10-28 — MICHELIN France 2026 and Peru catalogue data, with two
  migrations. Data details and QA ids are in the Michelin_Database
  CHANGELOG.
  - **Migrations:** `20261019120000_add_fr_2026_star_cities` (82 FR
    cities) and `20261019130000_add_pe_key_hotel_cities` (5 PE cities),
    only `public.cities` rows. Ledger 100 → 102.
  - **Data files** (`supabase/data/enrichment/APPLY_FR_PE_2026.md`):
    - France: 14 star corrections, 410 MICHELIN URLs, 173 new starred
      restaurants and 533 phones. France is now 652 starred: 30 / 80 / 542.
    - Peru: 14 Key hotels (Peru now 15: 1 / 4 / 10), Palacio Nazarenas'
      Key row, and Central and Mil's World's 50 Best history.
  - **Checked before and after:** every pre-write check was rerun read-only
    against production with the files' own data first; afterwards the
    counts, award rows and `_full` views were verified on production.
  - **Applied 2026-10-28.** No app code changed.

- 2026-10-28 — Venue events, phase 3: the app. It reads only the
  `20261018130000` RPCs; none of it works until that migration is
  applied.
  - **Events screen** (My venues → a venue → Events): every event the
    venue hosts, from `get_venue_events`, so every active manager sees
    the same list.
    - It groups them as awaiting review, not approved (with the
      reviewer's note), live, past and cancelled.
    - "Create an event" opens the form, and tapping an event edits it.
    - The landing page's summary counts upcoming, awaiting review and
      not approved.
  - **The event form** (`VenueEventFormScreen`):
    - name, description, one of the 7 V1 types, and tags from
      `event_tags`;
    - a date, an optional end date, an optional start time, and an end
      time only once there is a start. A time left out is sent as
      nothing and shown as "not given", never guessed;
    - "At {venue}", where the server copies the venue's verified
      location, or a place, city, country and a map pin
      (`PickEventLocationScreen`, OpenStreetMap);
    - the timezone comes from the country, and a country with several
      zones is asked;
    - ticket link, admission type and admission note.

    The form checks the server's own rules first: the window up to one
    year ahead, with "today" in the event's timezone; an end before the
    start on one day; https only. A refusal from the server is shown in
    its own words. A live event says "changes go live straight away", and
    a rejected one shows the note and "Save and resubmit". Cancelling
    asks for confirmation first.
  - **Review:** the queue gains EVENTS and CHANGES TO LIVE EVENTS, listed
    by event name. `ReviewEventScreen` handles both:
    - **a submitted event** shows its details as entered and "Preview
      the event page", which opens the real `EventDetailScreen`. The
      admin chooses Approve and publish, or Reject with a note;
    - **a change to a live event** shows each changed field, old → new,
      with a value left empty shown as "not given". The admin chooses
      Mark as seen, or Take offline with a note.
  - **Notifications:**
    - `event_approved` opens the event's page, and `event_rejected` shows
      the note;
    - the list and the unread count read the `_v2` functions, falling
      back to the old ones while a server doesn't have `_v2` yet;
    - **a type this build doesn't know is skipped** (`tryFromRow`), no
      longer a reason the whole list fails to load. The next new type
      can't empty the screen again.
  - **Event times:** venues may submit date-only or start-only events.
    This was decided by the product owner on 2026-10-28, over the time
    audit's earlier rule that host events need both times. The audit's
    "Host-Created Events" section is marked superseded in place, and
    `satisfiesHostCreatedEventTimeRequirement` stays unused with a note
    saying why.
  - **Tests:** 20 new; the existing venue tests now run against the new
    repository. 2,511 tests pass and analyze is clean.

    **Not tried on the simulator:** the screens need the phase 3
    migrations, which aren't on production yet.

- 2026-10-28 — Venue events, phase 3 of
  `docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md`: the database
  half. The design and the six decisions taken are in
  `docs/Architecture/VENUE_EVENTS_PHASE_3_DESIGN.md`. There are two
  migrations; no app code changes yet.
  - **`20261018120000_add_country_timezones`:**
    - adds `countries.timezones`, every IANA zone for each country
      (tzdata 2025b `zone.tab`; QA-226, see the Michelin_Database
      CHANGELOG);
    - with one zone, the event form uses it as the default; with
      several, the form asks.
  - **`20261018130000_add_venue_event_submission`, what a venue calls:**
    - venues write events only through `submit_venue_event`,
      `update_venue_event` and `cancel_venue_event`, and read their own
      with `get_venue_events`;
    - the rights are those of any active manager of a host venue, not
      "whoever submitted it";
    - submitting creates the event as `submitted`, with its host link and
      tags, in one transaction;
    - editing a rejected event resubmits it;
    - editing a live event keeps it live and records the change in
      `event_edits`; an unchanged save records nothing;
    - "held at the venue" copies the venue's own verified location.
  - **Same migration, the rules:** one validation function serves both
    submit and update:
    - the 7 V1 types, and only tags that exist;
    - start and end dates from today up to one year ahead, with "today"
      in the event's own timezone;
    - an end time only with a start time, and on a single day the end
      after the start (00:00 means the end of that day);
    - coordinates, and a timezone from the event country's own list;
    - `start_at`/`end_at` are set only from a known time, never invented.
  - **Same migration, what an admin calls:**
    - `admin_approve_event`, and `admin_reject_event`, which needs a note
      and also takes a live event offline;
    - `admin_mark_event_edit_seen`;
    - each sends `event_approved`/`event_rejected` to the submitter;
    - `get_review_queue()` gains the kinds `venue_event` and
      `venue_event_edit`; installed builds skip kinds they don't know;
    - admins can read events that aren't published yet, for the review
      preview;
    - `events` gains `submitted_at`, `reviewed_at`, `reviewed_by` and
      `review_note`.
  - **Same migration, policies dropped:** the loose write policies on
    `events` and its link tables, all keyed on `submitted_by`. They were
    an open insert and update with no window or field checks, plus the
    unused participant-link policies. Nothing wrote through them:
    production's 28 events have no `submitted_by`, and every app query on
    these tables is a read (checked 2026-10-28).
  - **Notifications for the new build:** `get_notifications_v2()` and
    `get_unread_notification_count_v2()` include the event types (see
    Fixed for why the old functions hide them).
  - **Proof:** on a local stack, all 100 migrations replayed from empty,
    and a 53-check scenario passes:
    - permissions: non-managers, revoked managers, members and anon are
      refused;
    - each form rule, including a timezone edge (Auckland's "today");
    - unknown times stay null;
    - "held at the venue" ignores the location the app sent;
    - resubmit, edit history and cancel;
    - admin approve and reject with their notifications, and both new
      queue kinds;
    - direct table writes are refused, even for an admin.

    Every new `SECURITY DEFINER` function is closed to anon and PUBLIC,
    checked with `has_function_privilege`. The internal helpers are
    closed to `authenticated` too. The old `get_notifications()` result
    type is identical to production's.
  - **`notify-venue-submission` understands `events`.** The submitter
    comes from `submitted_by`, and the host venue is looked up like any
    other submission. The email gives the name, type, date, location,
    ticket link and the description verbatim. It shows only the times the
    venue gave: "Sat, 14 Nov 2026 (no time given)", "from 19:30", or a
    range, plus the event's timezone. The calendar date is never shifted.
    A previously reviewed event is marked "Event resubmitted". 9 new
    tests; all 29 pass.
  - **Applied and deployed 2026-10-28**, from `feature/venue-events`:
    - **Checked first** (read-only): production still had the 58
      countries the migration covers, all 6 tag ids, and 28 events with
      none written from the app.
    - **Migrations:** plain `supabase db push --linked`, ledger 98 →
      100/100, local and remote in agreement.
    - **Verified on production** (read-only):
      - every country has its zones (44 with one);
      - still 6 tags and 28 published events, and no `event_edits`;
      - no write policy left on `events` or its link tables, and the
        four admin read policies are in place;
      - no new function is executable by anon or PUBLIC, and the
        internal helpers aren't executable by `authenticated`;
      - `get_notifications()`'s result type is unchanged.
    - **Compared with a fresh local replay:** 39 objects identical. That
      covers every new or changed function with its grants, the new
      table and columns, the countries' zones and the tags, the three
      constraints, and every policy on the events tables.
    - **Edge Function:** `notify-venue-submission` deployed (version 4 →
      5, `verify_jwt` still off). A missing or wrong secret gets 401, so
      the smoke test sent no email.
    - The phase 3 build is on the same branch and not yet released.
    - **Tried on the simulator** against production, signed in as the
      test manager `@test` (Flore):
      - the landing page shows "1 upcoming";
      - Events lists Flore's events, grouped as live and past;
      - "Create an event" loads the 6 tags and "Times are in
        Europe/Amsterdam.";
      - a date-only event, "TEST please ignore", was submitted at Flore.
        Production stored it as `submitted`, with `start_at`/`end_at`
        and `start_time` null, Flore's own address and coordinates, and
        a host link with `is_venue`. The admin email call returned 200;
      - the event showed under Awaiting review, and reopened in the
        form with nothing guessed;
      - cancelling it asked for confirmation first; it is now
        `cancelled` and no longer in the review queue.

      The test event stays in `events` as a cancelled row.
    - **Admin side, signed in as `@kylan`:**
      - a second test event, "TEST review please ignore", was submitted
        as `@test`;
      - Review showed it under EVENTS · 1;
      - the review screen showed its details;
      - "Preview the event page" opened the real event page of the
        unpublished event;
      - Reject with a note stored `rejected`, the note, `@kylan` as
        reviewer, and an `event_rejected` notification to `@test`.

      This found the two bugs under Fixed.
    - **Back as `@test`, with the fixes in:**
      - Explore doesn't show the rejected event;
      - the Notifications badge counted 1 (through `_v2`);
      - the list showed '"TEST review please ignore" at Flore was not
        approved.' with the note, alongside every older notification;
      - Flore's landing page read "1 upcoming · 1 not approved";
      - Events listed it under NOT APPROVED with the note;
      - the form opened with "Saving your changes sends it back for
        review." (closed without saving).

      Still not tried: approving, a live edit, and the map pin.

- 2026-10-28 — A landing page per managed venue, phase 2 of
  `docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md`. My Venues
  used to open one long screen with the about text and every photo
  control on it. Now:
  - **The landing page** (`VenueManagementScreen`) shows the venue's
    name with its card photo (card crop), then three rows, each with a
    one-line summary: **Profile** ("Published", "Awaiting review", "Not
    approved", "Nothing published yet"), **Photos** ("3 photos · 1
    awaiting review") and **Events** ("2 upcoming"). Preview my page and
    the contact line stay here. Coming back from any section reloads all
    three summaries. A failed lookup only blanks its own summary; the row
    still opens.
  - **Profile** (`VenueProfileScreen`) and **Photos**
    (`VenuePhotosScreen`) are the two halves of the old screen, moved
    unchanged. Nothing was removed.
  - **Events** (`VenueEventsScreen`) is new and read-only for now: the
    upcoming events the venue hosts, the same list its public page shows
    (`loadHostedEventsFor*`). Creating and editing events is phase 3, and
    deliberately has no placeholder button here.
  - Private chefs get the same page.
  - **App only:** no migration, nothing new read from the database.
  - **Tests:** the existing tests now run against the screen each one
    covers. New tests cover the landing page (summaries, card photo,
    failure isolation, navigation, reload on return, private chefs, no
    verified-data fields) and the Events screen.

- 2026-10-28 — In-app review for admins, phase 1 of
  `docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md`. Reviewing a
  venue claim, an about text or a photo meant finding the row in the
  Supabase dashboard and running SQL by hand, or `curl` with a secret for
  a photo, with no way to see what the submission would look like. Now:
  - **Profile → Review**, shown only to admins, with the number waiting.
    The queue groups everything by kind, oldest first. Each item opens
    with what's needed to decide:
    - **claim:** the claimant's details;
    - **about text:** the text, plus "Preview the venue page", which
      opens the real detail screen with it in place;
    - **photo:** the photo in its real header and card frames with its
      framing, plus the same page preview.
    Approve, or reject with a note the venue receives through the
    notifications that already existed.
  - **`20261017120000_add_in_app_review.sql`:**
    - `public.admins` (RLS on, no client policy and no grant — admins are
      added by hand in the dashboard) and `is_admin()`;
    - `get_review_queue()`;
    - admin-only wrappers that call the existing dashboard functions with
      `auth.uid()` as the reviewer — the originals keep their
      dashboard-only ACL as the fallback;
    - an admin read policy on the private `venue-photo-submissions`
      bucket, for the preview.
    Every new SECURITY DEFINER function carries its `revoke … from
    public, anon`.
  - **`publish-venue-photo`** also accepts an admin's own login. On that
    path the reviewer is always the caller (a `reviewed_by` in the body is
    ignored); the secret path is unchanged. 22 deno tests pass (5 new).
  - **Settled decision revised, on purpose.** CLAUDE.md said "There is no
    in-app admin identity and none is planned"; the product owner decided
    on 2026-10-28 to review in the app, and that an admin may approve
    their own submissions. The rule now names `is_admin()` as the single
    source of review permission. `VENUE_CLAIM_OPERATIONS.md` keeps its
    snippets, marked as the fallback, and says how to add an admin.
  - **Proven locally only.** On a replay of the 97 existing migrations
    with an admin, a manager and a member, then this one: `is_admin()` is
    true only for the admin; the queue showed a claim, an about text and a
    photo with venue, city and submitter, and refused the other two; every
    admin action refused a non-admin; approving the about text made it
    current, the claim approval granted the manager permission, the photo
    rejection stored its note, and each recorded the admin as reviewer;
    the venue got all four notifications; a second approval of the same
    item was refused; nobody could insert into `admins` from the app;
    anon and PUBLIC hold no EXECUTE on any new function. A fresh replay
    of all 98 files gave identical definitions. Analyzer clean; 2,476
    tests pass (9 new). Not yet seen on the simulator: it needs this
    applied, an admin row and the function deployed.
  - **Rollout order:** the migration, then the admin row, then deploy
    `publish-venue-photo`, then the build. Installed builds are
    unaffected — they don't call any of this.
  - **Applied 2026-10-28**, in that order:
    - **Migration:** plain `supabase db push --linked` (ledger 97 → 98/98).
      The 9 objects (7 functions, `admins`, the storage policy) are
      identical to the fresh replay's, and only `authenticated` holds
      EXECUTE on the new functions (not anon, not PUBLIC); the dashboard
      originals remain uncallable from the app.
    - **Admin row:** the product owner's account (`@kylan`) added by hand,
      the only admin.
    - **Edge Function:** `publish-venue-photo` deployed (version 4 → 5,
      `verify_jwt` still off). Smoke-tested without side effects: no
      login, and the anon key as a bearer, are both refused with 401.
    - **App:** on the simulator, signed in as the non-admin `@test`, the
      Review row correctly stays hidden. Signed in as `@kylan`, Review
      shows with a badge of 2; the queue loads production's pending Flore
      about text and photo, and the photo item shows the private
      submission (signed URL, so the admin storage policy works) in both
      the header and card frames. The product owner then approved both
      from the app (photo 15:59:28, about text 15:59:57 UTC), each
      recorded with `@kylan` as reviewer — the first production run of
      the admin wrappers and of the Edge Function's admin-JWT publish.
    - **Coordination:** a parallel session's branch
      (`feature/editorial-selection`) builds on this commit and carries
      `20261017130000`. It was confirmed unapplied before this push, so
      only this migration went out.

- Project documentation
- Database organisation
- Architecture documentation
- 2026-10-28 — Hotel phone numbers, from user feedback asking for a phone
  on every World's 50 Best venue. `20261016130000_add_hotel_phone.sql`
  adds `hotels.phone` and appends it to `hotels_full` (the follow-up
  `20260819120000_add_restaurant_phone.sql` named); `Hotel.phone`,
  `hotelFullColumns` and a Call action on `HotelDetailScreen`, wired exactly
  like the restaurant one (hidden when closed or no usable number).
  `20261016120000_add_worlds_50_best_countries_and_cities.sql` adds the
  countries/cities the missing World's 50 Best venues need. Same day:
  `20261016140000_add_nl_2026_star_cities.sql` adds the five NL cities the
  MICHELIN Gids Nederland 2026 update needs
  (`supabase/data/enrichment/michelin_nl_stars_2026/`). **Applied to
  production 2026-10-28**, all three with plain `supabase db push --linked`
  following `supabase/data/enrichment/APPLY_2026-10-28.md` (ledger 94 →
  97/97, no hang). Checked afterwards: 3 countries and 16 + 5 cities
  present, `hotels.phone` and `hotels_full.phone` present, `hotels_full`'s
  grants unchanged. The seven catalogue files from the same guide then ran
  in order, none aborting; their results, measured against production, are
  in the Michelin_Database CHANGELOG (World's 50 Best completion, NL 2026
  stars at 1/20/98, phones for 318 restaurants and 103 hotels, Place IDs,
  QA-209/216/218). `live_view_full_columns_test` now passes against
  production, so a build carrying the new `hotelFullColumns` can ship.
  Compiled and tested on the branch afterwards: analyzer clean, full suite
  passes (2,467). Not yet seen in the app: a hotel's and an Amsterdam
  restaurant's Call button, Azurite's page, De Librije's award history.
- 2026-10-02/03 — Admin email on every new content report, generic over
  `content_type`: `20261010120000_add_content_report_admin_email_
  notification.sql` (trigger `content_reports_notify_admin_on_insert` →
  pg_net → new `notify-content-report` Edge Function → Resend, its own
  `notify_content_report_webhook_secret`, warn-never-block like every
  other `notify_admin_of_pending_*`). `content_reports` had carried
  reports since September with no admin notification at all. A reported
  photo's venue is resolved by name in the email (`c0ae732`), since
  `content_id` alone doesn't say which of three photo tables it's in.
  Applied after the 1.1.0+12 build, so it sits here. Its commit
  (`9f81977`) says "not yet applied"; it was applied later, on a date
  nothing recorded — this entry was missing until 2026-10-27, when the
  state below was read back from production.
  **Verified 2026-10-27, read-only:** remote ledger holds the migration
  (88/88, no mismatch); trigger exists and is enabled; `anon` cannot
  execute `notify_admin_of_pending_content_report()`; function deployed
  (version 2, 2026-10-03 11:05, one minute after `c0ae732` — so very
  likely that version, inferred from timing, not from comparing
  source); `NOTIFY_CONTENT_REPORT_WEBHOOK_SECRET` and `RESEND_API_KEY`
  set as function secrets, and the vault entry's value matches the
  function secret (SHA-256 compared, no value read out); all 18 of the
  function's deno tests pass.
  **Not proven end to end.** Exactly one real report exists (a photo,
  2026-10-11 01:31 UTC). pg_net no longer retains its response, and the
  one response it does retain (200, 2026-10-13) can't be tied to it, so
  whether that email reached `claimedvenues@mantelier.app` is unknown —
  the inbox is the only remaining evidence.
- 2026-10-27 — `20260820125000_events_v2_timezone_backfill.sql`: writes
  the `events.timezone` backfill into migration history, so a
  from-scratch replay can get past `20260820130000`'s NOT NULL. The
  production backfill (4 events, Europe/Amsterdam) was a separately
  approved out-of-band UPDATE and never in history, so a fresh build's
  only migration-inserted event ('t Preuvenemint, NL) reached NOT NULL
  with timezone NULL and failed. Matches `timezone is null and
  country_code = 'NL'` only — no stable event code exists and name
  matching is forbidden; any other NULL still fails loudly. Timestamp
  deliberately sits between the two timezone migrations under
  CLAUDE.md's new in-between-backfill exception. **Applied to production
  2026-10-27** with `supabase db push --include-all`, after a dry run
  listed only this file. Beforehand, a read-only check found 0 of 28
  events it would match (`timezone` already NOT NULL, no NULLs) and
  only row-level triggers on `events`, so nothing could fire. Push
  returned normally. Afterwards, verified directly: ledger 89/89 with no
  mismatch, the version present, events unchanged (28, no NULL
  timezones).
- 2026-10-28 — Venue managers can frame their own photos and choose the
  cover. Until now every venue photo was a plain centred crop:
  `focus_x`/`focus_y` had existed on the published photo tables since
  20260828130000, but nothing wrote or read them, and there was no zoom.
  - **Framing.** A focus point plus a zoom factor (1–4) per photo, set in
    a drag/pinch editor that shows the real header frame with the card
    frame updating beneath it. At upload it replaces the old read-only
    `VenuePhotoFramePreview` (removed) and travels on the submission;
    on a published photo, My Venues' new "Adjust framing" saves it
    straight away through `set_venue_photo_framing`, with no re-review.
    Applied by one shared `FramedImage` in the detail heroes and every
    card (Explore, search, Passport, Wishlist, Rankings, Guides, private
    chefs), using news_articles' existing focus semantics (cover
    alignment, zoomed around the same point). Private chef photos nobody
    has framed keep exactly their old hero (−0.8) and card (−0.3)
    placements.
  - **Cover.** The first photo is labelled "Cover", with a line saying
    it's the one on cards in Explore, search and Passport; "Make cover"
    on any other photo moves it to the front through the existing
    `reorder_venue_photos`.
  - **`20261014120000_add_venue_photo_framing.sql`:**
    - adds `zoom` to the three photo tables and `focus_x`/`focus_y`/`zoom`
      to `venue_photo_submissions`; existing rows default to centred, 1x,
      so nothing that shows today changes;
    - adds `set_venue_photo_framing()` (SECURITY DEFINER,
      `is_active_venue_manager()` as the only permission source,
      `revoke … from public, anon`);
    - extends the column-lock trigger to `zoom`, so direct client writes
      to the image, alt text, focus or zoom are still refused;
    - makes `approve_venue_photo` carry the submission's framing across
      (same signature, so its dashboard-only ACL is kept);
    - adds `cover_focus_x`/`cover_focus_y`/`cover_zoom` to
      `restaurants_full`/`hotels_full` (derived from 20261006120000's
      definitions, new columns appended).
  - **Settled decision revised, on purpose.** CLAUDE.md said a manager
    may change only `display_order` on published photos; the product
    owner decided on 2026-10-28 that framing should be adjustable without
    review, since it presents the same verified photo rather than adding
    content. The rule now reads "order and framing, never the image or
    its alt text", both through their RPCs only; CLAUDE.md also records
    that the cover is simply the lowest-`display_order` photo.
  - **Proven locally only.** On a replay of the existing 92 migrations,
    with a manager, a restaurant and two published photos, then the
    migration applied: existing photos stayed 0.5/0.5/1; the manager's
    RPC call worked; another user, out-of-range values and direct UPDATEs
    were refused; reordering still worked and the view's cover columns
    followed the cover; a submission framed 0.7/0.25/2.5 published with
    exactly those values; anon and PUBLIC hold no EXECUTE on the new
    RPC. A fresh replay of all 93 files gave identical definitions for
    the functions, views, columns and checks (39 objects). Analyzer
    clean; 2,449 tests pass, including new ones for the model, the
    framed image, the editor's drag maths on a real image (and that the
    page scroll can't take a drag inside the frame), the Adjust screen,
    and Cover/Make cover. The 2 failing are `live_view_full_columns_test`
    against production, which lacks the new view columns until this is
    applied — exactly what that guard is for.
  - **Rollout order: migration first.** The new build selects the new
    columns by name, so against a database without them photos would
    fail to load; installed builds select their own lists and are
    unaffected.
  - **Applied to production 2026-10-28** with plain `supabase db push
    --linked` (ledger 93/93). A read-only snapshot before and after shows
    the photo tables, submissions and both full views unchanged (5
    restaurant, 0 hotel, 1 private chef photo, 6 submissions, 1,363
    restaurants, 775 hotels); every existing photo is at 0.5/0.5/1, the
    one cover is centred, and venues without a cover have null cover
    framing. All 39 definitions and their ACLs (functions, views,
    columns, checks) are identical to the fresh replay's;
    `set_venue_photo_framing` is SECURITY DEFINER and executable by
    `authenticated` only (not anon, not PUBLIC); `approve_venue_photo`
    stays dashboard-only. `live_view_full_columns_test` now passes
    against production, and the full suite is green (2,451). The app
    change ships with the next build.
  - **Not covered:** the feature hasn't been seen signed in on a device
    (the simulator build talks to production); friend tiles fed by the
    friend RPCs (visits, wishlist, profile overview) still show covers
    centred, since those RPCs don't return framing.
- 2026-10-28 — A venue's card photo: which of its approved photos shows
  on the small cards, with its own crop, separate from the cover that
  leads the detail page. Asked for by the product owner (a restaurant may
  want a different photo, or a different crop, for the small picture).
  - **My Venues.** A Card photo section sits between the photo list and
    "Awaiting or not approved": the card photo at card size with its card
    crop, "Same as your cover" or "Your chosen photo", and Change into a
    new CardPhotoScreen — pick from the approved photos (cover labelled),
    frame it in an editable 1:1 card (4:5 for private chefs) with
    Explore's 4:3 card previewed beneath, Save live with no review;
    "Follow my cover" clears the choice. "Make cover" is gone from the
    photo rows (the top photo says Cover; the arrows reorder), and the
    header editor (Adjust framing, upload) now shows only the header —
    its card preview had shown a crop the card no longer uses.
  - **Every card** (Explore, search, Passport, Wishlist, Rankings,
    Guides, the chef card, the friend tiles) now shows the card photo
    and card crop; only the detail hero uses the cover. With no choice,
    or against a server without the columns, the card is the cover.
  - **`20261015120000_add_venue_card_photo.sql`:**
    - adds `is_card` (at most one per venue, partial unique index) and
      `card_focus_x`/`card_focus_y`/`card_zoom` to the three photo
      tables — a card crop on every photo, so even the cover can be
      cropped differently for the card; defaults keep today's cards;
    - adds `set_venue_card_photo()` (SECURITY DEFINER,
      `is_active_venue_manager()`, `revoke … from public, anon`); a null
      photo means "follow the cover";
    - extends the column-lock trigger to the four new columns;
    - makes `approve_venue_photo` keep a replaced card photo the card
      photo (its crop reset for the new image);
    - adds `card_photo_url`/`card_focus_x`/`card_focus_y`/`card_zoom` to
      `restaurants_full`/`hotels_full` (flagged first, then lowest
      position), leaving `cover_photo_url` unchanged so installed builds
      keep showing the cover on cards until they update.
  - **CLAUDE.md:** the photo rule now reads "order, framing and which
    approved photo is the card photo, never the image or its alt text",
    with header and card crops, the three RPCs and both migrations named.
  - **Proven locally only.** On a replay of the 93 existing migrations
    with a manager, a restaurant and two published photos, then this
    one: no choice gives the cover; choosing another photo with a crop
    works; re-choosing keeps one flag; follow-the-cover clears it;
    another user, a foreign photo, out-of-range values and direct
    UPDATEs were refused; an approved replacement of the card photo kept
    the flag; anon and PUBLIC hold no EXECUTE. A fresh replay of all 94
    files gave identical definitions (74 objects). Analyzer clean; 2,465
    tests pass, including new ones for CardPhotoScreen, the card fields,
    the editor's header and card modes, and the section's place on My
    Venues. The 2 failing are `live_view_full_columns_test` against
    production, which lacks the new view columns until this is applied.
  - **Rollout order: migration first** — the new build selects the card
    columns by name.
  - **Applied to production 2026-10-28** with plain `supabase db push
    --linked` (ledger 94/94). A read-only snapshot before and after shows
    the photo tables, submissions and both full views unchanged; every
    photo is at the defaults (no card chosen, centred card crop) and
    every venue's card equals its cover. All 74 definitions and ACLs are
    identical to the fresh replay's; `set_venue_card_photo` is SECURITY
    DEFINER, executable by `authenticated` only (not anon, not PUBLIC);
    `approve_venue_photo` stays dashboard-only. `live_view_full_columns_
    test` passes against production and the full suite is green (2,467).
    Not yet seen on the simulator; the app change ships with the next
    build.

### Changed

- 2026-10-27 — Minimum iOS raised from 13.0 to 15.0
  (`IPHONEOS_DEPLOYMENT_TARGET`, all three Runner build configurations in
  `ios/Runner.xcodeproj/project.pbxproj`). Forced by the toolchain, not
  chosen: Xcode 27.1 on the new machine rejects anything below 15.0
  ("supported deployment target versions is 15.0 to 27.1.x"), so
  `flutter build ios --no-codesign --simulator` failed outright until it
  moved; the old machine's Xcode 26.6 still accepted 13.0, which is why
  1.1.0+12 shipped on it. Would recur on any machine with a newer Xcode.
  The next build drops iOS 13 and 14 devices; nothing in the repo
  recorded why 13.0 was originally chosen. Simulator build verified
  after the change; a signed device build and `flutter build ipa` have
  not been run yet.

### Fixed

- 2026-10-28 — Two bugs found trying the phase 3 review side on the
  simulator as the admin `@kylan`, both fixed on `feature/venue-events`:
  - **Unpublished events showed in an admin's discovery lists.** After
    `@kylan` rejected the test event "TEST review please ignore", it
    still appeared in Explore's What's On. Every events list query
    (Explore, What's On, a country's events, hosted events, wishlists,
    friends' and past attendance) relied on RLS alone. Since
    `20261018130000`, RLS also lets admins (`events_admin_read`) and an
    event's own submitter (`events_own_submission_read`) read submitted,
    rejected and archived rows. A submitter would have seen their own
    unapproved event in Explore the same way.
    - Every list now filters `moderation_status = 'published'` itself
      (`publishedEventsOnly`), so admins and submitters see exactly what
      everyone else sees. Regular users and anon were never affected.
    - Only `loadEventById` stays unfiltered, so the review preview can
      open an event before it's published.
    - **Production:** no change needed, because the policies are
      correct. The shipped build has the same unfiltered queries, but
      until today no unpublished event existed for anyone to see.
    - **Test:** `events_published_only_test.dart` records the real REST
      requests and checks each one.
    - **Would recur** whenever a new read policy widens access to
      events. Lists must say what they list rather than inherit RLS.
  - **The review queue never reloaded** after a decision or a pull to
    refresh, in debug builds. `setState(() => _future = next)` returns
    the Future, which Flutter rejects in debug mode, so the state never
    changed. The decision itself saved; only the list stayed stale.
    - Fixed there, in the Profile review badge (`_reviewCountFuture`),
      and in `EventsScreen._reload`, which had the same shape.
    - Release builds skip that check, so shipped builds were unaffected.
      It is the same mistake that broke `VenueEventsScreen` during phase
      3 and was caught by its tests.

- 2026-10-28 — Two gaps found while drafting phase 3, both closed in
  `20261018130000`:
  - **The six event tags existed only in production.** They were
    inserted 2026-08-22 outside any migration, so a fresh replay had none
    and tags could never be assigned there. The migration seeds
    production's exact rows, ids included, with `on conflict do nothing`;
    on production that is a no-op, since all six ids are present
    (checked). Tag validation reads `event_tags` instead of a hardcoded
    list, so a missing tag is an error rather than being silently
    dropped. Would recur whenever reference data is entered by hand in
    the dashboard.
  - **Installed builds throw on a notification type they don't know**
    (`AppNotificationType.fromWire`). One `event_approved` row would have
    made the whole Notifications screen fail to load on every current
    build. `get_notifications()` and `get_unread_notification_count()`
    now return only the types those builds know, and the phase 3 build
    reads the `_v2` functions. `_v2` was built from production's live
    definition, which has one more column (`friendship_status`) than the
    migration first read for it. The phase 3 build should also make the
    parser skip unknown types, so the next new type can't cause this
    again.

- 2026-10-02 — `claims_*.review_note` was written by `reject_venue_claim`
  but `get_notifications()` never surfaced it: a claimant whose venue
  claim was rejected saw "not approved" with no reason anywhere in the
  app. Carried through the same way `venue_about_submissions`/
  `venue_photo_submissions`' own rejection notes already were. Applied
  after the 1.1.0+12 build, so it sits here rather than in that
  release's own section, per CLAUDE.md's migration-naming/changelog rule.
- 2026-10-27 — `20260925120000_add_profiles_member_number.sql`'s
  `setval(seq, coalesce(max(member_number), 0))` raised "value 0 is out
  of bounds" on an empty `profiles` table, since the sequence's minimum
  is 1. Production had profiles when it ran, so only a fresh build hit
  it, and every from-scratch replay died there. Edited in place to the
  three-argument `setval(seq, coalesce(max, 1), max is not null)`, with
  the original statement quoted in the file — the first use of
  CLAUDE.md's new correct-an-applied-migration exception. Proven by
  running both forms side by side in a throwaway Postgres 17: empty
  table, the original errors and the new form gives 1; non-empty (max
  7), identical sequence state (`last_value=7, is_called=true`) and the
  same next value, 8. So no member number, and nothing printed on a
  passport, changed. Nothing to apply: production never re-runs it.
  Would recur in any migration that seeds a sequence from `max()` of a
  table that can be empty.
- 2026-10-27 — Fresh replay proof, the one `NEW_MACHINE_SETUP.md` §4
  had owed since 2026-10-02, run locally via `supabase start` (full
  stack). A bare `supabase/postgres` container can't do it: it has no
  `storage.*` tables (the storage service creates them) and no pg_net,
  so it fails at migration 4. The full stack found the two gaps above,
  one after the other, beyond the known countries one. With both fixes,
  all 89 files apply cleanly (55 countries, the one event on
  Europe/Amsterdam, member sequence at 1 unused, 5 buckets). Without the
  countries seed, replay fails exactly where §4 predicted. Nothing
  touched production.
- 2026-10-28 — `visit-photos` behaved differently in production from a
  database rebuilt from migration history. The bucket was first made by
  hand in the dashboard on 2026-07-27 (15 MiB, jpeg/png/webp/heic plus
  `image/heif`) along with four owner-only "Users can … own stored visit
  photos" policies on `storage.objects`, one of them UPDATE.
  `20260807120000` then inserted the bucket with `on conflict do
  nothing`, so production kept the dashboard settings and the migration's
  own (10 MiB, no heif, no update policy) never took effect there. Found
  by the 2026-10-28 schema diff, which matched everything else migrations
  create. `20261011120000_converge_visit_photos_storage_to_migrations.sql`
  moves production toward history rather than the reverse: no update
  policy is the documented design (`20260825170000`'s header), the other
  three policies duplicate `visit_photos_read`/`_insert`/`_delete`, the
  app never sends heif, never upserts or moves an object (none of it in
  git history either), and compresses every pick well under 10 MiB.
  It drops the four policies (`if exists`) and resets the bucket limits.
  Proven locally only: with production's state recreated (hashes of all
  17 `storage.objects` policies and the bucket matched production's), it
  converges exactly to a fresh replay's state; re-running it changes
  nothing; a fresh replay of all 90 files applies cleanly and is
  identical. Through the storage API afterwards, overwrite, `image/heif`
  and an 11 MiB upload are refused, normal uploads, reads and deletes
  work, and an 11 MiB object stored beforehand stays readable. **Applied
  to production 2026-10-28** with plain `supabase db push --linked`
  (ledger 90/90). Afterwards production's `visit-photos` bucket and all
  12 `storage.objects` policies hash-identical to a fresh replay's, and
  all 11 existing objects are still there. Beforehand, a read-only check of production's 11 existing
  `visit-photos` objects (2026-10-28) found none over 10 MiB and none of
  type heif — largest 912,712 bytes, only `image/jpeg` recorded — so the
  looser dashboard limits were never actually used. Two of the 11 carry
  no metadata at all (no size, no mimetype, no version, no `photos` row,
  both created at the identical instant 2026-08-13 06:39:01 UTC, two path
  segments deep rather than the app's three); where they came from is
  unknown, nothing in the repo inserts into `storage.objects`, and the
  bucket limits can't affect them either way. Would recur with any
  bucket or policy created in the dashboard rather than in a migration.
- 2026-10-28 — An incoming friend request could be impossible to find.
  Profile's Friends row counts `get_incoming_friend_requests` ("1
  request") and opened the Friends screen, but Notifications V1 had
  moved incoming requests off that screen entirely — its tabs were
  Friends and Sent, and Sent lists only requests you sent. The request
  lived only in Notifications, which marks everything read on open, so
  after one look nothing pointed to it any more. Reported by the
  developer's own account (request of 2026-10-08, its notification
  present and already read). Incoming requests are back on Friends as a
  Requests tab between Friends and Sent, with the same Accept/Decline
  RPCs as Notifications (which keeps its own row), reading the same RPC
  as Profile's count so the two can't disagree; Profile's row opens
  straight onto Requests when it shows a count. Analyzer clean, full
  suite passes (2,420), simulator build launches; not exercised signed
  in, since the simulator build talks to production. Found alongside,
  not fixed: 4 pending requests from 2026-09-23 have no notification at
  all (the trigger arrived 2026-09-24 with no backfill) — the new tab
  shows them, Notifications never will; an answered request's
  notification keeps its Accept/Decline, and tapping it then fails, now
  more reachable with two places to answer; and the Accept/Decline pair
  overflows at 320px width combined with 1.6x text, on both screens.
  Would recur whenever an action moves between screens while a count
  elsewhere still points at the old one.
- 2026-10-28 — Two of the gaps found alongside the entry above. **(1)** A
  friend request's notification kept Accept/Decline after the request was
  accepted, declined, cancelled or removed; tapping either made the RPC
  raise "no longer available", which NotificationsScreen never caught, so
  nothing visible happened. `20261012120000_add_friendship_status_to_
  notifications.sql` recreates `get_notifications()` with one more
  column, `friendship_status` (from the `friendships` join it already
  had; NULL once the row is gone), the same pattern as `invite_status`.
  The row now offers Accept/Decline only while pending, then "You
  accepted"/"You declined", nothing for blocked or gone; `_accept`/
  `_decline` catch the error, say so and reload (invites too).
  `AppNotification` tells a missing column from a NULL value, so a server
  without the column keeps the old always-offer behaviour and build and
  migration can ship in either order; builds already out ignore the extra
  column. **(2)** The 4 pending requests from 2026-09-23, sent before the
  notification trigger existed, had no notification at all.
  `20261013120000_backfill_pre_trigger_friend_request_notifications.sql`
  inserts one for every pending friendship without one, dated with the
  friendship's own `created_at` and unread; it matches 0 rows on a fresh
  replay. Proven locally only: with production's situation recreated
  (pending, accepted, declined, sender-cancelled, and two pre-trigger
  requests in both directions), the backfill inserted exactly the two
  missing notifications to the right recipients at their original dates,
  re-running either migration changed nothing, `get_notifications()`
  returned the right status per row as each user, only `authenticated`/
  `service_role` hold EXECUTE (not anon or PUBLIC), and a fresh replay of
  all 92 files gives an identical function definition and ACL. Analyzer
  clean, full suite passes (2,424). Not exercised: the app against the
  new function end to end, and the row's three states in the simulator.
  **Applied to production 2026-10-28** with plain `supabase db push
  --linked` (ledger 92/92). A read-only count just before still found
  exactly 4 pending requests without a notification, all 2026-09-23.
  Afterwards: 0 left; notifications went from 8 to 12, the 4 new ones
  each dated with its friendship's own `created_at`, unread, addressed to
  the request's recipient (3 distinct people); `get_notifications()`'s
  definition hash and ACL identical to the fresh replay's, with no
  EXECUTE for anon or PUBLIC. The app change ships with the next build;
  until then, installed builds ignore the new column. The
  320px-plus-1.6x overflow stays open. Would recur with
  any trigger added to a table that already has rows it should have
  fired for.
- 2026-10-28 — The incoming friend request's Decline/Accept pair
  overflowed by 75px at 320px width with 1.6x text, on both FriendsScreen
  and NotificationsScreen. IdentityRow gives its trailing widget
  unbounded width, so nothing ever made the pair give way. Both rows now
  use one shared `FriendRequestRow`
  (`lib/features/friends/widgets/friend_request_row.dart`): it measures
  its own width, caps the actions at what's left after the avatar, gaps
  and a 56px minimum for the name, and lets a `Wrap` stack Decline above
  Accept, right-aligned, only when they don't fit (the `Wrap` then shrinks
  to the wider button, so the name gets the space back). Thresholds
  measured with the real Inter files google_fonts had cached in the
  simulator, since tests render in a square-glyph font that makes
  "Decline" 122px against 74px: no overflow at 320/375/390/402px across
  1.0/1.3/1.6/2.0x; inline at 1.0x on every width (320px included, as
  before), at 1.3–1.6x from 375px up, stacked otherwise. Tests now pump
  the real row on both screens' suites, plus its own (stacking, 2.0x with
  a long name, the name's minimum); full suite passes (2,431), analyzer
  clean, simulator build installs. Not looked at signed in on a device.
  Would recur with any IdentityRow trailing wider than one short label.
- 2026-10-28 — Three problems found trying photo framing on the simulator
  with the developer's test venue, each fixed:
  - **Every venue photo list was sorted backwards.** postgrest-dart's
    `order()` defaults to `ascending: false`, so the five
    `.order('display_order')` photo queries (`RestaurantRepository`/
    `HotelRepository.getPhotos`, `PrivateChefRepository.getChefPhotos`/
    `getCoverPhotos`, `VenuePhotoSubmissionRepository.loadPublishedPhotos`)
    returned the highest position first, while the cards'
    `restaurants_full`/`hotels_full` cover takes the lowest. My Venues'
    "first photo" (now "Cover") was therefore never the photo on the
    cards, the detail gallery opened on the last photo, and each reorder
    from My Venues wrote the reverse of what the screen showed. Now
    `ascending: true` on all five. Not fixed, same class: every other
    unqualified `.order('name')` and the chef history/education
    `display_order` lists also sort descending. Would recur with any new
    `order()` call that leaves `ascending` out.
  - **The framing editor's header frame didn't match the real hero.**
    VenueDetailHero/PrivateChefHero are SliverAppBars, so on a device the
    header is the full screen width by expandedHeight (300/320) plus the
    status bar, with the status bar and toolbar drawn over its top. The
    editor showed a fixed 300px frame at page width — a different shape —
    so a face framed there landed higher, half under the status bar, on
    the detail page. The frame now has the hero's exact proportions,
    scaled to the page, with that covered strip shaded. The status bar
    comes from `View.of(context).padding`, not MediaQuery: the editor sits
    under an AppBar, which zeroes MediaQuery's top padding (the first
    attempt read 0 there — caught on the simulator, now covered by a
    test that runs it under an AppBar).
  - **My Venues jumped to the top after every reorder.** Each reload
    swapped the photo list for a spinner, collapsing the page; the
    spinner now shows only on the first load, and a reload keeps the
    previous list on screen. This is how two of the test taps landed on
    the wrong row and briefly reordered the test venue's photos; the
    original order and framing were restored through the app and
    verified against production.
  Analyzer clean, full suite passes (2,453), including a test that fails
  without the reload fix (checked by reverting it). Seen on the
  simulator: My Venues, the gallery and the search card now agree on the
  cover; the editor frame measures 326pt on a 402pt phone, (300 + 62) ×
  0.9, with a 106pt strip.

---

## v1.1.0 — 2026-10-02

### Added

- Venue claim request flow: a manager/owner/chef picks their venue,
  submits role/business email/phone, with duplicate-claim protection and
  a domain-mismatch flag surfaced on the admin notification
- Venue manager permission model (`venue_managers_restaurants`/`_hotels`/
  `_private_chefs`), replacing the claim-based `has_approved_venue_claim()`
  check across every policy that gated on it
- My venues screen, where a manager finds and opens what they manage
- Six venue approval RPCs — approve/reject for both about-text and photo
  submissions
- `publish-venue-photo` Edge Function, the documented normal path for
  photo approval
- Photo publishing end to end: a manager's submitted photo moves through
  review to the live catalogue without a manual storage copy
- Swipeable photo galleries on the Restaurant/Hotel and Private Chef
  Detail hero screens
- Owner preview: a venue manager can see their page rendered with their
  own pending text and photos, in the same screen a visitor sees, before
  submitting
- Review notifications: a manager is notified in-app when an about-text
  or photo submission is approved or rejected, with the reviewer's own
  note carried on a rejection
- A contact line on the venue management screen
- Passport stamp designs rebuilt with larger, size-aware footprints
- Database foundation for venues and organisers eventually hosting their
  own events: `cancelled_at` as the maintained cancellation signal (with
  a compatibility shim keeping the old `status` column in sync for any
  app build still reading it), an owner `UPDATE` policy plus a
  column-restriction trigger so a host can edit everything about their
  own event except the moderation machinery, and a per-link approval
  marker on the three participant join tables so crediting a
  co-participant doesn't require republishing the whole event. Backend
  only — no new screen yet; the one user-visible effect this build ships
  is the Fixed item below.

### Fixed

- A hero's photo gallery swipe was silently swallowed on three separate
  hero widgets (Restaurant/Hotel, Private Chef, Event Detail): each
  stretched its bottom text overlay full-size via `StackFit.expand`, and
  `Scrollable` defaults to an opaque hit test regardless of
  `NeverScrollableScrollPhysics` — combined with `Stack` stopping at the
  first hit (topmost first), the overlay absorbed every pointer-down over
  the photo before the gallery underneath ever saw it. One of the three
  had previously been "fixed" by reordering z-order instead, which
  masked the symptom without touching the actual hit-test behaviour. All
  three now set `hitTestBehavior: HitTestBehavior.translucent` on the
  overlay instead.
- Restaurant and Hotel Detail never fetched a venue's full photo set at
  all — only ever a single cover image — invisible as a gap until the
  first venue with more than one photo actually existed to expose it.
- Two pre-existing bugs in `PrivateChefDetailScreen._load()`, both
  surfaced only once the owner-preview refactor made the screen directly
  testable: a secondary fetch left unawaited after an earlier one failed
  (an unhandled-rejection risk), and any one secondary fetch failing
  could flip the whole screen into its generic error state even though
  the chef's own data had already resolved successfully.
- The owner-preview "PREVIEW" marker inherited `MaterialApp`'s own
  placeholder error text style (a double yellow underline) because its
  text sat outside any `Material` ancestor in the widget tree.
- A Private Chef's page could show two "about" sections — the chef's own
  catalogue biography and a separately-submitted "from the team" text —
  at once. The venue's own submitted text now always takes precedence;
  the biography shows only as a fallback until one exists.
- A manager replacing a photo already occupying the same display slot
  could lose track of which photo was which; replacement is now indexed
  explicitly, with a message when this happens.
- Owner preview re-fetches the venue fresh rather than reusing a stale
  copy, and discloses to the manager when that refetch itself fails.
- No migration ever seeded `public.countries`, so a database built from
  the migration set alone (a disaster-recovery replay, a fresh preview
  branch) failed at the first insert carrying a real `country_code` —
  invisible until something actually needed to rebuild from scratch.
  Seeded now from the live table, in migration history, so the gap
  doesn't resurface on the next rebuild.
- A hotel or private chef claim generated no admin email at all — only
  `claims_restaurants` was ever wired to send one. Generalised into one
  function across all three claim types rather than duplicated, and the
  matching one-pending-claim-per-venue protection `claims_restaurants`
  already had is now on `claims_hotels`/`claims_private_chefs` too, so a
  second person can no longer hold a simultaneous pending claim on a
  venue someone else already claimed.
- Event cancellation now reads a real, maintained `cancelled_at` column
  instead of a `status` value nothing was keeping correct — the database
  already stored it and a trigger kept it in sync, but the app never read
  it, which is what made the drift invisible. `EventStatus` is removed
  from the Dart model entirely: `upcoming`/`completed` were never read
  anywhere beyond making this one field possible (confirmed by direct
  search before removing it). `status` itself stays in the database,
  kept correct by the same trigger, for any app build still reading it.

---

## v0.1.0

### Added

- Flutter project
- Supabase integration
- Restaurant database
- Authentication
- Restaurant overview
- My Stamps

### Improved

- Project structure
