# Wereldwijd overzicht van komende gastronomische events

**Status: onderzoek, niets toegepast.** Er is niets naar Supabase geschreven. Bestanden:

- `world_event_overview_20261105.csv`: alle 215 kandidaten, gesorteerd.
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
| wev-001 | 2026-11-05 | White Truffle & Gaja Dinner | London, GB | Dinner | Wine, Winemaker | A | high | geen catalogusmatch |
| wev-002 | 2026-11-05 t/m 2026-11-07 | Big Sur Food & Wine Festival 2026 | Big Sur, US | Festival | Wine, Charity | A | high | geen catalogusmatch |
| wev-003 | 2026-11-05 | Signature Sessions: Sapiens X Kol | Lima, PE | Dinner | Guest Chef, Four Hands | A | high | geen catalogusmatch; voorgesteld: rest_0329 |
| wev-004 | 2026-11-06 | Cos d'Estournel Four-Hands Dinner: Jérôme Banctel x Marco Ortolani | Zurich, CH | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_87, rest_0060 |
| wev-005 | 2026-11-06 t/m 2026-11-10 | Merano WineFestival 2026 (35th edition) | Merano, IT | Festival | Wine | A | high | geen catalogusmatch |
| wev-006 | 2026-11-06 | 2026 JBF Gala for Good™ | New York, US | Gala | Charity, Guest Chef | A | high | rest_0746, rest_3043 |
| wev-007 | 2026-11-07 | Four-Hands Dinner | Six courses - two culinary signatures | Cologne, DE | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_162, rest_1936, rest_2084 |
| wev-008 | 2026-11-07 | Autumn in Vermont White Truffle Dinner Weekend (Twin Farms) | Barnard, US | Dinner | – | A | high | geen catalogusmatch |
| wev-009 | 2026-11-08 | 2026 World Alba White Truffle Charity Auction | Macau, MO | Gala | Charity, Guest Chef, Wine | A | high | geen catalogusmatch |
| wev-010 | 2026-11-08 | XXVII World Alba White Truffle Auction dinner at Riva del Fiume Ristorante | Bangkok, TH | Gala | Guest Chef, Charity, Wine | A | high | geen catalogusmatch |
| wev-011 | 2026-11-09 t/m 2026-11-15 | Saint Barth Gourmet Festival 2026 (13e édition) | Gustavia / Saint-Barthélemy, BL | Festival | Guest Chef | A | high | geen catalogusmatch |
| wev-012 | 2026-11-10 | KRUG 4-Hands-Dinner | Zurich, CH | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_2502, rest_0263, rest_0282 |
| wev-013 | 2026-11-13 | Winzer Dinner mit Weingut Lackner Tinnacher | Cologne, DE | Dinner | Wine, Winemaker | A | high | rest_2084 |
| wev-014 | 2026-11-13 | Jantar Magno Mesa SP 2026 – Grand Hyatt São Paulo | São Paulo, BR | Dinner | Guest Chef | A | high | geen catalogusmatch; voorgesteld: rest_0134, rest_1393 |
| wev-015 | 2026-11-14 | Gala de clôture du Festival des Étoilés Monte-Carlo 2026 | Monte Carlo, MC | Gala | Guest Chef | A | high | rest_1579, rest_1582, rest_1585 |
| wev-016 | 2026-11-16 | Dîner de Gala de Charité 2026 au profit de la Banque Alimentaire Luxembourg | Luxembourg City, LU | Gala | Charity, Guest Chef | A | high | geen catalogusmatch |
| wev-017 | 2026-11-18 | Château d'Yquem Wine Dinner with Chef Anne-Sophie Pic | Bangkok, TH | Dinner | Wine, Winemaker, Guest Chef | A | high | geen catalogusmatch |
| wev-018 | 2026-11-18 | 18. November: Gravner x Hiša Franko | Kobarid, SI | Dinner | Wine, Winemaker | A | high | rest_0424 |
| wev-020 | 2026-11-19 t/m 2026-11-22 | Pair'd Margaret River Region 2026 | Margaret River, AU | Festival | Wine, Guest Chef | A | high | geen catalogusmatch |
| wev-021 | 2026-11-20 | An extraordinary evening with Domaine Kuheiji (Kuheiji Dinner) | Amsterdam, NL | Dinner | Wine, Winemaker | A | high | rest_0119 |

## Top 5 per regio

### Benelux (23 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-016 | 2026-11-16 | Dîner de Gala de Charité 2026 au profit de la Banque Alimentaire Luxembourg | Luxembourg City, LU | Gala | Charity, Guest Chef | A | high | geen catalogusmatch |
| wev-021 | 2026-11-20 | An extraordinary evening with Domaine Kuheiji (Kuheiji Dinner) | Amsterdam, NL | Dinner | Wine, Winemaker | A | high | rest_0119 |
| wev-029 | 2026-11-25 | Truffelavond met Licata | Francorchamps, BE | Dinner | Wine, Winemaker | A | high | rest_0872 |
| wev-043 | 2026-12-12 | YVESKE'S Kitchen at MASTERS EXPO - Dinner 12 Dec | Amsterdam, NL | Dinner | Guest Chef | A | high | rest_0016, rest_0025, rest_0030, rest_0069 |
| wev-114 | 2026-11-07 t/m 2026-11-08 | Gary Gielen & Friends Dinner Show | Maastricht, NL | Party | – | A | low | hotel_05 |

### Zuid-Europa (24 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-005 | 2026-11-06 t/m 2026-11-10 | Merano WineFestival 2026 (35th edition) | Merano, IT | Festival | Wine | A | high | geen catalogusmatch |
| wev-015 | 2026-11-14 | Gala de clôture du Festival des Étoilés Monte-Carlo 2026 | Monte Carlo, MC | Gala | Guest Chef | A | high | rest_1579, rest_1582, rest_1585 |
| wev-018 | 2026-11-18 | 18. November: Gravner x Hiša Franko | Kobarid, SI | Dinner | Wine, Winemaker | A | high | rest_0424 |
| wev-031 | 2026-11-26 t/m 2026-11-27 | XI. Gastromasa İstanbul International Gastronomy Conference & Exhibition | Istanbul, TR | Festival | Guest Chef | A | high | rest_0325, rest_0331, rest_0362, rest_1003 |
| wev-045 | 2026-12-13 | Gourmet Skisafari Alta Badia | Alta Badia, IT | Tasting | Guest Chef | A | high | rest_0315, rest_2202, rest_2296 |

### Noord-/Centraal-Europa (80 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-001 | 2026-11-05 | White Truffle & Gaja Dinner | London, GB | Dinner | Wine, Winemaker | A | high | geen catalogusmatch |
| wev-004 | 2026-11-06 | Cos d'Estournel Four-Hands Dinner: Jérôme Banctel x Marco Ortolani | Zurich, CH | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_87, rest_0060 |
| wev-007 | 2026-11-07 | Four-Hands Dinner | Six courses - two culinary signatures | Cologne, DE | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_162, rest_1936, rest_2084 |
| wev-012 | 2026-11-10 | KRUG 4-Hands-Dinner | Zurich, CH | Dinner | Four Hands, Guest Chef, Wine | A | high | hotel_2502, rest_0263, rest_0282 |
| wev-013 | 2026-11-13 | Winzer Dinner mit Weingut Lackner Tinnacher | Cologne, DE | Dinner | Wine, Winemaker | A | high | rest_2084 |

### Noord-Amerika (39 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-002 | 2026-11-05 t/m 2026-11-07 | Big Sur Food & Wine Festival 2026 | Big Sur, US | Festival | Wine, Charity | A | high | geen catalogusmatch |
| wev-006 | 2026-11-06 | 2026 JBF Gala for Good™ | New York, US | Gala | Charity, Guest Chef | A | high | rest_0746, rest_3043 |
| wev-008 | 2026-11-07 | Autumn in Vermont White Truffle Dinner Weekend (Twin Farms) | Barnard, US | Dinner | – | A | high | geen catalogusmatch |
| wev-011 | 2026-11-09 t/m 2026-11-15 | Saint Barth Gourmet Festival 2026 (13e édition) | Gustavia / Saint-Barthélemy, BL | Festival | Guest Chef | A | high | geen catalogusmatch |
| wev-035 | 2026-12-06 t/m 2026-12-09 | By Land and Sea (Blackberry Farm) | Walland, US | Dinner | Guest Chef, Winemaker, Wine | A | high | rest_0755 |

### Azië & Midden-Oosten (33 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-009 | 2026-11-08 | 2026 World Alba White Truffle Charity Auction | Macau, MO | Gala | Charity, Guest Chef, Wine | A | high | geen catalogusmatch |
| wev-010 | 2026-11-08 | XXVII World Alba White Truffle Auction dinner at Riva del Fiume Ristorante | Bangkok, TH | Gala | Guest Chef, Charity, Wine | A | high | geen catalogusmatch |
| wev-017 | 2026-11-18 | Château d'Yquem Wine Dinner with Chef Anne-Sophie Pic | Bangkok, TH | Dinner | Wine, Winemaker, Guest Chef | A | high | geen catalogusmatch |
| wev-042 | 2026-12-12 | An Evening with Château Cheval Blanc | Macau, MO | Dinner | Wine, Winemaker | A | high | rest_0434 |
| wev-046 | 2026-12-26 t/m 2026-12-29 | An Exclusive Culinary Experience with Two-Star Michelin Chef Benjamin Peifer | Kandolhu Island (North Ari Atoll), MV | Dinner | Guest Chef | A | high | geen catalogusmatch |

### Zuid-Amerika, Afrika & Oceanië (16 kandidaten)

| id | datum | event | plaats | type | tags | bron | fit | catalogus |
|---|---|---|---|---|---|---|---|---|
| wev-003 | 2026-11-05 | Signature Sessions: Sapiens X Kol | Lima, PE | Dinner | Guest Chef, Four Hands | A | high | geen catalogusmatch; voorgesteld: rest_0329 |
| wev-014 | 2026-11-13 | Jantar Magno Mesa SP 2026 – Grand Hyatt São Paulo | São Paulo, BR | Dinner | Guest Chef | A | high | geen catalogusmatch; voorgesteld: rest_0134, rest_1393 |
| wev-020 | 2026-11-19 t/m 2026-11-22 | Pair'd Margaret River Region 2026 | Margaret River, AU | Festival | Wine, Guest Chef | A | high | geen catalogusmatch |
| wev-023 | 2026-11-20 | Wayfinder x St JOHN, presented by Lexus | Margaret River, AU | Dinner | Wine, Winemaker, Guest Chef | A | high | geen catalogusmatch; voorgesteld: rest_2590 |
| wev-064 | 2026-11-06 | Heritage Culinary Calendar 2026: Chef Cris Oberhammer & Anna Oberhammer | Bel Ombre, MU ⚠ land niet in countries | Dinner | Guest Chef | A | medium | geen catalogusmatch; voorgesteld: rest_2414 |

## Aantallen

**Per land:** DE 47, US 28, NL 19, AT 16, SG 12, IT 8, CH 7, FR 7, TH 6, BR 5, AU 5, MV 5, PT 5, HK 4, CA 4, MU 4, GB 3, MO 3, (geen) 3, LU 2, BE 2, IE 2, DK 2, MX 2, PE 1, BL 1, MC 1, SI 1, TR 1, AE 1, BH 1, JP 1, SE 1, ZA 1, KY 1, ES 1, IS 1, HU 1

**Per maand (startdatum):**

| maand | aantal |
|---|---|
| 2026-11 | 87 |
| 2026-12 | 36 |
| 2027-01 | 20 |
| 2027-02 | 24 |
| 2027-03 | 19 |
| 2027-04 | 6 |
| 2027-05 | 3 |
| 2027-06 | 4 |
| 2027-07 | 2 |
| 2027-08 | 3 |
| 2027-11 | 1 |
| 2027-12 | 1 |
| zonder  | 9 |

**Per prioriteit:** P0 79, P1 118, P2 18  
**Per bronniveau:** A 177, B 19, C 19  
**Per zekerheid:** confirmed 189, unclear 26

**Landen die niet in `countries` staan** (die moeten eerst worden toegevoegd): (geen), BH, KY, MU.

## Wat is afgevallen en waarom

**voorbij / vorige editie (83)**

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
- Four Hands: Where Jiangnan Meets Cantonese Mastery (Azië & Midden-Oosten): checked in merge: ends before 2026-11-05 (passed by delivery)
- Hong Kong Wine & Dine Festival 2026 (Azië & Midden-Oosten): Past (29 Oct-1 Nov 2026) and mass-market.
- Louise x Julien Royer second night (13 Nov 2026) (Azië & Midden-Oosten): Not a new event: The Beat list says dinners on 12 and 13 Nov; pass 1 row covers 12 Nov only - reviewer may extend that row end_date to 2026-11-13 after checking.
- Zi Yat Heen Master Series x Chengdu Corridor Bridge (Four Seasons Macao) (Azië & Midden-Oosten): Past: 31 Oct and 1 Nov 2026 (confirms pass 1 rejection).
- Sézanne x Caprice / est x Caprice four-hand dinners (Four Seasons Tokyo) (Azië & Midden-Oosten): Past: 2022 (Four Seasons press 2022; Time Out dated 4 Nov 2022).
- The Michelin Edition: Patrizia Di Benedetto at Celini, Grand Hyatt Mumbai (Azië & Midden-Oosten): Past: 21-23 Nov 2025.
- Villa Toscana (St. Regis Abu Dhabi) Four-Hands Dinner with Nicola Somma / Bobo Cerea (Azië & Midden-Oosten): Past: 5-7 Nov 2025 (article 29 Oct 2025).
- Saint Pierre x Restaurant Allen (Azië & Midden-Oosten): Past: 11 and 20 Sep 2025.
- Sofitel Legend Metropole Hanoi Culinary Stars Week (Azië & Midden-Oosten): Past: 2019 edition; no current edition found.
- Vietnam Senses of Capella (Capella Hanoi) (Azië & Midden-Oosten): Past: 17-20 Oct 2024; no 2026/27 edition found.
- Tatler Off Menu (Galaxy Macau) 2026 (Azië & Midden-Oosten): No 2026 edition dates found; last edition 14-15 Nov 2025.
- Taste of Shangri-La 8-hands dinner series (Dubai/Abu Dhabi/Jeddah) (Azië & Midden-Oosten): Past: 2026 Taste of Shangri-La ran 1-31 Oct 2026; 8-hands series was Sep 2025.
- SJM Stars Table Series: Don Alfonso 1890 (Iaccarino/Aprea) (Azië & Midden-Oosten): Past: 5-6 Dec 2025.
- Parisian Macao 10th anniversary Moët & Chandon dinners (Azië & Midden-Oosten): Past: September 2026.
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
- Ciel Bleu Refined Nights (Gaja 1 Oct 2026; winter truffle, Krug, caviar nights) (Benelux): Gaja night past; other themed Thursdays have no published dates - recheck later
- Okura Yamazato Moët & Chandon Grand Vintage Dinner / Ciel Bleu White Truffle Refined Night (Benelux): 2025-26 editions (post dated Oct 2025; truffle night 13 Dec 2025); no 2026-27 dates
- Truffeldiner (Benelux): checked in merge: ends before 2026-11-05 (passed by delivery)
- Zilte Exquis experiences (Benelux): re-checked: only 7 Jun 2026 Rutz lunch (past) and undated "Zondag 9 november" (Sunday in 2025, not 2026); no new dates
- Botanic Sanctuary Antwerp Gourmet Festival programme PDF (Benelux): PDF created Apr 2025 = past edition; no 2027 programme found
- Van Oys Christmas Lunch at Create / Maes, Christmas brunches, Christmas Signature Tasting, Christmas Concert, Sunday brunches (Dec 2026-Feb 2027) (Benelux): standard Christmas/New Year offerings and recurring brunch format; Dîner Dansant 24 Dec already in production (25 Dec edition same format)
- Comme Chez Soi 100 years (Brussels) (Benelux): centenary menu ran 10-21 June 2026 (past); no dated Dec/Jan event on own site
- Okura 24H Chefs 2027 (Benelux): sixth edition Sat 6 / Sun 7 June = 2026 (past); no 2027 date found
- A Walk in the Dutch Lowlands (Jonnie Boer tribute tour, RIJKS 8 Dec) (Benelux): article dated 14 Oct 2025 - 8 Dec was 2025 (past)
- Luxembourg Bocuse 100 dinner (French Embassy) (Benelux): private dinner, already held (Oct 2026)
- Zwischen Spitzenküche, TV & Musik (Nelson Müller, Amrum) (Noord-/Centraal-Europa): past: 2026-11-01
- Charity Dinner zugunsten Kinderschutzbund SH im Cap Polonio (Noord-/Centraal-Europa): past: 2026-11-01
- Four Hands Le Sept, Mandarin Oriental Vienna (Seifried x Ekkebus) (Noord-/Centraal-Europa): past: 23-25 Jan 2026
- Pavyllon London Four Hands (Alléno x Atherton) (Noord-/Centraal-Europa): past: 26 Oct 2026
- Hubert Wallner guest chef events 2026 (Wörthersee) (Noord-/Centraal-Europa): past: May-June 2026
- Ridge Fine & Rare Wine Dinner, Chewton Glen (Noord-/Centraal-Europa): past: Tuesday 20 October 2026
- Symphony of Stars 4-hands, Fifty Seconds Lisbon (Silvestre x Sinthon, 4 Dec) (Zuid-Europa): Page gives 4 December without year; images uploaded Nov 2025 and 4 Dec 2025 was the likely edition; year ambiguous, likely past.
- Mauro Colagreco x Quique Dacosta, Raffles London at The OWO (Thursday 28 Nov) (Noord-/Centraal-Europa): Thursday 28 November matches 2024, not 2026; past.
- Ein Prosit Udine 2026 (Zuid-Europa): Past: 14-18 October 2026.
- Italian Wine Experience Gstaad 2026 (HUUS) (Noord-/Centraal-Europa): Past: 6-7 June 2026.
- Le Meurice four-hands Quique Dacosta x Amaury Bouhours (13-14 Nov) (Zuid-Europa): Past: article dated 24/10/2025, events were November 2025.
- Ocean x F.X. Pichler, Vila Vita Parc (Zuid-Europa): Past (12 Aug 2025).
- Monte-Carlo Festival des Étoilés 2026 four-hands dinners (May-Sept) (Zuid-Europa): Past; only the 14 Nov closing gala remains (included).
- Es Fum Michelin Star Series 2026 (St. Regis Mardavall, Mallorca) (Zuid-Europa): Past; final 2026 dinner 26 Sept 2026; no 2027 dates published.
- San Sebastián Gastronomika 2027 (Zuid-Europa): No 2027 dates found; 2026 edition (Oct) is past.
- Sirha Omnivore 2027 / Taste of Paris 2027 / Sani Gourmet 2027 (Zuid-Europa): No 2027 dates published (2026 editions past).
- Forces of Nature 4-hands: Hiša Franko x Trèsind (Zuid-Europa): Past (13 Oct 2026); last dinner of the 2026 series.
- Sirha Omnivore Le Grand Banquet 2026 (Zuid-Europa): Past (12 Oct 2026). Omnivore 'Speakeasy' 21-24 Jan 2027 is within Sirha Lyon (already recorded).
- Austin Food & Wine Festival 2027 (Noord-Amerika): No 2027 date published; 2026 edition (Nov 6-8) past/ongoing at time of check.
- Friends of James Beard Benefit dinners (Dallas Nov 4, Clarksburg MD Nov 19) (Noord-Amerika): Dallas one is already past (Nov 4 is tomorrow-adjacent but listed only by day, venue not high-end catalogue); Clarksburg farm chef's counter is modest. Year not shown on page.
- Canada's Great Kitchen Party Vancouver 2026 (Noord-Amerika): Regional qualifier at The Pipe Shop on October 7 — past.
- Rosewood 'Yo Amo México' guest chef series (Noord-Amerika): All listed events Jan–Apr 2026 — past; no 2027 edition published.
- Vancouver World Chef Exchange: Wilfrid Hocquet at Boulevard Kitchen (Noord-Amerika): Took place 6 Feb 2026 — past.
- Signature Sessions: Rafael X Saint Peter (Zuid-Amerika, Afrika & Oceanië): checked in merge: ends before 2026-11-05 (passed by delivery)
- The 50 Best Restaurants 2026 awards ceremony (Zuid-Amerika, Afrika & Oceanië): checked in merge: ends before 2026-11-05 (passed by delivery)
- Signature Sessions: Clon X Naar / Shizen X Nuema / Rocco X Locale Firenze (1 Nov 2026); Cosme X Cocina Hermanos Torres (2 Nov 2026) (Zuid-Amerika, Afrika & Oceanië): past (1-2 Nov 2026, before 2026-11-03). Note Shizen X Nuema involves catalogue venue Nuema rest_1374.
- F.A.W.C! Hawke's Bay Food and Wine Classic (Zuid-Amerika, Afrika & Oceanië): on hiatus 2025-2026; 2027 dates not announced
- Davivienda Restaurant Tour 2026 - Cali dinner (5 Nov 2026) (Zuid-Amerika, Afrika & Oceanië): only secondary press gives 'Cali 5 Nov'; host restaurant and guest chef not identified; Atrapalo ticket page would not render. Other tour dinners (Sep-Oct 2026) are past. Revisit via Alimentarte/Fundación Corazón Verde channels.
- Heritage Culinary Calendar 2026: Chef Cris Oberhammer & Anna Oberhammer (Zuid-Amerika, Afrika & Oceanië): checked in merge: ends before 2026-11-05 (passed by delivery)
- Festival Ñam Santiago 2027 (Zuid-Amerika, Afrika & Oceanië): no 2027 dates announced (2026 edition was April, past); also a broad public food fair
- Chefs Week Rio 2026 (Copacabana Palace banquets 28-29 Jul 2026) (Zuid-Amerika, Afrika & Oceanië): past
- Eat Out Woolworths Restaurant Awards (Zuid-Amerika, Afrika & Oceanië): 2026 ceremony was 23 Mar 2026 (past); 2027 date not published
- Heritage Resorts Sustainable Gastronomy Week (5-11 Oct 2026) and Jakob Mielcke residency (13/15 Oct 2026) (Zuid-Amerika, Afrika & Oceanië): past

**geen (exacte) datum gepubliceerd (35)**

- Gourmet Abu Dhabi 2027 (Azië & Midden-Oosten): No 2027 edition found; brand appears folded into Abu Dhabi Culinary Season; no dates.
- Dubai Food Festival 2027 (Azië & Midden-Oosten): No official 2027 dates found; also largely mass-market.
- World Gourmet Summit 2027 (Singapore) (Azië & Midden-Oosten): No 2027 dates; last listing (2024) marked on hold.
- Mauro Colagreco at One&Only Royal Mirage Dubai (3-5 Dec) (Azië & Midden-Oosten): Page undated, no year; cannot confirm 2026.
- TakaHisa x Jara (Martín Berasategui) at The Lana, Dubai (Azië & Midden-Oosten): Official page 403 to fetch; no date found in snippets.
- Galaxy Macau Asami x Yamazato four hands / Chinese-Portuguese Master Chefs series (Azië & Midden-Oosten): Galaxy site returns 403; no dates obtained.
- Lobster Bar & Grill Sunday Roast Guest Chef Series (Island Shangri-La HK) (Azië & Midden-Oosten): Recurring weekly format; Nov/Dec 2026 guests not announced.
- Asia's 50 Best Restaurants 2027 / MENA's 50 Best Restaurants 2027 (Azië & Midden-Oosten): No 2027 date or host city published as of 4 Nov 2026; experiences page lists only Lima sessions.
- Abu Dhabi Culinary Season / Exceptional Chef Series 2026-27 (Azië & Midden-Oosten): Official pages JS-rendered with no dated listings; no 2026/27 dates verifiable.
- Okura Ciel Bleu 24H Chefs (Benelux): 'this June' with no exact dates/year (charity, worth re-checking for 2027 dates)
- Taste of Amsterdam 2027 (Benelux): no 2027 edition found; reported discontinued after 2022
- Merlet 'The Art of Dining' (Benelux): bookable group arrangement, no date
- Botanic Sanctuary Antwerp Gourmet Festival 2027 (Benelux): no 2027 dates published; site returns 403 to fetch
- Chefs Revolution (De Librije, Zwolle) 2027 (Benelux): no 2027 date found; official site offline
- La Paix by David Martin at Corinthia Brussels (reopening) (Benelux): 'opening soon', no date
- Château St. Gerlach / Château Neercanne events calendar (Benelux): calendar loads via JS, no dates retrievable; only Christmas/NYE arrangements
- Chefs Revolution 2027 (Benelux): re-checked: latest found edition 2021; no 2027 date
- Ciel Bleu Refined Nights 2027 (Krug x De Treeswijkhoeve April Thursday; caviar 19 June; winter truffle) (Benelux): themes listed without year/exact day on Okura page; iamsterdam listing has no dates - recheck in early 2027
- KITZ Kulinarik 2027 (Noord-/Centraal-Europa): no 2027 date published; town street-food style festival
- The Epicure 2027 (The Dolder Grand) (Noord-/Centraal-Europa): paused in 2026, returns 2027 but no dates published
- Prague Food Festival 2027 (Noord-/Centraal-Europa): site shows no 2027 dates
- Zilte residency at The Pagoda, Tivoli (autumn 2026) (Noord-/Centraal-Europa): No dates on official page; multi-week residency.
- Care's - The Ethical Chef Days 2027 (Zuid-Europa): No 2027 dates published on organiser/tourism pages.
- Soirée Laurent-Perrier Grand Siècle à 4 mains (MySwitzerland listing) (Noord-/Centraal-Europa): Listing page is JS-only and no date/venue could be confirmed from any source.
- Gran Cena "L'Oro della Terra" with Castiglion del Bosco (Campo del Drago, rest_0390) – San Giovanni d'Asso (Zuid-Europa): Sold out and no date printed on organiser page (7 Nov 2026 only inferable from image filename).
- Identità Golose Milano 2027 congress (Zuid-Europa): No 2027 dates published yet.
- Food & Wine Classic in Aspen 2027 (Noord-Amerika): No official 2027 date; only an aggregator (carnifest) lists June 18-20, 2027. foodandwine.com refuses fetch.
- Montréal en Lumière 2027 (Noord-Amerika): Dates Feb 18-28, 2027 confirmed but homepage shows no 2027 gastronomy/guest-chef programme yet; general arts & light festival. Recheck for 'Les Grandes Tables' programme.
- Auction Napa Valley 2027 (Noord-Amerika): Only a Sotheby's lot listing mentions June 3-5, 2027; organiser site shows no 2027 date.
- Oregon Truffle Festival 2027 (Noord-Amerika): No 2027 dates published yet.
- Melbourne Food & Wine Festival 2027 (Zuid-Amerika, Afrika & Oceanië): official site only says March 2027, no exact dates; secondary sources disagree (19-28 vs 20-29 Mar). Revisit when program launches.
- Margaret River Gourmet Escape 2026 (Zuid-Amerika, Afrika & Oceanië): official site unreachable (DNS failure); only aggregator dates (13-15 Nov 2026) and an aggregator saying 2026 not announced - conflicting, unverified
- Mistura 2026/2027 (Zuid-Amerika, Afrika & Oceanië): no official dates; APEGA only discussing versions abroad (Jul 2026); mass-market fair anyway
- Central Otago Pinot Noir Celebration 2027 (Zuid-Amerika, Afrika & Oceanië): official site 503; no 2027 dates found
- Constantia Fresh 2027 (Zuid-Amerika, Afrika & Oceanië): no 2027 dates published

**overig (29)**

- 1887 by André x visiting chef (TBC) - Marina Bay collaboration (Azië & Midden-Oosten): March 2027, guest chef 'to be confirmed' - too vague; recheck later.
- Sudachi x La BOMBANCE Kouri Island collaboration dinner (Azië & Midden-Oosten): 7-8 Nov 2026 but exclusively for hotel guests on a specific stay plan - not publicly bookable.
- JAL Michelin private dinner campaign at CYCLE by Mauro Colagreco (28 Nov 2026) (Azië & Midden-Oosten): Invitation/miles lottery for JAL elite cardholders; not a public event and not a collaboration.
- Asia's 50 Best Restaurants 2027 / 50 Best Signature Sessions (Azië & Midden-Oosten): 2027 date and host city not yet announced; experiences page lists nothing upcoming.
- Mushroom Season at Roganic Hong Kong (Simon Rogan x Oli Marlow x Ash Salmon, 12-13 Nov) (Azië & Midden-Oosten): No year on page; HK$980 price and Oli Marlow involvement indicate an old (c.2019) edition - not current.
- Il Ristorante - Luca Fantin x Kyoto Kitcho four-hands dinner (15-16 Nov) (Azië & Midden-Oosten): Page 403; snippets give 15-16 Nov but no year; Ginza Tower address and JPY44,000 price point to a pre-2023 edition. Not confirmed for 2026.
- Hotel des Indes guest-chef dinners (Benelux): no guest-chef event found in searches; no own events page located
- Rosewood Amsterdam guest-chef dinners (Benelux): no guest-chef event announced; only afternoon tea / menu news
- Villa D Este x Van Spaandonk wijndiner (Oudenbosch, 6 Nov 2026) (Benelux): wine-merchant dinner at unstarred venue, not in catalogue; low-end fit
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
- Burns Night Dinner, Claridge's L'Epicerie (Noord-/Centraal-Europa): Themed annual holiday dinner, no named guest chef/producer; year not stated.
- Vila Joya International Gourmet Festival / Tribute to Claudia 2026 (Zuid-Europa): No 2026/2027 edition on official site; hotel in hibernation until re-opening 21 March (year not stated).
- Roda dles Saus Genusswoche, Alta Badia (14-21 Mar 2027) (Zuid-Europa): Week-long traditional Ladin dishes promotion in ski huts; not a one-off high-end event.
- Hotel Eden Rome Taste Society guest-chef Sunday lunches (Zuid-Europa): 2026 series ended 4 Oct 2026; no later dates.
- Yeatman 'Taste & Toast Fest' (6 Nov 2026) (Zuid-Europa): Content unclear (no producer/chef named); looks like a general party — not verified as high-end gastronomy.
- Alba International White Truffle Fair 2026 (10 Oct - 6 Dec) (Zuid-Europa): Weeks-long fair/market, not a one-off; official site did not render; the World Auction (8 Nov) recorded separately.
- 50 Best Talks Lima (Zuid-Amerika, Afrika & Oceanië): 3 Nov 2026 talks, today/in progress and not a dining event
- Marlborough Wine & Food Festival 2027 (Zuid-Amerika, Afrika & Oceanië): planned 13 Feb 2027 but put on hold (announced 20 Aug 2026); no event
- Noosa Food & Wine Festival 2027 (Zuid-Amerika, Afrika & Oceanië): no announced 2027 dates
- Taste of Sydney 2027 (Zuid-Amerika, Afrika & Oceanië): no evidence of 2027 edition or dates

**terugkerend of standaardaanbod (15)**

- Aman Tokyo Festive Itinerary 2026 (Arva, Musashi etc.) (Azië & Midden-Oosten): Standard Christmas/NYE menus by resident chefs; no guest chef.
- Wildmiddag/Wildavond 8 & 29 Nov, 11 Dec 2026 (Olde Marckt) (Benelux): fully booked ('vol!'); recurring game-season format
- La Butte aux Bois culinaire agenda (Sundays @ La Source, Perla & Sapori 15 Nov, EXPLORE 13 Dec, Bubbles & Cakes, Next Generation Dinner) (Benelux): lifestyle/brunch/recurring formats, no guest chef or winemaker; not one-off high-end
- Klosse Wines Najaarsproeverij (De Echoput, 22 Nov 2026) and Echoput Christmas menus (Benelux): mass wine fair (€24) and standard Christmas menus; nothing at Wild Atelier
- Le Roannay festive season 2026 (Benelux): standard festive menus, no single dated one-off
- Latour Christmas/NYE 2026; Sunday Vibes & Cellar Dinners (Benelux): standard Christmas/NYE menus; recurring formats without published dates/guests
- Christmas at Cuchara (25-26 Dec 2026) (Benelux): standard Christmas service, albeit first in 18 years
- Brussels gastronomic Tram Experience 2026-27 (Benelux): season-long recurring format, not a one-off
- Kasteel van Ordingen / Aurum NYE package (Benelux): standard New Year package
- Taste of London: The Festive Edition 2026 (Noord-/Centraal-Europa): no 2026 festive edition dates found; large consumer festival, low fit
- taku Christmas / NYE / Valentine's / Taste Journey / Villa Bodinus pop-up (Noord-/Centraal-Europa): standard holiday menus or multi-week formats
- Monte-Carlo SBM agenda: L'Abysse Matataki menu / Pavyllon brunch (Zuid-Europa): Standing menus/brunches running for months.
- Blackberry Farm holiday/music/wellness events (Thanksgiving, Christmas, NYE, Jason Isbell, etc.) (Noord-Amerika): Standard holiday packages or non-gastronomy events.
- The Inn at Little Washington – upcoming events (Noord-Amerika): Only Thanksgiving (26 Nov 2026) and New Year's (31 Dec 2026) listed — standard holiday menus.
- Heritage Resorts festive menus by Laurent & Julie Lemal (24, 25, 27 Dec 2026) (Zuid-Amerika, Afrika & Oceanië): standard Christmas festive menus

**niet high-end (12)**

- Thanying x Snowcology 'A Gust of Snow' four-hands dinner (Amara Singapore) (Azië & Midden-Oosten): Secondary source only (27-28 Nov 2026, S$168++); mid-market, not high-end enough to justify a C-level row.
- Taste of Abu Dhabi 2026 (Azië & Midden-Oosten): 13-15 Nov 2026 per press; mass-market food & music festival, not high-end. Official page not checked.
- Karuizawa Marriott Makers Dinner / ANA Crowne Plaza Niigata x Fermier (21 and 29 Nov 2026) (Azië & Midden-Oosten): Not high-end (upper-midscale hotel winery dinners).
- Launch Gault&Millau Belux Guide Edition 2027 (9 Nov 2026) (Benelux): industry guide launch ceremony, not a consumer gastronomy event
- KACHEN TABLE #2 at Public House (LU, 6 Nov 2026) (Benelux): not high-end (€25 lunch)
- Winemakers dinners Winkel van Sinkel Utrecht / Bisque Groningen / Vinologen (Nov 2026) (Benelux): not high-end (~EUR 97) / unstarred, not catalogue venues
- Gault&Millau NL guide launch 2027 (1 Feb 2027, RAI) / Horecava 2027 (Benelux): industry/trade events, not consumer gastronomy events
- Sthlm Food & Wine 2026/2027 (Noord-/Centraal-Europa): consumer trade fair (mass-market); 2027 dates TBD
- Plaza Culinaria 2026 Freiburg (Noord-/Centraal-Europa): consumer fair, not high-end
- Taste of London 2027 (Noord-/Centraal-Europa): 2027 dates not yet announced (site: 'sign up to hear about our grand 2027 plans'); large consumer festival
- Sauvignon Blanc New Zealand 2027 (Marlborough, 2-4 Feb 2027) (Zuid-Amerika, Afrika & Oceanië): trade conference, not a consumer gastronomy event; secondary source only
- Barossa Vintage Festival 2027 (21-25 Apr 2027) (Zuid-Amerika, Afrika & Oceanië): dates verified on official site, but community festival (parade, scarecrows, grapestomp) - not high-end

**tegenstrijdige of onbetrouwbare bron (5)**

- Chef Tristan Brandt at Sirru Fen Fushi (Sirru Icons Series) (Azië & Midden-Oosten): HELD BACK - contradiction: resort page says '29 December 2026 and 2 January 2027'; Lets Go Maldives (11 Jun 2026) says four-hands dinner 26 December 2026. Resort page gives no event detail per date. Recheck with resort.
- æra x Mystic Island Winery wine pairing dinner (19 Nov 2026) (Azië & Midden-Oosten): Secondary only; unranked Asian-Nordic restaurant, no winemaker named, no price - not clearly high-end.
- Spectrum (Waldorf Astoria Amsterdam) guest dinners (Benelux): restaurant closed May 2026 per secondary sources
- F.A.Z. Lieblinge of the Year (Schloss Bensberg) (Noord-/Centraal-Europa): held back: page contradicts itself (banner 23 Jan 2027 vs details 24 Jan 2026 / title 2026); chefs unnamed
- Traful Invita 2026 (Villa Traful, Argentina) (Zuid-Amerika, Afrika & Oceanië): Sept/Oct 2026 article; not verified as upcoming, secondary only, regional event

## Dekking per regio: wat wel, deels en niet is doorzocht

(volgt)
