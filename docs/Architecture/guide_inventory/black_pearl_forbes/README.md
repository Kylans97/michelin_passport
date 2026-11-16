# Black Pearl and Forbes Travel Guide — research, 2026-11-16

Asked for by the product owner on 2026-11-16 ("Black Pearl (China) en
Forbes Travel Guide (VS en China) uitzoeken en klaarzetten"). **Nothing is
staged for import, on purpose:** for both guides the only complete list is
on the publisher's own site, and both sites' terms forbid extracting or
compiling it without written permission. Collecting it anyway would break
the "only factual, verified data, from sources we may use" standard this
project holds itself to. Both permission requests are drafted below, not sent.

Evidence: `BLACK_PEARL_SOURCE_NOTES.md`, `FORBES_SOURCE_NOTES.md`.

## Black Pearl Restaurant Guide (Meituan)

| | |
|---|---|
| Official source | https://blackpearl.meituan.com/ — a JavaScript site listing both 2026 lists together (City, Cuisine and Distinction filters). No official press release, PDF or newsroom post was found. |
| Counts on the site, 2026-11-16 | 13 three-diamond, 53 two-diamond, 327 one-diamond = 393 (260 mainland; 133 Hong Kong, Macau, Taipei, Tokyo, Seoul, Singapore, Bangkok). Press reported 263 + 135 at launch; unverified. The site has no year label and does not split the two lists. |
| Identifiers | A detail page per restaurant, `…/home/en/restaurant-detail?shopId=<id>`, with an English address and phone; no coordinates, website or hotel field. The shopId is a stable external id for `guide_venue_links`. |
| Terms | Meituan User Service Agreement (https://rules-center.meituan.com/rules-detail/4): no scraping of anything Meituan shows; the IP clause forbids compiling and republishing its content. |
| Contact | heizhenzhu@meituan.com (listed on the Black Pearl site). |
| Matching, if permitted | Address and phone per restaurant make code + country matching feasible; Chinese names need a Chinese-reading reviewer. |

## Forbes Travel Guide (US and China)

| | |
|---|---|
| Official source | The full list exists only at forbestravelguide.com/award-winners. FTG's own 2026 release (PR Newswire, Atlanta, 11 Feb 2026: https://www.prnewswire.com/ae/news-releases/forbes-travel-guide-reveals-2026-star-awards-302682723.html) names highlights only and points to the site for the full list. No US or China release, no press toolkit list. |
| Counts | Release: 2,422 (hotels 343 / 708 / 679 Five-Star / Four-Star / Recommended; restaurants 82 / 138 / 80; spas, ships). Award page: 2,406. The 16-entry gap is unexplained. |
| From the release only | 16 named properties for the US, mainland China, Hong Kong and Macau (`forbes_2026_press_release_highlights.csv`): names, sometimes a city, no ids or addresses. Not a usable basis for "Forbes Five-Star" on our pages: it is a highlight list, not the list. |
| Terms | https://www.forbestravelguide.com/termsofuse (updated 2025-09-30): personal, non-commercial use only unless agreed in writing; no robot, spider or scraper; no use of marks or logos. Permission via legal@forbestravelguide.com. |
| Conflict of interest | FTG sells partnerships, consulting and paid "VERIFIED" badges to rated properties; the badges must never be shown. |
| Matching, if permitted | Property pages carry address, phone, website and coordinates: strong. |

---

## Draft — to Meituan (Black Pearl), not sent

**To:** heizhenzhu@meituan.com — **Subject:** Request to reference Black Pearl diamonds on Mantelier

Dear Black Pearl team,

Mantelier is an app and website for discovering exceptional restaurants
and hotels, built in the Netherlands for a global audience. Each
restaurant page shows its recognition from the major guides side by side —
the MICHELIN Guide, The World's 50 Best and Gault&Millau today — each
named and linked.

We would like to add the Black Pearl Restaurant Guide and ask for your
written permission first: for restaurants already in our catalogue only,
the number of diamonds and the year, as plain text credited to Black
Pearl, with a link to the restaurant's page on blackpearl.meituan.com. No
logo, no descriptions, no copy of the full list. If you prefer a data
feed or a different attribution, we will follow it.

Kind regards, [name], Mantelier

## Draft — to Forbes Travel Guide, not sent

**To:** legal@forbestravelguide.com — **Subject:** Permission to reference Forbes Travel Guide Star Ratings on Mantelier

Dear Forbes Travel Guide team,

Mantelier is an app and website for discovering exceptional restaurants
and hotels. Each venue page shows its recognition from the major guides
side by side — MICHELIN, The World's 50 Best and Gault&Millau today — each
named and linked.

We would like to show Forbes Travel Guide Star Ratings and, as your terms
require, ask for written permission first: for hotels and restaurants
already in our catalogue only (starting with the United States and
China), the rating and year as plain text ("Forbes Travel Guide Five-Star,
2026"), credited and linked to the property's page on
forbestravelguide.com. No logos or badges, no reviews, no copy of the full
list; entries made by hand. If you offer a data licence or partner feed
for this, we would welcome the terms.

Kind regards, [name], Mantelier
