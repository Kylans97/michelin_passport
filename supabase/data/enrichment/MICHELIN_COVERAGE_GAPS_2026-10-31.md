# MICHELIN-dekking per land — gaten op 2026-10-31

Inventarisatie, geen import. Er is niets naar productie geschreven en er is
geen migratie gemaakt. Elke landenpass die hieruit volgt is een aparte stap
die eerst goedgekeurd moet worden.

## Kort

- **MICHELIN publiceert op 2026-10-31 3.906 sterrenrestaurants en 2.831
  Key-hotels. In productie staan er 3.439 en 1.816.** Netto ontbreken er
  ongeveer **483 sterrenrestaurants en 1.017 Key-hotels**.
- **Het grootste gat zit niet in de landen waar we niets hebben, maar in
  Japan**: 102 sterren en 27 Keys te weinig, en de verdeling klopt niet
  (61 tweesterren bij MICHELIN, 45 bij ons). Japan heeft nooit een eigen
  2026-pass gehad, de cijfers zijn nog die van de lancering.
- **Portugal, Thailand en Griekenland zijn bijna leeg**: samen 109
  sterren en 206 Keys te weinig.
- **Italië mist 69 Key-hotels** (224 bij MICHELIN, 155 bij ons). Spanje
  mist er 13, Duitsland 4 en België 3. De sterren kloppen daar wel.
- **Nieuw ten opzichte van wat we verwachtten**: MICHELIN geeft nu ook
  sterren in **Australië (11) en Nieuw-Zeeland (15)**, en heeft veel
  Key-hotels in landen zonder sterrengids: Indonesië 47, India 47,
  Zuid-Afrika 32, Marokko 31, Costa Rica 23, Chili 20 en Saoedi-Arabië 17.
- **De lange staart**: in 60 kleine bestemmingen (Caribisch gebied,
  Indische Oceaan, Kaukasus, Centraal-Azië en Afrika) staan nog 185
  Key-hotels. Die kunnen samen in één pass.
- **Ook andersom**: in productie staan **17 sterrenrestaurants** die
  MICHELIN niet meer als sterrenrestaurant toont. Het gaat om FR 6, IT 3,
  BE 3, CH 3, SE 1, plus 1 boekhoudkundig verschil tussen DK en FO, zie
  hieronder. Daarnaast staan **2 Key-hotels** te veel, in ME en SI.
- **Van de 24 vermoede gaten zijn er 23 bevestigd.** Saoedi-Arabië heeft
  nog **geen sterren**. MICHELIN heeft daar 49 restaurants geselecteerd,
  maar zonder ster. Wel zijn er 17 Key-hotels.

## Bron en werkwijze

Alleen MICHELIN's eigen live selecties op guide.michelin.com zijn gebruikt.
Er zijn geen artikelen en geen secundaire totalen gebruikt. Alles is
gelezen in de ingebouwde browser van de desktop-app op **2026-10-31**.

**Sterren.** Per land is `https://guide.michelin.com/en/{cc}/restaurants/all-starred`
gelezen, met alle pagina's (48 per pagina). Elke kaart in de hoofdlijst is
geteld op `data-dtm-distinction` en `data-restaurant-country`. Het blok
"nearby restaurants" onder de lijst is uitgesloten. In elk land klopte het
aantal unieke kaarten precies met MICHELIN's eigen kop ("1-48 of N
restaurants").

- De VAE staan bij MICHELIN onder twee regio-codes: `/en/ae-du/…`
  (Dubai, 20: 2/4/14) en `/en/ae-az/…` (Abu Dhabi, 3: 0/0/3). `/en/ae/…`
  geeft 404.
- 104 ISO-codes zijn geprobeerd. Een 404 betekent dat MICHELIN onder die
  code geen sterren heeft. Voor Saoedi-Arabië is dat apart nagekeken: de
  selectie (49) bestaat, maar zonder ster.
- `/en/ru/…` valt terug op de wereldlijst (3.906) en is niet meegeteld.
- **Controle.** De som per land is 3.905. MICHELIN's wereldlijst
  (`/en/restaurants/all-starred`) toont **3.906**. **Eén sterrenrestaurant
  is niet aan een land toegewezen**. Het zit onder een code die niet
  geprobeerd is, of de wereldteller wijkt af. Niet opgelost.
- Monaco staat los van Frankrijk (cc `mc`). PAZ in Tórshavn staat bij
  MICHELIN onder Denemarken (`dk`, zie de notitie van de CH/AT/Nordics-pass).
  Wij hebben PAZ onder FO. De +1 bij DK en de −1 bij FO zijn dus
  hetzelfde restaurant: **geen echt gat**.

**Key-hotels.** MICHELIN's hotellijst filtert Keys niet server-side
(`?distinction=all-keys` wordt genegeerd, zoals de GB-pass al vond). Daarom
is de complete wereldlijst gelezen: `https://guide.michelin.com/en/hotels-stays`,
alle 198 pagina's, **9.479 unieke hotels**, precies gelijk aan MICHELIN's
kop "of 9,479 Hotels". Per kaart is `data-distinction` gelezen (SELECTED /
ONE_KEY / TWO_KEYS / THREE_KEYS), net als eerdere passes deden, en het land
uit `data-hotel-country`.

- 20 Key-kaarten hadden geen land. Ze zijn met de hand toegewezen op de
  stad die MICHELIN zelf op de kaart zet: Singapore 11, Macau 3,
  Hongkong 1, Noorwegen 3 (Continental, Brosundet, Nusfjord) en
  Roemenië 2 (The Marmorosch Bucharest, Bethlen Estates Transylvania).
- **Controle tegen eerdere, per hotel geverifieerde passes.** US 359, FR 220,
  CH 89, AT 72, CN 54, MX 97, CA 42, NO 16, SE 11, DK 9, IS 5, FI 3, HK 10,
  MO 9 en IE 19 komen precies overeen met wat die passes per hotel
  bevestigden. Dat geeft vertrouwen in de telmethode voor de andere landen.
- De Keys zijn de **wereldwijde Key-selectie 2026** (lancering 18 sep 2026),
  zoals de site die nu toont.

**Productie.** Read-only geteld met
`supabase db query --linked -o csv -f production_counts.sql`. Geteld zijn
`status = 'open'` met `michelin_stars` 1–3 en `michelin_keys` 1–3. Er waren
geen gesloten rijen met een ster of Key, dus open en alle rijen geven
dezelfde aantallen.

**Wat dit niet is.** Dit is een **telling, geen koppeling per restaurant of
hotel**. Een netto verschil van 0 kan wegvallende en nieuwe rijen
verbergen. Zo heeft Hongarije 12 = 12 Keys, maar MICHELIN telt 0/2/10 en
wij 0/3/9. Ook Polen, Slovenië, Montenegro, Servië en Duitsland hebben een
andere verdeling. Elke landenpass moet daarom per record koppelen, op
MICHELIN-URL of op coördinaten. **Matchen op naam mag nooit.**

## Tabel per land

MICHELIN-cijfers live op 2026-10-31. Sterren: `https://guide.michelin.com/en/{cc}/restaurants/all-starred`
(VAE: `/en/ae-du/` + `/en/ae-az/`). Keys: `https://guide.michelin.com/en/hotels-stays`
(wereldlijst, geteld per `data-hotel-country`). "Δ totaal" telt alleen
ontbrekende rijen; te veel staat apart hieronder. Gesorteerd op Δ totaal.
Bestemmingen zonder sterren en met minder dan 10 ontbrekende Keys staan in
de lange staart.

| # | Land | MICHELIN ★ (3/2/1) | Wij ★ (3/2/1) | Δ ★ | MICHELIN Keys (3/2/1) | Wij Keys (3/2/1) | Δ Keys | Δ totaal |
|---|---|---|---|---|---|---|---|---|
| 1 | Japan (JP) | 356 (20/61/275) | 254 (21/45/188) | +102 | 145 (7/23/115) | 118 (6/15/97) | +27 | **129** |
| 2 | Portugal (PT) | 53 (0/9/44) | 1 (0/1/0) | +52 | 69 (2/14/53) | 0 (0/0/0) | +69 | **121** |
| 3 | Thailand (TH) | 43 (2/8/33) | 6 (1/2/3) | +37 | 71 (6/22/43) | 7 (2/4/1) | +64 | **101** |
| 4 | Griekenland (GR) | 20 (0/1/19) | 0 (0/0/0) | +20 | 74 (1/9/64) | 1 (1/0/0) | +73 | **93** |
| 5 | Italië (IT) | 377 (14/37/326) | 380 (15/38/327) | -3 | 224 (17/49/158) | 155 (12/37/106) | +69 | **69** |
| 6 | Australië (AU) | 11 (0/1/10) | 0 (0/0/0) | +11 | 54 (3/9/42) | 4 (0/1/3) | +50 | **61** |
| 7 | Zuid-Korea (KR) | 46 (1/10/35) | 2 (1/0/1) | +44 | 9 (0/3/6) | 0 (0/0/0) | +9 | **53** |
| 8 | Indonesië (ID) | 0 (0/0/0) | 0 (0/0/0) | +0 | 47 (3/11/33) | 2 (2/0/0) | +45 | **45** |
| 9 | Singapore (SG) | 45 (3/9/33) | 5 (3/0/2) | +40 | 11 (1/0/10) | 7 (1/0/6) | +4 | **44** |
| 10 | India (IN) | 0 (0/0/0) | 0 (0/0/0) | +0 | 47 (2/15/30) | 6 (0/4/2) | +41 | **41** |
| 11 | Nieuw-Zeeland (NZ) | 15 (0/1/14) | 1 (0/0/1) | +14 | 28 (0/10/18) | 1 (0/1/0) | +27 | **41** |
| 12 | VAE (AE) | 23 (2/4/17) | 6 (2/0/4) | +17 | 25 (1/5/19) | 2 (1/0/1) | +23 | **40** |
| 13 | Brazilië (BR) | 24 (2/3/19) | 4 (2/1/1) | +20 | 22 (2/3/17) | 3 (2/1/0) | +19 | **39** |
| 14 | Turkije (TR) | 17 (0/2/15) | 4 (0/2/2) | +13 | 23 (1/3/19) | 1 (0/1/0) | +22 | **35** |
| 15 | Vietnam (VN) | 11 (0/0/11) | 0 (0/0/0) | +11 | 21 (2/4/15) | 0 (0/0/0) | +21 | **32** |
| 16 | Zuid-Afrika (ZA) | 0 (0/0/0) | 0 (0/0/0) | +0 | 32 (3/11/18) | 2 (0/2/0) | +30 | **30** |
| 17 | Argentinië (AR) | 14 (0/1/13) | 1 (0/0/1) | +13 | 16 (0/7/9) | 0 (0/0/0) | +16 | **29** |
| 18 | Marokko (MA) | 0 (0/0/0) | 0 (0/0/0) | +0 | 31 (2/6/23) | 2 (1/1/0) | +29 | **29** |
| 19 | Costa Rica (CR) | 0 (0/0/0) | 0 (0/0/0) | +0 | 23 (2/8/13) | 0 (0/0/0) | +23 | **23** |
| 20 | Chili (CL) | 0 (0/0/0) | 0 (0/0/0) | +0 | 20 (2/9/9) | 0 (0/0/0) | +20 | **20** |
| 21 | Tsjechië (CZ) | 9 (0/1/8) | 0 (0/0/0) | +9 | 11 (0/1/10) | 0 (0/0/0) | +11 | **20** |
| 22 | Filipijnen (PH) | 10 (0/1/9) | 0 (0/0/0) | +10 | 9 (0/2/7) | 0 (0/0/0) | +9 | **19** |
| 23 | Maleisië (MY) | 9 (0/1/8) | 0 (0/0/0) | +9 | 9 (0/1/8) | 0 (0/0/0) | +9 | **18** |
| 24 | Saoedi-Arabië (SA) | 0 (0/0/0) | 0 (0/0/0) | +0 | 17 (1/3/13) | 0 (0/0/0) | +17 | **17** |
| 25 | Kroatië (HR) | 14 (0/1/13) | 1 (0/1/0) | +13 | 12 (1/1/10) | 10 (1/1/8) | +2 | **15** |
| 26 | Qatar (QA) | 3 (0/0/3) | 0 (0/0/0) | +3 | 11 (0/4/7) | 0 (0/0/0) | +11 | **14** |
| 27 | Egypte (EG) | 0 (0/0/0) | 0 (0/0/0) | +0 | 13 (0/2/11) | 0 (0/0/0) | +13 | **13** |
| 28 | Spanje (ES) | 296 (16/37/243) | 296 (16/37/243) | +0 | 122 (5/17/100) | 109 (4/10/95) | +13 | **13** |
| 29 | Polen (PL) | 11 (0/1/10) | 1 (0/1/0) | +10 | 14 (0/5/9) | 11 (0/7/4) | +3 | **13** |
| 30 | Cambodja (KH) | 0 (0/0/0) | 0 (0/0/0) | +0 | 12 (0/5/7) | 0 (0/0/0) | +12 | **12** |
| 31 | Malediven (MV) | 0 (0/0/0) | 0 (0/0/0) | +0 | 15 (4/4/7) | 3 (2/1/0) | +12 | **12** |
| 32 | Colombia (CO) | 0 (0/0/0) | 0 (0/0/0) | +0 | 11 (0/3/8) | 0 (0/0/0) | +11 | **11** |
| 33 | Sri Lanka (LK) | 0 (0/0/0) | 0 (0/0/0) | +0 | 12 (1/3/8) | 1 (0/0/1) | +11 | **11** |
| 34 | Slovenië (SI) | 10 (1/1/8) | 2 (1/1/0) | +8 | 5 (0/1/4) | 6 (0/1/5) | -1 | **8** |
| 35 | Hongarije (HU) | 9 (0/1/8) | 2 (0/2/0) | +7 | 12 (0/2/10) | 12 (0/3/9) | +0 | **7** |
| 36 | Litouwen (LT) | 4 (0/0/4) | 0 (0/0/0) | +4 | 2 (0/0/2) | 0 (0/0/0) | +2 | **6** |
| 37 | Malta (MT) | 7 (0/1/6) | 1 (0/1/0) | +6 | 6 (0/1/5) | 6 (0/1/5) | +0 | **6** |
| 38 | Letland (LV) | 2 (0/0/2) | 0 (0/0/0) | +2 | 3 (0/0/3) | 0 (0/0/0) | +3 | **5** |
| 39 | Duitsland (DE) | 338 (12/48/278) | 338 (12/48/278) | +0 | 130 (6/37/87) | 126 (6/31/89) | +4 | **4** |
| 40 | Estland (EE) | 2 (0/1/1) | 0 (0/0/0) | +2 | 2 (0/1/1) | 0 (0/0/0) | +2 | **4** |
| 41 | België (BE) | 124 (2/19/103) | 127 (2/20/105) | -3 | 18 (0/4/14) | 15 (0/2/13) | +3 | **3** |
| 42 | Verenigd Koninkrijk (GB) | 198 (10/23/165) | 196 (10/23/163) | +2 | 131 (9/42/80) | 130 (9/42/79) | +1 | **3** |
| 43 | Servië (RS) | 2 (0/0/2) | 0 (0/0/0) | +2 | 4 (0/1/3) | 4 (0/0/4) | +0 | **2** |
| 44 | Andorra (AD) | 1 (0/0/1) | 0 (0/0/0) | +1 | 4 (0/0/4) | 4 (0/0/4) | +0 | **1** |
| 45 | Denemarken (DK) | 42 (3/7/32) | 41 (3/6/32) | +1 | 9 (0/1/8) | 9 (0/1/8) | +0 | **1** |
| 46 | Luxemburg (LU) | 12 (0/2/10) | 12 (0/2/10) | +0 | 2 (0/1/1) | 1 (0/0/1) | +1 | **1** |
| 47 | Nederland (NL) | 119 (1/20/98) | 119 (1/20/98) | +0 | 18 (1/5/12) | 17 (1/5/11) | +1 | **1** |

**Lange staart: alleen Keys, minder dan 10 per land, 185 hotels in 60
bestemmingen.** Saint-Barthélemy 9 (1/2/6), Kenia 7, Seychellen 7, Georgië 6,
Mauritius 6, Roemenië 6, Bulgarije 5, Bhutan 5, Belize 5, Ecuador 5, Fiji 5,
Guatemala 5, Jamaica 5, Jordanië 5, Kazachstan 5, Frans-Polynesië 5 (1/4/0),
Turks- en Caicoseilanden 5, Uruguay 5, Panama 4 (wij 1), Antigua 4,
Bahama's 4, Dominicaanse Republiek 4, Rwanda 4, Oman 3 (wij 1), Anguilla 3,
Azerbeidzjan 3, Bahrein 3, Cyprus 3, Grenada 3, Kaaimaneilanden 3,
Saint Lucia 3, Namibië 3 (1/2/0), Nepal 3, Tanzania 3, Bermuda 2,
Honduras 2, Koeweit 2, Laos 2 (1/0/1), Puerto Rico 2, Slowakije 2,
Zimbabwe 2, en elk 1 in AM, BB, BJ, BQ, BW, DM, KN, LI, MF, MM, MN, MZ, NI,
TN, UZ, VC, VG, VI en ZM. De exacte verdeling per land staat in
`michelin_coverage_gaps_2026-10-31/coverage_by_country.csv`.

**Gelijk of meer dan MICHELIN.** Gelijk: AT, AW, CA, CN, FI, HK, IE, IS, MC,
MO, MX, NO, PE, TW en US. Bij deze landen staan in productie rijen die
MICHELIN niet meer als sterrenrestaurant of Key-hotel toont:

| Land | Sterren: MICHELIN / wij | Keys: MICHELIN / wij | Wat het waarschijnlijk is |
|---|---|---|---|
| FR | 646 / 652 | 220 / 220 | 6 ingetrokken rijen die al in de FR-2026-pass genoemd zijn |
| IT | 377 / 380 | 224 / 155 | 3 sterren te veel, niet per record nagekeken. Daarnaast ontbreken 69 Keys |
| BE | 124 / 127 | 18 / 15 | 3 sterren te veel, niet per record nagekeken |
| CH | 131 / 134 | 89 / 89 | De live selectie is nog de editie 2025. Wordt opgelost door de CH-2026-pass na 2 nov |
| SE | 23 / 24 | 11 / 11 | 1 ster te veel |
| DK + FO | 42 / 41+1 | 9 / 9 | PAZ staat bij ons onder FO en bij MICHELIN onder DK: geen verschil |
| ME | – | 5 / 6 | 1 Key te veel |
| SI | 10 / 2 | 5 / 6 | 1 Key te veel, en 8 sterren te weinig |

Dit is niet per record nagekeken en hoort bij de pass van het land zelf.
Een rij zonder ster wordt nooit gewist. Ze krijgt een eigen regel in
`award_history`, volgens de bestaande werkwijze.

## Wat niet is bevestigd

- **Eén sterrenrestaurant is niet aan een land toegewezen**: de landen
  samen tellen 3.905, de wereldlijst 3.906. Mogelijke oorzaken: een code die
  niet geprobeerd is (bijvoorbeeld de Kanaaleilanden, Puerto Rico of
  Saint-Barthélemy apart), of een afwijking in MICHELIN's eigen teller.
- **De editie per land is niet nagekeken.** Die staat op elke
  restaurantpagina als `dateAwarded` in de JSON-LD, en die pagina's zijn
  niet geopend. Elke pass moet dat eerst doen (regel QA-217: een launch-rij
  met het label 2026 kan een oudere editie zijn). Bekende gevallen:
  Zwitserland toont nog 2025, en bij de US-gidsen voor de Northeast Cities
  is `dateAwarded` 2025.
- **Totalen per land uit MICHELIN-artikelen zijn niet als bron gebruikt.**
  De FR-Keys-pass liet al zien dat een artikeltotaal kan afwijken van de
  links in datzelfde artikel. De live lijst is hier de bron. Voor JP, PT,
  TH, GR en IT Keys is ook niet vergeleken met een ceremonie-artikel.
- **Bij Keys is het land MICHELIN's veld `data-hotel-country`.** Dat is
  geografisch en niet per gids: BL, MF, PF en AW staan apart. Voor de 20
  kaarten zonder land is het land afgeleid uit de stad op de kaart.
- **De Kanaaleilanden** (Jersey en Guernsey, 2 Keys volgens de GB-pass)
  vallen bij MICHELIN onder `gb`. GB 131 tegen onze 130 kan daardoor
  komen; dat is niet nagekeken.
- **Coördinaten, adressen, Place IDs en de editie** van de ontbrekende
  restaurants en hotels zijn niet gelezen. De twee CSV's hieronder bevatten
  alleen wat op de lijstkaart staat.

## Voorstel voor de volgorde van passes

*Goedgekeurd door de product owner op 2026-10-31.* Die goedkeuring geldt
voor de volgorde. Elke pass afzonderlijk, en elke apply naar productie,
wordt nog steeds apart goedgekeurd.

De volgorde weegt drie dingen: de grootte van het gat, Europa eerst
(events zijn de hoofdpijler en Europees), en hoeveel werk er al klaar ligt.
Een land dat al eerder een pass had, gaat sneller.

1. **Keys bijwerken in IT, ES, DE, BE, NL en LU**: +69, +13, +4, +3, +1 en
   +1, samen 91 hotels. Voor alle zes bestaat al een pass met mappen en
   steden. Dit is het minste werk per hotel, en de verdelingen moeten toch
   per record gekoppeld worden.
2. **Portugal**: +52 sterren en +69 Keys. Het land is bijna leeg, ligt in
   Europa en heeft een eigen gids. `countries` heeft PT al.
3. **Japan**: +102 sterren en +27 Keys, het grootste gat in één land. Eerst
   de editie per gids nakijken (Tokyo, Kyoto/Osaka en de regiogidsen), en
   dan de launch-rijen een nieuw label geven volgens QA-217, vóór er iets
   bijkomt. Dit is de zwaarste pass.
4. **Griekenland en Turkije**: +33 sterren en +95 Keys, beide in Europa.
5. **Centraal- en Oost-Europa in één pass**: CZ, HU, PL, SI, HR, MT, EE, LV,
   LT, RS en AD. Samen +64 sterren en +23 Keys. Er moeten nieuwe
   `countries`-rijen bij voor CZ, EE, LV, LT, RO, BG, CY en SK.
6. **Oost- en Zuidoost-Azië**: TH, SG, KR, VN, MY en PH. Samen +151 sterren
   en +116 Keys.
7. **Australië en Nieuw-Zeeland**: +25 sterren en +77 Keys. Dit zijn nieuwe
   MICHELIN-gidsen, die tot nu toe in geen enkele planning stonden.
8. **Midden-Oosten**: AE, SA, QA, EG, BH, KW, JO en OM. Samen +20 sterren en
   +76 Keys.
9. **Latijns-Amerika**: BR, AR, CR, CL, CO, UY, EC en GT. Samen +33 sterren
   en +104 Keys.
10. **Alleen Keys**: Indonesië, India, Malediven, Sri Lanka, Cambodja,
    Zuid-Afrika en Marokko (+180), daarna de rest van de lange staart (ongeveer 158).

Nieuwe `countries`-rijen zijn ook nodig voor (onder meer) CR, PH, QA, SA,
EG en KH, en voor de meeste landen in de lange staart. Een pass voegt die
rijen toe in zijn eigen migratie, zoals de GB/IE- en US/CA/MX-passes deden.

Codes en QA-ids zijn **niet** geclaimd. Elke pass claimt die zelf in de
gedeelde notities. Volgens die notities is de eerstvolgende vrije QA QA-377.

## Bestanden

In `supabase/data/enrichment/michelin_coverage_gaps_2026-10-31/`:

| Bestand | Inhoud |
|---|---|
| `coverage_by_country.csv` | Per land: MICHELIN en productie, verdeling 3/2/1 en verschil |
| `michelin_starred_live_20261031.csv` | 3.882 sterrenkaarten: MICHELIN-id, pad, land, sterren, naam, stad. Zonder de 23 van de VAE: die zijn alleen geteld |
| `michelin_key_hotels_live_20261031.csv` | 2.831 Key-hotelkaarten: MICHELIN-pid, land, Keys, naam, stad |
| `production_counts.sql`, `production_counts_20261031.csv` | De read-only productiequery en de uitkomst |

De twee MICHELIN-CSV's zijn een momentopname van de lijstkaarten, geen
geverifieerde importbron. Een pass leest de pagina van elk restaurant of
hotel zelf.
