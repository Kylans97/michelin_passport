# Letland (LV): MICHELIN-sterren en Keys

Status: **toegepast op productie op 2026-11-04.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |
|---|---|---|---|
| Sterren | 0/0/2 | 0/0/0 | 0/0/2 |
| Keys | 0/0/3 | 0/0/0 | 0/0/3 |

Sterren aangekondigd op 2025-10-22; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (3).

## Voorstel

- **Nieuwe restaurants:** 2 (rest_4148..rest_4149); 2 met telefoon en 2 met website.
- **Nieuwe Key-hotels:** 3 (hotel_3116..hotel_3118), zonder telefoon, website en Place ID.
- **Bestaande rijen zonder afwijking:** 0.
- **Nieuwe plaatsen (QA-458):** Riga.
- **Hotelkoppelingen:** JOHN Chef's Hall → hotel_3116.

## Aandachtspunten

- **Land ontbreekt.** `countries` heeft nog geen `LV` (Latvia, 🇱🇻, Europe/Riga).
- **Hotelkoppeling.** JOHN Chef's Hall komt aan het nieuwe A22 Hotel; MICHELIN's tekst noemt dat hotel.

Elke rij met bron staat in [`controle/LV.csv`](../controle/LV.csv).
