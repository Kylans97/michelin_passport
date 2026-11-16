# Booking windows — run log

## 2026-11-16 — Netherlands, all open restaurants (129)

Asked by the product owner ("kunnen we een sessie laten zoeken naar die
bookingswindows van restaurants in Nederland?"). This run covers the
Netherlands ahead of the three-star-first order in the README.

- **Scope:** `restaurants` where `country_code = 'NL'` and `status = 'open'`,
  read from production on 2026-11-16 (read-only). 129 rows: 1 three-star, 20
  two-star, 98 one-star, 10 with no star.
- **Managers:** none of the 129 has an active venue manager (`revoked_at is
  null`), and none has a window yet. So no staged value overrides a venue's own.
  Re-check `has_active_manager` against production before any import: a claim
  approved in the meantime wins.
- **Method:** six parallel research passes, one per batch of 21–22 restaurants.
  They used only the restaurant's own site and its own booking page, at most
  about five fetches per restaurant. All five rules marked `found`, plus the
  ambiguous Spetters rule, were re-fetched separately and match the pages word
  for word.
- **Progress:** complete. Every code has a row. To resume or re-check, run only
  the rows that are not `found`.

### Coverage

| result | n | status |
|---|---|---|
| found | 5 | 4 `proposed` (high), 1 `unresolved` (One, medium) |
| not_stated | 112 | `unresolved`, kind `unknown` |
| ambiguous | 5 | `unresolved`, window left blank |
| site_unreachable | 6 | `unresolved` |
| closed_or_moved | 1 | `unresolved` |

**Found:**
- De Kas: rolling 3 months.
- Odille: rolling 3 months, released daily at 10:00. This is the only release
  time any site states.
- Wils: 8 weeks, staged as 56 days.
- Rozewied: rolling 3 months.
- One: 6 months, held at medium because groups get a longer window the site
  does not specify.

**Reviewer questions before import:**
1. **Off-by-one.** Every rule reads "up to N ahead" and none says whether day
   X + N itself is bookable. Our convention is that day X opens X + N.
2. **Wils.** "8 weken" is staged as 56 days because the schema has no week
   unit. The conversion is exact, but confirm it.
3. **One.** Can it be imported at medium? The regular rule is clear; only the
   group exception is vague.
4. **Spetters.** "2 maanden van tevoren", but the page's example ("op 1 januari
   … januari en februari") reads as monthly with `release_day = 1` and
   `months_ahead = 1`. Held until the restaurant confirms.

**Ambiguous (window left blank):**
- Novaela: quarterly release at the change of season, no dates.
- De Nieuwe Winkel: seasons are announced through the newsletter only.
- Smink: blocks released "tot en met Kerst 2026", no release date.
- Studio: only a same-day chef's-table rule, at 08:00.
- Spetters: see question 4 above.

**Unreachable:**
- Brut172: rendered by JavaScript.
- 't Nonnetje: empty pages.
- Sabero: 403 to the fetcher.
- Vista: 404 or connection refused.
- Graphite by Peter Gast: no own site found.
- Sense: no own site found; Vigor is listed at the same address.

**Catalogue observations** (outside this task; data corrections need their own
QA issue):
- The White Room by Jacob Jan Boerma: its site says it has closed, but the
  catalogue still has it as `open`.
- Demain: the Strandhotel site lists Bar Bulot, not Demain.
- Sense: Vigor is at the same address.
- Nami: the site now describes itself as Nikkei.
- Sinne: the site says it is temporarily closed for holidays.

**Platform enum:** most NL restaurants book through Formitable, Zenchef or
Guestplan, which the `platform` enum does not have. Those rows say `other`, and
`platform_seen` holds the name. Several platform names were inferred from widget
anchors, not named on the page; the notes say which.

## 2026-11-16 — World's 50 Best 2026 (101) and three MICHELIN stars (131)

Asked by the product owner ("oke laten we hierna dezelfde check doen voor de
world 50 best restaurants van de nieuwste editie. En als dat klaar is voor alle
3 michelin restaurants"). The rules are the same as the NL run.

**Scope:**
- **W50B:** `worlds_50_best` where `year = 2026`, 101 rows: top_50, 51–100 and
  one hall_of_fame. All 101 are linked to a `restaurant_id` and all are open.
  File: `booking_windows_w50b_2026_staging.csv`, with the extra column
  `w50b_rank_2026`.
- **Three stars:** `michelin_stars = 3`, `status = 'open'`, not ended: 162.
  **31 were skipped:** 30 are already in the W50B file and 1 (De Librije) is in
  the NL file. That leaves 131.
  File: `booking_windows_three_star_staging.csv`.
- **Managers:** none of the 232 has an active venue manager or an existing
  window. Re-check before an import.

**Method:** eleven parallel research passes, using the same sources and limits
as the NL run. The brief added two rules:
- Pick the timezone from the country's `countries.timezones`, matching the
  restaurant's city.
- If the source names a zone that differs from local time, treat the row as
  ambiguous.

Every `proposed` row was then re-fetched separately: 15 for W50B and 18 for
three stars. All 33 match the live page word for word. The two PDFs, Hélène
Darroze at The Connaught and La Pergola, were read directly.

### Coverage

| list | found | of which proposed | not_stated | ambiguous | unreachable |
|---|---|---|---|---|---|
| W50B 2026 (101) | 18 | 15 | 69 | 9 | 5 |
| Three stars (131) | 25 | 18 | 89 | 8 | 9 |

**Proposed, W50B:**
- Monthly:
  - Sazenka: on the 1st, the month 2 ahead.
  - The Jane: on the 1st, the month 3 ahead.
- Rolling:
  - DiverXO: 90 days, 00:00.
  - Florilège: 1 month, 00:00.
  - Septime: 21 days, 10:00.
  - Den: 2 months, 12:00, phone only.
  - Wing: 30 days, 00:00.
  - Kjolle: 5 months.
  - Saint Peter: 6 months.
  - Schloss Schauenstein: 8 months.
  - Sühring, Enigma, Seroja and Baan Tepa: 60 days each.
  - Txispa: 90 days.

**Proposed, three stars:**
- Monthly:
  - RyuGin: on the 1st at 12:00, the month 2 ahead.
  - Boury: on the 1st, the month 3 ahead.
  - Eleven Madison Park: on the 1st, the next month.
  - Quince: on the 1st, the next month.
  - Zen: on the 1st at 10:00, the next month.
  - El Celler de Can Roca: on the 1st at 00:00, the month 11 ahead.
- Seasonal:
  - Mirazur: dated releases at 09:00 for April, May and June 2027.
- Rolling:
  - Disfrutar: 12 months.
  - Mizai: 12 months.
  - Quintessence: 3 months, 09:30 on OMAKASE.
  - Taïrroir: 30 days.
  - Zilte: 120 days.
  - Taian Table: 90 days.
  - Benu: 30 days, 10:00.
  - Providence: 2 months.
  - Somni: 1 month.
  - Hélène Darroze at The Connaught: 90 days.
  - La Pergola: 120 days.

**Held at medium:**
- Vyn: "for stays" may mean the hotel.
- SingleThread: "9AM PST" year-round is 10:00 local during daylight saving.
- Tim Raue: "zurzeit"; online booking is offline after a phishing incident.
- Maaemo: "two months ahead" read as monthly.
- Geranium: garbled sentence, groups of 2–6 only.
- Ta Vie: WhatsApp and email only.
- Osteria Francescana: dated calendar.
- Villa Crespi: dated list.
- Dal Pescatore: the year is not printed.
- L'Osier: the release day is deduced, not stated.

**Rules the schema cannot hold** (left blank and listed for a product
decision, not forced into a nearby kind):
- A weekday-of-month release:
  - Kei: the first Tuesday, at 09:30.
  - Marcon: the first Tuesday.
  - Gion Sasaki: the first business day.
  - Villa Crespi: the first weekday.
  - Enclos and Kol: the last Friday.
- A weekly release: Tohru, every Monday.
- Different windows by channel or group size:
  - The Table Kevin Fehling
  - Restaurant Gordon Ramsay
  - Sorn
- A time in a named zone that differs from local time in part of the year:
  - Ikoyi: "12:00 pm (GMT)".
  - SingleThread: "9AM PST".

**Other ambiguous rows:**
- Alchemist and Eliane: approximate quarterly releases.
- Mil: two statements on the same page conflict.
- La Cime: the Japanese page says 2 months, the English page 1 month.
- Le Doyenné: the rule sits under the question about booking a room.
- Maido: "2 meses … el primer día de cada mes", with no example.
- Haerlin: "drei Monate" next to "folgenden Monat" on the 1st.

**Unreachable:**
- Blocked by the site:
  - Four Seasons (Le Cinq, Caprice)
  - Cheval Blanc (Le 1947, La Vague d'Or, Plénitude)
  - Épicure
  - Piazza Duomo
  - Frantzén
  - Jade Dragon
- Timeout: FZN.
- Self-signed certificate: Kanda, Isshisoden Nakamura.
- No readable content (rendered by JavaScript): Le Bernardin.
- No own site found: Harutaka.

Many Tock, OMAKASE, CoverManager and Superb pages returned 403, so some
`not_stated` rows rest on the restaurant's own site only. Their notes say
which.

**Catalogue observations** (outside this task):
- Osteria Francescana's `website_url` (osteria-francescana.net) does not
  resolve; its site is osteriafrancescana.it.
- Memories says it will stop operating in February 2027.
- No own website was found for:
  - Meet the Bund
  - Ru Yuan
  - Fu He Hui
  - Lamdre
  - Mérito
  - Chao Shang Chao

## 2026-11-17 — Import prepared, not applied

`import_booking_windows_20261117.sql` writes the 37 `proposed` rows: 4 NL, 15
W50B and 18 three-star. That is 37 windows plus Mirazur's three dated
releases. It is a prepared data file, not a migration, and it is applied only
with the product owner's approval.

- **Production, read-only, 2026-11-17:** all 37 `restaurant_code` +
  `country_code` pairs resolve to exactly one restaurant. None has an active
  manager or a window, and production has 0 windows in total.
- **Local stack** (every migration replayed, with fixture restaurants for the
  37 codes):
  - First run: 37 windows and 3 releases, all `research`.
  - Re-run: 0 written and 37 skipped. It is safe to run twice.
  - With a manager on Odille and a venue window on Eleven Madison Park: 35
    written and both skipped. Eleven Madison Park's own window is untouched.
  - With one code unresolvable: the run aborts with nothing written.
