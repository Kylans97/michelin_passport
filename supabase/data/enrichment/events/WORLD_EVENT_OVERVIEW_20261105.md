# Wereldwijd overzicht van komende gastronomische events

**Status: onderzoek, niets toegepast.** Er is niets naar Supabase geschreven. Bestanden:

- `world_event_overview_20261105.csv`: alle 187 kandidaten, gesorteerd.
- `_source/world_20261105/`: de ruwe onderzoeksregels per regio en de onderzoeksopdracht.

Periode: 3 november 2026 tot en met 31 december 2027, met de nadruk op de komende zes maanden. Opgesteld op 3–5 november 2026, op branch `claude/overnight-world-events`.

## Hoe gelezen

- **Bronniveau (`source_confidence`):**
  - **A** = de datum staat op de eigen pagina van de venue of organisator, en die pagina is bij dit onderzoek geopend.
  - **B** = eigen kanaal, maar deels; bijvoorbeeld de eigen tekst van de organisator op een nieuwsdienst, of een pagina die niet laadde terwijl het zoekfragment de datum toonde.
  - **C** = alleen een secundaire bron (pers, toerisme, aggregator).
- **`certainty`:** `confirmed` of `unclear`. Unclear betekent een datum zonder dag, een aflevering van een terugkerende reeks, of tegenstrijdige bronnen.
- **Sortering:**
  1. Hoe snel het event is: binnen 60 dagen, binnen 6 maanden, later, of zonder datum.
  2. Hoe goed het past (`fit`).
  3. Het bronniveau.
  4. De datum.
- **Prioriteit:**
  - **P0** = binnen 6 maanden, fit high en bron A of B.
  - **P1** = binnen 6 maanden, of fit high met bron A.
  - **P2** = de rest.
- **Tijden** staan er alleen als de bron ze noemt. Een leeg tijdveld is dus correct en geen gat. Tijdzone = de IANA-zone van de venue.
- **Catalogus (`catalog_match`), per betrokken venue met rol host, venue of participant:**
  - `code+country verified`: de code bestaat, het land klopt, en naam en plaats stemmen overeen met de catalogus.
  - `PROPOSED`: gevonden via naam, plaats en land; nog bevestigen.
  - `AMBIGUOUS`: meerdere codes mogelijk; niets besloten.
  - `not in catalogue`.

  De catalogus is gelezen uit de productie-export van 2 november 2026 (`restaurants_LIVE_20261102.csv`, 3.555 restaurants) plus de hotelcodes uit de exports en voorbereide bestanden in de repo. Er was geen directe toegang tot productie: geen anon key in deze omgeving.
- **`already_in_production`:** vergeleken met de events die volgens `docs/Architecture/Events/*PRODUCTION_APPLY.md` in productie staan. Komend zijn dat er drie: Flore × Sebastian Frank op 9 november, Merlet × Joann op 22 november en Dîner Dansant op 24 december. Events die via de app zijn ingediend, zijn **niet** gecontroleerd. Dat moet bij het toevoegen nog een keer, in productie zelf.

## Top 20 om eerst toe te voegen

De beste kandidaten volgens de sortering: met een datum, `confirmed`, bron A of B, en nog niet in productie. Per organisator-pagina staan er maximaal 2, zodat één festival de lijst niet vult.

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-001 | 2026-11-05 t/m 2026-11-07 | Big Sur Food & Wine Festival 2026 | Big Sur, US | Festival | Wine, Charity | A | high | geen catalogusmatch |
| wev-002 | 2026-11-05 | Signature Sessions: Sapiens X Kol | Lima, PE | Dinner | Guest Chef, Four Hands | A | high | geen catalogusmatch; voorgesteld: rest_0329 |
| wev-003 | 2026-11-06 t/m 2026-11-10 | Merano WineFestival 2026 (35th edition) | Merano, IT | Festival | Wine | A | high | geen catalogusmatch |
| wev-004 | 2026-11-06 | 2026 JBF Gala for Good™ | New York, US | Gala | Charity, Guest Chef | A | high | rest_0746, rest_3043 |
| wev-005 | 2026-11-07 | Four-Hands Dinner | Six courses - two culinary signatures | Cologne, DE | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_162, rest_1936, rest_2084 |
| wev-006 | 2026-11-07 | Autumn in Vermont White Truffle Dinner Weekend (Twin Farms) | Barnard, US | Dinner | – | A | high | geen catalogusmatch |
| wev-007 | 2026-11-09 t/m 2026-11-15 | Saint Barth Gourmet Festival 2026 (13e édition) | Gustavia / Saint-Barthélemy, BL | Festival | Guest Chef | A | high | geen catalogusmatch |
| wev-008 | 2026-11-10 | KRUG 4-Hands-Dinner | Zurich, CH | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_2502, rest_0263, rest_0282 |
| wev-009 | 2026-11-13 | Winzer Dinner mit Weingut Lackner Tinnacher | Cologne, DE | Dinner | Wine, Winemaker | A | high | rest_2084 |
| wev-010 | 2026-11-13 | Jantar Magno Mesa SP 2026 – Grand Hyatt São Paulo | São Paulo, BR | Dinner | Guest Chef | A | high | geen catalogusmatch; voorgesteld: rest_0134, rest_1393 |
| wev-011 | 2026-11-14 | Gala de clôture du Festival des Étoilés Monte-Carlo 2026 | Monte Carlo, MC | Gala | Guest Chef | A | high | rest_1579, rest_1582, rest_1585 |
| wev-012 | 2026-11-16 | Dîner de Gala de Charité 2026 au profit de la Banque Alimentaire Luxembourg | Luxembourg City, LU | Gala | Charity, Guest Chef | A | high | geen catalogusmatch |
| wev-013 | 2026-11-18 | 18. November: Gravner x Hiša Franko | Kobarid, SI | Dinner | Wine, Winemaker | A | high | rest_0424 |
| wev-014 | 2026-11-18 | Château d'Yquem Wine Dinner with Chef Anne-Sophie Pic | Bangkok, TH | Dinner | Wine, Winemaker, Guest Chef | A | high | geen catalogusmatch |
| wev-016 | 2026-11-19 t/m 2026-11-22 | Pair'd Margaret River Region 2026 | Margaret River, AU | Festival | Wine, Guest Chef | A | high | geen catalogusmatch |
| wev-017 | 2026-11-20 | An extraordinary evening with Domaine Kuheiji (Kuheiji Dinner) | Amsterdam, NL | Dinner | Wine, Winemaker | A | high | rest_0119 |
| wev-018 | 2026-11-20 | Wayfinder x St JOHN, presented by Lexus | Margaret River, AU | Dinner | Wine, Winemaker, Guest Chef | A | high | geen catalogusmatch; voorgesteld: rest_2590 |
| wev-019 | 2026-11-21 | An extraordinary evening with Domaine Kuheiji (Kuheiji Dinner) | Amsterdam, NL | Dinner | Wine, Winemaker | A | high | rest_0119 |
| wev-020 | 2026-11-21 | Falstaff Wine Trophy | Bergisch Gladbach, DE | Gala | Wine, Winemaker, Guest Chef | A | high | hotel_175, rest_0189, rest_2044, rest_2089, rest_2114, rest_2117 |
| wev-021 | 2026-11-21 | Ronny Siewert & Friends - Küchenparty an der Ostsee | Bad Doberan, DE | Party | Guest Chef, Wine | A | high | hotel_176, rest_1916, rest_2090 |

## Top 5 per regio

### Benelux (17 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-012 | 2026-11-16 | Dîner de Gala de Charité 2026 au profit de la Banque Alimentaire Luxembourg | Luxembourg City, LU | Gala | Charity, Guest Chef | A | high | geen catalogusmatch |
| wev-017 | 2026-11-20 | An extraordinary evening with Domaine Kuheiji (Kuheiji Dinner) | Amsterdam, NL | Dinner | Wine, Winemaker | A | high | rest_0119 |
| wev-024 | 2026-11-25 | Truffelavond met Licata | Francorchamps, BE | Dinner | Wine, Winemaker | A | high | rest_0872 |
| wev-036 | 2026-12-12 | YVESKE'S Kitchen at MASTERS EXPO - Dinner 12 Dec | Amsterdam, NL | Dinner | Guest Chef | A | high | rest_0016, rest_0025, rest_0030, rest_0069 |
| wev-160 | 2027-01-10 | Wildmiddag (5-gangen wildmenu) | Aalten, NL | Lunch | Wild/Game | A | low | rest_0150 |

### Zuid-Europa (20 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-003 | 2026-11-06 t/m 2026-11-10 | Merano WineFestival 2026 (35th edition) | Merano, IT | Festival | Wine | A | high | geen catalogusmatch |
| wev-011 | 2026-11-14 | Gala de clôture du Festival des Étoilés Monte-Carlo 2026 | Monte Carlo, MC | Gala | Guest Chef | A | high | rest_1579, rest_1582, rest_1585 |
| wev-013 | 2026-11-18 | 18. November: Gravner x Hiša Franko | Kobarid, SI | Dinner | Wine, Winemaker | A | high | rest_0424 |
| wev-025 | 2026-11-26 t/m 2026-11-27 | XI. Gastromasa İstanbul International Gastronomy Conference & Exhibition | Istanbul, TR | Festival | Guest Chef | A | high | rest_0325, rest_0331, rest_0362, rest_1003 |
| wev-038 | 2026-12-13 | Gourmet Skisafari Alta Badia | Alta Badia, IT | Tasting | Guest Chef | A | high | rest_0315, rest_2202, rest_2296 |

### Noord-/Centraal-Europa (68 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-005 | 2026-11-07 | Four-Hands Dinner | Six courses - two culinary signatures | Cologne, DE | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_162, rest_1936, rest_2084 |
| wev-008 | 2026-11-10 | KRUG 4-Hands-Dinner | Zurich, CH | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_2502, rest_0263, rest_0282 |
| wev-009 | 2026-11-13 | Winzer Dinner mit Weingut Lackner Tinnacher | Cologne, DE | Dinner | Wine, Winemaker | A | high | rest_2084 |
| wev-020 | 2026-11-21 | Falstaff Wine Trophy | Bergisch Gladbach, DE | Gala | Wine, Winemaker, Guest Chef | A | high | hotel_175, rest_0189, rest_2044, rest_2089, rest_2114, rest_2117 |
| wev-021 | 2026-11-21 | Ronny Siewert & Friends - Küchenparty an der Ostsee | Bad Doberan, DE | Party | Guest Chef, Wine | A | high | hotel_176, rest_1916, rest_2090 |

### Noord-Amerika (39 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-001 | 2026-11-05 t/m 2026-11-07 | Big Sur Food & Wine Festival 2026 | Big Sur, US | Festival | Wine, Charity | A | high | geen catalogusmatch |
| wev-004 | 2026-11-06 | 2026 JBF Gala for Good™ | New York, US | Gala | Charity, Guest Chef | A | high | rest_0746, rest_3043 |
| wev-006 | 2026-11-07 | Autumn in Vermont White Truffle Dinner Weekend (Twin Farms) | Barnard, US | Dinner | – | A | high | geen catalogusmatch |
| wev-007 | 2026-11-09 t/m 2026-11-15 | Saint Barth Gourmet Festival 2026 (13e édition) | Gustavia / Saint-Barthélemy, BL | Festival | Guest Chef | A | high | geen catalogusmatch |
| wev-029 | 2026-12-06 t/m 2026-12-09 | By Land and Sea (Blackberry Farm) | Walland, US | Dinner | Guest Chef, Winemaker, Wine | A | high | rest_0755 |

### Azië & Midden-Oosten (24 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-014 | 2026-11-18 | Château d'Yquem Wine Dinner with Chef Anne-Sophie Pic | Bangkok, TH | Dinner | Wine, Winemaker, Guest Chef | A | high | geen catalogusmatch |
| wev-039 | 2026-12-26 t/m 2026-12-29 | An Exclusive Culinary Experience with Two-Star Michelin Chef Benjamin Peifer | Kandolhu Island (North Ari Atoll), MV | Dinner | Guest Chef | A | high | geen catalogusmatch |
| wev-040 | 2026-11-13 t/m 2026-11-14 | Mezzaluna at lebua (Two Michelin Stars) featuring L'Osier Tokyo (Three Michelin Stars) – Collaboration Dinner 2026 | Bangkok, TH | Dinner | Four Hands, Guest Chef | B | high | rest_0505 |
| wev-041 | 2026-11-20 t/m 2026-11-21 | Galaxy Stars of Gastronomy 2026 | Macau, MO | Festival | Guest Chef | B | high | rest_0125, rest_0319, rest_0439, rest_0441, rest_0463, rest_2862 |
| wev-053 | 2026-11-05 | Wolfgang Puck Generational Tasting Tour - Bahrain | Manama, BH ⚠ land niet in countries | Dinner | Guest Chef | A | medium | geen catalogusmatch |

### Zuid-Amerika, Afrika & Oceanië (19 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-002 | 2026-11-05 | Signature Sessions: Sapiens X Kol | Lima, PE | Dinner | Guest Chef, Four Hands | A | high | geen catalogusmatch; voorgesteld: rest_0329 |
| wev-010 | 2026-11-13 | Jantar Magno Mesa SP 2026 – Grand Hyatt São Paulo | São Paulo, BR | Dinner | Guest Chef | A | high | geen catalogusmatch; voorgesteld: rest_0134, rest_1393 |
| wev-016 | 2026-11-19 t/m 2026-11-22 | Pair'd Margaret River Region 2026 | Margaret River, AU | Festival | Wine, Guest Chef | A | high | geen catalogusmatch |
| wev-018 | 2026-11-20 | Wayfinder x St JOHN, presented by Lexus | Margaret River, AU | Dinner | Wine, Winemaker, Guest Chef | A | high | geen catalogusmatch; voorgesteld: rest_2590 |
| wev-046 | 2026-11-04 | The 50 Best Restaurants 2026 awards ceremony | Lima, PE | Gala | – | A | medium | geen catalogusmatch |

## Aantallen

**Per land:** DE 46, US 28, AT 16, NL 14, SG 11, IT 7, BR 5, TH 5, AU 5, MU 5, PT 5, MV 4, CA 4, FR 4, PE 3, (geen) 3, CH 2, LU 2, MX 2, BL 1, MC 1, SI 1, BE 1, TR 1, MO 1, HK 1, BH 1, JP 1, GB 1, ZA 1, KY 1, ES 1, IS 1, DK 1, HU 1

**Per maand (startdatum):**

| maand | aantal |
|---|---|
| 2026-11 | 70 |
| 2026-12 | 33 |
| 2027-01 | 18 |
| 2027-02 | 24 |
| 2027-03 | 17 |
| 2027-04 | 6 |
| 2027-05 | 2 |
| 2027-06 | 2 |
| 2027-07 | 2 |
| 2027-08 | 3 |
| 2027-11 | 1 |
| 2027-12 | 1 |
| zonder  | 8 |

**Per prioriteit:** P0 69, P1 103, P2 15  
**Per bronniveau:** A 162, B 13, C 12  
**Per zekerheid:** confirmed 168, unclear 19

**Landen die niet in `countries` staan** (die moeten eerst worden toegevoegd): (geen), BH, KY, MU.

## Wat is afgevallen en waarom

**voorbij / vorige editie (52)**

- Parkheuvel Wijnmakersdiner Perrier-Jouët / Club Leroy (Benelux): past (1 Oct 2026, 20 Sep 2026); no new dated events on site
- Restaurant Flore 4 Hands Dinner Series (22 Jun, 17 Aug, 19 Oct 2026) (Benelux): past; 9 Nov 2026 Sebastian Frank already in production; no new dates published
- Inter Scaldes events (Two Chefs One Night w/ Andrea Aprea 13 Apr 2026 etc.) (Benelux): past; 'Aankomende events' empty
- VanOost Christmas / New Year's Eve 2026 (Benelux): standard Christmas/NYE menus; all guest-chef editions on page are past
- Zilte Exquis x Dominique Crenn (Dec 4/5) (Benelux): past edition (2024), secondary blog
- Zilte Exquis: Viki Geunes x Marco Müller ('Zondag, 9 november') (Benelux): no year; 9 Nov is a Sunday in 2025, not 2026 -> past edition; the 7 Jun 2026 lunch is past
- Ma Langue Sourit x Tanja Grandits (Stucki) four hands (Benelux): 27 October - before window (past)
- Gucci Giardino bar takeover at Pulitzer's Bar (15 Nov) / Jansz. Winter Garden (Benelux): cocktail-bar takeover and seasonal formats, no year stated; not gastronomy one-off
- Sterren Proeverij Den Haag (1 Nov) / Proef Blokzijl (27 Sep 2026) (Benelux): past; Proef Blokzijl is a town food walk, not high-end
- Parkheuvel x North Sea Jazz pop-up (Benelux): 2026 edition past; no 2027 date
- Okura 'Noël's Wine Exploration' tastings (Benelux): listed dates are past / sommelier has retired (farewell evenings)
- Le Meurice four-hands Quique Dacosta x Amaury Bouhours (13-14 Nov) (Zuid-Europa): Past: article dated 24/10/2025, events were November 2025.
- Ocean x F.X. Pichler, Vila Vita Parc (Zuid-Europa): Past (12 Aug 2025).
- Monte-Carlo Festival des Étoilés 2026 four-hands dinners (May-Sept) (Zuid-Europa): Past; only the 14 Nov closing gala remains (included).
- Es Fum Michelin Star Series 2026 (St. Regis Mardavall, Mallorca) (Zuid-Europa): Past; final 2026 dinner 26 Sept 2026; no 2027 dates published.
- San Sebastián Gastronomika 2027 (Zuid-Europa): No 2027 dates found; 2026 edition (Oct) is past.
- Sirha Omnivore 2027 / Taste of Paris 2027 / Sani Gourmet 2027 (Zuid-Europa): No 2027 dates published (2026 editions past).
- Forces of Nature 4-hands: Hiša Franko x Trèsind (Zuid-Europa): Past (13 Oct 2026); last dinner of the 2026 series.
- Sirha Omnivore Le Grand Banquet 2026 (Zuid-Europa): Past (12 Oct 2026). Omnivore 'Speakeasy' 21-24 Jan 2027 is within Sirha Lyon (already recorded).
- Zwischen Spitzenküche, TV & Musik (Nelson Müller, Amrum) (Noord-/Centraal-Europa): past: 2026-11-01
- Charity Dinner zugunsten Kinderschutzbund SH im Cap Polonio (Noord-/Centraal-Europa): past: 2026-11-01
- Four Hands Le Sept, Mandarin Oriental Vienna (Seifried x Ekkebus) (Noord-/Centraal-Europa): past: 23-25 Jan 2026
- Pavyllon London Four Hands (Alléno x Atherton) (Noord-/Centraal-Europa): past: 26 Oct 2026
- Hubert Wallner guest chef events 2026 (Wörthersee) (Noord-/Centraal-Europa): past: May-June 2026
- Ridge Fine & Rare Wine Dinner, Chewton Glen (Noord-/Centraal-Europa): past: Tuesday 20 October 2026
- Austin Food & Wine Festival 2027 (Noord-Amerika): No 2027 date published; 2026 edition (Nov 6-8) past/ongoing at time of check.
- Friends of James Beard Benefit dinners (Dallas Nov 4, Clarksburg MD Nov 19) (Noord-Amerika): Dallas one is already past (Nov 4 is tomorrow-adjacent but listed only by day, venue not high-end catalogue); Clarksburg farm chef's counter is modest. Year not shown on page.
- Canada's Great Kitchen Party Vancouver 2026 (Noord-Amerika): Regional qualifier at The Pipe Shop on October 7 — past.
- Rosewood 'Yo Amo México' guest chef series (Noord-Amerika): All listed events Jan–Apr 2026 — past; no 2027 edition published.
- Vancouver World Chef Exchange: Wilfrid Hocquet at Boulevard Kitchen (Noord-Amerika): Took place 6 Feb 2026 — past.
- Salisterra x Toyo Eatery Four Hands Dinner (Upper House 16th anniversary) (Azië & Midden-Oosten): Past: took place 7 Nov 2025; no 2026 edition found.
- Ho Lee Fook x Man Ho - The Four Treasures (Azië & Midden-Oosten): Past: 13 Nov 2025 (Tatler article dated 31 Oct 2025); search summary wrongly suggested 2026.
- Zi Yat Heen Masters Series with The Bridge, Chengdu (Four Seasons Macao) (Azië & Midden-Oosten): Past: 31 Oct and 1 Nov 2026. Series 'continues' but no further dates published - worth rechecking.
- Loca Niru four-hands with Allen Suh (Restaurant Allen, Seoul) (Azië & Midden-Oosten): Past: 27-28 Oct 2026.
- Symphony of Eight Hands, Jiang-Nan Chun, Four Seasons Singapore (Azië & Midden-Oosten): Past: 10 April 2026.
- Mandala Masters x Le Du pop-up, Mandarin Oriental Singapore (Azië & Midden-Oosten): Past: Nov 2023 edition.
- Chef Stefan Fäth at JW Marriott Maldives Kaafu Atoll (Azië & Midden-Oosten): Year ambiguous: article published 1 Dec 2025 says '4 and 5 December 2026' - almost certainly the Dec 2025 event with a typo. Secondary only.
- Chef Norimasa Kosaka four-hands at TAPASAKE, One&Only Reethi Rah (Azië & Midden-Oosten): Past: 27 and 29 March 2026.
- Keyaki x Kenrantei four-hand, Pan Pacific Singapore (Azië & Midden-Oosten): Past: 20-21 August 2026.
- MICHELIN Guide Food Festival Abu Dhabi (2026 edition) (Azië & Midden-Oosten): No 2026 dates published; only the 2025 edition (21-23 Nov 2025) found. Recheck.
- Michael Mina at Mina Brasserie, Four Seasons DIFC (Azië & Midden-Oosten): Multi-day visit 30 Oct-4 Nov 2026 with off-menu dishes, not a one-off dinner; almost over. Not fetched.
- MICHELIN Star Table (SJM) - Robuchon au Dôme x Gérald Passedat (Azië & Midden-Oosten): Year unclear (15-16 Nov, possibly a past year); page returned 503, could not verify. Recheck - would be high value.
- Sézanne x Caprice four-hand dinner, Four Seasons Tokyo Marunouchi (Azië & Midden-Oosten): Not verified - no date/year seen; likely past. Not fetched (search budget).
- Mandarin Oriental Tokyo x Roy Caceres collaboration (Azië & Midden-Oosten): Past: July 2026 per search summary.
- Ritz-Carlton Kyoto Mizuki guest chef dinner (Azië & Midden-Oosten): Past: 23 and 25 Sep 2026.
- Signature Sessions: Clon X Naar / Shizen X Nuema / Rocco X Locale Firenze (1 Nov 2026); Cosme X Cocina Hermanos Torres (2 Nov 2026) (Zuid-Amerika, Afrika & Oceanië): past (1-2 Nov 2026, before 2026-11-03). Note Shizen X Nuema involves catalogue venue Nuema rest_1374.
- F.A.W.C! Hawke's Bay Food and Wine Classic (Zuid-Amerika, Afrika & Oceanië): on hiatus 2025-2026; 2027 dates not announced
- Davivienda Restaurant Tour 2026 - Cali dinner (5 Nov 2026) (Zuid-Amerika, Afrika & Oceanië): only secondary press gives 'Cali 5 Nov'; host restaurant and guest chef not identified; Atrapalo ticket page would not render. Other tour dinners (Sep-Oct 2026) are past. Revisit via Alimentarte/Fundación Corazón Verde channels.
- Festival Ñam Santiago 2027 (Zuid-Amerika, Afrika & Oceanië): no 2027 dates announced (2026 edition was April, past); also a broad public food fair
- Chefs Week Rio 2026 (Copacabana Palace banquets 28-29 Jul 2026) (Zuid-Amerika, Afrika & Oceanië): past
- Eat Out Woolworths Restaurant Awards (Zuid-Amerika, Afrika & Oceanië): 2026 ceremony was 23 Mar 2026 (past); 2027 date not published
- Heritage Resorts Sustainable Gastronomy Week (5-11 Oct 2026) and Jakob Mielcke residency (13/15 Oct 2026) (Zuid-Amerika, Afrika & Oceanië): past

**geen (exacte) datum gepubliceerd (27)**

- Okura Ciel Bleu 24H Chefs (Benelux): 'this June' with no exact dates/year (charity, worth re-checking for 2027 dates)
- Taste of Amsterdam 2027 (Benelux): no 2027 edition found; reported discontinued after 2022
- Merlet 'The Art of Dining' (Benelux): bookable group arrangement, no date
- Botanic Sanctuary Antwerp Gourmet Festival 2027 (Benelux): no 2027 dates published; site returns 403 to fetch
- Chefs Revolution (De Librije, Zwolle) 2027 (Benelux): no 2027 date found; official site offline
- La Paix by David Martin at Corinthia Brussels (reopening) (Benelux): 'opening soon', no date
- Château St. Gerlach / Château Neercanne events calendar (Benelux): calendar loads via JS, no dates retrievable; only Christmas/NYE arrangements
- Gran Cena "L'Oro della Terra" with Castiglion del Bosco (Campo del Drago, rest_0390) – San Giovanni d'Asso (Zuid-Europa): Sold out and no date printed on organiser page (7 Nov 2026 only inferable from image filename).
- Identità Golose Milano 2027 congress (Zuid-Europa): No 2027 dates published yet.
- KITZ Kulinarik 2027 (Noord-/Centraal-Europa): no 2027 date published; town street-food style festival
- The Epicure 2027 (The Dolder Grand) (Noord-/Centraal-Europa): paused in 2026, returns 2027 but no dates published
- Prague Food Festival 2027 (Noord-/Centraal-Europa): site shows no 2027 dates
- Food & Wine Classic in Aspen 2027 (Noord-Amerika): No official 2027 date; only an aggregator (carnifest) lists June 18-20, 2027. foodandwine.com refuses fetch.
- Montréal en Lumière 2027 (Noord-Amerika): Dates Feb 18-28, 2027 confirmed but homepage shows no 2027 gastronomy/guest-chef programme yet; general arts & light festival. Recheck for 'Les Grandes Tables' programme.
- Auction Napa Valley 2027 (Noord-Amerika): Only a Sotheby's lot listing mentions June 3-5, 2027; organiser site shows no 2027 date.
- Oregon Truffle Festival 2027 (Noord-Amerika): No 2027 dates published yet.
- Gourmet Abu Dhabi 2027 (Azië & Midden-Oosten): No 2027 edition found; brand appears folded into Abu Dhabi Culinary Season; no dates.
- Dubai Food Festival 2027 (Azië & Midden-Oosten): No official 2027 dates found; also largely mass-market.
- World Gourmet Summit 2027 (Singapore) (Azië & Midden-Oosten): No 2027 dates; last listing (2024) marked on hold.
- Mauro Colagreco at One&Only Royal Mirage Dubai (3-5 Dec) (Azië & Midden-Oosten): Page undated, no year; cannot confirm 2026.
- TakaHisa x Jara (Martín Berasategui) at The Lana, Dubai (Azië & Midden-Oosten): Official page 403 to fetch; no date found in snippets.
- Galaxy Macau Asami x Yamazato four hands / Chinese-Portuguese Master Chefs series (Azië & Midden-Oosten): Galaxy site returns 403; no dates obtained.
- Melbourne Food & Wine Festival 2027 (Zuid-Amerika, Afrika & Oceanië): official site only says March 2027, no exact dates; secondary sources disagree (19-28 vs 20-29 Mar). Revisit when program launches.
- Margaret River Gourmet Escape 2026 (Zuid-Amerika, Afrika & Oceanië): official site unreachable (DNS failure); only aggregator dates (13-15 Nov 2026) and an aggregator saying 2026 not announced - conflicting, unverified
- Mistura 2026/2027 (Zuid-Amerika, Afrika & Oceanië): no official dates; APEGA only discussing versions abroad (Jul 2026); mass-market fair anyway
- Central Otago Pinot Noir Celebration 2027 (Zuid-Amerika, Afrika & Oceanië): official site 503; no 2027 dates found
- Constantia Fresh 2027 (Zuid-Amerika, Afrika & Oceanië): no 2027 dates published

**overig (21)**

- Hotel Eden Rome Taste Society guest-chef Sunday lunches (Zuid-Europa): 2026 series ended 4 Oct 2026; no later dates.
- Yeatman 'Taste & Toast Fest' (6 Nov 2026) (Zuid-Europa): Content unclear (no producer/chef named); looks like a general party — not verified as high-end gastronomy.
- Alba International White Truffle Fair 2026 (10 Oct - 6 Dec) (Zuid-Europa): Weeks-long fair/market, not a one-off; official site did not render; the World Auction (8 Nov) recorded separately.
- Goose time in the castle (Schloss Bensberg) (Noord-/Centraal-Europa): seasonal menu, not one-off
- Krug Chalet fondue (The Dolder Grand) (Noord-/Centraal-Europa): seasonal pop-up running for months, not one-off
- Claude & Co at Brooklands (Peninsula London) 2026/27 (Noord-/Centraal-Europa): no upcoming dates published
- LA MAISON Saarlouis Four Hands (Sandor x Laarberg, 22 Nov 2026) (Noord-/Centraal-Europa): held back: search summary claimed 22 Nov 2026, but the venue's own page as fetched lists no 2026-Nov date (latest 16 Feb 2026); not verifiable
- Four-Hands Dinner ConTanima Bozen (Noord-/Centraal-Europa): out of region (Italy)
- Gelinaz! next event (Noord-/Centraal-Europa): no upcoming dated event published
- Kempinski Berchtesgaden PUR Kehrausparty (Noord-/Centraal-Europa): farewell party 7 Nov 2026 with no guest chef; low fit
- Kesselhaus Osnabrück Küchenparty (29 Nov 2026) (Noord-/Centraal-Europa): held back: only a search snippet; venue site failed to load (proxy 502); not verified
- Waterford Festival of Food 2027 (Noord-/Centraal-Europa): 2027 dates not yet published; site still shows 2026; broad public food festival
- Día de los Muertos Supper Club, Lympstone Manor (Noord-/Centraal-Europa): themed supper club, no guest chef/date verified; low fit
- 1887 by André x visiting chef (TBC) - Marina Bay collaboration (Azië & Midden-Oosten): March 2027, guest chef 'to be confirmed' - too vague; recheck later.
- Sudachi x La BOMBANCE Kouri Island collaboration dinner (Azië & Midden-Oosten): 7-8 Nov 2026 but exclusively for hotel guests on a specific stay plan - not publicly bookable.
- JAL Michelin private dinner campaign at CYCLE by Mauro Colagreco (28 Nov 2026) (Azië & Midden-Oosten): Invitation/miles lottery for JAL elite cardholders; not a public event and not a collaboration.
- Asia's 50 Best Restaurants 2027 / 50 Best Signature Sessions (Azië & Midden-Oosten): 2027 date and host city not yet announced; experiences page lists nothing upcoming.
- 50 Best Talks Lima (Zuid-Amerika, Afrika & Oceanië): 3 Nov 2026 talks, today/in progress and not a dining event
- Marlborough Wine & Food Festival 2027 (Zuid-Amerika, Afrika & Oceanië): planned 13 Feb 2027 but put on hold (announced 20 Aug 2026); no event
- Noosa Food & Wine Festival 2027 (Zuid-Amerika, Afrika & Oceanië): no announced 2027 dates
- Taste of Sydney 2027 (Zuid-Amerika, Afrika & Oceanië): no evidence of 2027 edition or dates

**terugkerend of standaardaanbod (10)**

- Wildmiddag/Wildavond 8 & 29 Nov, 11 Dec 2026 (Olde Marckt) (Benelux): fully booked ('vol!'); recurring game-season format
- La Butte aux Bois culinaire agenda (Sundays @ La Source, Perla & Sapori 15 Nov, EXPLORE 13 Dec, Bubbles & Cakes, Next Generation Dinner) (Benelux): lifestyle/brunch/recurring formats, no guest chef or winemaker; not one-off high-end
- Klosse Wines Najaarsproeverij (De Echoput, 22 Nov 2026) and Echoput Christmas menus (Benelux): mass wine fair (€24) and standard Christmas menus; nothing at Wild Atelier
- Monte-Carlo SBM agenda: L'Abysse Matataki menu / Pavyllon brunch (Zuid-Europa): Standing menus/brunches running for months.
- Taste of London: The Festive Edition 2026 (Noord-/Centraal-Europa): no 2026 festive edition dates found; large consumer festival, low fit
- taku Christmas / NYE / Valentine's / Taste Journey / Villa Bodinus pop-up (Noord-/Centraal-Europa): standard holiday menus or multi-week formats
- Blackberry Farm holiday/music/wellness events (Thanksgiving, Christmas, NYE, Jason Isbell, etc.) (Noord-Amerika): Standard holiday packages or non-gastronomy events.
- The Inn at Little Washington – upcoming events (Noord-Amerika): Only Thanksgiving (26 Nov 2026) and New Year's (31 Dec 2026) listed — standard holiday menus.
- Aman Tokyo Festive Itinerary 2026 (Arva, Musashi etc.) (Azië & Midden-Oosten): Standard Christmas/NYE menus by resident chefs; no guest chef.
- Heritage Resorts festive menus by Laurent & Julie Lemal (24, 25, 27 Dec 2026) (Zuid-Amerika, Afrika & Oceanië): standard Christmas festive menus

**niet high-end (9)**

- Launch Gault&Millau Belux Guide Edition 2027 (9 Nov 2026) (Benelux): industry guide launch ceremony, not a consumer gastronomy event
- KACHEN TABLE #2 at Public House (LU, 6 Nov 2026) (Benelux): not high-end (€25 lunch)
- Sthlm Food & Wine 2026/2027 (Noord-/Centraal-Europa): consumer trade fair (mass-market); 2027 dates TBD
- Plaza Culinaria 2026 Freiburg (Noord-/Centraal-Europa): consumer fair, not high-end
- Taste of London 2027 (Noord-/Centraal-Europa): 2027 dates not yet announced (site: 'sign up to hear about our grand 2027 plans'); large consumer festival
- Thanying x Snowcology 'A Gust of Snow' four-hands dinner (Amara Singapore) (Azië & Midden-Oosten): Secondary source only (27-28 Nov 2026, S$168++); mid-market, not high-end enough to justify a C-level row.
- Taste of Abu Dhabi 2026 (Azië & Midden-Oosten): 13-15 Nov 2026 per press; mass-market food & music festival, not high-end. Official page not checked.
- Sauvignon Blanc New Zealand 2027 (Marlborough, 2-4 Feb 2027) (Zuid-Amerika, Afrika & Oceanië): trade conference, not a consumer gastronomy event; secondary source only
- Barossa Vintage Festival 2027 (21-25 Apr 2027) (Zuid-Amerika, Afrika & Oceanië): dates verified on official site, but community festival (parade, scarecrows, grapestomp) - not high-end

**tegenstrijdige of onbetrouwbare bron (4)**

- Spectrum (Waldorf Astoria Amsterdam) guest dinners (Benelux): restaurant closed May 2026 per secondary sources
- F.A.Z. Lieblinge of the Year (Schloss Bensberg) (Noord-/Centraal-Europa): held back: page contradicts itself (banner 23 Jan 2027 vs details 24 Jan 2026 / title 2026); chefs unnamed
- Chef Tristan Brandt at Sirru Fen Fushi (Sirru Icons Series) (Azië & Midden-Oosten): HELD BACK - contradiction: resort page says '29 December 2026 and 2 January 2027'; Lets Go Maldives (11 Jun 2026) says four-hands dinner 26 December 2026. Resort page gives no event detail per date. Recheck with resort.
- Traful Invita 2026 (Villa Traful, Argentina) (Zuid-Amerika, Afrika & Oceanië): Sept/Oct 2026 article; not verified as upcoming, secondary only, regional event

## Dekking per regio: wat wel, deels en niet is doorzocht

(volgt)
