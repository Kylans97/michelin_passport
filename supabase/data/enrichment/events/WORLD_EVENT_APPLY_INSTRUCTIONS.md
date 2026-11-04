# Instructie voor de productiesessie: events uit het wereldoverzicht toevoegen

**Bron:** `world_event_overview_20261105.csv` en `WORLD_EVENT_OVERVIEW_20261105.md`, op branch `claude/overnight-world-events`.

Dit volgt dezelfde werkwijze als de eerdere batches (`docs/Architecture/Events/*_PRE_APPLY.md` → menselijke goedkeuring → `*_PRODUCTION_APPLY.md`). Lees CLAUDE.md en `docs/Architecture/Events/EUROPEAN_EVENT_BATCH_1_PRODUCTION_APPLY.md` voordat je begint.

**Twee fases. Fase 1 schrijft niets naar productie. Fase 2 begint pas na expliciete goedkeuring van de product owner, voor precies de goedgekeurde lijst.**

---

## Fase 1: read-only controle en pre-apply-rapport

### 1. Schema live lezen, niet aannemen

Lees de kolommen en check-constraints van:

- `events`, met name `event_type`, `status`, `moderation_status`, `availability_status`, `time_precision`, `timezone` en `external_host_name`;
- `event_restaurants` en `event_hotels` (`is_host`, `is_venue`);
- `event_tags` en `event_tag_assignments`;
- `countries`.

Gebruik alleen waarden die de constraints toestaan.

### 2. Kandidaten kiezen

- **Voorstel voor batch 1:** de rijen met `priority = P0`, plus de Benelux-rijen met `source_confidence` A en `certainty = confirmed`.
- **Niet in batch 1:** rijen met `certainty = unclear` of `source_confidence = C`. Die gaan alleen mee als de product owner dat per rij beslist.
- **Datum:** sla alles over dat op de dag van de apply al voorbij is.

### 3. Per kandidaat controleren, live in productie

1. **Dubbel?** Zoek in `events` op dezelfde `start_date` en dezelfde venue of host, en op een vergelijkbare naam. Doe dit ook voor events die via de app zijn ingediend (`venue_event_submission`), want die kon het onderzoek niet zien.
2. **Catalogus:** controleer elke code in `catalog_match` op `restaurant_code`/`hotel_code` **plus** `country_code` in `restaurants_full`/`hotels_full`. Naam en plaats moeten kloppen.
   - **`PROPOSED` en `AMBIGUOUS`:** nooit zelf beslissen. Zet ze in het rapport als beslispunt.
   - **Niet in de catalogus:** de host gaat in `external_host_name`. Maak geen catalogusrij aan.
3. **Land:** staat het in `countries`? Zo niet (BH, KY, MU), dan gaat de rij niet mee. Meld welk land eerst moet worden toegevoegd. De drie Four Seasons Yachts-rijen hebben geen land en gaan niet mee.
4. **Bron:** open `official_url` opnieuw en controleer datum, tijd en uitverkocht/afgelast.
   - Wijkt iets af? Dan gaat de rij niet mee; noteer de afwijking.
   - Corrigeer niets op basis van een andere bron.

### 4. Pre-apply-rapport schrijven

Schrijf `docs/Architecture/Events/WORLD_EVENT_BATCH_1_PRE_APPLY.md` en commit het. Daarin staat per event de exacte rij die geschreven zou worden:

- naam, type en tags;
- `start_date`/`end_date`, tijden, `time_precision` en tijdzone;
- de koppelingen met `is_host`/`is_venue`, of `external_host_name`;
- coördinaten;
- `official_url`, `ticket_url`, `admission_type`, prijs en beschikbaarheid.

Daarnaast staan in het rapport:

- de lijst die **niet** meegaat, met reden;
- de open beslispunten uit het overzichtsrapport, sectie "Te beslissen vóór het toevoegen".

**Stop hier en vraag om goedkeuring.**

---

## Fase 2: apply (alleen na goedkeuring, alleen de goedgekeurde lijst)

### 1. Vlak voor het schrijven

Lees opnieuw: het aantal events, dat geen enkel goedgekeurd event al bestaat, en de catalogus-UUID's.

Klopt er iets niet meer? Stop en meld het. Wijk niet af van het plan.

### 2. Schrijven in één transactie

- **`events`:**
  - type in kleine letters (`dinner`, `festival`, …);
  - `timezone` = de IANA-zone uit het overzicht;
  - `start_at`/`end_at` alleen als de bron de tijd noemt, berekend vanuit de lokale tijd in die tijdzone.
- **Tijden: nooit verzinnen.**
  - Een event met alleen een datum heeft lege `start_time`/`end_time`/`start_at`/`end_at`.
  - Geen `00:00`, `23:59` of een geschatte eindtijd.
- **Coördinaten:** alleen overgenomen van de eigen catalogusrij van de venue, anders NULL. Nooit een benadering.
- **Koppelingen:**
  - `event_restaurants`/`event_hotels` volgens de goedgekeurde rollen: host en venue → `is_host`/`is_venue` true;
  - participant → beide false. Een participant wordt nooit host.
- **Tags:** via `event_tag_assignments`, alleen met de zes bestaande slugs.
- **Niet aanraken:** maak geen `event_chefs`, attendance-, trip-, visit- of fotorijen aan. Download geen foto's: `image_url` blijft NULL tenzij de product owner anders beslist.

### 3. Na het schrijven

Lees alles terug en schrijf `docs/Architecture/Events/WORLD_EVENT_BATCH_1_PRODUCTION_APPLY.md`, in dezelfde opbouw als `EUROPEAN_EVENT_BATCH_1_PRODUCTION_APPLY.md`:

- de ingevoegde rijen;
- de koppelingen;
- de controle op tijden, zonder verzonnen precisie;
- de bestaande data, die onveranderd moet zijn;
- `event_confirmed_attendance`, die onveranderd moet blijven;
- de verschillen in aantallen.

### 4. Changelog en afronding

- Voeg een regel toe in `docs/Plannnig/CHANGELOG.md` onder Unreleased: data in productie gezet, geen build.
- Dit is data en geen migratie: maak geen migratiebestand aan.
- Commit naar de eigen branch van de sessie. Nooit naar main.
