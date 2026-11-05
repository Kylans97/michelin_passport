# WERELDWIJDE EVENTS — BATCH 1 PRODUCTION APPLY

Verslag van de toevoeging aan productie op 2026-11-04, na expliciet akkoord van de product owner. Plan en bronnen: `WORLD_EVENT_BATCH_1_PRE_APPLY.md`, exacte rijen: `supabase/data/enrichment/events/world_event_batch_1_approved.json`.

## 1. Wat is goedgekeurd

- De 64 events uit het pre-apply-rapport (51 zonder open punt, 13 met een koppelingsbesluit).
- Daarbij wev-021, wev-024 (Domaine Kuheiji, Okura Amsterdam) en wev-030 (Cuchara × Alma Carraovejas), op verzoek. Hun pagina's zijn vlak voor het schrijven opnieuw gelezen: datum en prijs kloppen, geen tijd genoemd, geen jaartal op de pagina (2026 volgens de eerdere controle).
- **Niet mee:** de zeven hotelgasten-events (Blackberry Farm, Kandolhu), de overige zeven P0-rijen buiten batch 1, en de tien afgevallen rijen uit §4 van het rapport.
- **Koppelingen goedgekeurd:** Kol, Eden Kitchen & Bar, Troisgros (restaurant), St. JOHN, Van Oys (wev-117, wev-120), es:senz (restaurant), L.A. Jordan (restaurant).
- **Koppelingen niet gelegd:** Maido, Evvai, Burg Hotel en Hotel Gasthof Post (volgens de product owner een ander hotel dan Post Lech Arlberg; `venue_name` blijft tekst, zonder coördinaten). La Paulée gaat in `external_host_name`.
- **Eindtijden overgenomen van de eigen pagina:** wev-034, wev-037, wev-038, wev-039 (22:00), wev-036, wev-041 (22:30).

## 2. Vlak voor het schrijven

Opnieuw gelezen: aantallen, alle catalogus-UUID's op code, geen goedgekeurd event al aanwezig, geen event met dezelfde `official_url`, niets al voorbij, 0 volgers bij de hosts. Daarna een proefrun in een transactie met `set constraints all immediate` en `rollback`: 97 events binnen de transactie, 30 erna. Niets week af van het plan.

## 3. Verschillen in aantallen

| Tabel | Voor | Na | Verschil |
|---|---:|---:|---:|
| events | 30 | 97 | +67 |
| event_restaurants | 36 | 108 | +72 |
| event_hotels | 4 | 12 | +8 |
| event_tag_assignments | 36 | 158 | +122 |
| event_chefs | 0 | 0 | +0 |
| event_attendance | 4 | 4 | +0 |
| event_confirmed_attendance | 0 | 0 | +0 |
| notifications (followed_venue_event) | 0 | 0 | +0 |
| restaurants | 3629 | 3629 | +0 |
| hotels | 2127 | 2127 | +0 |

De 30 bestaande events zijn niet aangeraakt. Er is geen catalogusrij, `event_chefs`-, attendance-, trip-, visit- of fotorij gemaakt, en geen migratie. Er zijn geen pushmeldingen verstuurd.

## 4. Controle na het schrijven

Alle 67 rijen zijn veld voor veld teruggelezen en vergeleken met de goedgekeurde rijen, inclusief tags en koppelingen: **0 afwijkingen**. Events met alleen een datum hebben lege `start_time`, `end_time`, `start_at` en `end_at`; er is geen tijd verzonnen. Gepubliceerde events die nog moeten komen of bezig zijn: 70.

wev-117 eindigt om 00:00: `end_at` valt daarom op de volgende dag, `end_date` blijft de avond zelf.

**Niet getest:** de weergave in de app. Alle events staan er zonder foto.

## 5. De ingevoegde events

| Rij | Event | Datum | Tijd | Land | Beschikbaar | Koppelingen of externe host |
|---|---|---|---|---|---|---|
| wev-003 | Signature Sessions: Sapiens X Kol | 2026-11-05 | – | PE | available | rest_0329 (participant); extern: The 50 Best Restaurants (The 50) |
| wev-004 | Cos d'Estournel Four-Hands Dinner: Jérôme Banctel x Marco Ortolani | 2026-11-06 | – | CH | unknown | hotel_87 (venue), rest_0060 (participant), rest_3526 (host+venue) |
| wev-005 | Merano WineFestival 2026 (35th edition) | 2026-11-06 – 2026-11-10 | – | IT | unknown | extern: Gourmet's International (Helmuth Köcher) |
| wev-006 | 2026 JBF Gala for Good™ | 2026-11-06 | 18:00 | US | sold_out | rest_3043 (participant), rest_0746 (participant); extern: James Beard Foundation |
| wev-007 | Four-Hands Dinner / Six courses - two culinary signatures | 2026-11-07 | 18:30 | DE | unknown | rest_2084 (host+venue), hotel_162 (venue), rest_1936 (participant) |
| wev-117 | Gary Gielen & Friends Dinner Show | 2026-11-07 – 2026-11-08 | 19:00–00:00 | NL | unknown | hotel_05 (host+venue) |
| wev-009 | 2026 World Alba White Truffle Charity Auction | 2026-11-08 | 18:00 | MO | unknown | extern: Don Alfonso 1890 (Grand Lisboa Palace) |
| wev-010 | XXVII World Alba White Truffle Auction dinner at Riva del Fiume Ristorante | 2026-11-08 | 18:30 | TH | unknown | extern: Riva del Fiume Ristorante, Four Seasons Hotel Bangkok at Chao Phraya River |
| wev-011 | Saint Barth Gourmet Festival 2026 (13e édition) | 2026-11-09 – 2026-11-15 | – | BL | unknown | extern: Comité Territorial du Tourisme de Saint-Barthélemy |
| wev-012 | KRUG 4-Hands-Dinner | 2026-11-10 | – | CH | unknown | rest_0263 (host+venue), hotel_2502 (venue), rest_0282 (participant) |
| wev-013 | Winzer Dinner mit Weingut Lackner Tinnacher | 2026-11-13 | 19:00 | DE | unknown | rest_2084 (host+venue) |
| wev-014 | Jantar Magno Mesa SP 2026 – Grand Hyatt São Paulo | 2026-11-13 | 20:00 | BR | unknown | extern: Mesa São Paulo (Prazeres da Mesa) |
| wev-050 | Mezzaluna at lebua (Two Michelin Stars) featuring L'Osier Tokyo (Three Michelin Stars) – Collaboration Dinner 2026 | 2026-11-13 – 2026-11-14 | 18:00–21:30 | TH | unknown | rest_0505 (participant); extern: Mezzaluna (lebua at State Tower) |
| wev-016 | Dîner de Gala de Charité 2026 au profit de la Banque Alimentaire Luxembourg | 2026-11-16 | 19:00–23:45 | LU | sold_out | rest_1409 (participant); extern: Lions Club Luxembourg International |
| wev-017 | Château d'Yquem Wine Dinner with Chef Anne-Sophie Pic | 2026-11-18 | – | TH | unknown | extern: Anne-Sophie Pic at Le Normandie, Mandarin Oriental Bangkok |
| wev-018 | 18. November: Gravner x Hiša Franko | 2026-11-18 | – | SI | unknown | rest_0424 (host+venue) |
| wev-120 | Italian Evening x MosaeVino & Francine Recca | 2026-11-18 | 18:30–23:00 | NL | unknown | hotel_05 (host+venue) |
| wev-020 | Pair'd Margaret River Region 2026 | 2026-11-19 – 2026-11-22 | – | AU | available | extern: Pair'd Margaret River Region |
| wev-021 | An extraordinary evening with Domaine Kuheiji (Kuheiji Dinner) | 2026-11-20 | – | NL | unknown | rest_0119 (host+venue) |
| wev-022 | Château Palmer 4-Hands Dinner | 2026-11-20 | 19:00–23:00 | GB | unknown | rest_2630 (host+venue) |
| wev-023 | Wayfinder x St JOHN, presented by Lexus | 2026-11-20 | 18:00–22:00 | AU | sold_out | rest_2590 (participant); extern: Wayfinder Winery & Farm |
| wev-052 | Galaxy Stars of Gastronomy 2026 | 2026-11-20 – 2026-11-21 | – | MO | unknown | rest_0125 (participant), rest_0463 (participant), rest_0319 (participant), rest_0441 (participant), rest_2862 (participant), rest_0439 (participant); extern: Galaxy Macau (Cabana, 2/F) |
| wev-024 | An extraordinary evening with Domaine Kuheiji (Kuheiji Dinner) | 2026-11-21 | – | NL | unknown | rest_0119 (host+venue) |
| wev-025 | Falstaff Wine Trophy | 2026-11-21 | 18:30 | DE | available | hotel_175 (host+venue), rest_2114 (participant), rest_2117 (participant), rest_2089 (participant), rest_2044 (participant), rest_0189 (participant); extern: Falstaff |
| wev-027 | Vasse Felix x Bonheur, presented by Lexus | 2026-11-21 | 18:00–22:30 | AU | sold_out | extern: Vasse Felix |
| wev-122 | Club Leroy x Latour | 2026-11-22 | 13:00 | NL | unknown | rest_0785 (host+venue) |
| wev-029 | Truffelavond met Licata | 2026-11-25 | 19:00 | BE | unknown | rest_0872 (host+venue) |
| wev-030 | Cuchara × Alma Carraovejas | 2026-11-25 | – | BE | unknown | rest_0166 (host+venue) |
| wev-032 | Weinberg Arlberg 2026 | 2026-12-03 – 2026-12-13 | – | AT | unknown | extern: Weinberg Arlberg |
| wev-034 | Wine Dinner Château Pichon Comtesse | 2026-12-06 | 19:00–22:00 | AT | available | extern: Weinberg Arlberg |
| wev-036 | Domaine Raveneau & Salomon Alttus | 2026-12-07 | 18:30–22:30 | AT | available | hotel_135 (venue); extern: Weinberg Arlberg |
| wev-037 | Domaine de Chevalier Vertical | 2026-12-08 | 19:00–22:00 | AT | available | extern: Weinberg Arlberg |
| wev-038 | GAJA: ICONS & VINTAGES | 2026-12-09 | 19:00–22:00 | AT | available | rest_3648 (venue); extern: Weinberg Arlberg |
| wev-039 | Egon Müller Vertical | 2026-12-10 | 19:00–22:00 | AT | available | extern: Weinberg Arlberg |
| wev-040 | Two Wine Cultures. Four Centuries. One Evening. Trimbach meets Château Figeac | 2026-12-10 | 19:00 | AT | available | extern: Weinberg Arlberg |
| wev-095 | YVESKE'S Kitchen at MASTERS EXPO - Dinner 10 Dec | 2026-12-10 | – | NL | sold_out | rest_0001 (participant), rest_0035 (participant), rest_0048 (participant); extern: MASTERS EXPO (RAI Amsterdam) |
| wev-124 | MASTERS EXPO 2026 | 2026-12-10 – 2026-12-14 | – | NL | unknown | extern: MASTERS EXPO (RAI Amsterdam) |
| wev-041 | Visionaries & Icons of Burgundy | 2026-12-11 | 18:30–22:30 | AT | available | hotel_135 (venue); extern: Weinberg Arlberg |
| wev-099 | YVESKE'S Kitchen at MASTERS EXPO - Lunch 11 Dec | 2026-12-11 | – | NL | sold_out | rest_0038 (participant), rest_0041 (participant), rest_0047 (participant); extern: MASTERS EXPO (RAI Amsterdam) |
| wev-100 | YVESKE'S Kitchen at MASTERS EXPO - Dinner 11 Dec | 2026-12-11 | – | NL | sold_out | rest_0085 (participant), rest_0013 (participant), rest_0079 (participant), rest_0103 (participant), rest_0090 (participant); extern: MASTERS EXPO (RAI Amsterdam) |
| wev-042 | An Evening with Château Cheval Blanc | 2026-12-12 | 18:30–23:00 | MO | unknown | rest_0434 (host+venue) |
| wev-043 | YVESKE'S Kitchen at MASTERS EXPO - Dinner 12 Dec | 2026-12-12 | – | NL | available | rest_0025 (participant), rest_0069 (participant), rest_0030 (participant), rest_0016 (participant); extern: MASTERS EXPO (RAI Amsterdam) |
| wev-101 | YVESKE'S Kitchen at MASTERS EXPO - Lunch 12 Dec | 2026-12-12 | – | NL | sold_out | rest_1400 (participant), rest_0120 (participant), rest_0104 (participant); extern: MASTERS EXPO (RAI Amsterdam) |
| wev-044 | YVESKE'S Kitchen at MASTERS EXPO - Lunch 13 Dec | 2026-12-13 | – | NL | available | rest_0037 (participant), rest_0017 (participant), rest_0027 (participant), rest_0146 (participant), rest_0114 (participant); extern: MASTERS EXPO (RAI Amsterdam) |
| wev-045 | Gourmet Skisafari Alta Badia | 2026-12-13 | 11:00–15:00 | IT | unknown | rest_0315 (participant), rest_2296 (participant), rest_2202 (participant); extern: Alta Badia Tourism |
| wev-104 | YVESKE'S Kitchen at MASTERS EXPO - Lunch 14 Dec | 2026-12-14 | – | NL | sold_out | rest_0111 (participant), rest_0051 (participant); extern: MASTERS EXPO (RAI Amsterdam) |
| wev-185 | Wildmiddag (5-gangen wildmenu) | 2027-01-10 | – | NL | unknown | rest_0150 (host+venue) |
| wev-129 | Napa Truffle Festival 2027 | 2027-01-15 – 2027-01-18 | – | US | available | extern: Napa Truffle Festival |
| wev-130 | Four-Hands Dinner: 2** trifft Region | 2027-01-16 | 18:30 | DE | unknown | rest_0188 (host+venue) |
| wev-186 | Wildmiddag (5-gangen wildmenu) | 2027-01-17 | – | NL | unknown | rest_0150 (host+venue) |
| wev-131 | Leidenschaft, Disziplin und Teamgeist | 2027-01-23 – 2027-01-24 | 18:30 | DE | available | rest_0201 (participant); extern: Schleswig-Holstein Gourmet Festival e.V. |
| wev-134 | Madrid Fusión Alimentos de España 2027 (25th edition) | 2027-02-01 – 2027-02-03 | – | ES | unknown | extern: Madrid Fusión (Vocento Gastronomía) |
| wev-136 | 30. Rheingau Gourmet & Wein Festival | 2027-02-18 – 2027-03-07 | – | DE | unknown | extern: Kronenschlösschen |
| wev-137 | 3-Sternekoch Martin Öfner, Taiwan (***) & Monteverro & Brunello di Montalcino & Champagne Louis Roederer | 2027-02-19 | 19:30 | DE | available | extern: Kronenschlösschen |
| wev-138 | Jüngster 2-Sterne-Koch feiert Festival-Premiere | 2027-02-20 – 2027-02-21 | 18:00 | DE | available | rest_0204 (participant); extern: Schleswig-Holstein Gourmet Festival e.V. |
| wev-139 | 3-Sternekoch Edip Sigl*** & Laurent-Perrier / Tempos Vega Sicilia / Oremus / Joh. Jos. Prüm / Schlossgut Diel / Robert Weil / Wittmann / Rochelt | 2027-02-21 | 19:30 | DE | available | rest_0179 (participant); extern: Kronenschlösschen |
| wev-140 | 2-Sternekoch Jan-Philipp Berner** (SÖL´RING HOF, Sylt) & Champagne Ayala | 2027-02-22 | 19:30 | DE | available | rest_0227 (participant); extern: Kronenschlösschen |
| wev-141 | eat! berlin 2027 | 2027-02-25 – 2027-03-07 | – | DE | unknown | extern: eat! berlin |
| wev-142 | Alex Dilling** (Hotel Café Royal, London) | 2027-02-26 | 19:30 | DE | available | rest_2454 (participant); extern: Kronenschlösschen |
| wev-144 | Einer der weltbesten 3-Sterneköche: Christian Bau*** & Château Lascombes | 2027-03-02 | 19:30 | DE | available | rest_0184 (participant); extern: Kronenschlösschen |
| wev-145 | Food & Fun Festival 2027 | 2027-03-03 – 2027-03-07 | – | IS | unknown | extern: Food & Fun Festival |
| wev-146 | La Paulée de New York 2027 | 2027-03-03 – 2027-03-06 | – | US | unknown | extern: La Paulée (Daniel Johnnes) |
| wev-147 | 3-Sternekoch Daniel Schimkowitsch*** & „Die besten deutschen Sekte“ | 2027-03-05 | 19:30 | DE | available | rest_0194 (participant); extern: Kronenschlösschen |
| wev-149 | La Paulée Mexico City 2027 | 2027-03-11 – 2027-03-13 | – | MX | unknown | extern: La Paulée (Daniel Johnnes) |
| wev-150 | wachau GOURMETfestival 2027 | 2027-04-01 – 2027-04-18 | – | AT | unknown | extern: wachau GOURMETfestival (Vinaria / LWmedia) |
| wev-152 | Dorfer & Friends | 2027-04-12 | 18:00 | AT | unknown | rest_0272 (host+venue); extern: wachau GOURMETfestival |
| wev-153 | Tasting Australia presented by Journey Beyond 2027 | 2027-04-30 – 2027-05-09 | – | AU | unknown | extern: Tasting Australia (festival hub, Adelaide and regional South Australia) |

## 5a. Aanvulling: landen en Cayman Cookout (2026-11-04)

Na expliciet akkoord van de product owner, op de instructie "Aanvulling 5 november 2026":

- **Migratie `20261101310000_add_bh_ky_mu_countries.sql` toegepast**, vanaf de lokale apply-branch `claude/apply-bh-ky-mu` (`origin/main` plus alleen `origin/claude/overnight-world-events`). Ze was de enige openstaande. BH, KY en MU staan nu in `countries`. **Ledger: 145, lokaal en remote gelijk op die branch.**
- **wev-128 Cayman Cookout 2027 toegevoegd** in één transactie, zoals in het pre-apply-rapport: 14–17 januari 2027, alleen datum, `external_host_name` The Ritz-Carlton, Grand Cayman, vier participants (rest_0059, rest_0743, rest_3043, rest_3052), tag guest_chef. Teruggelezen: geen afwijkingen.
- **Aantallen:** events 97 → 98, `event_restaurants` 108 → 112, `event_tag_assignments` 158 → 159, `notifications` (followed_venue_event) 0 → 0.
- **Niet toegepast:** `20261101320000`; die gaat mee met de app-build. wev-154 (MU) blijft buiten: de pagina gaf 403.

## 6. Om later op te pakken

- `20261101310000` is toegepast maar staat nog niet op main. Tot ze daar staat, toont `supabase migration list --linked` op main één remote-rij zonder lokaal bestand.
- `sold_out` wordt nog niet als label getoond in de app.
- Batch 2 en de `decide`-rijen staan nog in het overzicht.
