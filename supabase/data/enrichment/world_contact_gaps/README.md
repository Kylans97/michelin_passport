# Wereld: ontbrekende telefoons, websites en Place IDs (nachtronde 2026-11-04)

**Status: TOEGEPAST op productie op 2026-11-05.** Alle 41 bestanden zonder fout. Gevuld: 300 Place IDs, 394 telefoons, 262 websites; per land gelijk aan `progress.csv`. Controle achteraf, rij voor rij tegen een read-only momentopname van vlak voor het toepassen: alle 5769 rijen in beide tabellen vergeleken; geen rij erbij of weg; geen naam of land gewijzigd; geen bestaande waarde overschreven; geen dubbele Place ID binnen een tabel. Als controle is die rij-voor-rij-vergelijking gebruikt in plaats van `export_world_contact_gaps_query.sql` opnieuw te draaien.

## Bron en omvang

De bron is `world_contact_gaps_export_20261104.json`: een read-only export van productie van
2026-11-04 22:10 UTC (`export_world_contact_gaps_query.sql`). De export telt 1130 rijen in 54 landen.

- **Griekenland (78 rijen) is overgeslagen.** Dat is al voorbereid in `../michelin_gr/` (QA-431).
- **Alle andere 1052 rijen zijn beoordeeld.** Elk land staat op `klaar` in `progress.csv`.
  Klaar betekent: elke rij heeft per veld een status en een reden. Het betekent niet dat elk gat
  gevuld is.

Place IDs zaten eerst niet in de opdracht. Ze zijn op verzoek van de product owner meegenomen
(bericht tijdens de ronde, 2026-11-04). Dat geldt alleen voor rijen zonder Place ID en nooit
voor het vasteland van China.

## Totalen

Een waarde telt alleen als `confirmed`. Al het andere is achtergehouden, met de reden in de CSV.

| | Gevuld | Gat | |
|---|---|---|---|
| Place ID | **300** | 557 | 125 daarvan in CN, bewust niet gezocht |
| Telefoon | **394** | 986 | |
| Website | **262** | 731 | |
| Gesloten, niets gevuld | 13 rijen | | QA-465 |

Per land:

| Land | Rijen | Place ID | Telefoon | Website | Gesloten |
|---|---|---|---|---|---|
| JP | 272 | — | 131/266 | 163/267 | 2 |
| US | 175 | 127/161 | 86/167 | 19/86 | |
| CN | 128 | 0/125 | 0/127 | 0/90 | |
| GR | 78 | overgeslagen | | | |
| MX | 53 | 37/52 | 13/43 | 13/34 | |
| IT | 50 | 0/16 | 20/49 | 1/32 | |
| TW | 42 | 32/38 | 22/42 | 0/25 | |
| DE | 28 | 0/7 | 4/28 | 0/10 | 3 |
| FR | 26 | 2/13 | 2/19 | 5/15 | 5 |
| HK | 25 | 19/20 | 15/24 | 4/11 | |
| TR | 24 | 19/24 | 16/24 | 8/22 | |
| CA | 20 | 19/20 | 11/19 | 3/9 | |
| GB | 20 | — | 2/20 | 0/1 | |
| BE | 14 | 0/2 | 2/9 | 5/13 | 3 |
| ES | 14 | 0/3 | 4/11 | 0/8 | |
| AT | 13 | 0/6 | 7/13 | 0/11 | |
| CZ | 13 | 12/13 | 9/13 | 5/11 | |
| EG | 13 | 8/13 | 8/13 | 6/13 | |
| NO | 12 | — | 3/12 | 1/1 | |
| SG | 10 | — | 6/9 | 3/6 | |
| CH | 9 | 0/7 | 0/8 | 1/9 | |
| AE | 7 | — | 3/6 | 3/4 | |
| PT | 7 | 0/4 | 0/7 | 0/4 | |
| TH | 7 | — | 2/2 | 4/5 | |
| PE | 6 | 2/2 | 2/2 | 3/6 | |
| HR | 5 | 5/5 | 4/5 | 3/4 | |
| MO | 5 | 1/4 | 0/5 | 0/1 | |
| PL | 5 | 4/5 | 3/5 | 1/3 | |
| SI | 4 | 2/2 | 1/3 | 2/2 | |
| HU, LV | 3 + 3 | 2/2, 3/3 | 3/3, 2/3 | 1/2, 2/3 | |
| BR, DK, ME, NL, SE | 3 elk | NL 0/1 | 0, 1/3, 1/3, 0/2, 0/2 | 1/3, 0/1, 0/1, 0/3, 1/2 | |
| AU, EE, IN, KR, LT, RS | 2 elk | | zie `progress.csv` | | |
| AD, AR, AW, BL, CL, CO, FI, ID, IE, IS, MT, MV | 1 elk | | zie `progress.csv` | | |

## Methode

De scripts staan in `scripts/`, de regels bovenaan `scripts/build_contact_fill.py`. Alles is
fill-only: er wordt alleen geschreven waar het veld NULL is.

**Bronnen**
- **MICHELIN:** elke opgeslagen `michelin_url` is opgehaald, 2,5 s tussen verzoeken.
  - Een pagina telt pas als ze bij de rij hoort: hetzelfde land, en de postcode of het huisnummer
    plus straat komt overeen.
  - Vijf pagina's met hetzelfde adres in een andere schrijfwijze zijn met de hand goedgekeurd.
    Ze staan met reden in `scripts/parse_michelin.py`.
  - Hotelpagina's van MICHELIN hebben nooit een websitelink.
- **Google:** Place Details van het opgeslagen Place ID.
  - Niet gebruikt als het record meer dan 500 m van het opgeslagen punt ligt.
  - Niet gebruikt als een hotel geen lodging-record heeft.
- **Eigen site:** één gewone GET per site, plus maximaal drie contact- of toegangspagina's.

**Website**
- MICHELIN's link en het Google-record wijzen naar hetzelfde domein, of de site laadt en noemt
  de zaak in de titel of de URL.
- Een vermelding alleen ergens in de tekst telt niet, want dat kan een groeps- of hotelsite zijn.
- Nooit een boekings-, aggregator-, gids- of social-medialink. Ook geblokkeerd: gorp.jp,
  myconciergejapan, tableall, pocket-concierge en vergelijkbare diensten.
- Trackingparameters (`utm_…`, `SEO_id=GMB…`) zijn verwijderd.

**Telefoon**
- MICHELIN en Google geven hetzelfde nummer, of het nummer staat op de eigen site.
- Geven MICHELIN en Google een ander nummer, dan telt een treffer op de site alleen voor het
  nummer van MICHELIN.
- Een restaurant in een hotel krijgt alleen een nummer dat op zijn eigen pagina staat, en nooit
  een nummer dat alleen van Google komt. Als "in een hotel" telt: `property_name`, een "Stay at"-blok
  bij MICHELIN, of een dining-pagina op een hotelsite.
- Hotels: gratis nummers, 0570 en andere centrale nummers, en nummers uit een ander land worden
  achtergehouden. Hetzelfde geldt als de eigen site andere nummers toont maar dit niet (QA-461).
  Als de site niet leesbaar is, is MICHELIN plus Google genoeg; de reden zegt dan
  "own site not readable".
- Hetzelfde nummer voor twee rijen, of een restaurantnummer dat gelijk is aan een hotelnummer:
  beide achtergehouden.
- Het formaat is dat van productie: Google's internationale vorm, en `+1`-nummers met spaties.

**Place ID**
- Text Search op "naam stad", rond het opgeslagen punt. Voor hotels ook een zoekopdracht op
  alleen lodging.
- De naam moet minstens 0,8 overeenkomen. Een gedeeltelijke match telt alleen met twee
  onderscheidende woorden, of als de extra woorden de stad of generieke woorden zijn.
- Het record moet van het juiste type zijn, en binnen 100 m liggen, of binnen 500 m met
  MICHELIN's officiële domein.
- Twee kandidaten die allebei voldoen, of een record dat CLOSED_PERMANENTLY is: achtergehouden.
- In China is niet gezocht.

**Gesloten**
Meldt Google CLOSED_PERMANENTLY, dan is voor die rij niets gevuld. CLOSED_TEMPORARILY wordt
alleen genoteerd.

## Bijna-fouten (QA-471)

In de eerste versie zaten vier regels die foute waarden zouden schrijven. Steekproeven vonden ze
alle vier, en alles is opnieuw opgebouwd:

1. **Raffles London.** Mauro Colagreco kreeg `+44 20 3907 7500`, een nummer uit de voettekst van
   het hotel. MICHELIN geeft `…7520`. Dezelfde regel gold voor PRUNIER (Tokyo Kaikan) en voor
   Les Saisons, Torakuro en ESTERRE.
2. **Naam-insluiting.** "Sushi Inaba" werd gekoppeld aan het record "Inaba Japanese Restaurant"
   op 80 m.
3. **Te brede blokkadelijst.** `roccofortehotels.com` en `bulgarihotels.com` werden geblokkeerd
   als "hotels.com", en `auberge*.com` als "uber".
4. **Gesplitste Google-naam.** Uit "Kikunoi Sushi Aoi / Niku Unshuu" kreeg Kikunoi Sushi Ao de
   site van Niku Unshuu.

Er is nog een bijna-fout gevonden. Toen een land na aanscherping niets meer te schrijven had (ID),
bleef het oude SQL-bestand staan met één waarde die de CSV niet meer bevestigde. Dat bleek uit
een telling: 957 geschreven tegen 956 bevestigd. De generator verwijdert zo'n bestand nu.

## Bevindingen

- **QA-464:** twee opgeslagen MICHELIN-URL's wijzen naar een ander restaurant in een ander land:
  Sushi Sho (US) naar Stockholm, en Sense (NL, Vught) naar Athene.
- **QA-465:** 13 rijen zijn gesloten volgens Google. Bij 8 daarvan is ook de MICHELIN-pagina weg.
  Bij JP Den is het mogelijk een oud adres.
- **QA-466:** 8 MICHELIN-pagina's geven 404 terwijl Google de zaak als open toont.
- **QA-467:** bij 11 opgeslagen Place IDs ligt het record 0,5–3,6 km van het opgeslagen punt
  (vooral World's 50 Best in Zuid-Amerika).
- **QA-468:** bij 72 rijen ligt het enige record met dezelfde naam 100 m tot 12 km van ons punt.
  Er is dan geen Place ID voorgesteld. Voor hotels is 100–500 m nooit haalbaar, omdat MICHELIN's
  hotelpagina's geen domein geven. Een voorstel voor een regel staat in de QA-regel.
- **QA-469:** productie heeft bij 5 rijen een boekings- of Instagramlink als website. Die zijn
  niet aangeraakt (fill-only).
- **QA-470:** JL Studio (TW) heeft bij MICHELIN een ander adres.

**Patronen**
- **China:** MICHELIN geeft een telefoon maar bijna nooit een website, en Google is daar
  onbruikbaar. Met de regel "één bron = achterhouden" komt China op 0.
- **JP:** restaurants hebben geen MICHELIN-URL in productie. Daar kan alleen Google plus de
  eigen site, met de Japanse naam van Google in de titel van de site.
- **Hotelketens:** Marriott, Hyatt, Four Seasons, Rocco Forte en IHG weigeren automatische
  verzoeken met 403 (193 sites). Die websites zijn achtergehouden.

## Wat niet getest is

- **Getest** (`tests/`): elk SQL-bestand (41; landen zonder bevestigde waarde hebben geen bestand)
  is op een lokale Postgres 16 gedraaid, gevuld uit de export.
  - Toepassen slaagt en schrijft precies wat de CSV bevestigt: 956 waarden.
  - Een tweede run verandert niets.
  - Een hernoemde rij laat het bestand stoppen zonder wijziging.
  - Alle 41 na elkaar slagen, zonder botsing tussen landen.
- **Niet getest: botsingen met Place IDs buiten de export.** De scratch-database bevat alleen de
  gap-rijen. Productie heeft meer rijen met Place IDs. De SQL-guard stopt het hele bestand als een
  Place ID al bij een andere rij in dezelfde tabel staat. Dat is veilig, maar kan een land
  blokkeren.
- **Niet getest:** het echte schema (constraints, triggers, RLS). De scratch-tabellen hebben alleen
  de kolommen die de SQL raakt.
- **Sites met 403:** niet opnieuw geprobeerd met een browser. Die aanpak is in deze sessie geweigerd
  als omzeiling van botbeveiliging. Sites met 000, 429 of 503 zijn één keer rustig opnieuw
  geprobeerd: 19 laadden toen wel.
- **Telefoonnummers op sites:** die worden met een patroon uit de tekst gehaald. Ruis, zoals cijfers
  uit scripts, kan bij hotels een terechte overeenkomst van MICHELIN en Google onnodig laten
  achterhouden, met de reden "site prints other numbers". Het kan geen nummer toevoegen dat niet ook van MICHELIN of Google komt.
- **Google:** de API-sleutel was aanwezig. Er zijn 789 Place Details-aanroepen en 677 Text
  Search-aanroepen gedaan. Er staat geen sleutel in de bestanden; dat is per commit gecontroleerd.
- **Ruwe HTML:** niet bewaard in de repo. Het gaat om ongeveer 2.000 pagina's; ze stonden in de
  scratchmap van de sessie. Wel bewaard: `michelin_pages_parsed_20261104.json`,
  `sites_index_20261104.json` (status per site) en de ruwe Google-antwoorden.
- **QA-nummers:** de gedeelde notities waren in deze container niet bereikbaar. QA-464 t/m QA-471
  volgen op de hoogste id op alle branches (QA-463). **Controleer ze tegen de gedeelde notities.**
- **Changelog:** `docs/Plannnig/CHANGELOG.md` is niet aangepast. Er is geen bestaand script of
  schema gewijzigd; alleen nieuwe scripts in deze map.

## Toepassen (niet gedaan)

Per land `prepared_<cc>_contact_fill.sql`, in willekeurige volgorde. Elk bestand is één transactie
en mag opnieuw draaien. Evidence per rij staat in `<cc>_contact_fill.csv`: bron, afstand, nummers,
en de reden per veld, ook voor elke achtergehouden waarde.
