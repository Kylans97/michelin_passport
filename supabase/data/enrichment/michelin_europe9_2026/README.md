# Negen Europese landen: MICHELIN-sterren en Keys (2026-11-04)

Status: **voorbereid, niets toegepast.** Er is geen migratie of SQL geschreven en niets naar productie of `main` gegaan. De controlebestanden wachten op het oordeel van de product owner.

## Resultaat

| Land | Sterren MICHELIN | Sterren productie | Keys MICHELIN | Keys productie | Nieuwe restaurants | Nieuwe hotels | Achtergehouden |
|---|---|---|---|---|---|---|---|
| [CZ](rapporten/CZ.md) | 0/1/8 | 0/0/0 | 0/1/10 | 0/0/0 | 9 | 11 | 0 |
| [HR](rapporten/HR.md) | 0/1/13 | 0/1/0 | 1/1/10 | 1/1/8 | 13 | 2 | 2 |
| [SI](rapporten/SI.md) | 1/1/8 | 1/1/0 | 0/1/4 | 0/1/5 | 8 | 1 | 2 |
| [HU](rapporten/HU.md) | 0/1/8 | 0/2/0 | 0/2/10 | 0/3/9 | 8 | 0 | 2 |
| [MT](rapporten/MT.md) | 0/1/6 | 0/1/0 | 0/1/5 | 0/1/5 | 6 | 0 | 0 |
| [LT](rapporten/LT.md) | 0/0/4 | 0/0/0 | 0/0/2 | 0/0/0 | 4 | 2 | 0 |
| [LV](rapporten/LV.md) | 0/0/2 | 0/0/0 | 0/0/3 | 0/0/0 | 2 | 3 | 0 |
| [EE](rapporten/EE.md) | 0/1/1 | 0/0/0 | 0/1/1 | 0/0/0 | 2 | 2 | 0 |
| [RS](rapporten/RS.md) | 0/0/2 | 0/0/0 | 0/1/3 | 0/0/4 | 2 | 0 | 1 |
| **Totaal** | | | | | **54** | **21** | **7** |

De verdeling is 3/2/1. De live selectie is identiek aan de telling van 31 oktober. De Key-totalen kloppen met MICHELIN's wereldartikel van 18 september 2026.

## Achtergehouden

| Rij | Productie | MICHELIN | Wat er aan de hand is | Voorstel | Issue |
|---|---|---|---|---|---|
| HU `rest_0427` Platán Gourmet | 2 sterren | geen | Gestopt volgens de eigen site; MICHELIN-pagina geeft 404 | Rij bewaren, sterren NULL, status gesloten, 2 sterren als geschiedenis | QA-450 |
| HU `hotel_277` Párisi Udvar | 2 Keys | 1 | Importfout: 1 Key in 2025 en 2026 | Rij van 2026 ter plekke corrigeren (QA-384) | QA-451 |
| RS `hotel_280` The Bristol Belgrade | 1 Key | 2 | Echte wijziging in 2026 | 1 Key wordt 2025, nieuwe rij 2026 (QA-383) | QA-452 |
| SI `hotel_301` Peterc Vineyard Estate | 1 Key | geen | Key kwijt in 2026 | Hotel blijft, `michelin_keys` NULL (QA-387) | QA-453 |
| SI `hotel_305` Nebesa Chalets | 1 Key | geen | Key kwijt in 2026 | Hotel blijft, `michelin_keys` NULL (QA-387) | QA-453 |
| HR `hotel_260` Villa Dubrovnik | 1 Key | 2 | Echte wijziging in 2026 | 1 Key wordt 2025, nieuwe rij 2026 (QA-383) | QA-454 |
| HR `hotel_267` Palace Elisabeth Hvar | 2 Keys | 1 | Echte wijziging in 2026 | 2 Keys wordt 2025, nieuwe rij 2026 (QA-383) | QA-454 |

De twee Kroatische rijen stonden niet in de opdracht. De verdeling verbergt ze, omdat de wijzigingen elkaar opheffen.

## Te beslissen

1. **Toevoegen:** mogen de 54 restaurants en 21 hotels erin, met de 4 landen en 35 plaatsen die ze nodig hebben?
2. **Achtergehouden rijen:** elke rij hierboven volgens voorstel, of anders?
3. **Editiejaar (QA-455):**
   - Hongarije staat bij MICHELIN nog op 2025, maar Stand staat in productie op `guide_year` 2026.
   - Tsjechië heet in MICHELIN's artikel "2025", terwijl de pagina's 2026 zeggen.
   - Voorstel: het jaar van de pagina voor nieuwe rijen, en Stand ongemoeid laten.
4. **Plaatsnamen (QA-458):** MICHELIN schrijft Sibenik, Porec, Korcula en Lasko zonder diakrieten. Voorstel: overnemen zoals eerdere passes, tenzij je Šibenik, Poreč, Korčula en Laško wilt.

## Niet voorgesteld

- **Demo, Vilnius (QA-456):** het artikel van 5 juni 2026 noemt een ster, maar de live lijst niet en de pagina geeft 404.
- **Place ID's (QA-457):** deze sessie had geen toegang tot Google.
- **Telefoon en website van nieuwe hotels (QA-457):** MICHELIN's hotelpagina's hebben geen websitelink. MICHELIN's telefoonnummer staat wel in het controlebestand, maar is niet bevestigd op een eigen site.
- **Telefoon van 9 nieuwe restaurants en website van 3 (QA-457):** niet bevestigd op de eigen site; zie `match_report.csv`.
- **Website van Milka (QA-457):** de link gaf een HTTP 500.
- **Hotelkoppeling op alleen afstand of "een hotel" (QA-459):** zes gevallen, gelogd. Koppelingen en `property_name` staan er alleen waar MICHELIN's tekst het hotel noemt.

## Bronnen

- **Live selectie:** sterrenlijsten `/en/{cc}/restaurants/all-starred` en hotellijsten `/en/hotels-stays/{land}`, plus elke pagina. Tsjechië staat onder `czech-republic`.
- **Edities:** MICHELIN's eigen artikelen in `_source/articles/`.
- **Keys van 2025:** MICHELIN's Hongaarse artikel van 8 oktober 2025 en kopieën van MICHELIN's lijsten in het Internet Archive van 16, 17 en 22 oktober 2025 (`_source/wayback/`). Die kopieën zijn geen live bron; ze dienen alleen om een wijziging van een importfout te onderscheiden.
- **Sluiting Platán Gourmet:** de eigen site, `_source/pages/platangourmet_com.html`. Dit is de enige niet-MICHELIN-bron voor een achtergehouden rij.
- **Productie:** read-only export, `export_europe9_query.sql`.

## Identiteit

Bestaande rijen zijn gekoppeld op MICHELIN's id als de URL is opgeslagen. Anders telt het dichtstbijzijnde punt in hetzelfde land: binnen 150 m en duidelijk dichterbij dan het op één na dichtstbijzijnde. Een grens van 500 m bleek te ruim: in Valletta liggen drie Key-hotels binnen die afstand van elkaar. Er is nergens op naam gematcht.

## Getest en niet getest

- **Gecontroleerd:** de controlebestanden bevatten precies dezelfde ids en waarden als de telling van 31 oktober, geen dubbele codes en de Key-totalen uit het wereldartikel.
- **Niet getest:** er is geen SQL, dus ook geen proefdraai.

## Na toestemming

Nog te maken, en pas dan te testen op een scratch-database:

1. Een migratie voor `countries` (CZ, LT, LV, EE met tijdzone) en de 35 plaatsen, genummerd na de hoogste bestaande migratie.
2. Een `prepared_*.sql` volgens `michelin_pl_tr_2026/`.
3. De regels in `docs/Architecture/Michelin_Database/CHANGELOG.md`, die in deze pass bewust niet is aangeraakt.

## Bestanden

- `controle/<CC>.csv`: elke rij met actie, bron en achtergehouden waarden.
- `rapporten/<CC>.md`: kort rapport per land.
- `match_report.csv`: elke afweging, met issue-id.
- `build_europe9.py`: schrijft de controlebestanden en rapporten uit `_source/`.
- `fetch_michelin.py`, `fetch_reviews.py`, `check_sites.py`: halen de bronnen op.
- Gereserveerd: `rest_4100..rest_4153`, `hotel_3100..hotel_3120`, QA-450..QA-459.
