# WERELDWIJDE EVENTS — BATCH 1 PRE-APPLY

Fase 1 van `supabase/data/enrichment/events/WORLD_EVENT_APPLY_INSTRUCTIONS.md`. Gelezen op 2026-11-04. **Er is niets naar productie geschreven.** Fase 2 begint alleen na expliciet akkoord van de product owner, voor precies de goedgekeurde lijst.

De exacte rijen staan ook machineleesbaar in `supabase/data/enrichment/events/world_event_batch_1_pre_apply.json`.

## 1. Kort

- **Kandidaten** met `apply_decision = batch 1`: 81.
- **Klaar om te schrijven:** 51 events zonder open punt.
- **Klaar, op een koppeling na:** 13 events. Het event zelf kan mee; de koppeling is aan jou (§5, besluit 1).
- **Wachten op jouw besluit over hotelgasten:** 7 events (besluit 2). Zonder besluit gaan ze niet mee.
- **Vallen af:** 10 events (§4).
- **Schrijft bij volledig akkoord:** maximaal 71 events, `moderation_status = published`, `status = upcoming`, `image_url = NULL`.

## 2. Wat er live gecontroleerd is

**Schema.** Kolommen, check-constraints en triggers van `events`, `event_restaurants`, `event_hotels`, `event_tags` en `event_tag_assignments` zijn uit productie gelezen. Toegestane waarden:
- `event_type`: festival, dinner, tasting, market, experience, other, lunch, gala, brunch, party
- `admission_type`: free, paid, mixed, unknown
- `availability_status`: available, sold_out, unknown
- `moderation_status`: draft, submitted, published, archived, rejected; `status`: upcoming, cancelled, completed
- tags: wine, winemaker, wild_game, guest_chef, four_hands, charity

**Twee verschillen met de instructie:**
- `events` heeft **geen kolom `time_precision`**. De precisie volgt uit welke tijdvelden leeg zijn. Datum zonder tijd: alle vier de tijdvelden NULL.
- Er is **geen tabel `venue_event_submission`**. Via de app ingediende events staan in `events` met `submitted_by`. Productie heeft er nu 0 van, dus daar kan geen dubbel zitten.

**Productie vandaag:** 30 events (28 published/upcoming, 1 submitted/cancelled, 1 rejected), 36 `event_restaurants`, 4 `event_hotels`, 36 `event_tag_assignments`, 0 `event_confirmed_attendance`, 4 `event_attendance`, 65 landen.

**Dubbelen.** Vergeleken op datum plus land, op naam en op `official_url` met alle 30 events: geen dubbel. Eén rij deelt alleen de datum en het land met een ander event (wev-122, Club Leroy x Latour; het andere is Merlet x Joann).

**Catalogus.** Alle 96 genoemde codes bestaan in productie op code plus land. Bij vier koppelingen is de catalogusnaam veranderd sinds het overzicht is gemaakt; de code klopt: rest_0424 is nu Hiša Franko, rest_0114 Vinkeles, rest_0047 Flore en rest_0188 PUR (Kempinski Berchtesgaden).

**Bronpagina's.** Elke `official_url` is op 2026-11-04 opnieuw opgehaald. Beperkingen:
- De meeste pagina's zijn gelezen via een samenvattende fetch, niet als ruwe tekst. "Geen tijd" betekent dus: niet teruggekomen in die samenvatting. Een paar pagina's die zo niets gaven zijn uit de ruwe HTML of de eigen data van de site gelezen.
- `available` steunt op een boekknop of koopknop, niet op een bewijs van voorraad.
- Twee pagina's gaven 403 (wev-151, wev-154); die vallen af. Er is niet geprobeerd daaromheen te werken.
- De app is niet getest met deze rijen. Alle events komen zonder foto, want er worden geen foto's gedownload.

**Pushmeldingen.** Een gepubliceerd event met een goedgekeurde host stuurt via `fan_out_followed_venue_event` meldingen aan de volgers van die host. De 14 catalogus-hosts in deze batch hebben vandaag samen **0 volgers**, dus er gaat niets uit. Dit lees ik vlak voor het schrijven opnieuw.

## 3. De rijen die geschreven zouden worden

Voor alle rijen: `status = upcoming`, `moderation_status = published`, `image_url = NULL`, `description = NULL`, `address = NULL`. Coördinaten alleen van de eigen catalogusrij van de venue, anders NULL. Tijden in de lokale tijd van `timezone`; `start_at`/`end_at` zijn daaruit berekend, in UTC. `admission_note` is de prijs zoals de pagina die noemt.

### 3.1 Zonder open punt (51)

#### wev-005 · Merano WineFestival 2026 (35th edition)

- `event_type` festival · tags: wine · bron A
- `start_date` 2026-11-06 · `end_date` 2026-11-10 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Rome
- `start_at` NULL · `end_at` NULL
- `venue_name` Kurhaus Merano · `city` Merano · `country_code` IT
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Gourmet's International (Helmuth Köcher)
- `official_url` https://www.meranowinefestival.com/en/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-006 · 2026 JBF Gala for Good™

- `event_type` gala · tags: charity, guest_chef · bron A
- `start_date` 2026-11-06 · `end_date` 2026-11-06 · `start_time`–`end_time` 18:00 – NULL · `timezone` America/New_York
- `start_at` 2026-11-06T23:00:00+00:00 · `end_at` NULL
- `venue_name` The Pierre, A Taj Hotel · `city` New York · `country_code` US
- `latitude`/`longitude` NULL / NULL
- `external_host_name` James Beard Foundation
- `official_url` https://www.jamesbeard.org/events/2026-jbf-gala-for-good
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` Individual ticket $1,500; Crystal $15,000; Silver $25,000; Ruby $40,000 · `availability_status` sold_out
- Koppelingen:
  - `event_restaurants` rest_3043 Daniel (New York, US) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0746 Saison (San Francisco, US) · `is_host` false · `is_venue` false

#### wev-007 · Four-Hands Dinner | Six courses - two culinary signatures

- `event_type` dinner · tags: four_hands, guest_chef, wine · bron A
- `start_date` 2026-11-07 · `end_date` 2026-11-07 · `start_time`–`end_time` 18:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2026-11-07T17:30:00+00:00 · `end_at` NULL
- `venue_name` taku, Excelsior Hotel Ernst · `city` Cologne · `country_code` DE
- `latitude`/`longitude` 50.9417798 / 6.9563194 (van rest_2084)
- `external_host_name` NULL
- `official_url` https://shop.e-guma.ch/excelsiorhotelernst/en/events/four-hands-dinner-sechs-gaenge-zwei-handschriften-2225363
- `ticket_url` https://shop.e-guma.ch/excelsiorhotelernst/en/events/four-hands-dinner-sechs-gaenge-zwei-handschriften-2225363
- `admission_type` paid · `admission_note` 285,00 € Standard Ticket, VAT included · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_2084 taku (Cologne, DE) · `is_host` true · `is_venue` true
  - `event_hotels` hotel_162 Excelsior Hotel Ernst (Cologne, DE) · `is_host` false · `is_venue` true
  - `event_restaurants` rest_1936 Hannappel (Essen, DE) · `is_host` false · `is_venue` false

#### wev-009 · 2026 World Alba White Truffle Charity Auction

- `event_type` gala · tags: charity, guest_chef, wine · bron A
- `start_date` 2026-11-08 · `end_date` 2026-11-08 · `start_time`–`end_time` 18:00 – NULL · `timezone` Asia/Macau
- `start_at` 2026-11-08T10:00:00+00:00 · `end_at` NULL
- `venue_name` Don Alfonso 1890 (Grand Lisboa Palace) · `city` Macau · `country_code` MO
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Don Alfonso 1890 (Grand Lisboa Palace)
- `official_url` https://www.grandlisboapalace.com/en/happenings/2026-world-alba-white-truffle-charity-auction
- `ticket_url` NULL
- `admission_type` paid · `admission_note` MOP5,888+ per person incl. wine pairing · `availability_status` unknown
- Koppelingen: geen

#### wev-010 · XXVII World Alba White Truffle Auction dinner at Riva del Fiume Ristorante

- `event_type` gala · tags: guest_chef, charity, wine · bron A
- `start_date` 2026-11-08 · `end_date` 2026-11-08 · `start_time`–`end_time` 18:30 – NULL · `timezone` Asia/Bangkok
- `start_at` 2026-11-08T11:30:00+00:00 · `end_at` NULL
- `venue_name` Riva del Fiume Ristorante, Four Seasons Hotel Bangkok at Chao Phraya River · `city` Bangkok · `country_code` TH
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Riva del Fiume Ristorante, Four Seasons Hotel Bangkok at Chao Phraya River
- `official_url` https://press.fourseasons.com/bangkok/hotel-news/2026/truffle-auction
- `ticket_url` NULL
- `admission_type` paid · `admission_note` THB 16,000++ per person · `availability_status` unknown
- Koppelingen: geen

#### wev-011 · Saint Barth Gourmet Festival 2026 (13e édition)

- `event_type` festival · tags: guest_chef · bron A
- `start_date` 2026-11-09 · `end_date` 2026-11-15 · `start_time`–`end_time` NULL – NULL · `timezone` America/St_Barthelemy
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Gustavia / Saint-Barthélemy · `country_code` BL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Comité Territorial du Tourisme de Saint-Barthélemy
- `official_url` https://www.saintbarthgourmetfestival.com/
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-012 · KRUG 4-Hands-Dinner

- `event_type` dinner · tags: four_hands, guest_chef, wine · bron A
- `start_date` 2026-11-10 · `end_date` 2026-11-10 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Zurich
- `start_at` NULL · `end_at` NULL
- `venue_name` The Restaurant, The Dolder Grand · `city` Zurich · `country_code` CH
- `latitude`/`longitude` 47.372763 / 8.572771 (van rest_0263)
- `external_host_name` NULL
- `official_url` https://www.thedoldergrand.com/en/special-offer/krug-4-hands-dinner/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` CHF 698.00 per person incl. champagne pairing and beverages · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0263 The Restaurant (Zurich, CH) · `is_host` true · `is_venue` true
  - `event_hotels` hotel_2502 The Dolder Grand (Zurich, CH) · `is_host` false · `is_venue` true
  - `event_restaurants` rest_0282 Konstantin Filippou (Vienna, AT) · `is_host` false · `is_venue` false

#### wev-013 · Winzer Dinner mit Weingut Lackner Tinnacher

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-11-13 · `end_date` 2026-11-13 · `start_time`–`end_time` 19:00 – NULL · `timezone` Europe/Berlin
- `start_at` 2026-11-13T18:00:00+00:00 · `end_at` NULL
- `venue_name` taku, Excelsior Hotel Ernst · `city` Cologne · `country_code` DE
- `latitude`/`longitude` 50.9417798 / 6.9563194 (van rest_2084)
- `external_host_name` NULL
- `official_url` https://taku.de/events/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` 269 EUR incl. menu, aperitif, wine, water, coffee · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_2084 taku (Cologne, DE) · `is_host` true · `is_venue` true

#### wev-050 · Mezzaluna at lebua (Two Michelin Stars) featuring L'Osier Tokyo (Three Michelin Stars) – Collaboration Dinner 2026

- `event_type` dinner · tags: four_hands, guest_chef · bron B
- `start_date` 2026-11-13 · `end_date` 2026-11-14 · `start_time`–`end_time` 18:00 – 21:30 · `timezone` Asia/Bangkok
- `start_at` 2026-11-13T11:00:00+00:00 · `end_at` 2026-11-14T14:30:00+00:00
- `venue_name` Mezzaluna (lebua at State Tower) · `city` Bangkok · `country_code` TH
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Mezzaluna (lebua at State Tower)
- `official_url` https://www.tablecheck.com/lebua-hotels-and-resorts-mezzaluna/reserve/experience/6aa91fe957eacf9020c05cf7
- `ticket_url` https://www.tablecheck.com/lebua-hotels-and-resorts-mezzaluna/reserve/experience/6aa91fe957eacf9020c05cf7
- `admission_type` paid · `admission_note` THB 17,655 net pp; wine pairing THB 11,181.50 net · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0505 L'OSIER (Tokyo, JP) · `is_host` false · `is_venue` false

#### wev-017 · Château d'Yquem Wine Dinner with Chef Anne-Sophie Pic

- `event_type` dinner · tags: wine, winemaker, guest_chef · bron A
- `start_date` 2026-11-18 · `end_date` 2026-11-18 · `start_time`–`end_time` NULL – NULL · `timezone` Asia/Bangkok
- `start_at` NULL · `end_at` NULL
- `venue_name` Anne-Sophie Pic at Le Normandie, Mandarin Oriental Bangkok · `city` Bangkok · `country_code` TH
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Anne-Sophie Pic at Le Normandie, Mandarin Oriental Bangkok
- `official_url` https://cdn-assets-dynamic.frontify.com/4001946/eyJhc3NldF9pZCI6NjM1MTUsInNjb3BlIjoiYXNzZXQ6dmlldyJ9:mandarin-oriental-hotel-group:tVkSC3bDoMQAJ3qLoo6fXnkH0xjpePgnvuJvnTVxvbc
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-018 · 18. November: Gravner x Hiša Franko

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-11-18 · `end_date` 2026-11-18 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Ljubljana
- `start_at` NULL · `end_at` NULL
- `venue_name` Hiša Franko · `city` Kobarid · `country_code` SI
- `latitude`/`longitude` 46.247249 / 13.537761 (van rest_0424)
- `external_host_name` NULL
- `official_url` https://www.hisafranko.com/novice/234/18-november-gravner-x-hisa-franko
- `ticket_url` NULL
- `admission_type` paid · `admission_note` 725 € per person incl. tasting menu and Gravner pairing · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0424 Hiša Franko (Kobarid, SI) · `is_host` true · `is_venue` true

#### wev-020 · Pair'd Margaret River Region 2026

- `event_type` festival · tags: wine, guest_chef · bron A
- `start_date` 2026-11-19 · `end_date` 2026-11-22 · `start_time`–`end_time` NULL – NULL · `timezone` Australia/Perth
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Margaret River · `country_code` AU
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Pair'd Margaret River Region
- `official_url` https://pairdmargaretriver.com/
- `ticket_url` https://pairdmargaretriver.com/program/2026-event-program
- `admission_type` paid · `admission_note` NULL · `availability_status` available
- Koppelingen: geen

#### wev-022 · Château Palmer 4-Hands Dinner

- `event_type` dinner · tags: wine, winemaker, four_hands, guest_chef · bron A
- `start_date` 2026-11-20 · `end_date` 2026-11-20 · `start_time`–`end_time` 19:00 – 23:00 · `timezone` Europe/London
- `start_at` 2026-11-20T19:00:00+00:00 · `end_at` 2026-11-20T23:00:00+00:00
- `venue_name` Waterside Inn · `city` Bray · `country_code` GB
- `latitude`/`longitude` 51.5091092 / -0.6994376 (van rest_2630)
- `external_host_name` NULL
- `official_url` https://www.waterside-inn.co.uk/wine-dinners/chateau-palmer-4-hands-dinner/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` £1,200.00 per person · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_2630 Waterside Inn (Bray, GB) · `is_host` true · `is_venue` true

#### wev-052 · Galaxy Stars of Gastronomy 2026

- `event_type` festival · tags: guest_chef · bron B
- `start_date` 2026-11-20 · `end_date` 2026-11-21 · `start_time`–`end_time` NULL – NULL · `timezone` Asia/Macau
- `start_at` NULL · `end_at` NULL
- `venue_name` Galaxy Macau (Cabana, 2/F) · `city` Macau · `country_code` MO
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Galaxy Macau (Cabana, 2/F)
- `official_url` https://vietnamnews.vn/media-outreach/1799769/november-20-21-galaxy-stars-of-gastronomy-presents-michelin-starred-mastery-12-chefs-24-glittering-stars.html
- `ticket_url` https://www.galaxyticketing.com
- `admission_type` paid · `admission_note` From MOP1,988 pp (min 2); tables MOP3,976 (2 pax) to MOP18,888 (Cabana VIP 8 pax); early bird 20% off until 4 Oct · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0125 Odette (Singapore, SG) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0463 JL Studio (Taichung, TW) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0319 Florilège (Tokyo, JP) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0441 8 1/2 Otto e Mezzo - Bombana (Hong Kong, HK) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_2862 Vea (Hong Kong, HK) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0439 Feng Wei Ju (Macau, MO) · `is_host` false · `is_venue` false

#### wev-025 · Falstaff Wine Trophy

- `event_type` gala · tags: wine, winemaker, guest_chef · bron A
- `start_date` 2026-11-21 · `end_date` 2026-11-21 · `start_time`–`end_time` 18:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2026-11-21T17:30:00+00:00 · `end_at` NULL
- `venue_name` Althoff Grandhotel Schloss Bensberg · `city` Bergisch Gladbach · `country_code` DE
- `latitude`/`longitude` 50.966916 / 7.162146 (van hotel_175)
- `external_host_name` Falstaff
- `official_url` https://www.althoffcollection.com/en/althoff-grandhotel-schloss-bensberg/castle-events/falstaff-wine-trophy
- `ticket_url` NULL
- `admission_type` paid · `admission_note` EUR 335 per person incl. all food and beverages · `availability_status` available
- Koppelingen:
  - `event_hotels` hotel_175 Althoff Grandhotel Schloss Bensberg (Bensberg, DE) · `is_host` true · `is_venue` true
  - `event_restaurants` rest_2114 Yunico (Bonn, DE) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_2117 Zur Post (Odenthal, DE) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_2089 the dune (Frankfurt on the Main, DE) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_2044 Restaurant Überfahrt (Rottach-Egern, DE) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0189 Vendôme (Bergisch Gladbach, DE) · `is_host` false · `is_venue` false

#### wev-027 · Vasse Felix x Bonheur, presented by Lexus

- `event_type` dinner · tags: wine, winemaker, guest_chef, four_hands · bron A
- `start_date` 2026-11-21 · `end_date` 2026-11-21 · `start_time`–`end_time` 18:00 – 22:30 · `timezone` Australia/Perth
- `start_at` 2026-11-21T10:00:00+00:00 · `end_at` 2026-11-21T14:30:00+00:00
- `venue_name` Vasse Felix · `city` Margaret River · `country_code` AU
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Vasse Felix
- `official_url` https://pairdmargaretriver.com/events/vasse-felix-x-bonheur
- `ticket_url` https://pairdmargaretriver.com/events/vasse-felix-x-bonheur
- `admission_type` paid · `admission_note` $398 per person (booking fees included) · `availability_status` sold_out
- Koppelingen: geen

#### wev-122 · Club Leroy x Latour

- `event_type` lunch · tags: geen · bron A
- `start_date` 2026-11-22 · `end_date` 2026-11-22 · `start_time`–`end_time` 13:00 – NULL · `timezone` Europe/Amsterdam
- `start_at` 2026-11-22T12:00:00+00:00 · `end_at` NULL
- `venue_name` Restaurant Latour (Grand Hotel Huis ter Duin) · `city` Noordwijk aan Zee · `country_code` NL
- `latitude`/`longitude` 52.2412489 / 4.4276191 (van rest_0785)
- `external_host_name` NULL
- `official_url` https://restaurantlatour.nl/agenda/club-leroy-x-latour/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` EUR 225 per person, excl. wines · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0785 Latour (Noordwijk aan Zee, NL) · `is_host` true · `is_venue` true

#### wev-029 · Truffelavond met Licata

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-11-25 · `end_date` 2026-11-25 · `start_time`–`end_time` 19:00 – NULL · `timezone` Europe/Brussels
- `start_at` 2026-11-25T18:00:00+00:00 · `end_at` NULL
- `venue_name` Le Roannay · `city` Francorchamps · `country_code` BE
- `latitude`/`longitude` 50.4561478 / 5.9526291 (van rest_0872)
- `external_host_name` NULL
- `official_url` https://roannay.be/nl/nieuws/25-november-truffelavond-met-licata/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` EUR 220 pp all-in with drinks, prepayment · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0872 Le Roannay (Francorchamps, BE) · `is_host` true · `is_venue` true

#### wev-032 · Weinberg Arlberg 2026

- `event_type` festival · tags: wine, winemaker · bron A
- `start_date` 2026-12-03 · `end_date` 2026-12-13 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Vienna
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Lech am Arlberg · `country_code` AT
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Weinberg Arlberg
- `official_url` https://www.weinbergarlberg.at/en
- `ticket_url` https://www.weinbergarlberg.at/en/events
- `admission_type` paid · `admission_note` per event; no festival price · `availability_status` unknown
- Koppelingen: geen

#### wev-036 · Domaine Raveneau & Salomon Alttus

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-12-07 · `end_date` 2026-12-07 · `start_time`–`end_time` 18:30 – NULL · `timezone` Europe/Vienna
- `start_at` 2026-12-07T17:30:00+00:00 · `end_at` NULL
- `venue_name` Burg Vital Resort · `city` Lech am Arlberg · `country_code` AT
- `latitude`/`longitude` 47.217414 / 10.138714 (van hotel_135)
- `external_host_name` Weinberg Arlberg
- `official_url` https://www.weinbergarlberg.at/en/events/domaine-raveneau-and-salomon-alttus
- `ticket_url` https://www.weinbergarlberg.at/en/events
- `admission_type` paid · `admission_note` EUR 820.00 incl. VAT · `availability_status` available
- Koppelingen:
  - `event_hotels` hotel_135 Burg Vital Resort (Lech am Arlberg, AT) · `is_host` false · `is_venue` true

#### wev-038 · GAJA: ICONS & VINTAGES

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-12-09 · `end_date` 2026-12-09 · `start_time`–`end_time` 19:00 – NULL · `timezone` Europe/Vienna
- `start_at` 2026-12-09T18:00:00+00:00 · `end_at` NULL
- `venue_name` La Fenice, Hotel Arlberg Lech · `city` Lech am Arlberg · `country_code` AT
- `latitude`/`longitude` 47.2083376 / 10.1413176 (van rest_3648)
- `external_host_name` Weinberg Arlberg
- `official_url` https://www.weinbergarlberg.at/en/events/gaja-icons-and-vintages
- `ticket_url` https://www.weinbergarlberg.at/en/events
- `admission_type` paid · `admission_note` EUR 590,00 incl. VAT · `availability_status` available
- Koppelingen:
  - `event_restaurants` rest_3648 La Fenice (Lech am Arlberg, AT) · `is_host` false · `is_venue` true

#### wev-040 · Two Wine Cultures. Four Centuries. One Evening. Trimbach meets Château Figeac

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-12-10 · `end_date` 2026-12-10 · `start_time`–`end_time` 19:00 – NULL · `timezone` Europe/Vienna
- `start_at` 2026-12-10T18:00:00+00:00 · `end_at` NULL
- `venue_name` Die Krone von Lech · `city` Lech am Arlberg · `country_code` AT
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Weinberg Arlberg
- `official_url` https://www.weinbergarlberg.at/en/events
- `ticket_url` https://www.weinbergarlberg.at/en/events
- `admission_type` paid · `admission_note` EUR 480 · `availability_status` available
- Koppelingen: geen

#### wev-095 · YVESKE'S Kitchen at MASTERS EXPO - Dinner 10 Dec

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2026-12-10 · `end_date` 2026-12-10 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` MASTERS EXPO (RAI Amsterdam) · `city` Amsterdam · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` MASTERS EXPO (RAI Amsterdam)
- `official_url` https://mastersexpo.com/en/the-yveske-kitchen
- `ticket_url` https://mastersexpo.com/en/tickets
- `admission_type` paid · `admission_note` NULL · `availability_status` sold_out
- Koppelingen:
  - `event_restaurants` rest_0001 Aan de Poel (Amstelveen, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0035 De Kromme Watergang (Hoofdplaat, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0048 Fred (Rotterdam, NL) · `is_host` false · `is_venue` false

#### wev-124 · MASTERS EXPO 2026

- `event_type` festival · tags: geen · bron A
- `start_date` 2026-12-10 · `end_date` 2026-12-14 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` MASTERS EXPO (RAI Amsterdam) · `city` Amsterdam · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` MASTERS EXPO (RAI Amsterdam)
- `official_url` https://mastersexpo.com/en
- `ticket_url` https://mastersexpo.com/en/tickets
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-041 · Visionaries & Icons of Burgundy

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-12-11 · `end_date` 2026-12-11 · `start_time`–`end_time` 18:30 – NULL · `timezone` Europe/Vienna
- `start_at` 2026-12-11T17:30:00+00:00 · `end_at` NULL
- `venue_name` Burg Vital Resort · `city` Lech am Arlberg · `country_code` AT
- `latitude`/`longitude` 47.217414 / 10.138714 (van hotel_135)
- `external_host_name` Weinberg Arlberg
- `official_url` https://www.weinbergarlberg.at/en/events/visionaries-and-icons-of-burgundy
- `ticket_url` https://www.weinbergarlberg.at/en/events
- `admission_type` paid · `admission_note` EUR 1,410.00 incl. VAT · `availability_status` available
- Koppelingen:
  - `event_hotels` hotel_135 Burg Vital Resort (Lech am Arlberg, AT) · `is_host` false · `is_venue` true

#### wev-099 · YVESKE'S Kitchen at MASTERS EXPO - Lunch 11 Dec

- `event_type` lunch · tags: guest_chef · bron A
- `start_date` 2026-12-11 · `end_date` 2026-12-11 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` MASTERS EXPO (RAI Amsterdam) · `city` Amsterdam · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` MASTERS EXPO (RAI Amsterdam)
- `official_url` https://mastersexpo.com/en/the-yveske-kitchen
- `ticket_url` https://mastersexpo.com/en/tickets
- `admission_type` paid · `admission_note` NULL · `availability_status` sold_out
- Koppelingen:
  - `event_restaurants` rest_0038 De Lindenhof (Giethoorn, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0041 De Treeswijkhoeve (Waalre, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0047 Flore (Amsterdam, NL) · `is_host` false · `is_venue` false

#### wev-100 · YVESKE'S Kitchen at MASTERS EXPO - Dinner 11 Dec

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2026-12-11 · `end_date` 2026-12-11 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` MASTERS EXPO (RAI Amsterdam) · `city` Amsterdam · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` MASTERS EXPO (RAI Amsterdam)
- `official_url` https://mastersexpo.com/en/the-yveske-kitchen
- `ticket_url` https://mastersexpo.com/en/tickets
- `admission_type` paid · `admission_note` NULL · `availability_status` sold_out
- Koppelingen:
  - `event_restaurants` rest_0085 Restaurant 212 (Amsterdam, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0013 Bistro de la Mer (Amsterdam, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0079 Parkheuvel (Rotterdam, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0103 t Amsterdammertje (Loenen aan de Vecht, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0090 Restaurant kasteel Heemstede (Houten, NL) · `is_host` false · `is_venue` false

#### wev-042 · An Evening with Château Cheval Blanc

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-12-12 · `end_date` 2026-12-12 · `start_time`–`end_time` 18:30 – 23:00 · `timezone` Asia/Macau
- `start_at` 2026-12-12T10:30:00+00:00 · `end_at` 2026-12-12T15:00:00+00:00
- `venue_name` Robuchon au Dôme (Grand Lisboa) · `city` Macau · `country_code` MO
- `latitude`/`longitude` 22.190458 / 113.543295 (van rest_0434)
- `external_host_name` NULL
- `official_url` https://www.grandlisboa.com/en/experience/an-evening-with-chateau-cheval-blanc
- `ticket_url` NULL
- `admission_type` paid · `admission_note` MOP39,888+ per person (includes wine pairing) · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0434 Robuchon au Dôme (Macau, MO) · `is_host` true · `is_venue` true

#### wev-043 · YVESKE'S Kitchen at MASTERS EXPO - Dinner 12 Dec

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2026-12-12 · `end_date` 2026-12-12 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` MASTERS EXPO (RAI Amsterdam) · `city` Amsterdam · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` MASTERS EXPO (RAI Amsterdam)
- `official_url` https://mastersexpo.com/en/the-yveske-kitchen
- `ticket_url` https://mastersexpo.com/en/tickets
- `admission_type` paid · `admission_note` € 500p.p. · `availability_status` available
- Koppelingen:
  - `event_restaurants` rest_0025 Ciel Bleu (Amsterdam, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0069 MOS (Amsterdam, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0030 De Bokkedoorns (Overveen, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0016 Bougainville (Amsterdam, NL) · `is_host` false · `is_venue` false

#### wev-101 · YVESKE'S Kitchen at MASTERS EXPO - Lunch 12 Dec

- `event_type` lunch · tags: guest_chef · bron A
- `start_date` 2026-12-12 · `end_date` 2026-12-12 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` MASTERS EXPO (RAI Amsterdam) · `city` Amsterdam · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` MASTERS EXPO (RAI Amsterdam)
- `official_url` https://mastersexpo.com/en/the-yveske-kitchen
- `ticket_url` https://mastersexpo.com/en/tickets
- `admission_type` paid · `admission_note` NULL · `availability_status` sold_out
- Koppelingen:
  - `event_restaurants` rest_1400 Le Epifaan (Veeningen, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0120 Zarzo (Eindhoven, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0104 t Ganzenest (Rijswijk, NL) · `is_host` false · `is_venue` false

#### wev-044 · YVESKE'S Kitchen at MASTERS EXPO - Lunch 13 Dec

- `event_type` lunch · tags: guest_chef · bron A
- `start_date` 2026-12-13 · `end_date` 2026-12-13 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` MASTERS EXPO (RAI Amsterdam) · `city` Amsterdam · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` MASTERS EXPO (RAI Amsterdam)
- `official_url` https://mastersexpo.com/en/the-yveske-kitchen
- `ticket_url` https://mastersexpo.com/en/tickets
- `admission_type` paid · `admission_note` € 395p.p. · `availability_status` available
- Koppelingen:
  - `event_restaurants` rest_0037 De Librije (Zwolle, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0017 Brass Boer Thuis (Zwolle, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0027 Create by Guido Braeken (Eijsden, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0146 't Nonnetje (Harderwijk, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0114 Vinkeles (Amsterdam, NL) · `is_host` false · `is_venue` false

#### wev-045 · Gourmet Skisafari Alta Badia

- `event_type` tasting · tags: guest_chef · bron A
- `start_date` 2026-12-13 · `end_date` 2026-12-13 · `start_time`–`end_time` 11:00 – 15:00 · `timezone` Europe/Rome
- `start_at` 2026-12-13T10:00:00+00:00 · `end_at` 2026-12-13T14:00:00+00:00
- `venue_name` Mountain huts: Ütia Piz Arlara, Ütia Pralongiá, Club Moritzino, Ütia I Tablá, Ütia Bioch · `city` Alta Badia · `country_code` IT
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Alta Badia Tourism
- `official_url` https://www.altabadia.org/en/events/gourmet-skisafari.html
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0315 Le Calandre (Rubano, IT) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_2296 La Stüa de Michil - Simone Cantafio (Corvara in Badia, IT) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_2202 Dolada (Plois, IT) · `is_host` false · `is_venue` false

#### wev-104 · YVESKE'S Kitchen at MASTERS EXPO - Lunch 14 Dec

- `event_type` lunch · tags: guest_chef · bron A
- `start_date` 2026-12-14 · `end_date` 2026-12-14 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` MASTERS EXPO (RAI Amsterdam) · `city` Amsterdam · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` MASTERS EXPO (RAI Amsterdam)
- `official_url` https://mastersexpo.com/en/the-yveske-kitchen
- `ticket_url` https://mastersexpo.com/en/tickets
- `admission_type` paid · `admission_note` NULL · `availability_status` sold_out
- Koppelingen:
  - `event_restaurants` rest_0111 Triptyque (Wateringen, NL) · `is_host` false · `is_venue` false
  - `event_restaurants` rest_0051 Inter Scaldes (Kruiningen, NL) · `is_host` false · `is_venue` false

#### wev-185 · Wildmiddag (5-gangen wildmenu)

- `event_type` lunch · tags: wild_game · bron A
- `start_date` 2027-01-10 · `end_date` 2027-01-10 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` Olde Marckt · `city` Aalten · `country_code` NL
- `latitude`/`longitude` 51.927491 / 6.581685 (van rest_0150)
- `external_host_name` NULL
- `official_url` https://www.oldemarckt.nl/agenda/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` € 100,00 · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0150 Olde Marckt (Aalten, NL) · `is_host` true · `is_venue` true

#### wev-129 · Napa Truffle Festival 2027

- `event_type` festival · tags: wine, guest_chef · bron A
- `start_date` 2027-01-15 · `end_date` 2027-01-18 · `start_time`–`end_time` NULL – NULL · `timezone` America/Los_Angeles
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Napa · `country_code` US
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Napa Truffle Festival
- `official_url` https://napatrufflefestival.com/
- `ticket_url` https://napatrufflefestival.com/schedule
- `admission_type` unknown · `admission_note` NULL · `availability_status` available
- Koppelingen: geen

#### wev-130 · Four-Hands Dinner: 2** trifft Region

- `event_type` dinner · tags: four_hands, guest_chef, wine · bron A
- `start_date` 2027-01-16 · `end_date` 2027-01-16 · `start_time`–`end_time` 18:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-01-16T17:30:00+00:00 · `end_at` NULL
- `venue_name` Kempinski Hotel Berchtesgaden (Ulrich Heimann's 2-star restaurant) · `city` Berchtesgaden · `country_code` DE
- `latitude`/`longitude` 47.63391 / 13.046298 (van rest_0188)
- `external_host_name` NULL
- `official_url` https://www.kempinski.com/de/kempinski-hotel-berchtesgaden/restaurants-bars/culinary-highlights/four-hands-dinner
- `ticket_url` NULL
- `admission_type` paid · `admission_note` EUR 270,- pro Person inkl. Weinbegleitung · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0188 PUR (Berchtesgaden, DE) · `is_host` true · `is_venue` true

#### wev-186 · Wildmiddag (5-gangen wildmenu)

- `event_type` lunch · tags: wild_game · bron A
- `start_date` 2027-01-17 · `end_date` 2027-01-17 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Amsterdam
- `start_at` NULL · `end_at` NULL
- `venue_name` Olde Marckt · `city` Aalten · `country_code` NL
- `latitude`/`longitude` 51.927491 / 6.581685 (van rest_0150)
- `external_host_name` NULL
- `official_url` https://www.oldemarckt.nl/agenda/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` € 100,00 · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0150 Olde Marckt (Aalten, NL) · `is_host` true · `is_venue` true

#### wev-131 · Leidenschaft, Disziplin und Teamgeist

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2027-01-23 · `end_date` 2027-01-24 · `start_time`–`end_time` 18:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-01-23T17:30:00+00:00 · `end_at` NULL
- `venue_name` Romantik Hotel Waldschlösschen · `city` Schleswig · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Schleswig-Holstein Gourmet Festival e.V.
- `official_url` https://www.gourmetfestival.de/
- `ticket_url` mailto:reception@hotel-waldschloesschen.de
- `admission_type` paid · `admission_note` 215 Euro · `availability_status` available
- Koppelingen:
  - `event_restaurants` rest_0201 Jante (Hanover, DE) · `is_host` false · `is_venue` false

#### wev-134 · Madrid Fusión Alimentos de España 2027 (25th edition)

- `event_type` festival · tags: geen · bron A
- `start_date` 2027-02-01 · `end_date` 2027-02-03 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Madrid
- `start_at` NULL · `end_at` NULL
- `venue_name` IFEMA Madrid · `city` Madrid · `country_code` ES
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Madrid Fusión (Vocento Gastronomía)
- `official_url` https://www.ifema.es/madrid-fusion
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-136 · 30. Rheingau Gourmet & Wein Festival

- `event_type` festival · tags: wine, winemaker, guest_chef · bron A
- `start_date` 2027-02-18 · `end_date` 2027-03-07 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Berlin
- `start_at` NULL · `end_at` NULL
- `venue_name` Kronenschlösschen · `city` Eltville am Rhein · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kronenschlösschen
- `official_url` https://www.rheingau-gourmet-festival.de/
- `ticket_url` https://www.rheingau-gourmet-festival.de/programm/
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-137 · 3-Sternekoch Martin Öfner, Taiwan (***) & Monteverro & Brunello di Montalcino & Champagne Louis Roederer

- `event_type` dinner · tags: guest_chef, wine, winemaker · bron A
- `start_date` 2027-02-19 · `end_date` 2027-02-19 · `start_time`–`end_time` 19:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-02-19T18:30:00+00:00 · `end_at` NULL
- `venue_name` Kronenschlösschen · `city` Eltville am Rhein · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kronenschlösschen
- `official_url` https://www.rheingau-gourmet-festival.de/programm/
- `ticket_url` https://www.rheingau-gourmet-festival.de/programm/
- `admission_type` paid · `admission_note` 450 EUR · `availability_status` available
- Koppelingen: geen

#### wev-138 · Jüngster 2-Sterne-Koch feiert Festival-Premiere

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2027-02-20 · `end_date` 2027-02-21 · `start_time`–`end_time` 18:00 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-02-20T17:00:00+00:00 · `end_at` NULL
- `venue_name` Romantik Hotel Kieler Kaufmann · `city` Kiel · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Schleswig-Holstein Gourmet Festival e.V.
- `official_url` https://www.gourmetfestival.de/
- `ticket_url` mailto:info@kieler-kaufmann.de
- `admission_type` paid · `admission_note` 229 Euro · `availability_status` available
- Koppelingen:
  - `event_restaurants` rest_0204 Gotthardt's by Yannick Noack (Koblenz, DE) · `is_host` false · `is_venue` false

#### wev-140 · 2-Sternekoch Jan-Philipp Berner** (SÖL´RING HOF, Sylt) & Champagne Ayala

- `event_type` dinner · tags: guest_chef, wine · bron A
- `start_date` 2027-02-22 · `end_date` 2027-02-22 · `start_time`–`end_time` 19:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-02-22T18:30:00+00:00 · `end_at` NULL
- `venue_name` Kronenschlösschen · `city` Eltville am Rhein · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kronenschlösschen
- `official_url` https://www.rheingau-gourmet-festival.de/programm/
- `ticket_url` https://www.rheingau-gourmet-festival.de/programm/
- `admission_type` paid · `admission_note` 350 EUR · `availability_status` available
- Koppelingen:
  - `event_restaurants` rest_0227 Söl'ring Hof (Sylt/Rantum, DE) · `is_host` false · `is_venue` false

#### wev-141 · eat! berlin 2027

- `event_type` festival · tags: guest_chef · bron A
- `start_date` 2027-02-25 · `end_date` 2027-03-07 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Berlin
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Berlin · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` eat! berlin
- `official_url` https://www.eat-berlin.de/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-142 · Alex Dilling** (Hotel Café Royal, London)

- `event_type` dinner · tags: guest_chef, wine · bron A
- `start_date` 2027-02-26 · `end_date` 2027-02-26 · `start_time`–`end_time` 19:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-02-26T18:30:00+00:00 · `end_at` NULL
- `venue_name` Kronenschlösschen · `city` Eltville am Rhein · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kronenschlösschen
- `official_url` https://www.rheingau-gourmet-festival.de/programm/
- `ticket_url` https://www.rheingau-gourmet-festival.de/programm/
- `admission_type` paid · `admission_note` 395 EUR · `availability_status` available
- Koppelingen:
  - `event_restaurants` rest_2454 Alex Dilling at Hotel Café Royal (London, GB) · `is_host` false · `is_venue` false

#### wev-144 · Einer der weltbesten 3-Sterneköche: Christian Bau*** & Château Lascombes

- `event_type` dinner · tags: guest_chef, wine, winemaker · bron A
- `start_date` 2027-03-02 · `end_date` 2027-03-02 · `start_time`–`end_time` 19:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-03-02T18:30:00+00:00 · `end_at` NULL
- `venue_name` Kronenschlösschen · `city` Eltville am Rhein · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kronenschlösschen
- `official_url` https://www.rheingau-gourmet-festival.de/programm/
- `ticket_url` https://www.rheingau-gourmet-festival.de/programm/
- `admission_type` paid · `admission_note` 450 EUR · `availability_status` available
- Koppelingen:
  - `event_restaurants` rest_0184 Victor's Fine Dining by Christian Bau (Perl, DE) · `is_host` false · `is_venue` false

#### wev-145 · Food & Fun Festival 2027

- `event_type` festival · tags: guest_chef · bron A
- `start_date` 2027-03-03 · `end_date` 2027-03-07 · `start_time`–`end_time` NULL – NULL · `timezone` Atlantic/Reykjavik
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Reykjavík · `country_code` IS
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Food & Fun Festival
- `official_url` https://www.foodandfun.is/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-149 · La Paulée Mexico City 2027

- `event_type` festival · tags: wine, winemaker · bron A
- `start_date` 2027-03-11 · `end_date` 2027-03-13 · `start_time`–`end_time` NULL – NULL · `timezone` America/Mexico_City
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Mexico City · `country_code` MX
- `latitude`/`longitude` NULL / NULL
- `external_host_name` La Paulée (Daniel Johnnes)
- `official_url` https://www.lapaulee.com/
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-150 · wachau GOURMETfestival 2027

- `event_type` festival · tags: wine, winemaker, guest_chef · bron A
- `start_date` 2027-04-01 · `end_date` 2027-04-18 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Vienna
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Krems an der Donau · `country_code` AT
- `latitude`/`longitude` NULL / NULL
- `external_host_name` wachau GOURMETfestival (Vinaria / LWmedia)
- `official_url` https://www.vinaria.at/wachau-gourmet-festival/de/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-152 · Dorfer & Friends

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2027-04-12 · `end_date` 2027-04-12 · `start_time`–`end_time` 18:00 – NULL · `timezone` Europe/Vienna
- `start_at` 2027-04-12T16:00:00+00:00 · `end_at` NULL
- `venue_name` Landhaus Bacher · `city` Mautern an der Donau · `country_code` AT
- `latitude`/`longitude` 48.393174 / 15.5795 (van rest_0272)
- `external_host_name` wachau GOURMETfestival
- `official_url` https://www.vinaria.at/wachau-gourmet-festival/de/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen:
  - `event_restaurants` rest_0272 Landhaus Bacher (Mautern an der Donau, AT) · `is_host` true · `is_venue` true

#### wev-153 · Tasting Australia presented by Journey Beyond 2027

- `event_type` festival · tags: wine · bron A
- `start_date` 2027-04-30 · `end_date` 2027-05-09 · `start_time`–`end_time` NULL – NULL · `timezone` Australia/Adelaide
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` Adelaide · `country_code` AU
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Tasting Australia (festival hub, Adelaide and regional South Australia)
- `official_url` https://tastingaustralia.com.au/news/pull-up-a-chair-at-tasting-australia-2027
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

### 3.2 Met een open koppeling (13)

#### wev-003 · Signature Sessions: Sapiens X Kol

- `event_type` dinner · tags: guest_chef, four_hands · bron A
- `start_date` 2026-11-05 · `end_date` 2026-11-05 · `start_time`–`end_time` NULL – NULL · `timezone` America/Lima
- `start_at` NULL · `end_at` NULL
- `venue_name` Sapiens · `city` Lima · `country_code` PE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` The 50 Best Restaurants (The 50)
- `official_url` https://www.the50.com/restaurants/best-in-the-world/experiences.html
- `ticket_url` https://bit.ly/T50BR26SapiensxKol
- `admission_type` paid · `admission_note` S/345 · `availability_status` available
- Koppelingen: geen
- **Open koppeling:** Kol (participant), zie besluit 1

#### wev-004 · Cos d'Estournel Four-Hands Dinner: Jérôme Banctel x Marco Ortolani

- `event_type` dinner · tags: four_hands, guest_chef, wine · bron A
- `start_date` 2026-11-06 · `end_date` 2026-11-06 · `start_time`–`end_time` NULL – NULL · `timezone` Europe/Zurich
- `start_at` NULL · `end_at` NULL
- `venue_name` Eden Kitchen (La Réserve Eden au Lac Zurich) · `city` Zurich · `country_code` CH
- `latitude`/`longitude` 47.362874 / 8.547407 (van hotel_87)
- `external_host_name` NULL
- `official_url` https://www.lareserve-paris.com/en/actualites/cos-d-estournel-four-hands-dinner-jerome-banctel-x-marco-ortolani/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` CHF 340 (approx. EUR 360) per person · `availability_status` unknown
- Koppelingen:
  - `event_hotels` hotel_87 La Réserve Eden au Lac Zurich (Zurich, CH) · `is_host` false · `is_venue` true
  - `event_restaurants` rest_0060 Le Gabriel - La Reserve Paris (Paris, FR) · `is_host` false · `is_venue` false
- **Open koppeling:** Eden Kitchen (La Réserve Eden au Lac Zurich) (host+venue), zie besluit 1

#### wev-117 · Gary Gielen & Friends Dinner Show

- `event_type` party · tags: geen · bron A
- `start_date` 2026-11-07 · `end_date` 2026-11-08 · `start_time`–`end_time` 19:00 – 00:00 · `timezone` Europe/Amsterdam
- `start_at` 2026-11-07T18:00:00+00:00 · `end_at` 2026-11-07T23:00:00+00:00
- `venue_name` Van Oys Maastricht Retreat (Sainte Cécile Ballroom) · `city` Eijsden-Margraten · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` NULL
- `official_url` https://www.vanoys.com/event-calendar/gary-gielen-friends-dinnershow/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` €159 per person · `availability_status` unknown
- Koppelingen: geen
- **Open koppeling:** Van Oys Maastricht Retreat (Sainte Cécile Ballroom) (host+venue), zie besluit 1

#### wev-014 · Jantar Magno Mesa SP 2026 – Grand Hyatt São Paulo

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2026-11-13 · `end_date` 2026-11-13 · `start_time`–`end_time` 20:00 – NULL · `timezone` America/Sao_Paulo
- `start_at` 2026-11-13T23:00:00+00:00 · `end_at` NULL
- `venue_name` Grand Hyatt São Paulo · `city` São Paulo · `country_code` BR
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Mesa São Paulo (Prazeres da Mesa)
- `official_url` https://mesasp.com.br/jantaresmagno
- `ticket_url` https://wa.me/5511994644694
- `admission_type` paid · `admission_note` R$ 620 + 13% de serviço · `availability_status` unknown
- Koppelingen: geen
- **Open koppeling:** Maido (participant), zie besluit 1
- **Open koppeling:** Evvai (participant), zie besluit 1

#### wev-016 · Dîner de Gala de Charité 2026 au profit de la Banque Alimentaire Luxembourg

- `event_type` gala · tags: charity, guest_chef · bron A
- `start_date` 2026-11-16 · `end_date` 2026-11-16 · `start_time`–`end_time` 19:00 – 23:45 · `timezone` Europe/Luxembourg
- `start_at` 2026-11-16T18:00:00+00:00 · `end_at` 2026-11-16T22:45:00+00:00
- `venue_name` Le Royal Hotel Luxembourg · `city` Luxembourg City · `country_code` LU
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Lions Club Luxembourg International
- `official_url` https://www.tickettailor.com/events/lcli/2263683
- `ticket_url` https://www.tickettailor.com/events/lcli/2263683
- `admission_type` paid · `admission_note` €220 pp through 30 Sep 2026 (Early Bird); €250 pp from 1 Oct 2026; menu and wine pairing included · `availability_status` sold_out
- Koppelingen: geen
- **Open koppeling:** Troisgros (Le Bois sans Feuilles) (participant), zie besluit 1

#### wev-120 · Italian Evening x MosaeVino & Francine Recca

- `event_type` dinner · tags: wine · bron A
- `start_date` 2026-11-18 · `end_date` 2026-11-18 · `start_time`–`end_time` 18:30 – 23:00 · `timezone` Europe/Amsterdam
- `start_at` 2026-11-18T17:30:00+00:00 · `end_at` 2026-11-18T22:00:00+00:00
- `venue_name` Van Oys Maastricht Retreat (Sainte Cécile Ballroom) · `city` Eijsden-Margraten · `country_code` NL
- `latitude`/`longitude` NULL / NULL
- `external_host_name` NULL
- `official_url` https://www.vanoys.com/event-calendar/italian-evening-with-mosaevino/
- `ticket_url` NULL
- `admission_type` paid · `admission_note` €135 per person · `availability_status` unknown
- Koppelingen: geen
- **Open koppeling:** Van Oys Maastricht Retreat (Sainte Cécile Ballroom) (host+venue), zie besluit 1

#### wev-023 · Wayfinder x St JOHN, presented by Lexus

- `event_type` dinner · tags: wine, winemaker, guest_chef · bron A
- `start_date` 2026-11-20 · `end_date` 2026-11-20 · `start_time`–`end_time` 18:00 – 22:00 · `timezone` Australia/Perth
- `start_at` 2026-11-20T10:00:00+00:00 · `end_at` 2026-11-20T14:00:00+00:00
- `venue_name` Wayfinder Winery & Farm · `city` Margaret River · `country_code` AU
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Wayfinder Winery & Farm
- `official_url` https://pairdmargaretriver.com/events/wayfinder-x-st-john
- `ticket_url` https://pairdmargaretriver.com/events/wayfinder-x-st-john
- `admission_type` paid · `admission_note` $398 per person, booking fees included · `availability_status` sold_out
- Koppelingen: geen
- **Open koppeling:** St. JOHN (participant), zie besluit 1

#### wev-034 · Wine Dinner Château Pichon Comtesse

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-12-06 · `end_date` 2026-12-06 · `start_time`–`end_time` 19:00 – NULL · `timezone` Europe/Vienna
- `start_at` 2026-12-06T18:00:00+00:00 · `end_at` NULL
- `venue_name` Burg Hotel · `city` Lech am Arlberg · `country_code` AT
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Weinberg Arlberg
- `official_url` https://www.weinbergarlberg.at/en/events/wine-dinner-chateau-pichon-comtesse
- `ticket_url` https://www.weinbergarlberg.at/en/events
- `admission_type` paid · `admission_note` EUR 460.00 incl. VAT · `availability_status` available
- Koppelingen: geen
- **Open koppeling:** Burg Hotel (venue), zie besluit 1

#### wev-037 · Domaine de Chevalier Vertical

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-12-08 · `end_date` 2026-12-08 · `start_time`–`end_time` 19:00 – NULL · `timezone` Europe/Vienna
- `start_at` 2026-12-08T18:00:00+00:00 · `end_at` NULL
- `venue_name` Hotel Gasthof Post · `city` Lech am Arlberg · `country_code` AT
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Weinberg Arlberg
- `official_url` https://www.weinbergarlberg.at/en/events/domaine-de-chevalier-vertical
- `ticket_url` https://www.weinbergarlberg.at/en/events
- `admission_type` paid · `admission_note` EUR 390.00 incl. VAT · `availability_status` available
- Koppelingen: geen
- **Open koppeling:** Hotel Gasthof Post (venue), zie besluit 1

#### wev-039 · Egon Müller Vertical

- `event_type` dinner · tags: wine, winemaker · bron A
- `start_date` 2026-12-10 · `end_date` 2026-12-10 · `start_time`–`end_time` 19:00 – NULL · `timezone` Europe/Vienna
- `start_at` 2026-12-10T18:00:00+00:00 · `end_at` NULL
- `venue_name` Hotel Gasthof Post · `city` Lech am Arlberg · `country_code` AT
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Weinberg Arlberg
- `official_url` https://www.weinbergarlberg.at/en/events/egon-mueller-vertical
- `ticket_url` https://www.weinbergarlberg.at/en/events
- `admission_type` paid · `admission_note` EUR 390,00 incl. VAT · `availability_status` available
- Koppelingen: geen
- **Open koppeling:** Hotel Gasthof Post (venue), zie besluit 1

#### wev-139 · 3-Sternekoch Edip Sigl*** & Laurent-Perrier | Tempos Vega Sicilia | Oremus | Joh. Jos. Prüm | Schlossgut Diel | Robert Weil | Wittmann | Rochelt

- `event_type` dinner · tags: guest_chef, wine, winemaker · bron A
- `start_date` 2027-02-21 · `end_date` 2027-02-21 · `start_time`–`end_time` 19:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-02-21T18:30:00+00:00 · `end_at` NULL
- `venue_name` Kronenschlösschen · `city` Eltville am Rhein · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kronenschlösschen
- `official_url` https://www.rheingau-gourmet-festival.de/programm/
- `ticket_url` https://www.rheingau-gourmet-festival.de/programm/
- `admission_type` paid · `admission_note` 450 EUR · `availability_status` available
- Koppelingen: geen
- **Open koppeling:** es:senz (Das Achental Resort) (participant), zie besluit 1

#### wev-146 · La Paulée de New York 2027

- `event_type` festival · tags: wine, winemaker · bron A
- `start_date` 2027-03-03 · `end_date` 2027-03-06 · `start_time`–`end_time` NULL – NULL · `timezone` America/New_York
- `start_at` NULL · `end_at` NULL
- `venue_name` NULL · `city` New York · `country_code` US
- `latitude`/`longitude` NULL / NULL
- `external_host_name` NULL
- `official_url` https://www.lapaulee.com/
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen
- **Open koppeling:** La Paulée (Daniel Johnnes) (host), zie besluit 1

#### wev-147 · 3-Sternekoch Daniel Schimkowitsch*** & „Die besten deutschen Sekte“

- `event_type` dinner · tags: guest_chef, wine · bron A
- `start_date` 2027-03-05 · `end_date` 2027-03-05 · `start_time`–`end_time` 19:30 – NULL · `timezone` Europe/Berlin
- `start_at` 2027-03-05T18:30:00+00:00 · `end_at` NULL
- `venue_name` Kronenschlösschen · `city` Eltville am Rhein · `country_code` DE
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kronenschlösschen
- `official_url` https://www.rheingau-gourmet-festival.de/programm/
- `ticket_url` https://www.rheingau-gourmet-festival.de/programm/
- `admission_type` paid · `admission_note` 395 EUR · `availability_status` available
- Koppelingen: geen
- **Open koppeling:** L.A. Jordan (Hotel Ketschauer Hof) (participant), zie besluit 1

### 3.3 Wacht op besluit 2, hotelgasten (7)

#### wev-035 · By Land and Sea (Blackberry Farm)

- `event_type` dinner · tags: guest_chef, winemaker, wine · bron A
- `start_date` 2026-12-06 · `end_date` 2026-12-09 · `start_time`–`end_time` NULL – NULL · `timezone` America/New_York
- `start_at` NULL · `end_at` NULL
- `venue_name` Blackberry Farm · `city` Walland · `country_code` US
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Blackberry Farm
- `official_url` https://www.blackberryfarm.com/experiences/events/by-land-and-sea
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` NULL · `availability_status` sold_out
- Koppelingen:
  - `event_restaurants` rest_0755 Harbor House Inn (Elk, US) · `is_host` false · `is_venue` false

#### wev-046 · An Exclusive Culinary Experience with Two-Star Michelin Chef Benjamin Peifer

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2026-12-26 · `end_date` 2026-12-26 · `start_time`–`end_time` NULL – NULL · `timezone` Indian/Maldives
- `start_at` NULL · `end_at` NULL
- `venue_name` Kandolhu Maldives (Olive restaurant) · `city` Kandolhu Island (North Ari Atoll) · `country_code` MV
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kandolhu Maldives (Olive restaurant)
- `official_url` https://www.kandolhu.com/festive-season.html
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-047 · An Exclusive Culinary Experience with Two-Star Michelin Chef Benjamin Peifer

- `event_type` dinner · tags: guest_chef · bron A
- `start_date` 2026-12-29 · `end_date` 2026-12-29 · `start_time`–`end_time` NULL – NULL · `timezone` Indian/Maldives
- `start_at` NULL · `end_at` NULL
- `venue_name` Kandolhu Maldives (Olive restaurant) · `city` Kandolhu Island (North Ari Atoll) · `country_code` MV
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Kandolhu Maldives (Olive restaurant)
- `official_url` https://www.kandolhu.com/festive-season.html
- `ticket_url` NULL
- `admission_type` paid · `admission_note` NULL · `availability_status` unknown
- Koppelingen: geen

#### wev-048 · Wine Geek (Blackberry Farm)

- `event_type` tasting · tags: wine, winemaker · bron A
- `start_date` 2027-01-03 · `end_date` 2027-01-06 · `start_time`–`end_time` NULL – NULL · `timezone` America/New_York
- `start_at` NULL · `end_at` NULL
- `venue_name` Blackberry Farm · `city` Walland · `country_code` US
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Blackberry Farm
- `official_url` https://www.blackberryfarm.com/experiences/events/wine-geek-3
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` $2,000 (activity fee per person, separate from room; taxes and 20% service additional) · `availability_status` unknown
- Koppelingen: geen

#### wev-135 · Excellence in Residence (Blackberry Farm)

- `event_type` dinner · tags: guest_chef, wine · bron A
- `start_date` 2027-02-07 · `end_date` 2027-02-10 · `start_time`–`end_time` NULL – NULL · `timezone` America/New_York
- `start_at` NULL · `end_at` NULL
- `venue_name` Blackberry Farm · `city` Walland · `country_code` US
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Blackberry Farm
- `official_url` https://www.blackberryfarm.com/experiences/events/excellence-in-residence
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` $2,000 (activity fee per person, separate from room; taxes and 20% service additional) · `availability_status` unknown
- Koppelingen: geen

#### wev-143 · La Paulée (Blackberry Farm)

- `event_type` dinner · tags: winemaker, wine · bron A
- `start_date` 2027-02-28 · `end_date` 2027-03-03 · `start_time`–`end_time` NULL – NULL · `timezone` America/New_York
- `start_at` NULL · `end_at` NULL
- `venue_name` Blackberry Farm · `city` Walland · `country_code` US
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Blackberry Farm
- `official_url` https://www.blackberryfarm.com/experiences/events/la-paulee-2
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` NULL · `availability_status` sold_out
- Koppelingen: geen

#### wev-148 · Hospice du Rhône (Blackberry Farm)

- `event_type` tasting · tags: winemaker, wine · bron A
- `start_date` 2027-03-07 · `end_date` 2027-03-10 · `start_time`–`end_time` NULL – NULL · `timezone` America/New_York
- `start_at` NULL · `end_at` NULL
- `venue_name` Blackberry Farm · `city` Walland · `country_code` US
- `latitude`/`longitude` NULL / NULL
- `external_host_name` Blackberry Farm
- `official_url` https://www.blackberryfarm.com/experiences/events/hospice-du-rhone-2027
- `ticket_url` NULL
- `admission_type` unknown · `admission_note` $1,500 (activity fee per person, separate from room; taxes and 20% service additional); optional tasting $295++ pp · `availability_status` unknown
- Koppelingen: geen

## 4. Valt af (10)

| Rij | Event | Reden |
|---|---|---|
| wev-002 | Big Sur Food & Wine Festival 2026 | Ticketlink wijkt af: de pagina linkt naar een andere URL (eindigt op -5, overzicht op -4). Start ook al 5 november. |
| wev-015 | Gala de clôture du Festival des Étoilés Monte-Carlo 2026 | Locatie wijkt af op de pagina zelf: de tekst zegt Salle Empire, de gestructureerde data Casino de Monte-Carlo. Is ook uitverkocht. |
| wev-026 | Ronny Siewert & Friends - Küchenparty an der Ostsee | Tijd wijkt af: het overzicht zegt 18:00-01:00, de pagina noemt alleen "Saturday evening", geen kloktijd. |
| wev-028 | Althoff Modern Chefs Circle (Die Althoff 6-Hands-Serie) | Tijd niet hard: 18:00 is de receptie, diner 18:30, en beide staan bij de reeks, niet bij deze datum. |
| wev-031 | XI. Gastromasa İstanbul International Gastronomy Conference & Exhibition | Ticketlink wijkt af: de pagina linkt naar een andere URL dan het overzicht. |
| wev-033 | Portugal meets Mondschein: Chef's Night with Dieter Koschina & Douro Boys | Plaats wijkt af: pagina noemt Stuben am Arlberg, overzicht Lech. Ook staat er een tweede Chef's Night op 5 december die apart moet worden bekeken. |
| wev-128 | Cayman Cookout 2027 | Land KY staat niet in countries; afgesproken: geen migratie in deze batch. |
| wev-132 | Naples Winter Wine Festival 2027 | Overzicht zegt invite_only, de pagina toont alleen een Ticket Inquiry-knop; invite_only is bovendien geen toegestane waarde voor admission_type. |
| wev-151 | Pebble Beach Food & Wine 2027 | Bronpagina gaf 403: datum, tijd en beschikbaarheid niet te controleren. |
| wev-154 | Constance Festival Culinaire 2027 (20th edition) | Land MU staat niet in countries, en de bronpagina gaf 403: niets te controleren. |

Niets hiervan is gecorrigeerd op basis van een andere bron.

## 5. Open beslispunten

### Besluit 1: koppelingen (`PROPOSED`, `AMBIGUOUS` en achtergehouden)

Ik beslis deze niet zelf. De kolom "Voorstel" is mijn advies. Wordt een koppeling niet goedgekeurd, dan komt ze er niet; een host gaat dan in `external_host_name`, een venue blijft tekst in `venue_name` zonder coördinaten.

| Rij | In de bron | Rol | Optie(s) in de catalogus | Voorstel |
|---|---|---|---|---|
| wev-003 | Kol | participant | rest_0329 Kol (London, GB) | ja, zelfde naam, stad en land als de bron |
| wev-004 | Eden Kitchen (La Réserve Eden au Lac Zurich) | host+venue | rest_3526 Eden Kitchen & Bar (Zurich, CH) | ja, het is de zaak van de bron; de catalogusnaam is "Eden Kitchen & Bar" |
| wev-014 | Maido | participant | rest_0134 Maido (Lima, PE) | nee, de bron noemt alleen de chef, niet het restaurant |
| wev-014 | Evvai | participant | rest_1393 Evvai (São Paulo, BR) | nee, de bron noemt alleen de chef, niet het restaurant |
| wev-016 | Troisgros (Le Bois sans Feuilles) | participant | rest_1409 Troisgros - Le Bois sans Feuilles (Ouches, FR); hotel_2055 Troisgros (Ouches, FR) | ja, het restaurant, niet het hotel |
| wev-023 | St. JOHN | participant | rest_2590 St. JOHN (London, GB) | ja, zelfde naam en stad als de bron |
| wev-034 | Burg Hotel | venue | hotel_135 Burg Vital Resort (Lech am Arlberg, AT); rest_0270 Griggeler Stuba (Lech am Arlberg, AT) | nee, geen van beide opties is aantoonbaar "Burg Hotel"; venue_name blijft tekst |
| wev-037 | Hotel Gasthof Post | venue | hotel_134 Post Lech Arlberg (Lech am Arlberg, AT) | ja, als je bevestigt dat Hotel Gasthof Post nu Post Lech Arlberg heet |
| wev-039 | Hotel Gasthof Post | venue | hotel_134 Post Lech Arlberg (Lech am Arlberg, AT) | ja, als je bevestigt dat Hotel Gasthof Post nu Post Lech Arlberg heet |
| wev-117 | Van Oys Maastricht Retreat (Sainte Cécile Ballroom) | host+venue | hotel_05 Van Oys Maastricht Retreat (Maastricht, NL) | ja, de Sainte Cécile Ballroom hoort bij dit hotel volgens de bron |
| wev-120 | Van Oys Maastricht Retreat (Sainte Cécile Ballroom) | host+venue | hotel_05 Van Oys Maastricht Retreat (Maastricht, NL) | ja, de Sainte Cécile Ballroom hoort bij dit hotel volgens de bron |
| wev-139 | es:senz (Das Achental Resort) | participant | hotel_103 Das Achental Resort (Grassau, DE); rest_0179 ES:SENZ (Grassau, DE) | ja, het restaurant, niet het resort |
| wev-146 | La Paulée (Daniel Johnnes) | host | rest_3043 Daniel (New York, US) | nee, Daniel is een restaurant; de host is La Paulée. Wordt external_host_name |
| wev-147 | L.A. Jordan (Hotel Ketschauer Hof) | participant | hotel_95 Hotel Ketschauer Hof (Deidesheim, DE); rest_0194 L.A. Jordan (Deidesheim, DE) | ja, het restaurant, niet het hotel |

### Besluit 2: alleen voor hotelgasten?

Jouw besluit van 5 november: alleen voor hotelgasten gaat niet mee. Deze pagina's zeggen dat niet bij het event zelf, maar er is wel twijfel:

- **Blackberry Farm** (wev-035, wev-048, wev-135, wev-143, wev-148): de sitebrede voettekst zegt dat alleen geregistreerde gasten op het terrein mogen. Het zijn meerdaagse arrangementen met activiteitenkosten los van de kamer.
- **Kandolhu Maldives** (wev-046, wev-047): de pagina noemt de diners een hoogtepunt voor gasten die er verblijven. Een resort op een eigen eiland.

**Voorstel:** alle zeven niet meenemen. Ze zijn in de praktijk niet los te boeken.

### Besluit 3: tijden die de pagina wel noemt en het overzicht niet

Niets hiervan is verzonnen, maar deze rijen hebben een lege tijd terwijl de bron meer zegt:

- **Eindtijd op dezelfde pagina:** wev-034, wev-037, wev-038, wev-039 (19:00–22:00), wev-036, wev-041 (18:30–22:30). **Voorstel:** eindtijd overnemen van de eigen pagina.
- **Tijden per dag of per onderdeel:** wev-005, wev-020, wev-052, wev-124, wev-134. **Voorstel:** alleen de datum; één tijd zou niet kloppen.
- **Inloopvenster:** wev-185, wev-186 (intake 13.00–15.00). **Voorstel:** alleen de datum.
- **Start is de receptie:** wev-006 (18:00, diner 19:00), wev-025 (18:30, diner 20:00), wev-122 (13:00, programma 14:00). **Voorstel:** zo laten; het is de tijd waarop gasten worden verwacht.

### Besluit 4: bron zonder jaartal

wev-017 (pdf-nieuwsbrief, "18 November", pdf gemaakt in oktober 2026) en wev-018 ("18. novembra", onder een kop "oktober 2026"). **Voorstel:** meenemen; het jaar volgt uit de context.

### Besluit 5: buiten Europa

17 van de klaarstaande events zijn buiten Europa (AU 4, US 3, MO 3, TH 3, PE 1, BL 1, BR 1, MX 1). `CLAUDE.md` omschrijft events als "across Europe". Jij vroeg om een wereldwijde zoektocht, maar nog niet om ze ook te publiceren. Mogen ze mee?

### Besluit 6: "P0" en de kolom `apply_decision`

Jouw opdracht noemt alle P0-rijen; de CSV zet er tien daarvan niet in batch 1, volgens je besluiten van 5 november. Ik volg de kolom:

- `decide` (onduidelijke datum of format): wev-001, wev-019, wev-021, wev-024, wev-030, wev-049, wev-051, wev-053
- `excluded` (alleen hotelgasten): wev-008, wev-133

### Besluit 7: KY en MU

wev-128 (Cayman Cookout) en wev-154 vallen af omdat die landen ontbreken en jij geen migratie wilt in deze opdracht. `20261101310000_add_bh_ky_mu_countries.sql` staat alleen op de overzichtsbranch en is niet toegepast. wev-154 gaf bovendien 403.

### Om te weten: events die vervallen

Wat op de dag van de apply al voorbij is, sla ik over. Binnenkort vallen dus weg: wev-003 (2026-11-05), wev-004 (2026-11-06), wev-005 (2026-11-10), wev-006 (2026-11-06), wev-007 (2026-11-07), wev-117 (2026-11-08), wev-009 (2026-11-08), wev-010 (2026-11-08), wev-012 (2026-11-10).

### Om te weten: uitverkocht

Op de pagina uitverkocht, en dus `sold_out`: wev-006, wev-016, wev-023, wev-027, wev-035, wev-095, wev-099, wev-100, wev-101, wev-104, wev-143. wev-143 staat in het overzicht als `unknown`, maar de pagina zegt uitverkocht met wachtlijst. De app toont dit nog niet als label; dat stond al als apart productwerk op de lijst.

## 6. Status

**Gestopt voor goedkeuring.** Productie is niet gewijzigd. Geen migratie, geen foto's, geen catalogusrij.
