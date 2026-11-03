# Estland (EE): MICHELIN-sterren en Keys

Status: **getest op een scratch-database, nog niet toegepast op productie.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |
|---|---|---|---|
| Sterren | 0/1/1 | 0/0/0 | 0/1/1 |
| Keys | 0/1/1 | 0/0/0 | 0/1/1 |

Sterren aangekondigd op 2026-05-19; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (2).

## Voorstel

- **Nieuwe restaurants:** 2 (rest_4150..rest_4151); 2 met telefoon en 2 met website.
- **Nieuwe Key-hotels:** 2 (hotel_3119..hotel_3120), zonder telefoon, website en Place ID.
- **Bestaande rijen zonder afwijking:** 0.
- **Nieuwe plaatsen (QA-458):** Tallinn.

## Aandachtspunten

- **Land ontbreekt.** `countries` heeft nog geen `EE` (Estonia, 🇪🇪, Europe/Tallinn).

Elke rij met bron staat in [`controle/EE.csv`](../controle/EE.csv).
