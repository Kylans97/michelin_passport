# Litouwen (LT): MICHELIN-sterren en Keys

Status: **voorbereid, niets toegepast.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toevoegen, zonder de achtergehouden rijen |
|---|---|---|---|
| Sterren | 0/0/4 | 0/0/0 | 0/0/4 |
| Keys | 0/0/2 | 0/0/0 | 0/0/2 |

Sterren aangekondigd op 2026-06-05; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (2).

## Voorstel

- **Nieuwe restaurants:** 4 (rest_4144..rest_4147); 4 met telefoon en 4 met website.
- **Nieuwe Key-hotels:** 2 (hotel_3114..hotel_3115), zonder telefoon, website en Place ID.
- **Bestaande rijen zonder afwijking:** 0.
- **Nieuwe plaatsen (QA-458):** Radiškis, Trakai, Vilnius.

## Aandachtspunten

- **Land ontbreekt.** `countries` heeft nog geen `LT` (Lithuania, 🇱🇹, Europe/Vilnius).
- **Demo is niet meegenomen (QA-456).** MICHELIN's artikel van 5 juni 2026 telt vijf sterren, met Demo in Vilnius. De live lijst telt er vier en de Demo-pagina geeft 404. De live selectie is gevolgd; de reden van het verdwijnen is niet gevonden.

Elke rij met bron staat in [`controle/LT.csv`](../controle/LT.csv).
