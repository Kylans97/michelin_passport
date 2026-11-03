# Hongarije (HU): MICHELIN-sterren en Keys

Status: **getest op een scratch-database, nog niet toegepast op productie.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |
|---|---|---|---|
| Sterren | 0/1/8 | 0/2/0 | 0/1/8 |
| Keys | 0/2/10 | 0/3/9 | 0/2/10 |

Sterren aangekondigd op 2025-10-09; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (12).

## Voorstel

- **Nieuwe restaurants:** 8 (rest_4130..rest_4137); 6 met telefoon en 7 met website.
- **Nieuwe Key-hotels:** 0.
- **Bestaande rijen zonder afwijking:** 12.
- **Aanvullen, alleen als het veld leeg is:** 1 rijen (`proposed_fill`).
- **Nieuwe plaatsen (QA-458):** Esztergom, Őriszentpéter.

## Aandachtspunten

- **Platán Gourmet is gesloten (QA-450).** Productie heeft 2 sterren. In de 2025-editie van 9 okt 2025 had het die nog, maar de MICHELIN-pagina geeft nu 404, het staat niet in de sterrenlijst, en de pagina van Platán Manor noemt alleen nog Platán Bisztró. De eigen site meldt: "a Platán Gourmet befejezte működését" (is gestopt). De sluitingsdatum staat er niet bij.
- **Daardoor wijkt de sterrenverdeling af.** MICHELIN 0/1/8; productie 0/2/0. Stand heeft wel 2 sterren.
- **Párisi Udvar-Key (QA-451).** Productie 2, MICHELIN 1 in zowel 2025 als 2026: een importfout, geen wijziging.
- **Editiejaar (QA-455).** Hongarije zit nog op de 2025-editie (`dateAwarded 2025`); er is geen 2026-artikel gevonden. Stand staat in productie als `guide_year` 2026. Voorstel: nieuwe rijen krijgen 2025; Stand blijft ongewijzigd (besloten 2026-11-04).
- **Babel (QA-457).** MICHELIN's link laadt, maar de pagina noemt in de opgehaalde HTML naam noch telefoon. Website en telefoon blijven leeg.

## Apart behandeld

Door de product owner besloten op 2026-11-04, volgens het voorstel in `controle/`.

| Code | Naam | Productie | MICHELIN | Issue |
|---|---|---|---|---|
| rest_0427 | Platán Gourmet | 2 | geen | QA-450 |
| hotel_277 | Párisi Udvar Hotel Budapest | 2 | 1 | QA-451 |

Elke rij met bron staat in [`controle/HU.csv`](../controle/HU.csv).
