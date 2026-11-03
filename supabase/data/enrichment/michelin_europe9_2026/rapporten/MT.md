# Malta (MT): MICHELIN-sterren en Keys

Status: **getest op een scratch-database, nog niet toegepast op productie.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |
|---|---|---|---|
| Sterren | 0/1/6 | 0/1/0 | 0/1/6 |
| Keys | 0/1/5 | 0/1/5 | 0/1/5 |

Sterren aangekondigd op 2026-02-17; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (6).

## Voorstel

- **Nieuwe restaurants:** 6 (rest_4138..rest_4143); 5 met telefoon en 6 met website.
- **Nieuwe Key-hotels:** 0.
- **Bestaande rijen zonder afwijking:** 7.
- **Aanvullen, alleen als het veld leeg is:** 7 rijen (`proposed_fill`).
- **Nieuwe plaatsen (QA-458):** Sliema, St. Julian's.
- **Hotelkoppelingen:** De Mondion → hotel_292, Under Grain → hotel_288.
- **`property_name`:** Le GV → Le Soleil Hotel.

## Aandachtspunten

- **Keys kloppen.** Alle 6 hotels komen overeen; alleen `michelin_url` ontbreekt nog.
- **Le GV (QA-459).** `property_name` Le Soleil Hotel, zoals MICHELIN's tekst het noemt.

Elke rij met bron staat in [`controle/MT.csv`](../controle/MT.csv).
