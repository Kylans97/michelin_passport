# Guide source links — staging

2026-10-28, `feature/guide-sources`. Staging only. **Nothing here has been
written to Supabase**, and the migration it needs
(`20261021120000_add_worlds_50_best_urls.sql`) is committed but not applied.
Plan: `docs/Architecture/GUIDE_SOURCE_LINKS_PLAN.md`.

| File | What | Rows to apply |
|---|---|---|
| `worlds_50_best_restaurant_urls.csv` | Each restaurant's World's 50 Best page | 113 of 143 (`apply=yes`) |
| `worlds_50_best_hotel_urls.csv` | Each hotel's World's 50 Best page | 123 of 134 |
| `gault_millau_at_urls.csv` | The 8 Austrian rows stored as `"not found"` | 7 of 8 (Obauer: none) |
| `gault_millau_toques.csv` | Belgian and Dutch toque counts | 21 of 22 (GEM already had its 4) |
| `apply_guide_source_links.sql` | The update, in one transaction, every step checking its row count | — |
| `match_worlds_50_best.py` | The matcher, to rerun or audit | — |
| `generate_apply_sql.py` | Rebuilds the SQL from the CSVs | — |

Run `apply_guide_source_links.sql` only after the migration is live. A
read-only dry run on 2026-10-28 matched every expected count: 8
placeholders, 7 Austrian rows, 21 toque rows, 113 restaurant codes, 123
hotel codes.

## World's 50 Best: how a URL was found and proven

The site moved from `theworlds50best.com` to **`the50.com`**. The old
domain answers with a 301 redirect to the new one. Stored URLs use the new
domain.

**Candidates** come only from the site's own `sitemap.xml` (6,303 URLs,
3,536 `discovery/Establishments/<Country>/<City>/<Name>.html` profiles,
plus the 50 current hotel list pages). Nothing was built from our names.
Name similarity only chose which pages to fetch, never what was accepted.

**Accepted (`status=verified`)** only when all three hold:
1. The page's type is the venue's type. Each profile's title says
   `- Restaurant -`, `- Hotel -` or `- Bar -`; a bar page is never a
   restaurant's page, even on the same domain (The Connaught vs Connaught
   Bar).
2. The page's country is ours. The site files Hong Kong and Macau under
   China, so those count only when the city also matches. On a hotel list
   page an exact rank + year identifies the hotel by itself.
3. At least one piece of evidence that doesn't depend on the name
   (column `evidence`):
   - `rank`: the page states a World's 50 Best rank + year equal to one of
     our own `worlds_50_best(_hotels)` rows;
   - `worlds_best_year` / `hall_of_fame`: the "World's Best Restaurant
     YYYY" / "Best of the Best" accolades match our No.1 years or Hall of
     Fame row;
   - `phone`: the page's phone ends in the same 8 digits as ours;
   - `website`: same domain as our `website_url`, and ours is the venue's
     own site. A sub-page of a group site doesn't count: Four Seasons,
     Mandarin Oriental and City of Dreams host sibling venues on one domain
     (Caprice vs Caprice Bar);
   - `address`: our street + house number appears on the page.

**Not applied** (`apply=no`): 30 restaurants and 11 hotels. Either no
candidate exists in the sitemap (`no_candidate`: Aqua, Lido 84, Quattro
Passi, Amisfield; Grand Park Rovinj, Maçakızı, Orient Express La Minerva),
or the only candidate couldn't be proven (`review_no_rank_on_page`). The
second group includes correct rejections: La Colombe → La Petite Colombe,
Caprice → Caprice Bar, Aman Kyoto → Ace Hotel Kyoto, Huka Lodge →
Flockhill Lodge, San Domenico Palace → Gritti Palace, and Arca, which the
site files as a Bar. Many others are probably right (Arzak, Saison,
Amangiri) but we hold neither a phone nor a website to prove them, and
their address is written differently. They wait for a person, per
QA-248.

Two hotel URLs (`url_kind=list_page`: Hotel Sacher Wien, Hôtel de Paris
Monte-Carlo) point at the 2026 list page, because no profile was found for
them. A verified profile always wins over a list page. These may move when the next list is published. Every other URL
is a `discovery_profile`, which also exists for venues no longer ranked.

## Gault&Millau

- **Austrian URLs:** candidates from gaultmillau.at's own sitemap
  (`providers.xml`, 2,239 URLs). Each was accepted only when the page title
  ("Döllerer, Golling – 5 Hauben, 19/20") matched our city, Hauben count
  and score, and the page showed our street and postcode. Stüva's page
  writes "Dorfstraße 73", ours "Dorfstr. 73"; same postcode, checked by
  hand. Obauer has no page in the sitemap and stays NULL.
- **Toques:** on gault-millau.nl/.be the main score block holds one icon
  per toque. A count was accepted only when that block's score equals our
  stored score; all 22 matched. Swiss pages (gaultmillau.ch) render the
  score as a graphic with no readable toque data, so Swiss rows stay NULL.

## Findings, not changed here

- **QA-246:** verified profiles show 9 World's 50 Best rank-years our
  `worlds_50_best` table doesn't have (Hof van Cleve 2021/2022, Jordnær
  2022, Nobelhart & Schmutzig 2024, Leo 2023, Oteque 2024, Fyn 2022, The
  Clove Club 2022/2023). Award History is short of them. Unverified;
  see the next point.
- **QA-247:** profile rank lines are not reliable on their own. A Casa do
  Porco's profile says No.25 in 2025; the official 2025 list says No.83,
  as we have. Mandarin Oriental Hong Kong (profile 42, list 41) and
  One&Only Mandarina (38 vs 39) are the same: our data matches the
  official list. Le Calandre (profile 2023 No.44, ours No.41) is
  unchecked. The site's previous-list pages ignore the year in their path
  and print every year unlabelled, so they couldn't settle it.
