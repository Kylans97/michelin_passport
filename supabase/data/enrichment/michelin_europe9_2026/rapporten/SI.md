# Slovenië (SI): MICHELIN-sterren en Keys

Status: **getest op een scratch-database, nog niet toegepast op productie.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |
|---|---|---|---|
| Sterren | 1/1/8 | 1/1/0 | 1/1/8 |
| Keys | 0/1/4 | 0/1/5 | 0/1/4 |

Sterren aangekondigd op 2026-06-16; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (5).

## Voorstel

- **Nieuwe restaurants:** 8 (rest_4122..rest_4129); 7 met telefoon en 8 met website.
- **Nieuwe Key-hotels:** 1 (hotel_3113), zonder telefoon, website en Place ID.
- **Bestaande rijen zonder afwijking:** 6.
- **Aanvullen, alleen als het veld leeg is:** 8 rijen (`proposed_fill`).
- **Nieuwe plaatsen (QA-458):** Bohinj, Lasko, Nova Gorica, Petrovče, Portorož, Radovljica, Vipava, Zgornja Kungota, Šentjošt nad Horjulom.

## Aandachtspunten

- **Plaatsnaam (QA-458).** MICHELIN's lijst schrijft Lasko zonder diakriet; zo staat het nu voorgesteld.
- **Het "ene hotel te veel" zijn er twee (QA-453).** Peterc Vineyard Estate en Nebesa Chalets verloren in 2026 hun Key, Vila Muhr kwam erbij. Zo komt het verschil op -1. Beide hotels bleven op de nieuwste archiefkopie op 1 Key staan.
- **Voorstel volgens QA-387:** de hotels blijven staan, met `michelin_keys` NULL en een lege huidige 2026-rij; 1 Key blijft als geschiedenis bewaard.

## Apart behandeld

Door de product owner besloten op 2026-11-04, volgens het voorstel in `controle/`.

| Code | Naam | Productie | MICHELIN | Issue |
|---|---|---|---|---|
| hotel_301 | Peterc Vineyard Estate | 1 | geen | QA-453 |
| hotel_305 | Nebesa Chalets | 1 | geen | QA-453 |

Elke rij met bron staat in [`controle/SI.csv`](../controle/SI.csv).
