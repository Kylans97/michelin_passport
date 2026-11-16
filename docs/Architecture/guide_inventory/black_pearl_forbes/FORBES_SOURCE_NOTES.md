# Forbes Travel Guide 2026 Star Awards — official sources (researched 2026-11-16)

## Sources
- Official release, PR Newswire, "News provided by Forbes Travel Guide", dateline ATLANTA, Feb. 11, 2026:
  https://www.prnewswire.com/ae/news-releases/forbes-travel-guide-reveals-2026-star-awards-302682723.html
  (same text on newswire.ca, hospitalitynet.org/news/4130845.html, kyodonewsprwire.jp; PT/ES PRN translations exist).
  No media contact listed, no explicit "for publication / free for media use" note.
- FTG editorial roundup linked from the FTG media center (not a wire release):
  https://stories.forbestravelguide.com/forbes-travel-guides-2026-star-award-winners-including-the-worlds-first-five-star-cruise
- FTG media center: https://www.forbestravelguide.com/media-center — one 2026 item (the stories link above); no per-region
  releases, no downloadable winner list or toolkit.
- No FTG-issued US-, China-, HK- or Macau-specific release found. Property/operator releases exist (e.g. Galaxy Macau,
  Marriott Luxury Group, Macau IR roundups) but are not FTG-issued; not used.

## Does the official release enumerate all winners? NO.
It names only highlights (new Five-Stars and a few firsts) and says "See the full list of honorees on ForbesTravelGuide.com".
The complete list exists only on forbestravelguide.com/award-winners, which the terms forbid scraping/commercial reuse of.
CSV therefore holds 16 rows: the release's US/CN/HK/MO mentions only. It is NOT a complete list.

## Counts (release)
2,422 total = hotels 343/708/679 (5*/4*/Rec, 1,730) + restaurants 82/138/80 (300) + spas 118/241 (359)
+ cruise ships 1/9/9 (19) + cruise-ship restaurants 1/8/5 (14). The category figures sum exactly to 2,422.
The live award-winners page says "All 2406 Star Award Winners by Destination" (read 2026-11-16).
The 16 difference is not explained anywhere I found. Possible causes (closures, delistings since Feb, or counting
differences) are unverified. Macau: release says 28 Five-Star hotels; Galaxy Macau/Forbes Australia say 26. Also unresolved.

## Terms (https://www.forbestravelguide.com/termsofuse, last updated 30 Sep 2025)
- Section D: "you may only use the content for your personal and non-commercial use" (unless FTG agrees in writing).
- Section G prohibits "any robot, spider, scraper, or other automated or manual means" to access the services.
- Rights requests: legal@forbestravelguide.com. No press/media carve-out in the terms. The wire release has no reuse
  statement either. Wire releases are distributed for media coverage by convention, but nothing grants a licence to
  build a database from them. Treat any use beyond citing facts as needing FTG's written permission.

## Identifiers in official sources
Name only, sometimes with a city or state in free text. No IDs, addresses or codes. Restaurants rarely name the host hotel
(only Atlas Buckhead is tied to The St. Regis Atlanta). Several names embed the city ("Mandarin Oriental Qianmen, Beijing",
"Paiza Grand, Macau"). The comma may be part of the name or a location, so I recorded the city where it reads as a location.
Name + city is insufficient for our code+country matching; each row needs manual linking to restaurant_code/hotel_code.

## CSV field decisions (left blank rather than guessed)
- City blank where the release prints none: Yacht Club at The Boca Raton, Capella Shanghai, Regent Hong Kong,
  Capella at Galaxy Macau, Palazzo Versace Macau, St. Regis Macao. The city appearing in the name was not used.
  Orlando is taken from "the city's first" context. Atlanta is from "Atlanta earns its first double Five-Star".
- State is blank unless printed (only Pennsylvania and Rhode Island are printed).
- Aurelia/Flybridge parent hotel is blank in the release. The FTG stories article says Aurelia is at Castle Hill Inn
  (temporarily closed after a fire, per its editor's note) and Flybridge is at Yacht Club at The Boca Raton.
- The Charleston Place: "earn Four-Stars", so new_for_2026 is unknown. The state (SC) is not printed.

## Not captured (only in the FTG stories article or property releases, not the wire release)
Lai Heen (The Ritz-Carlton, Macau) and Sushi Kissho by Miyakawa (Raffles at Galaxy Macau) are called Macau's "two new
Five-Star restaurants". The Ritz-Carlton's own release calls Lai Heen's its "sixth" Five-Star, so "new" conflicts (it may be a
re-gain). Also The Spa at Palazzo Versace Macau (Five-Star spa) and The Ritz-Carlton, Cleveland (Recommended).
No Four-Star restaurants or spas, and no complete Five-Star restaurant list for the US or China, appear in any official FTG
release. 82 Five-Star restaurants exist worldwide, and the release names 3 US ones plus 1 at sea.
