# Instructie voor de productiesessie: events uit het wereldoverzicht toevoegen

**Bron:** `world_event_overview_20261105.csv` en `WORLD_EVENT_OVERVIEW_20261105.md`, op branch `claude/overnight-world-events`.

Dit volgt dezelfde werkwijze als de eerdere batches (`docs/Architecture/Events/*_PRE_APPLY.md` → menselijke goedkeuring → `*_PRODUCTION_APPLY.md`). Lees CLAUDE.md en `docs/Architecture/Events/EUROPEAN_EVENT_BATCH_1_PRODUCTION_APPLY.md` voordat je begint.

**Twee fases. Fase 1 schrijft niets naar productie. Fase 2 begint pas na expliciete goedkeuring van de product owner, voor precies de goedgekeurde lijst.**

---

## Aanvulling 5 november 2026: twee migraties op twee branches

| Migratie | Branch | Wat | Wanneer |
|---|---|---|---|
| `20261101310000_add_bh_ky_mu_countries.sql` | `claude/overnight-world-events` (deze) | landen BH, KY en MU | **vóór** de events uit die landen, in deze apply |
| `20261101320000_add_event_announcement_status.sql` | `claude/event-expected-soldout` | kolommen `announcement_status` en `expected_source_url` voor het label "Expected" | **niet in deze apply**: pas als die branch op main staat en de build met het label is uitgebracht |

**Werkwijze voor deze apply:**

1. **Apply-branch:** maak een lokale apply-branch vanaf `origin/main` en merge alleen `origin/claude/overnight-world-events`. Push die apply-branch niet naar main.
2. **Volgorde:** de landenmigratie moet als enige pending staan in `supabase migration list --linked`. Controleer ook dat haar nummer hoger is dan de hoogste migratie op main; zo niet, hernoem haar en meld dat.
3. **Uitverkocht:** zet `availability_status = 'sold_out'` als de pagina dat zegt. Die kolom bestaat al, dus dit mag nu. De huidige app toont het nog niet; de build van `claude/event-expected-soldout` wel.
4. **Expected (bron C):** zet geen event op `expected` en voeg geen `later: expected`-rijen toe. De kolom bestaat pas na migratie `…320000`. Een oudere app zou zo'n event bovendien zonder label als officieel tonen.
5. **Na de apply:** rond af zoals in fase 2 hierboven beschreven, inclusief `supabase migration list --linked`: lokaal en remote moeten gelijk zijn.

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

Volg de kolom `apply_decision` in de CSV. Die legt de besluiten van de product owner van 5 november 2026 vast; zie de sectie "Besluiten" in het rapport.

- **`batch 1`:** deze batch.
- **`batch 2`:** de volgende batch, op dezelfde manier.
- **`decide: …`:** alleen mee als de product owner dat per rij beslist.
- **`later: pop-up section`:** niet als event. Er komt later een aparte pop-upsectie voor residenties van een week of langer.
- **`later: expected`:** niet toevoegen. Bron C wacht op de officiële aankondiging, of op een nog te bouwen "expected"-status.
- **`excluded: …`:** niet toevoegen: alleen voor hotelgasten, of geen land (cruise).
- Sla alles over dat op de dag van de apply al voorbij is.

**Landen BH, KY en MU** staan nog niet in `countries`. Pas eerst `supabase/migrations/20261101310000_add_bh_ky_mu_countries.sql` toe:
- **Nummering:** controleer dat het nummer nog na de hoogste migratie op main komt. Zo niet, hernoem het bestand; het is nergens toegepast.
- **Toepassen:** `supabase db push --linked`.
- **Controle:** `supabase migration list --linked`.
- **Branch:** de migratie staat op een branch die achterloopt op main. Pas haar toe vanuit een checkout die main plus deze branch bevat, zoals in `APPLY_2026-11-01.md` §0.

### 3. Per kandidaat controleren, live in productie

1. **Dubbel?** Zoek in `events` op dezelfde `start_date` en dezelfde venue of host, en op een vergelijkbare naam. Doe dit ook voor events die via de app zijn ingediend (`venue_event_submission`), want die kon het onderzoek niet zien.
2. **Catalogus:** controleer elke code in `catalog_match` op `restaurant_code`/`hotel_code` **plus** `country_code` in `restaurants_full`/`hotels_full`. Naam en plaats moeten kloppen.
   - **`PROPOSED` en `AMBIGUOUS`:** nooit zelf beslissen. Zet ze in het rapport als beslispunt.
   - **Niet in de catalogus:** de host gaat in `external_host_name`. Maak geen catalogusrij aan.
3. **Land:** staat het in `countries`? Zo niet (BH, KY, MU), dan gaat de rij niet mee. Meld welk land eerst moet worden toegevoegd. De drie Four Seasons Yachts-rijen hebben geen land en gaan niet mee.
4. **Bron:** open `official_url` opnieuw en controleer datum, tijd en uitverkocht/afgelast.
   - Wijkt iets af? Dan gaat de rij niet mee; noteer de afwijking.
   - Corrigeer niets op basis van een andere bron.
   - Stel ook vast of het event **uitverkocht** is. De kolom `availability_status` in de CSV is afgeleid uit notities, dus de pagina beslist. Uitverkocht wordt `events.availability_status = 'sold_out'`, geen tag.
   - Controleer of het event **alleen voor hotelgasten** is. Is dat zo, dan gaat het niet mee.

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
- **Tags:** via `event_tag_assignments`, alleen met de zes bestaande slugs. Maak geen tags aan voor "uitverkocht" of "expected": dat zijn geen tags, zie de besluiten in het rapport.
- **`availability_status`:** `sold_out` als de pagina dat zegt, `available` als er nog te boeken is, anders `unknown`.
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
