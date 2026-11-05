# Brief: sourcing upcoming gastronomy events (research only)

Today is 2026-11-03. Find **upcoming** one-off, high-end gastronomy events in your region, from today to 2027-12-31. Weight the search hard toward 2026-11-03 → 2027-05-31: short-term supply matters most. The product is a luxury gastronomy app; its event page shows curated events.

## What fits
One-off occasions on a specific date:
- four-hands dinners and guest-chef collaborations or takeovers;
- winemaker dinners tied to a named producer and a date;
- galas and charity dinners;
- gastronomy festivals, including recurring annual ones: the 2027 edition with its own announced dates counts;
- special tastings tied to a date;
- truffle and game one-nights.

A MICHELIN or 50 Best link is a plus, not a requirement. The test for anything else: **if someone could book it next week too, it is not an event.** These do not fit:
- standing menus, seasonal menus that run for weeks, or weekly or monthly recurring formats (unless one instalment has a named guest chef and a date — then include it with `certainty` `unclear`);
- standard Christmas or New Year's Eve menus;
- private hire;
- vague announcements without a date.

## Hard rules (never guess)
- **Source:** the date must be published by the venue or the organiser itself: its own website, or its own Instagram or Facebook post if that is the only channel. **Open (WebFetch) the source page and confirm the date is on it.** Record the exact URL.
  - Level C: only a secondary source (press, aggregator, ticketing site, listicle). Keep such rows only when clearly valuable, and say so in the notes.
  - Level A: confirmed on the venue's or organiser's own page, with the date.
  - Level B: own channel but partial — for example a social post only, or a page that fails to load fully but whose search snippet shows the date.
- **Times:** start and end time are set only if the source states them (local HH:MM). Never infer 19:00 for a "dinner". Empty is correct.
- **Partial dates:** a date given only as a month means `start_date` stays empty, the wording goes in the notes, and `certainty` is `unclear`.
- **Year:** a year inferred from context must be unambiguous; otherwise mark it `unclear`.
- **Past events:** do not include events that already happened (before 2026-11-03), and do not include past editions.
- **Timezone:** the venue's IANA timezone (Europe/Amsterdam, Asia/Tokyo, America/New_York, …).
- **Type:** exactly one of: Dinner, Lunch, Festival, Gala, Tasting, Brunch, Party.
- **Tags:** only from: Wine, Winemaker, Wild/Game, Guest Chef, Four Hands, Charity. Type and tags are separate dimensions; leave tags empty if none apply.
- **Venues:** for each venue involved, give its role, which is exactly one of `host` (organises), `venue` (where it takes place), or `participant` (a guest chef's restaurant, a winery, …). The same restaurant can be both host and venue: list it twice, or once with role "host+venue".
- **Catalogue codes:** give the catalogue code only if you found the venue in the catalogue file below **and** its country and city agree. Never match on name alone; if unsure, leave the code empty and explain.
- **Photos:** do not download them. Note only whether the event or venue page has an image, with its URL if easy to get.
- **Skip the event if:**
  - the official page contradicts a secondary source (log it in the notes of a "held back" record, see below);
  - it is sold out *and* passed;
  - it is clearly not high-end (a mass-market food fair, a beer festival, a street-food market).

## Where to look
1. The catalogue venues for your region, listed in the TSV file named in your task, starred and key venues first. Check their events, news or agenda pages and Instagram (via search snippets).
2. Big annual gastronomy festivals, galas and chef series in your region: find each one's next edition dates on its own official site.
3. Hotel-hosted guest-chef series (e.g. Mandarin Oriental, Four Seasons, Aman, Peninsula and Rosewood guest-chef dinners), wine estates' dinners, and chef collaboration series.

Use WebSearch to discover and WebFetch to verify. Aim for quality over volume: typically 25–60 good events for your region, more if you find them efficiently. Stop when you have covered the region reasonably or after about 120 tool calls, whichever comes first.

## Output
Write **JSON Lines** to the output file named in your task, one event per line, written incrementally (append as you go, so nothing is lost). Each line is a JSON object with exactly these keys:

```
{"name": "event name as the source writes it",
 "region": "<your region key>",
 "country_code": "NL", "city": "Amsterdam",
 "start_date": "2026-11-20", "end_date": "2026-11-20",
 "start_time": "", "end_time": "",
 "time_precision": "DATE_ONLY | START_KNOWN_END_UNKNOWN | FULL_TIME | MULTI_DAY_DATE_ONLY | DATE_UNKNOWN",
 "timezone": "Europe/Amsterdam",
 "event_type": "Dinner", "tags": ["Four Hands", "Guest Chef"],
 "venues": [{"name": "Restaurant Flore", "city": "Amsterdam", "country_code": "NL", "role": "host+venue", "catalogue_code": "rest_0xxx or empty", "code_note": ""},
            {"name": "Horváth", "city": "Berlin", "country_code": "DE", "role": "participant", "catalogue_code": "", "code_note": "not in catalogue file"}],
 "participants": "free text: guest chefs/winemakers with their restaurants",
 "admission_type": "paid | free | invite_only | unknown",
 "price": "as published, else 'not published'",
 "official_url": "the venue's or organiser's own page with the date",
 "ticket_url": "",
 "source_publisher": "venue | organiser | secondary",
 "verification_level": "A | B | C",
 "certainty": "confirmed | unclear",
 "date_checked_on_page": true,
 "photo_available": "yes | no | unknown", "photo_url": "",
 "recognition": "e.g. 'host 2 MICHELIN stars; guest W50B #12' or empty",
 "fit": "high | medium | low",
 "notes": "anything the reviewer needs"}
```

Things you considered and **rejected** (not one-off, past, no date, contradictory source, not high-end) go in the same file with `"status": "rejected"` and a `"reject_reason"`. Keep these short: name, url, reason. All other rows get `"status": "candidate"`.

## Final reply
Report briefly:
- counts of candidates and rejections;
- which countries or areas you covered fully, partly, or not at all;
- what blocked you (sites that refuse fetching, Instagram-only venues);
- where venues in this region tend to announce events.

Do not write anywhere except your output file. Do not touch the git repository.
