# Booking windows — collection plan (not started)

Planned 2026-11-16, alongside `supabase/migrations/20261101400000_add_wishlist_month_and_booking_windows.sql`.
**Nothing here has been researched or imported.** This is the plan and an
empty staging file, for review before a run starts.

## Why

A member who plans a month at a restaurant on their wishlist gets a push the
day before that month opens for booking — but only when the restaurant's
booking window is known. A claimed restaurant's manager sets it themselves
(Venue → Booking window, live at once). Every other restaurant has no window,
so no reminder, until we research one. A wrong window is worse than none: it
sends a member to a booking page a day early or a day late, at the one moment
that matters. So the never-guess rule applies at full strength.

## Order

1. **MICHELIN three stars** (`_source/three_star_restaurants.csv`), the ones
   hardest to book.
2. **The World's 50 Best**, current list, ranks 1–50, then 51–100.
3. **Two stars**, only once 1 and 2 are reviewed, starting with the countries
   members wishlist most (`select … from wishlist` counts by country, run by
   hand; the planned month itself is private and is not read for this).

Done in batches of about 25 restaurants, each batch one review.

## Where a window may come from

In order of trust; record which one it was in `evidence_source`:

1. **The restaurant's own website or booking page** stating the rule ("Reservations
   open 60 days in advance at 10:00", "On the 1st of each month we open the month
   after next").
2. **The booking platform's own page for that restaurant** (Tock, Resy,
   SevenRooms, TheFork, OpenTable) when it states the rule in words. A calendar
   that happens to show dates up to some day is **not** a rule: it is one
   observation and says nothing about the time of day — record it in `notes`,
   never as the window.
3. **The restaurant's own newsletter or social post** announcing a release
   (seasonal).

Not acceptable as a source: press articles, booking-tips blogs, Reddit,
aggregator "how to book" pages. They may point to where to look; they are never
the evidence. If only they exist, the row is `unresolved`.

## How to record a window

One row per restaurant in `booking_windows_staging.csv`, keyed on
`restaurant_code` + `country_code` (never the name; the name is there for the
reviewer only). Fields map one-to-one onto `restaurant_booking_windows`:

| kind | Means | Fill |
|---|---|---|
| `rolling` | On day X at `release_time`, day X + N opens | `rolling_amount`, `rolling_unit` (`day`/`month`) |
| `monthly` | On day D of each month, the month M months later opens, all of it | `release_day`, `months_ahead` |
| `seasonal` | One-off releases, each opening a run of dates | `releases`: `release_on@HH:MM:covers_from..covers_to`, `;`-separated, all ISO dates |
| `unknown` | Looked, could not verify | nothing; say what was checked in `notes` |

Watch the convention for `rolling`: "60 days in advance" on a site may count
today or not. Record it as the restaurant means it, in our convention (day X
opens X + N), and quote the source sentence in `source_quote` so the reviewer
can check the off-by-one.

- `timezone`: the restaurant's IANA zone, one of its country's
  `countries.timezones`. Times are always the restaurant's local time.
- `release_time`: only when the source states it. Unknown stays blank — the
  reminder then names the date alone. Never fill in "midnight" or "10:00"
  because it is common.
- `platform`: `tock`, `resy`, `sevenrooms`, `thefork`, `opentable`, `own_site`,
  `phone`, `email`, `other`.
- `confidence`, `match_method`, `status`: as `../PROVENANCE_SCHEMA.md`.
  Only `high` (the restaurant's or its platform's own words) goes to import;
  `medium` and `low` stay `unresolved` until a manager or a better source
  confirms.
- Waitlist-only or "call us" with no stated release: `unknown`, platform
  `phone`/`other`, and say so in `notes`.

## Import, after review

A reviewed batch becomes rows with `source_kind = 'research'`, `source_url` =
the evidence URL and `verified_on` = `retrieved_at`, written by a prepared SQL
file in this folder that checks every `restaurant_code` resolves to exactly one
restaurant first — never by an agent writing to Supabase directly, and never
without the product owner's approval. A restaurant whose manager has already set
a window is skipped: the venue's own word wins.

## Keeping it current

Windows change (a new platform, a new season). Re-check `research` rows older
than six months, oldest first; a row that can no longer be confirmed goes back
to `unknown` rather than staying as it was. A manager's own entry is never
overwritten by research.
