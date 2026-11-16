# D — Hotel guides and membership associations

Researched 2026-11-16. Research only; nothing written to any database.

How to read this file:
- **Verified** means I opened the publisher's own page during this session.
- **Reported** means a press release or trade outlet said it and I did not open the publisher's page.
- **Unverified** means the figure comes from an aggregator or secondary source only.
- `cntraveler.com` and `travelandleisure.com` refused automated fetches, so nothing about Condé Nast Traveler or Travel + Leisure is verified at the publisher.

The key distinction throughout is between three kinds of recognition:
- **Award or rating:** independent inspection or anonymous voting.
- **Readers' poll:** popularity among a magazine's readers.
- **Paid membership:** the venue pays dues to belong. This is a commercial affiliation and must never be shown as an award.

---

## 1. The World's 50 Best Hotels (already held)

### Publisher & independence
- William Reed Media.
- The ranking comes from a voting body of more than 800 anonymous industry figures (reported). No fee for inclusion.
- The site has moved from theworlds50best.com to **the50.com**, with a 301 redirect, verified.

### Scale
Ranked 1–50, plus an extended list ranked 51–100.

### Coverage & count
- 100 hotels worldwide.
- The 2026 top 50 spans 22 territories (reported).

### Cadence & latest edition
- Annual.
- **2026 edition:** the 51–100 list was released on **1 September 2026**. The 1–50 list was revealed at a ceremony in **Paris on 15 September 2026**.
- No.1 is Rosewood Hong Kong for the second year running, verified on the50.com.
- **A 51–100 list exists for 2026.**

### Openness & format
- Free web pages at the50.com/hotels/list/1-50, verified.
- Entries 1–50 link to per-hotel pages. Entries 51–100 appeared without links in the fetched page.

### Terms of use
Not re-checked; the terms URL returned 404. This is unchanged from what we already hold.

### Matching
- Each entry shows the city only, not the country.
- The per-hotel pages for 1–50 are the anchor. Positions 51–100 need manual confirmation against the hotel's own site.

### Recommendation
**Hold now** (already held). Ingest the 2026 51–100 list alongside 1–50.

### Sources
- https://www.the50.com/hotels/list/1-50
- https://www.theworlds50best.com/stories/News/the-50-best-hotels-2026-the-51-100-list.html
- https://www.hospitalitynet.org/news/4134173/the-worlds-50-best-hotels-2026-announces-the-extended-51-100-list
- https://en.prnasia.com/releases/apac/rosewood-hong-kong-named-no-1-in-the-50-best-hotels-2026-for-the-second-consecutive-year-548025.shtml

---

## 2. MICHELIN Keys (already held)

### Publisher & independence
MICHELIN Guide, using anonymous inspectors. No fee.

### Scale
One, Two or Three Keys.

### Coverage & count
The 2026 selection has **2,832 Key hotels** (reported, consistent across outlets):

| Tier | Hotels |
|---|---|
| One Key | 2,020 |
| Two Keys | 657 |
| Three Keys | 155 |

- 470 hotels are new.
- Keys reached 10 new countries, including Liechtenstein and Slovakia.

### Cadence & latest edition
- One **global annual announcement**, not per country.
- **Latest: 18 September 2026** (reported). The previous one was October 2025.
- I did not find separate per-country dates for the 2026 Keys.

### Openness & format
Free on guide.michelin.com, as already used.

### Terms of use
Unchanged from what we already hold.

### Matching
Per-hotel guide pages, as already used.

### Recommendation
**Hold now** (already held). Refresh from the 18 September 2026 selection. That includes Key losses, which become award_history rows under the QA-387 rule.

### Sources
- https://www.michelin.com/en/publications/products-and-services/michelin-guide-2026-michelin-key-selection (listed in results, not opened)
- https://www.travelpulse.com/news/hotels-and-resorts/michelin-guide-expands-with-470-new-key-selection-hotels
- https://www.outlooktraveller.com/News/michelin-reveals-its-2026-key-hotels-with-470-new-additions-worldwide

---

## 3. Forbes Travel Guide Star Ratings

### Publisher & independence
- The Five Star Travel Corporation. It uses the Forbes name **under licence** and is not part of Forbes Media. The site footer states "Forbes is a registered trademark of Forbes LLC used under license", verified.
- Ratings come from anonymous inspections against published standards.
- FTG says it charges no fee for a rating and that a rating cannot be bought (reported).
- **Conflict-of-interest concern:** FTG runs several paid services for the same properties it rates:
  - a paid "Global Partnership" programme, which gives "transparency into the Star Rating process" and logo access;
  - a consulting division, AtelierCX;
  - Star Coach training;
  - a "VERIFIED" Responsible Hospitality badge, free for partners and paid for everyone else.
- The ratings themselves are inspection-based. Rated properties can still buy insight into the process and training against the standards. I found no published policy separating inspectors from consultants (not verified either way).
- The paid "VERIFIED" badges (Responsible Hospitality, health security) are **not** awards and must never be shown as one.

### Scale
Five-Star, Four-Star and Recommended. These cover hotels, restaurants, spas, cruise ships and cruise restaurants.

### Coverage & count
- The 2026 award-winners page states **2,406** winners, verified.
- The press release said 2,422 in total. Its hotel tiers were 343 Five-Star, 708 Four-Star and 679 Recommended (reported).
- The two totals differ (2,406 vs 2,422). This is a discrepancy and should not be reconciled by guessing.
- Coverage is global but strongest in the US, Asia and Macau. Europe is thinner.

### Cadence & latest edition
- Annual.
- **2026 Star Awards announced 11 February 2026**, embargoed until 9:00 EST, verified via the partner toolkit and the press release.
- The 2027 awards are expected around February 2027 (not verified).

### Openness & format
- Free and openly published, verified: forbestravelguide.com/award-winners.
- The page is searchable and filterable by type, tier and "New for 2026", and is grouped by destination.
- Every entry links to a per-property page.

### Terms of use
Restrictive, verified at forbestravelguide.com/termsofuse:
- Use is personal and non-commercial only.
- "You may not copy, reproduce, distribute, publish…" content without written permission.
- "You may not use any mark, logo, or trade name owned or used by us in any medium whatsoever" without permission.
- Robots, spiders and scrapers are prohibited.
- Logos are licensed: rated properties that are not partners must **purchase** a logo licence.

Practical implications:
- Showing the star **logo** is not permitted.
- Plain-text factual mention such as "Forbes Travel Guide Five-Star, 2026" with a link is ordinary factual reference and probably acceptable. That is a judgement, not legal advice; get written permission before shipping.
- Bulk scraping the list is prohibited, so collection would have to be manual or under licence.

### Matching
Good. Each property page carries:
- full street address, verified on the Le Bristol Paris page;
- phone number;
- the official website link;
- map coordinates, embedded in the map URL;
- a stable URL slug such as /hotels/paris-france/le-bristol-paris.

### Recommendation
**Hold later.**
- It is credible, inspection-based, and overlaps heavily with Key hotels at Five-Star level.
- Before holding it we need written permission for commercial use of the facts.
- Show tier and year in plain text only, with no logo, and never show the paid VERIFIED badges.
- Include restaurants and spas only if the restaurant agent concurs.

### Sources
- https://www.forbestravelguide.com/award-winners
- https://www.forbestravelguide.com/termsofuse
- https://www.forbestravelguide.com/landing/toolkit
- https://www.forbestravelguide.com/hotels/paris-france/le-bristol-paris
- https://www.forbestravelguide.com/starcoachterms
- https://www.hospitalitynet.org/news/4130845/forbes-travel-guide-reveals-2026-star-awards
- https://www.86dme.com/r-and-r/forbes-five-star-audit/ (critic's opinion piece, not evidence)

---

## 4. Condé Nast Traveler — Gold List, Hot List, Readers' Choice Awards

### Publisher & independence
Condé Nast. The three lists work differently:

| List | How it is chosen | Fee |
|---|---|---|
| Gold List | Editors' picks | None known |
| Hot List | Editors' picks of new openings | None known |
| Readers' Choice Awards | Readers' poll; the 2026 edition was the 39th, with about 800k votes (reported, single French source) | None known |

### Scale
- Gold List and Hot List: unranked inclusion.
- Readers' Choice Awards: ranked lists by region and category, with a score.

### Coverage & count
- Gold List 2026: unverified. One aggregator counts 73 entries and one blog says "about 64".
- Hot List 2026: count not verified.
- Readers' Choice 2026: several thousand ranked places across categories (not verified). As one data point, LHW alone reported 130 member winners.

### Cadence & latest edition
| List | Latest edition | Status |
|---|---|---|
| Gold List 2026 | Published in the final week of December 2025 | Reported |
| Hot List 2026 | Late April 2026 | Reported |
| Readers' Choice 2026 | Around 6 October 2026 | Reported |

The Gold List 2027 is expected around December 2026 (not verified).

### Openness & format
- Free web galleries on cntraveler.com, as far as I know from training.
- The site blocked automated fetch, so this is **not verified** this session.
- The UK edition (cntraveller.com) publishes its own separate lists.

### Terms of use
- Not verified; the publisher's terms page could not be fetched.
- Condé Nast titles generally restrict reproduction and commercial use of content. Treat the list as copyrighted editorial.

### Matching
- Weak. Entries are gallery cards with name and city, sometimes linking to a hotel review page.
- No stable per-venue ID that I could confirm.

### Recommendation
**Leave out.**
- The Gold List and Hot List are editorial curation with no published criteria.
- Readers' Choice is a popularity poll that partly measures readership size.
- All three overlap heavily with Key hotels and 50 Best Hotels, add little signal, and are hard to match.
- If anything is added later, the Gold List is the only defensible one, as an editorial mention rather than an award.

### Sources
- https://www.timeout.com/uk/news/three-posh-british-hotels-have-been-named-the-best-in-europe-by-a-luxury-travel-magazine-121825
- https://www.lhw.com/press-center/1026_cnt
- https://preferredhotels.com/bulletin/preferred-hotels-resorts-celebrates-93-member-hotels-recognized-conde-nast-traveler-2026
- https://www.journalduluxe.fr/fr/lifestyle/hotels-resorts-spas-grands-gagnants-conde-nast-traveler-readers-choice-awards-2026
- https://timeout.com/news/these-are-the-worlds-best-new-hotels-in-2026-according-to-cn-traveller-042426
- https://www.enprimeurclub.com/lists/conde-nast-gold-list-2026 (aggregator, unverified)

---

## 5. Condé Nast Johansens (paid membership)

### Publisher & independence
- Condé Nast Johansens says Local Experts "research, inspect and invite" properties.
- It is a **commercial collection**. Its own 2024 media kit says members can enter the awards "with no additional fee for members", which implies paid membership. The fee amount was not found.
- Its Awards for Excellence mix expert evaluation, guest feedback and reader votes, and are open only to members (reported).

### Scale
Membership. The awards are given per region and category.

### Coverage & count
Not verified.

### Cadence & latest edition
The awards were presented in London on 2 November 2026 and are styled "2027" (reported).

### Openness & format
Not checked; low priority.

### Terms of use
Not checked.

### Matching
Not checked.

### Recommendation
**Leave out.** It is a paid membership, and its awards are restricted to members, so it is not an independent award.

### Sources
- https://strapi-bus-eng-prod.s3.us-east-1.amazonaws.com/CN_Johansens_2024_66c32d6718.pdf
- https://www.timeout.com/news/the-best-new-hotels-in-the-world-according-to-a-prestigious-award-110526

---

## 6. Travel + Leisure — World's Best Awards and T+L 500

### Publisher & independence
- Travel + Leisure, part of Dotdash Meredith / People Inc.
- The World's Best Awards are a **readers' poll**.
- The **T+L 500** is not a separate judgement: it is the top-scoring hotels from the *previous* year's readers' survey, unranked and grouped by region (reported).
- T+L also publishes an editors' "It List" of new hotels.

### Scale
- World's Best Awards: ranked, with a top 100 hotels in the world plus regional lists.
- T+L 500: unranked inclusion.

### Coverage & count
- Global.
- The T+L 500 is about 500 hotels. Nearly 190 were in the US in one edition (reported).

### Cadence & latest edition
- Annual.
- **2026 World's Best Awards published around July 2026** (reported; it ran in the August 2026 issue). No.1 hotel was Patina Osaka.
- T+L 500 2026: derived from the 2025 survey. Exact date not verified.

### Openness & format
- Free web articles on travelandleisure.com, as far as I know from training.
- The site blocked automated fetch, so this is **not verified**.

### Terms of use
Not verified. It is copyrighted editorial.

### Matching
Weak. Article lists show name, city and a score. No stable per-venue ID.

### Recommendation
**Leave out.**
- It is a readers' popularity poll that is US-skewed.
- The T+L 500 re-packages the previous year's poll.
- It overlaps heavily with our high end and adds no independent judgement.

### Sources
- https://www.hotel-online.com/news/travel-leisure-announces-2026-worlds-best-awards-showcasing-the-top-travel-destinations-hotels-airlines-and-more
- https://www.lhw.com/press-center/0726_travel_and_leisure
- https://preferredhotels.com/bulletin/preferred-hotels-resorts-celebrates-52-member-hotels-honored-travel-leisure-2026-worlds
- https://austin.culturemap.com/news/travel/travel-leisure-500-austin-proper/

---

## 7. La Liste — Top 1,000 World's Best Hotels

### Publisher & independence
- La Liste, a Paris company founded in 2015 by Philippe Faure.
- It is an **aggregator**: a score out of 100 computed from hundreds of guides, publications and customer reviews (reported).
- **For 2026 it integrated MICHELIN Keys data for the first time** (reported). Showing it beside Keys would partly double-count Keys.
- The weighting is not published (not verified).

### Scale
- A score out of 100. The 2026 top score of 99.5 was shared by ten hotels (reported).
- La Liste also gives Special Awards and "Discovery Gem" awards.

### Coverage & count
- 1,000 hotels selected from about 7,300 evaluated in more than 200 countries (reported).
- France has 100 entries.

### Cadence & latest edition
- Annual.
- The 2026 hotels list was unveiled around **8 July 2026**. This comes from a French outlet's pre-announcement and was not verified at the publisher.

### Openness & format
- Not verified: la-liste.com pages returned 404 to the fetcher.
- From training: the site and app are free and show per-establishment pages, but this needs a manual check.

### Terms of use
Not verified.

### Matching
Not verified this session. If the per-hotel pages carry an address, matching is feasible.

### Recommendation
**Leave out**, at most hold later:
- it is a meta-score built partly from awards we already hold, including Keys;
- its method is opaque;
- a second number beside Keys and 50 Best adds noise rather than independent signal.

Revisit only if the restaurant agent recommends La Liste for restaurants and wants consistency across venue types.

### Sources
- https://www.timeout.com/news/these-are-officially-the-worlds-best-hotels-in-2026-according-to-a-prestigious-award-070926
- https://www.thepeakmagazine.com.sg/lifestyle/la-liste-top-1000-worlds-best-hotels-list
- https://www.journalduluxe.fr/fr/lifestyle/la-liste-2026-plus-beaux-hotels-de-luxe-du-monde

---

## 8. AAA Diamonds (hotels; brief)

### Publisher & independence
- The American Automobile Association.
- Diamonds come from in-person inspection. Properties must first meet "AAA Inspected & Approved" requirements.
- No fee for the rating, as far as I know from training (not verified).

### Scale
- One to Five Diamonds.
- Only Four and Five Diamonds are publicised.
- AAA also publishes Top 10 lists.

### Coverage & count
- The US, Canada, Mexico and the Caribbean only.
- Roughly 145 Five Diamond hotels (reported, rounded, September 2026).

### Cadence & latest edition
- **Rolling designations** throughout the year. For example, The Hazelton Toronto and Waldorf Astoria New York were added in May 2026.
- The annual lists are published around the start of the year.
- The Top 10 lists were published on 12 June 2026.

### Openness & format
- Lists are published at newsroom.aaa.com, including PDFs.
- The full search is on AAA's own travel site (not verified).

### Terms of use
Not checked.

### Matching
Not checked.

### Recommendation
**Leave out.**
- It is North-America-only, while the app is Benelux-first.
- Its signal is redundant with Keys and Forbes for luxury hotels.
- Rolling updates are costly to maintain.

### Sources
- https://newsroom.aaa.com/aaa-diamonds
- https://newsroom.aaa.com/2026/06/aaa-diamonds-top-10/
- https://travelpulse.com/news/hotels-and-resorts/aaa-releases-2026-five-diamond-hotel-restaurant-lists

---

## 9. Relais & Châteaux (paid membership association)

### Publisher & independence
- An association of independent owners.
- Admission is selective:
  - a paid candidate fee covering inspection;
  - inspector visits and anonymous audits;
  - a board vote.
- Members then pay **annual dues**: roughly €7,500–30,000 by property size, average around €15,000 (reported, secondary, older; **unverified**).
- This makes it a **paid membership**, not an award.

### Scale
- Membership only. There are hotel members and restaurant-only members.
- The older "Relais Gourmand" designation still appears in secondary sources (not verified as current).

### Coverage & count
**580 hotels and restaurants in 65 countries**, verified on relaischateaux.com.

### Cadence & latest edition
- Membership is rolling. New-member cohorts were announced in 2026: 9 members early in the year and 10 in July (reported).
- 34 new members were admitted in 2025.

### Openness & format
- Free, verified. The site has "All our hotels and restaurants" and country listing pages, with per-property pages.
- The per-property pages were not opened this session.

### Terms of use
- Not checked.
- The name and logo are trademarks.
- Factual membership is publicly asserted by the members themselves.

### Matching
- Per-property pages normally carry an address and a booking page (not verified this session).
- Members often also link to Relais & Châteaux on their own sites, which helps confirm a match.

### Recommendation
**Hold later**, if at all, and **only as a labelled affiliation** ("Member of Relais & Châteaux"):
- never shown as an award;
- never gold;
- kept in a separate dimension from awards.

It is respected and Europe-heavy, and it overlaps strongly with Key and starred venues. But the CLAUDE.md rule "a paid membership is not an award" means it needs a distinct data model and UI treatment first. If that is not wanted, leave out.

### Sources
- https://www.relaischateaux.com/us/
- https://www.relaischateaux.com/us/magazine/the-concierge/news/relais-chateaux-welcomes-eight-new-members
- https://www.afar.com/magazine/relais-chateaux-adds-9-new-hotels-and-restaurants
- https://openthemagazine.com/features/living/we-cannot-afford-not-to-be-here (dues; secondary)
- https://fine-dining-guide.com/?p=3174 (fees; secondary, older)

---

## 10. Les Grandes Tables du Monde (membership association)

### Publisher & independence
- An association of restaurants, founded in 1954, with its registered office in Valence.
- Admission follows "exclusive admission criteria" that the association does not publish.
- Membership fees exist as far as I know from training, but this was **not verified**.
- It is a membership, not an award.

### Scale
Membership only. The association also gives some annual awards, such as a Restaurateur of the Year.

### Coverage & count
- "More than 200" restaurateurs in **28 countries**, verified on the association page.
- 23 new members from 13 countries were admitted at the October 2026 Majorca congress (reported).

### Cadence & latest edition
- One annual congress, at which new members are admitted.
- The latest was **October 2026** (reported).

### Openness & format
- Members are listed on the website and in an annual PDF guide (the 2025 guide is a PDF on their site).
- The association page itself shows no member directory with addresses, verified. The directory pages were not opened.

### Terms of use
Not checked.

### Matching
Probably name plus city plus the restaurant's website, from the guide PDF. Not verified.

### Recommendation
**Leave out** for now. Its members are almost all 2–3 MICHELIN star restaurants we already show, so it adds little signal. Restaurant-side; the restaurant agent may judge it differently.

### Sources
- https://lesgrandestablesdumonde.com/en/association/
- https://www.yonder.fr/news/food/grandes-tables-monde-2026-alexandre-gauthier-meilleur-restaurateur-grenouillere
- https://lesgrandestablesdumonde.com/wp-content/uploads/2018/05/guide-lgtdm-2025-law.pdf

---

## 11. Leading Hotels of the World / Small Luxury Hotels of the World / Preferred Hotels & Resorts (brief)

### Publisher & independence
- All three are **commercial marketing and booking consortia**.
- Hotels pay membership or marketing fees and booking commissions. SLH charges a flat fee plus revenue share (reported). The fee amounts were not verified for any of the three.
- All three have quality audits as a condition of membership.

### Scale
Membership only. Preferred also has sub-brands.

### Coverage & count
- LHW: around 400+ hotels (unverified; secondary sources conflict).
- SLH: 700+ hotels in about 100 countries as of Q1 2026 (reported).
- Preferred: not verified.

### Cadence & latest edition
Rolling membership.

### Openness & format
Open booking sites.

### Terms of use
Not checked.

### Matching
Not checked.

### Recommendation
**Leave out.** These are paid sales affiliations, not recognition. Never present them as awards.

### Sources
- https://www.travelpulse.com/news/hotels-and-resorts/small-luxury-hotels-of-the-world-adds-29-properties-in-first-quarter-of-2026
- https://www.fathomaway.com/hotel-collections-explainer/
- https://www.lhw.com/press-center/0926_michelin_guide

---

## 12. JRE – Jeunes Restaurateurs, Euro-Toques, Les Collectionneurs and similar (brief)

### Publisher & independence
These are chef and restaurateur membership associations:
- **JRE** admits younger chef-owners by its own criteria, and members pay dues.
- **Euro-Toques** is a chefs' association focused on advocacy for food quality.

Neither is an award.

### Scale
Membership only.

### Coverage & count
- **JRE:** "400+ restaurants and 160 hotels in 21 countries" (reported, April 2026). The JRE "about us" page still lists 17 countries.
- **Euro-Toques:** not verified.

### Cadence & latest edition
Rolling membership. JRE expanded to Argentina, Chile and Peru at its 2026 congress in Cologne.

### Openness & format
- JRE has a member directory on jre.eu (not opened).
- Euro-Toques: not checked.

### Terms of use
Not checked.

### Matching
Not checked.

### Recommendation
**Leave out.** These are professional associations rather than quality signals. JRE is mid-range as often as high-end.

### Sources
- https://jre.eu/en/500-culinary-leaders-from-jre-jeunes-restaurateurs-unite-to-seed-the-future-of-gastronomy
- https://jre.eu/en/about-us

---

## 13. Gault&Millau hotel ratings (brief)

### Publisher & independence
- The Gault&Millau national licensees, each run separately.
- France rates and lists hotels at fr.gaultmillau.com/en/hotels/…, including an "Exceptional Hotel" designation.
- Austria and Switzerland have historically had hotel guides (not verified for 2026).
- **Benelux and Germany:** no hotel ratings found.

### Scale
It varies by market. In France it is a hotel listing plus a label, and some pages show restaurant toques/score alongside.

### Coverage & count
Not verified.

### Cadence & latest edition
- The French guide follows the restaurant guide; the 2026 gala was 17 November 2025.
- Austria's 2027 guide was unveiled on 20 October 2026, but whether it rates hotels was not verified.

### Openness & format
- French hotel pages exist on the public site, with per-hotel URLs (seen in search results, not opened).

### Terms of use
Not checked.

### Matching
Not checked.

### Recommendation
**Leave out for now.**
- The scale and method are inconsistent across markets.
- There is no Benelux hotel rating.
- The restaurant side of Gault&Millau is already held.

Revisit if the product wants French or Swiss hotel coverage.

### Sources
- https://fr.gaultmillau.com/en/news/les-hotels-des-laureats-gault-millau-2026
- https://fr.gaultmillau.com/en/search/hotel

---

## 14. Telegraph, Tatler, Mr & Mrs Smith, Virtuoso and others (brief judgement)

### Publisher & independence
- **The Telegraph:** "250 Best Hotels in the UK" 2026 guide, with 60 reviewers and about 2,000 properties visited (reported). It is UK-only editorial.
- **Tatler:**
  - The UK Travel Guide (the "101 Best Hotels in the World" 2025 edition was the latest found) is editorial.
  - Tatler Asia publishes Best Asia-Pacific lists for 2026.
- **Mr & Mrs Smith:** a curated **booking platform** that is commercial and commission-based. It is now owned by IHG (not re-verified).
- **Virtuoso:** a travel-agency network. Its hotel programme is a **paid preferred-partner** programme.
- **Others:**
  - The Sunday Times and Gallivanter's Guide are niche editorial.
  - The Hotel Guru is a booking and editorial site.
  - The Robb Report "50 Greatest Luxury Hotels" is editorial.

### Scale
Editorial lists, and commercial collections for Mr & Mrs Smith and Virtuoso.

### Coverage & count
Narrow (UK or Asia-Pacific) or commercial.

### Cadence & latest edition
- Telegraph 2026 UK guide: around May 2026 (reported).
- Tatler Asia Best 2026: reported.

### Openness & format
Mostly article form, with some behind paywalls (the Telegraph and Sunday Times are paywalled, from training).

### Terms of use
Copyrighted editorial.

### Matching
Weak: name and town in an article.

### Recommendation
**Leave out** all of them:
- editorial lists are narrow, paywalled and hard to match;
- Mr & Mrs Smith and Virtuoso are commercial affiliations.

### Sources
- https://www.timeout.com/london/news/best-hotels-in-the-uk-london-2026-telegraph-ranking-053026
- https://www.tatlerasia.com/collection/best-asia

---

## Summary table

| Guide | Type | Recommendation |
|---|---|---|
| World's 50 Best Hotels (1–100) | Anonymous vote | Hold now (held); add 2026 51–100 |
| MICHELIN Keys | Inspection | Hold now (held); refresh 18 Sep 2026 |
| Forbes Travel Guide | Inspection, with paid partner and consulting ties | Hold later: text only, no logo, written permission first |
| Relais & Châteaux | Paid membership | Hold later only as a labelled affiliation; else leave out |
| La Liste hotels | Aggregated meta-score (includes Keys) | Leave out |
| CN Traveler Gold/Hot/Readers' Choice | Editors / readers' poll | Leave out |
| T+L World's Best / T+L 500 | Readers' poll | Leave out |
| CN Johansens, LHW, SLH, Preferred, Virtuoso, Mr & Mrs Smith | Paid / commercial | Leave out |
| Les Grandes Tables du Monde, JRE, Euro-Toques | Membership | Leave out |
| AAA Diamonds | Inspection, North America only | Leave out |
| Gault&Millau hotels | Varies by market | Leave out for now |
| Telegraph, Tatler and others | Editorial | Leave out |
