# Kroatië (HR): MICHELIN-sterren en Keys

Status: **toegepast op productie op 2026-11-04.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.

| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |
|---|---|---|---|
| Sterren | 0/1/13 | 0/1/0 | 0/1/13 |
| Keys | 1/1/10 | 1/1/8 | 1/1/10 |

Sterren aangekondigd op 2026-06-25; Keys op 2026-09-18. Het Key-totaal klopt met MICHELIN's wereldartikel (12).

## Voorstel

- **Nieuwe restaurants:** 13 (rest_4109..rest_4121); 10 met telefoon en 11 met website.
- **Nieuwe Key-hotels:** 2 (hotel_3111..hotel_3112), zonder telefoon, website en Place ID.
- **Bestaande rijen zonder afwijking:** 9.
- **Aanvullen, alleen als het veld leeg is:** 1 rijen (`proposed_fill`).
- **Nieuwe plaatsen (QA-458):** Jastrebarsko, Korcula, Mali Lošinj, Novalja, Porec, Rijeka, Sibenik, Split.
- **`property_name`:** Nebo → Hilton Rijeka Costabella.

## Aandachtspunten

- **Plaatsnamen (QA-458).** MICHELIN's lijst schrijft Sibenik, Porec en Korcula zonder diakrieten; zo staan ze nu voorgesteld.
- **Twee Key-wijzigingen apart behandeld (QA-454).** Dit stond niet in de telling: de verdeling klopt toevallig wel, doordat de twee elkaar opheffen. Villa Dubrovnik ging van 1 naar 2 Keys, Palace Elisabeth Hvar van 2 naar 1. Productie heeft beide nog op de waarde van 2025.
- **Twee sites zonder bevestiging (QA-457).** Cap Aureo heeft geen link bij MICHELIN; Alfred Keller alleen een boekingslink. Beide blijven leeg.

## Apart behandeld

Door de product owner besloten op 2026-11-04, volgens het voorstel in `controle/`.

| Code | Naam | Productie | MICHELIN | Issue |
|---|---|---|---|---|
| hotel_267 | Palace Elisabeth Hvar | 2 | 1 | QA-454 |
| hotel_260 | Villa Dubrovnik | 1 | 2 | QA-454 |

Elke rij met bron staat in [`controle/HR.csv`](../controle/HR.csv).
