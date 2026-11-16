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
