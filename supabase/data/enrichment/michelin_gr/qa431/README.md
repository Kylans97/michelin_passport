# Griekenland: Place IDs, telefoon en website (QA-431)

Status: **VOORBEREID, NIET TOEGEPAST.** Geschreven op 2026-11-03.

`prepared_gr_qa431_fill.sql` is fill-only. Het schrijft alleen in lege velden. Het draait bovenop
`../prepared_gr_2027.sql`, dat op 2026-11-04 is toegepast.

## Conclusie

| | Voorgesteld | Al gevuld | Achtergehouden |
|---|---|---|---|
| Restaurants: Place ID | **20** van 20 | 0 | 0 |
| Restaurants: telefoon | **3** (Delta, Lauda, Soil) | 16 | 1 (Pelagos) |
| Hotels: Place ID | **66** van 73 | `hotel_716` | 7 |
| Hotels: telefoon | **68** van 74 | 0 | 6 + `hotel_716` |
| Hotels: website | **65** van 73 | `hotel_716` | 8 |

Restaurantwebsites stonden al op productie, dus daar is niets nodig.

## Omgeving bij de start

- **`GOOGLE_PLACES_API_KEY`:** gezet. Een testzoekopdracht naar `places.googleapis.com` werkte.
- **`guide.michelin.com`:** proxy-403 (CONNECT geweigerd). Niets in deze ronde komt van MICHELIN's
  site. MICHELIN-gegevens komen uit `gr_control.csv` (gelezen op 2026-11-04).
- **`katikies.com`:** eerst ook proxy-403 met `curl`. Later laadde de sitecontrole (Python, via
  dezelfde proxy) de drie Katikies-hotelpagina's wel. Een nieuwe test van de geblokkeerde hosts
  is daarna niet meer gedaan. Waarom het verschil ontstond, is niet vastgesteld.
- **Andere venue-sites:** bereikbaar. Alleen `https` loopt via de proxy, dus `http://`-links zijn als
  `https://` geopend.

## Methode

Gelijk aan `../../europe_gaps/README.md` en de skill `find-place-id`.

**Place ID**

- Het eigen record van de zaak: een restaurantrecord voor een restaurant, een logiesrecord voor een
  hotel. Een gelijknamige gecombineerde vermelding mag (ERGON House).
- Onder 100 m: aanvaard. 100–500 m: alleen als de website van het record het officiële domein is
  en die site laadt en de zaak noemt. Boven 500 m: afgewezen.
- De afstand is per rij gemeten en staat in `distance_m`.

**Telefoon (hotels)**

Dit wijkt bewust af van "MICHELIN en Google zijn het eens". Die regel had verschillende
hoofdkantoornummers geschreven (QA-461).

1. Het nummer in het zichtbare contactblok van de eigen site.
2. Een lokale hotellijn gaat voor een lijn van een hoofdkantoor of reserveringsdienst.
3. Alleen als de site niet te lezen is: MICHELIN en Google moeten overeenkomen.
4. Spreken de bronnen elkaar tegen zonder beslissende bron: achtergehouden.

**Website**

De site laadt en noemt het hotel. Dat mag de eigen site zijn of de pagina van het hotel op de site
van het merk. Boekingsmachines, dealsites en sociale media worden nooit gebruikt.

## De verdachte nummers uit `uncertain`

| Hotel | MICHELIN | Voorstel | Bewijs |
|---|---|---|---|
| Numo Mykonos | +30 2834 055000 (Kreta) | **+30 2289 071420** | contactblok: "Kalafatis Mykonos 84600 – Greece T: +30 22890 71420". Het Kreta-nummer staat alleen in de JSON-LD |
| Domes Zeen Chania | +30 2310 810624 (Thessaloniki) | **leeg** | eigen pagina geeft alleen centrale reserveringen +30 2312 317000; Google +30 2821 607000 |
| Porto Zante | +30 21 0821 8640 (Athene) | **+30 2695 065100** | "Reservations tel: (+30) 210 8218640 - (+30) 26950 65100". De 26950-lijn is Zakynthos |
| Tainaron Blue Retreat | +30 210 8080049 (Athene) | **+30 697 300 7006** | "T. +30-2108080049 M. +30-6973007006". Het mobiele nummer is ook Google's |
| Boheme Mykonos Town | +30 22894 40360 | **+30 2289 023300** | kop van de site: "H: +302289023300". MICHELIN's nummer staat er ook, maar is ook MICHELIN's nummer voor NOMAD |
| NOMAD Mykonos | +30 22894 40360 | **leeg** | nomadsmykonos.com bestaat niet in DNS. Google +30 2289 072800 |

Hoofdkantoor- of reserveringsnummers zijn ook vervangen bij Cove Paros, The Townhouse Mykonos en
Canaves Sunday (zie `gr_qa431_control.csv`).

## Pelagos, Lauda, Soil, Delta en `hotel_716`

| Rij | Voorstel | Bewijs |
|---|---|---|
| Delta | +30 698 665 7553 | contactpagina: "Tel: 6986657553" |
| Soil | +30 21 0751 3505 | homepage: "+30 210 75 13 505 (landline)" |
| Lauda | +30 2286 186696 | homepage: "Reserve a table (+30) 2286186696", gelijk aan Google. MICHELIN's 072182 staat er niet |
| Pelagos | leeg | pelagosathens.com geeft geen nummer. MICHELIN 1190 en Google 1192 verschillen |
| `hotel_716` | leeg | fourseasons.com geeft 403 (van de site zelf) |

Delta en Soil stonden in de vorige ronde als "niet op de eigen site". Nu staan ze er wel. Het
verschil is niet onderzocht: de nummers staan op een contactpagina of zijn anders opgemaakt.

## QA-432: adressen

Bevestigd op de eigen site. Dit staat **niet in de fill-only SQL**, omdat het een opgeslagen waarde
zou overschrijven. Zie `gr_qa432_qa433_findings.csv`.

| Hotel | Nu | Eigen site |
|---|---|---|
| Erosantorini | postcode 87400 | 84700 ("Messaria 84700 Santorini"; Google ook 847 00) |
| Cove Paros | "Agioi Anargyroi Beach S.A." | "Agioi Anargyroi - Naoussa 84401" |
| Numo Mykonos | alleen "84600 Mykonos" | "Kalafatis Mykonos 84600" |
| Noma Milos | Κήπος | niet vastgesteld: alleen Google geeft "Kipos" |

## QA-433: Selene en Botrini's Santorini

- **Selene:** selene.gr zegt dat het restaurant in "what used to be an 18th century Catholic
  Monastery" zit. De site citeert ook een recensie over "the exquisite historical setting of
  Katikies Garden Hotel, a beautifully converted monastery where ... the culinary distinction of
  the Selene Restaurant". MICHELIN geeft beide "Old Catholic Monastery".
  - Selene's eigen tekst noemt het hotel niet. De expliciete zin is van een derde.
  - Voorstel: een koppeling aan `hotel_3034` als **beslissing voor de product owner**, net als
    Tudor Hall. Deze koppeling staat niet in de SQL.
- **Botrini's Santorini:** de eigen site zegt "The restaurant is located at Katikies Santorini
  hotel". MICHELIN splitst dat hotel in Pelagos House en Gea House, en de site zegt niet welk.
  - Pelagos House ligt in dezelfde straat (123 m). Dat kiezen op nabijheid zou raden zijn.
  - Daarom geen koppeling.
- **De katikies.com-pagina `selene-wine-bar`** uit de aanwijzing is **niet geopend**. Na de
  geweigerde hertest van de geblokkeerde hosts is katikies.com niet opnieuw benaderd.

## Bijna-fouten

- **Twee Istoria's:** istoriahotel.gr heeft Istoria Beach (Perivolos) en Istoria Cliff
  (Firostefani). Het opgeslagen punt is het strandhotel. Google noemt dat "Istoria Beach".
- **Perivolas:** Google heeft twee records. "Perivolas Lifestyle Houses" ligt 924 m weg en linkt
  naar een dealsite. "Perivolas Hotel" ligt 125 m weg, maar die site geeft 403. Daarom achtergehouden.
- **Lauda:** het Google-record heeft ook logies-types, maar draagt de naam van het restaurant en linkt
  naar laudarestaurant.com. Het is dus niet het record van Andronis Boutique Hotel.
- **Lauda, Lycabettus en Domes White Coast:** deze staan in november op CLOSED_TEMPORARILY. Dat is
  seizoensgebonden, geen sluiting.
- **Pelagos:** het record van het restaurant zelf is gebruikt (161 m, met MICHELIN's eigen domein).
  Het record van de Four Seasons is niet gebruikt.
- **Elix, Olea en Palladium:** het juiste record ligt 615–715 m van ons punt (QA-460). Het punt is
  niet aangepast.

## Getest

Getest op een lokale PostgreSQL 16. De database is gevuld met `../test_scratch.py`, daarna kwamen de
GR-migratie en `prepared_gr_2027.sql`. De uitgangsstand gelijkt op productie na 2026-11-04: hotels 1
Place ID, 0 telefoons en 1 website; restaurants 16 telefoons en 20 websites.

- **Eerste run:** hotels 67 / 68 / 66, restaurants 20 / 19 / 20. Alle 92 rijen in de database zijn
  gelijk aan `gr_qa431_fill.csv`.
- **Tweede run:** niets verandert, ook `updated_at` niet.
- **Een al gevulde telefoon, website of Place ID** wordt niet overschreven.
- **Een hernoemde rij** breekt alles af en past niets toe.
- **Een Place ID die al bij een andere rij hoort** breekt alles af en past niets toe.

**Niet getest:**

- **Botsingen met Place IDs van niet-Griekse rijen op productie.** De scratch-database bevat alleen
  Griekenland en deze container heeft geen productietoegang. De repo-exports bevatten geen enkel
  voorgesteld ID. De SQL stopt bij een botsing.
- **Een from-scratch replay op de echte Supabase-stack.** Docker ontbreekt.
- **De app.**

## Bestanden

- **`gr_qa431_control.csv`:** per rij het Google-record, de afstand, het type en de status, plus
  telefoon en website met bron en bewijs. Ook elke achtergehouden waarde staat erin.
- **`gr_qa431_fill.csv`:** de invoer voor `europe_gaps/build_gap_fill_sql.py`.
- **`prepared_gr_qa431_fill.sql`:** de voorbereide SQL, gegenereerd.
- **`gr_qa432_qa433_findings.csv`:** de adressen en koppelingen, alleen als voorstel.
- **`fetch_places.py`, `lodging_search.py` en `check_sites.py`:** het ophalen.
- **`build_qa431.py`:** de beslissingen per rij, met citaten. Het script schrijft de CSV's en de SQL.
- **`places_raw_20261103.json`, `places_followup_20261103.json` en `sites_20261103.json`:** de ruwe
  antwoorden. Er staat geen API-sleutel in.

Nieuwe QA-ids: QA-460 t/m QA-463. De gedeelde notities zijn in deze container niet bereikbaar. De
hoogste id op een andere branch was QA-459 (`claude/michelin-europe9-2026`). **Controleer deze
nummers tegen de gedeelde notities.**
