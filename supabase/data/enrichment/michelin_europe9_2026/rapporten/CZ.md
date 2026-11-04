# Tsjechië (CZ): MICHELIN-sterren en Keys

Status: **toegepast op productie op 2026-11-04.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |
|---|---|---|---|
| Sterren | 0/1/8 | 0/0/0 | 0/1/8 |
| Keys | 0/1/10 | 0/0/0 | 0/1/10 |

Sterren aangekondigd op 2025-12-11; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (11).

## Voorstel

- **Nieuwe restaurants:** 9 (rest_4100..rest_4108); 7 met telefoon en 9 met website.
- **Nieuwe Key-hotels:** 11 (hotel_3100..hotel_3110), zonder telefoon, website en Place ID.
- **Bestaande rijen zonder afwijking:** 0.
- **Nieuwe plaatsen (QA-458):** Carlsbad, Hlohovec, Mcely, Olomouc, Prague, Vysoký Újezd, Zlín, Šumperk.
- **`property_name`:** Entrée → The Theatre Hotel, ESSENS → Chateau de Frontiere.

## Aandachtspunten

- **Land ontbreekt.** `countries` heeft nog geen `CZ` (Czechia, 🇨🇿, Europe/Prague).
- **Editie-etiket (QA-455).** MICHELIN's artikel van 11 dec 2025 noemt dit "Czechia 2025", terwijl alle pagina's `dateAwarded 2026` en "2026 MICHELIN Guide" zeggen. Voorstel: `guide_year` 2026 volgens de pagina, `announced_on` 2025-12-11.
- **Carlsbad (QA-458).** MICHELIN's hotelpagina schrijft Carlsbad; de stad heet ook Karlovy Vary. Voorstel: MICHELIN's schrijfwijze.

Elke rij met bron staat in [`controle/CZ.csv`](../controle/CZ.csv).
