# Negen Europese landen: MICHELIN-sterren en Keys (2026-11-04)

Status: **getest op een scratch-database, nog niet toegepast op productie.** De product owner heeft op 2026-11-04 de 54 restaurants, de 21 hotels en alle voorstellen hieronder geaccepteerd. Voor productie is nog een apart akkoord nodig.

Toepassen, in deze volgorde:

1. `supabase/migrations/20261101300000_add_europe9_2026_countries_and_cities.sql` (4 landen, 35 plaatsen), met `supabase db push --linked`.
2. `prepared_europe9_2026.sql` (één transactie; breekt af bij elke mislukte controle), met `supabase db query --linked -f <absoluut pad>`.

**Griekenland:** die sessie heeft migratie `20261101290000` op een eigen branch, nog niet toegepast. Wordt deze eerst toegepast, dan heeft de Griekse straks `db push --include-all` nodig.

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

## Apart behandeld (in het controlebestand: `HELD BACK`)

| Rij | Productie | MICHELIN | Wat er aan de hand is | Besluit | Issue |
|---|---|---|---|---|---|
| HU `rest_0427` Platán Gourmet | 2 sterren | geen | Gestopt volgens de eigen site; MICHELIN-pagina geeft 404 | Rij bewaren, sterren NULL, status gesloten, 2 sterren als geschiedenis | QA-450 |
| HU `hotel_277` Párisi Udvar | 2 Keys | 1 | Importfout: 1 Key in 2025 en 2026 | Rij van 2026 ter plekke corrigeren (QA-384) | QA-451 |
| RS `hotel_280` The Bristol Belgrade | 1 Key | 2 | Echte wijziging in 2026 | 1 Key wordt 2025, nieuwe rij 2026 (QA-383) | QA-452 |
| SI `hotel_301` Peterc Vineyard Estate | 1 Key | geen | Key kwijt in 2026 | Hotel blijft, `michelin_keys` NULL (QA-387) | QA-453 |
| SI `hotel_305` Nebesa Chalets | 1 Key | geen | Key kwijt in 2026 | Hotel blijft, `michelin_keys` NULL (QA-387) | QA-453 |
| HR `hotel_260` Villa Dubrovnik | 1 Key | 2 | Echte wijziging in 2026 | 1 Key wordt 2025, nieuwe rij 2026 (QA-383) | QA-454 |
| HR `hotel_267` Palace Elisabeth Hvar | 2 Keys | 1 | Echte wijziging in 2026 | 2 Keys wordt 2025, nieuwe rij 2026 (QA-383) | QA-454 |

De twee Kroatische rijen stonden niet in de opdracht. De verdeling verbergt ze, omdat de wijzigingen elkaar opheffen.

## Besloten op 2026-11-04

1. **Toevoegen:** de 54 restaurants en 21 hotels, met 4 landen en 35 plaatsen.
2. **Apart behandelde rijen:** alle zeven volgens de tabel hierboven.
3. **Editiejaar (QA-455):** nieuwe rijen krijgen het jaar van de pagina (Hongarije 2025, de rest 2026). Stand blijft op 2026.
4. **Plaatsnamen (QA-458):** MICHELIN's schrijfwijze, dus Sibenik, Porec, Korcula, Lasko en Carlsbad.

**Eigen invulling bij Platán Gourmet:** MICHELIN kondigde geen verlies aan en Hongarije heeft nog geen 2026-editie. De 2 sterren worden 2025; de huidige rij is 2026 met lege waarde en lege `announced_on`, en `status_since` blijft leeg, omdat de sluitingsdatum onbekend is.

## Niet meegenomen

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

## Getest (`test_scratch.sh`)

Op een lokale PostgreSQL 17, gevuld met de productie-export. De beperkingen van productie zijn nagebouwd. Docker en PostGIS waren er niet, dus `geography` en de twee ST-functies zijn vervangers.

- **Zonder de migratie:** breekt af, er verandert niets.
- **Met de migratie:** alle negen landen staan op MICHELIN's verdeling; 119 rijen uit de controlebestanden vergeleken zonder verschil; zes koppelingen; de geschiedenis van de zeven rijen klopt.
- **Opnieuw draaien:** het bestand breekt af; de migratie doet niets.
- **Controles:** een hernoemde rij, een gewijzigde Key, een bezette code en een al gevulde URL breken het hele bestand af.
- **Productie ongewijzigd:** een tweede read-only export op 2026-11-04 was gelijk aan de eerste.

**Niet getest:** echte PostGIS, de volledige productie-schema's en de app. De schema-afdruk komt uit de export en de gelezen beperkingen.

## Bij toepassen nog te doen

- Regels in `docs/Architecture/Michelin_Database/CHANGELOG.md` en `docs/Plannnig/CHANGELOG.md`, de status in `qa_issues.csv`, en een controle met een nieuwe export.

## Bestanden

- `controle/<CC>.csv`: elke rij met actie, bron en achtergehouden waarden.
- `rapporten/<CC>.md`: kort rapport per land.
- `match_report.csv`: elke afweging, met issue-id.
- `prepared_europe9_2026.sql`: de wijziging zelf.
- `build_europe9.py`: schrijft de controlebestanden en rapporten uit `_source/`.
- `build_sql.py`: schrijft de migratie en de SQL uit de controlebestanden.
- `test_scratch.sh`, `test_seed.py`, `test_verify.py`: de test.
- `fetch_michelin.py`, `fetch_reviews.py`, `check_sites.py`: halen de bronnen op.
- Gereserveerd: `rest_4100..rest_4153`, `hotel_3100..hotel_3120`, QA-450..QA-459.
