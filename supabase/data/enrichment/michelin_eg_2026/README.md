# Egypte: MICHELIN Key-hotels (2026-11-04)

Status: **getest op een scratch-database, nog niet toegepast op productie.**

Productie had geen enkele Egyptische rij: geen land, plaats, hotel of restaurant. Egypte heeft 13 Key-hotels (0/2/11) en geen sterrenlijst: `/en/eg/restaurants/all-starred` geeft 404.

## Bronnen

- **Live lijst:** `/en/hotels-stays/egypt` (25 hotels, waarvan 13 met een Key), gelijk aan de telling van 31 oktober.
- **Hotelpagina's:** de Key op elk van de 13 pagina's klopt met de kaart in de lijst.
- **Totaal:** MICHELIN's wereldartikel van 18 september 2026: "Egypt – 13 Key hotels".

## Wat erbij komt

- **Migratie** `20261101370000_add_eg_2026_country_and_cities.sql`: land EG (Africa/Cairo) en 7 plaatsen.
- **`prepared_eg_2026.sql`:** `hotel_3121`..`hotel_3133`, elk met een huidige 2026-rij, aangekondigd 2026-09-18.
- **Controlebestand:** `eg_key_hotels_2026.csv`.

Toepassen op volgorde: `supabase db push --linked`, daarna `supabase db query --linked -f <absoluut pad naar prepared_eg_2026.sql>`.

## Niet meegenomen (QA-460)

- Geen Place ID: geen Google-toegang.
- Geen telefoon of website: alleen MICHELIN als bron. MICHELIN's telefoonnummer staat wel in het controlebestand.
- Geen hotelkoppelingen: er is geen Egyptisch restaurant in de catalogus.

## Bijzonderheden in MICHELIN's gegevens (QA-460)

- St. Regis Cairo heeft postcode 99999, een plaatshouder; die is weggelaten.
- Bij Giza Palace staat een URL in het telefoonveld; die is weggelaten.
- Casa Cook heeft alleen "Hurghada" als straat. Dat is zo overgenomen.
- Plaatsnamen volgen MICHELIN: The Oberoi in Sahl Hasheesh valt onder Hurghada, en Giza Palace in 6th of October City onder Giza.

## Getest (`test_scratch.sh`)

Lokale PostgreSQL 17 met vervangers voor PostGIS, zonder Docker: toepassen geeft 2/11 met 13 huidige rijen en 7 plaatsen. Zonder de migratie, bij opnieuw draaien, bij een bezette code en bij een al aanwezig MICHELIN-id breekt het bestand af zonder iets te wijzigen.
