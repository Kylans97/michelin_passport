# Servië (RS): MICHELIN-sterren en Keys

Status: **getest op een scratch-database, nog niet toegepast op productie.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |
|---|---|---|---|
| Sterren | 0/0/2 | 0/0/0 | 0/0/2 |
| Keys | 0/1/3 | 0/0/4 | 0/1/3 |

Sterren aangekondigd op 2025-12-10; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (4).

## Voorstel

- **Nieuwe restaurants:** 2 (rest_4152..rest_4153); 2 met telefoon en 2 met website.
- **Nieuwe Key-hotels:** 0.
- **Bestaande rijen zonder afwijking:** 3.
- **Aanvullen, alleen als het veld leeg is:** 4 rijen (`proposed_fill`).
- **Nieuwe plaatsen (QA-458):** Novi Slankamen.

## Aandachtspunten

- **The Bristol Belgrade (QA-452).** Dit is de afwijkende verdeling: echt van 1 naar 2 Keys in 2026. MICHELIN schreef op 3 juli 2026 nog One-Key; de live pagina zegt Two Keys. Besloten: volgens voorstel.
- **Editie.** MICHELIN's artikel heet "Belgrade 2026", maar noemt ook Fleur de Sel in Novi Slankamen; beide sterren staan in de live Servische lijst.

## Apart behandeld

Door de product owner besloten op 2026-11-04, volgens het voorstel in `controle/`.

| Code | Naam | Productie | MICHELIN | Issue |
|---|---|---|---|---|
| hotel_280 | The Bristol Belgrade | 1 | 2 | QA-452 |

Elke rij met bron staat in [`controle/RS.csv`](../controle/RS.csv).
