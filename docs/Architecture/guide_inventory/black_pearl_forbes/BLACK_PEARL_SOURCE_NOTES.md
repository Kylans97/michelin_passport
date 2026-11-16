# Black Pearl Restaurant Guide 2026 — official-source research (2026-11-16)

## Official source found
- https://blackpearl.meituan.com/ (Meituan's own site, title "Black Pearl Restaurant Guide"; JS app, so a plain fetch shows only the title).
  Rendered in a real browser it lists every currently listed restaurant, both lists together, as cards
  (16 per page, 25 pages), with filters City / Cuisine / Distinction. English UI (en route); a zh route exists
  but redirected to en in this session.
- Detail page per restaurant: https://blackpearl.meituan.com/home/en/restaurant-detail?shopId=<id>
  e.g. shopId=875509755 (BLACKSWAN by Vianney Massot, Beijing) shows: name, street address (English),
  phone (53859911), price per head, cuisine, diamond icon(s), description. No coordinates, website or
  hotel field seen. The same id appears as `poi_id` in Meituan's analytics beacons, so it is the
  Meituan/Dianping shop/POI id — whether it equals the public dianping.com/shop/<id> URL id was NOT verified.
- Data comes from apimeishi.meituan.com/blackpearl/pc/rank/filterList etc., every call signed with
  Meituan's mtgsig/H5guard anti-bot token. Not called directly (that would be circumventing bot protection).
- Official social accounts linked from the site footer: Weibo https://weibo.com/u/6839663217 ,
  Dianping https://www.dianping.com/member/1804661395 , Xiaohongshu, Instagram, Facebook; contact heizhenzhu@meituan.com.
- No Meituan press release (meituan.com newsroom) or PR Newswire release for either 2026 list was found
  (PRN search for "Black Pearl Restaurant Guide" returns only an unrelated Oct 2026 release). No official PDF found.
  Official WeChat account articles not reachable/verified.

## Counts
Official site filter counts (live, viewed 2026-11-16; both lists combined):
- One Diamond 327, Two Diamonds 53, Three Diamonds 13 = 393.
- Cities: mainland 35 cities summing to 260 (Beijing 34, Shanghai 61, Hangzhou 20, Guangzhou 18, Chengdu 18, Shenzhen 17 ...);
  HK 38, Macau 20, Taipei 5, Tokyo 32, Seoul 8, Singapore 18, Bangkok 12 = 133.
Press (NOT official, for comparison only): mainland 263 in 32 cities, 3/2/1 diamond = 6/25/232
(bjnews https://www.bjnews.com.cn/detail/1769579926168117.html ; ifeng https://i.ifeng.com/c/8qHH4lRP6w8);
overseas 135 in 7 cities (bjnews https://www.bjnews.com.cn/detail/1774357330169683.html).
Discrepancy: site shows 260 vs 263 mainland (Beijing 34 vs 35) and 133 vs 135 overseas — the site is a live
list (likely removals/closures since launch); it carries no visible edition/year label or per-list split, so
per-list per-tier counts as announced could not be confirmed from an official source. City set (Seoul,
Nantong, Qingdao, Shijiazhuang, Shenyang present) matches the 2026 editions.
Mainland 6/25/232 implies overseas 7/28/100 if the totals were unchanged — inference only, not verified.

## Terms
Meituan User Service Agreement (美团用户服务协议, published 2023-12-27): https://rules-center.meituan.com/rules-detail/4
- Clause (8): no 非法抓取 of any content Meituan displays without prior written permission
  ("未经美团事先书面许可，不应…非法抓取美团所展示的任何内容"), defined as using programs not approved by Meituan.
- IP clause: no use, display, copying, 转载 (republishing), 汇编 (compiling) or 抓取 by robot, spider or screenshot
  without prior written permission.
The Black Pearl site has no separate terms page; it is a Meituan property (京ICP备10211739号).

## CSV
NOT created. The only official full list is the Meituan site, whose terms forbid compiling/scraping/republishing
its content without written permission, and whose API is bot-protected. Extracting 393 rows would be bulk
scraping against the terms, so it was not done. Route: ask Meituan (heizhenzhu@meituan.com) for written
permission/a data licence, or enter rows by hand per restaurant from the official detail page, keyed on shopId.

## Not verified
- Official WeChat articles / any official PDF of either list.
- Whether shopId == dianping.com/shop id.
- Per-list (mainland vs overseas) per-tier counts from an official source.
