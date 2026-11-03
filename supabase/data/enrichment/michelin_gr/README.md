# Griekenland: MICHELIN-sterren, Key-hotels en World's 50 Best (2026-11-04)

Status: **onderzoek, ter goedkeuring.** Er is geen migratie of SQL geschreven en niets
naar productie gegaan. De productiestand is alleen gelezen.

## Conclusie

Het gat is echt. Griekenland heeft bij MICHELIN 20 sterrenrestaurants en 74 Key-hotels.
Productie heeft 0 restaurants, 1 hotel en 1 stad.

| | Bron (live, 2026-11-04) | Productie nu | Ontbreekt |
|---|---|---|---|
| Sterren (3/2/1) | 0/1/19 = 20 | 0 | **20** |
| Keys (3/2/1) | 1/9/64 = 74 | 1/0/0 = 1 | **73** |
| World's 50 Best Restaurants, 1-100 | geen Griekse vermelding | geen | 0 |
| World's 50 Best Hotels 2026, 1-100 | Four Seasons Astir Palace, plek 27 | zelfde | 0 |
| Steden | 21 nodig | Athens | **20** |
| `award_history` | | 0 rijen voor GR | **94** |

De totalen kloppen met MICHELIN's eigen publicaties:

- **Sterren:** de persmededeling van 23 oktober 2026 noemt 1 tweesterren- en 19
  eensterrenrestaurants. De acht restaurants die zij als nieuw noemt, staan allemaal op de lijst.
- **Keys:** het wereldartikel van 18 september 2026 noemt "Greece – 74 Key hotels".

## Wat al klopt

`hotel_716` Four Seasons Astir Palace Hotel Athens:

- 3 Keys, gelijk aan MICHELIN.
- Het opgeslagen punt ligt 57 m van MICHELIN's pin.
- World's 50 Best 2026 plek 27 klopt.

Het hotel heeft alleen **geen enkele rij in `award_history`**. Die moet erbij: 2026, 3 Keys.

## Wat een migratie zou toevoegen

Pas na goedkeuring:

1. **20 steden.** Zie `gr_new_cities.csv`.
2. **20 restaurants** met `inclusion_reason = 'michelin_star'`, plus een huidige rij in
   `award_history`: `guide_year` 2027, aangekondigd op 2026-10-23.
3. **73 Key-hotels**, plus een huidige rij: `guide_year` 2026, aangekondigd op 2026-09-18,
   zoals de andere landen.
4. **De ontbrekende award-rij** voor `hotel_716`.
5. **1 koppeling:** Pelagos naar `hotel_716`. MICHELIN noemt het hotel in de recensie en
   beide pagina's geven Apollonos 40.
6. **`property_name` op 6 restaurants** waarvan het hotel geen Key heeft:

| Restaurant | `property_name` | Bewijs |
|---|---|---|
| Lycabettus | Andronis Luxury Suites | persmededeling en recensie |
| Lauda | Andronis Boutique Hotel | recensie, zelfde telefoonnummer |
| Patio | The Margi | recensie, zelfde adres |
| SENSE | AthensWas | recensie, zelfde adres |
| The Zillers Rooftop Gastronomy | The Zillers, Athens | zelfde adres en telefoonnummer |
| Tudor Hall | King George | alleen de eigen site: beslispunt 2 |

Restaurants krijgen ook:

- **Website:** alle 20. MICHELIN's link laadt en noemt het restaurant.
- **Telefoon:** 16 van de 20, alleen als het nummer op de eigen site staat.

Rijcodes worden pas bij de migratie toegekend, omdat andere sessies ook nummers reserveren.

## Achtergehouden

- **Geen Google Place IDs** voor de 93 nieuwe rijen (QA-431, gereserveerd). Er is in deze sessie
  geen Places-sleutel, dus dit is niet gecontroleerd. Ze blijven leeg tot een aparte
  `find-place-id`-ronde. QA-430 is gereserveerd voor de import zelf; beide gaan pas bij de
  migratie in `qa_issues.csv` en de changelog.
- **4 telefoonnummers van restaurants** (Pelagos, Lauda, Soil, Delta): MICHELIN's nummer
  staat niet op de eigen site.
- **Alle telefoonnummers en websites van de 73 hotels.** MICHELIN's hotelpagina's hebben geen
  websitelink en de nummers zijn niet tegen een eigen site gecontroleerd. Enkele lijken een
  hoofdkantoor of een fout, zie de kolom `uncertain` (onder meer Numo, Domes Zeen, Porto Zante).
- **Het telefoonnummer van `hotel_716`.** MICHELIN geeft +30 21 0890 1040, Google
  +30 21 0890 1000.
- **Koppelingen van Botrini's Santorini en Selene aan een Katikies-hotel.** Beide sites horen
  bij Katikies Hotels en Selene deelt het adres met Katikies Garden Santorini, maar MICHELIN
  zegt niet dat ze in dat hotel zitten.
- **Spondi, World's 50 Best 2013 plek 97.** Een eerdere ronde parkeerde deze rij omdat
  Griekenland geen restaurants had. De bron is niet opnieuw bekeken.
- **Eerdere edities.** Twaalf restaurants hadden al een ster vóór 2027. Die jaren zijn niet
  onderzocht, dus er komt alleen een rij voor 2027.

Buiten de scope en dus niet opgenomen: 10 Bib Gourmand en 32 Recommended-restaurants, en de
205 Griekse hotelkaarten zonder Key.

## Bijna-fouten

- **Andronis:** Lycabettus en Lauda zitten in Andronis-hotels zonder Key. Andronis Arcadia en
  Concept hebben wel een Key, maar zijn andere hotels. Daarom `property_name`, geen koppeling.
- **SENSE:** productie heeft al een Sense in Vught met dezelfde slug. Dat is een ander land,
  id en punt. Een match op naam of slug alleen zou hier fout gaan.
- **Restaurantlijst op hotelpagina's:** dat is nabijheid, geen relatie. Pelagos staat ook bij
  One&Only Aesthesis, en Kos-hotels tonen restaurants in Bodrum. Geen enkele koppeling rust hierop.
- **Key-hotels die dicht bij elkaar liggen** hebben aparte MICHELIN-id's en zijn geen duplicaten.
- **Euphoria Retreat, Myconian Utopia Resort en Amazon Suites:** deze staan in MICHELIN's
  Key-artikel over 2025 maar hebben nu geen Key. Ze staan niet in `hotels`, dus ze vallen
  buiten de scope en worden niet toegevoegd.

## Beslispunten

1. **Crete als stad (6 hotels).** MICHELIN geeft als plaats alleen het eiland, zoals bij
   Santorini en Mykonos. Advies: zo overnemen, want de adressen zijn te ongelijk om een
   plaats af te leiden.
2. **Tudor Hall → `property_name` King George.** Dit rust op de eigen site ("On the 7th Floor
   of King George"). MICHELIN's recensie zegt alleen "a hotel". Advies: overnemen.
3. **Kastri en Mouzaki als stad.** Bij Tainaron Blue Retreat en Montanema geeft MICHELIN een
   regio als plaats (Peloponnese, Thessaly). Ik gebruik de plaats uit het adres. Advies:
   overnemen.

## Wat niet is getest of vastgesteld

- **Editie van de Keys:** hotelpagina's geven geen jaartal. Het jaar 2026 volgt uit de
  publicatiedatum van het wereldartikel en de conventie op productie.
- **World's 50 Best Restaurants:** de pagina toont bijschriften met 2025 en geen koptekst met
  een editie. Productie staat ook op 2025. Of er al een lijst van 2026 is, is hier niet vastgesteld.
- **World's 50 Best Hotels 2023:** plek 35 op productie komt uit een secundaire bron en is niet
  opnieuw gecontroleerd.
- **Adressen:** veel Griekse adressen zijn alleen een gebied ("Oia") en een paar staan deels in
  het Grieks. De pin van MICHELIN is het sterkste locatiegegeven.
- **Sitecontrole:** "noemt het restaurant" is een tekstcontrole op één pagina.
- **Keuken:** MICHELIN's waarde staat in het controlebestand maar is niet aan `cuisines` gekoppeld.
- **SQL:** er is nog geen SQL, dus ook niets op een testdatabase gedraaid.

## Bestanden

- **`gr_control.csv`:** per kandidaat de bron, vaststelling, onzekerheid (`uncertain`) en de
  verplichte kolommen uit `PROVENANCE_SCHEMA.md`. `match_method = none_new_row` is hier toegevoegd
  voor rijen zonder bestaande productierij.
- **`gr_new_cities.csv`:** steden met het aantal rijen.
- **`build_gr_control.py`:** bouwt beide uit `_source/` en stopt als een telling of award afwijkt.
- **`fetch_michelin.py` en `check_sites.py`:** ophalen en sitecontrole.
- **`_source/`:** de ruwe MICHELIN-gegevens, de lijsten van the50.com en de productie-export
  van 2026-11-04, beperkt tot GR.

Bronnen:
[persmededeling MICHELIN](https://www.michelin.com/en/publications/products-and-services/the-michelin-guide-athens-thessaloniki-santorini-2027),
[sterren Griekenland](https://guide.michelin.com/en/gr/restaurants/all-starred),
[hotels Griekenland](https://guide.michelin.com/en/hotels-stays/greece),
[Key-artikel 2026](https://guide.michelin.com/us/en/article/travel/all-the-key-hotels-in-the-world-michelin-guide),
[50 Best Restaurants](https://www.the50.com/restaurants/best-in-the-world/list/1-50),
[50 Best Hotels](https://www.the50.com/hotels/best-in-the-world/list/1-50).
