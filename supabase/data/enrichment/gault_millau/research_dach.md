# Gault&Millau DACH (Switzerland, Germany, Austria) — Research Report

Retrieval date: 2026-08-11.

## Part A — System findings by country

### Switzerland (gaultmillau.ch)
- **Score/threshold:** 0-20, practical floor ~11 ("average cuisine"), no single explicit minimum-inclusion sentence found on the official site itself.
- **Toque mapping:** 5-tier "Hauben" — same bands as France/Austria (11-12.5=1 ... 19-19.5=5). Found on the DACH-wide reference page (gaultmillau.at/news/das-gaultmillau-bewertungssystem), not a CH-specific page.
- **Unscored restaurants:** not confirmed either way.
- **Current edition:** Guide 2026, published 6 Oct 2025. No public browsable historical archive found.
- **Profile URL:** `gaultmillau.ch/restaurants/{slug}-{numeric-id}`.
- **Special awards:** Koch des Jahres, Entdeckung des Jahres (multiple winners), Aufsteiger des Jahres, Patissier des Jahres, Sommelier des Jahres, Gastgeberin des Jahres, Green Chef, Hotel des Jahres.
- **Notable quirk — significant for data collection:** individual restaurant profile pages **do not display the numeric score or toques on-page** (checked on 5 pages, none showed it). Scores only appear in separate annual editorial "best of" round-up articles — a scraper needs to cross-reference two different content types.

### Germany (gaultmillau.de) — **effectively unusable as a live source right now**
- **Score system: points formally abolished in 2022.** Germany is now **Hauben-only, no numeric score at all** — a real structural difference from CH/AT, not an oversight.
- **Toque system:** up to 5 RED or 5 BLACK Hauben (10 effective grade levels — red = "outstanding within its category," black = standard top tier below that). No score-to-toque table exists post-2022 because points were removed entirely.
- **Current edition: NONE for 2026.** Last live edition was 2025 (published 20 Jan 2025). The licensee (Henris Edition) exited around May 2025 amid an **unresolved licensing dispute** with the French rights-holder — a Düsseldorf court ruled in Henris's favor, but the French licensor shut the German site down anyway and no successor has been named. `gaultmillau.de` returned a **certificate error** during this research (site is down/unmaintained).
- **Profile URL:** `gaultmillau.de/places/{numeric-id}/{slug}/` — only one example independently confirmed (via search-index cache, since the live site is unreachable).
- **Special awards (2025, last edition):** Koch des Jahres (Benjamin Peifer), Sommelière des Jahres (Désirée Steinheuer), Patissier des Jahres (Dennis Quetsch), Aufsteigerin des Jahres (Isabelle Pering), Gastronom des Jahres (Simon Tress).
- **This is an active, unresolved gap, not a temporary outage.**

### Austria (gaultmillau.at) — **highest-quality DACH source right now**
- **Score/threshold:** 0-20, explicit minimum documented: **10-10.5 = "empfohlen ohne Haube"** (recommended, no toque) — one full band below the first toque.
- **Toque mapping — officially published, dated page found:** [gaultmillau.at/news/das-gaultmillau-bewertungssystem](https://www.gaultmillau.at/news/das-gaultmillau-bewertungssystem) (5 Nov 2024): 5=19-19.5, 4=17-18.5, 3=15-16.5, 2=13-14.5, 1=11-12.5, no toque=10-10.5. Austria added the 5th toque tier relatively recently (previously capped at 4) — exact year not pinned down.
- **Unscored restaurants: NO** — every listed restaurant, even below the first toque, gets a numeric score (the 10-10.5 "no toque" band proves this).
- **Current edition:** Guide 2026, ceremony at Andaz Vienna. News archive back to at least 2024 with year-tagged articles — the best visible year-over-year public trail of the three DACH markets.
- **Profile URL:** `gaultmillau.at/restaurant/{slug}` (sometimes `-2` disambiguation suffix). A legacy `at.gaultmillau.com` domain exists but has an expired SSL cert — unreliable, don't use.
- **Special awards (2026):** Koch des Jahres (Vitus Winkler), Newcomerin des Jahres (Lisa Morent), Patissière des Jahres (Julia Knoll), Service-Award (Gloria Conti), Lebenswerk/Lifetime Achievement (Karl Kolarik), Gastronom:innen des Jahres (Familie Huth), Barkeeper des Jahres (Marcus Philipp), Sommelier des Jahres (René Kollegger), Wein des Jahres (Georg Prieler), + Bierkarte des Jahres, Wirtshaus des Jahres, Wiener Wirtshaus des Jahres.
- Profile pages **do display score and toque count directly** (verified on 3 pages) — good for structured extraction.

### The Austria/Germany independence question — answered explicitly
**Austria runs a fully independent Gault&Millau operation**, not a subset of the German edition. Evidence: own top-level domain with own homepage/news/awards/database; own annually published print guide, historically sold separately; own ceremony and full award slate. **Decisive evidence**: Germany has NO 2026 edition at all (paused since the 2025 licensing collapse), while Austria's 2026 edition published and was celebrated on schedule — if Austria were a section of the German edition, it would have gone dark too. It didn't.

## Part B — Sample data

**Switzerland (10 restaurants, Guide 2026):** all 19/20 tier — Cheval Blanc by Peter Knogl/Grand Hotel Les Trois Rois (Basel), Stucki/Tanja Grandits (Basel), La Brezza/Eden Roc (Ascona), La Brezza/Tschuggen Grand Hotel (Arosa), Restaurant de l'Hôtel de Ville de Crissier (Crissier), The Restaurant/The Dolder Grand (Zürich), Schloss Schauenstein (Fürstenau), Domaine de Châteauvieux (Satigny), plus 2 at 18/20 (The Counter Zürich, Des Trois Tours). Scores cross-referenced from editorial round-up (gourmoer.ch), NOT shown on profile pages themselves.

**Germany (15 restaurants, Guide 2025 — last live edition, LOWER CONFIDENCE, secondary-sourced since gaultmillau.de is down):** all 5-Hauben tier (5 red: JAN/Jan Hartwig Munich, Vendôme/Joachim Wissler Bergisch Gladbach, Schwarzwaldstube Baiersbronn, Victor's Fine Dining/Christian Bau Perl, Waldhotel Sonnora Dreis; 5 black: Aqua Wolfsburg, es:senz Grassau, Horváth Berlin, IKIGAI Krün, Lafleur Frankfurt, Restaurant Haerlin Hamburg, Rutz Berlin, schanz.restaurant Piesport, The Table Kevin Fehling Hamburg, Restaurant Tim Raue Berlin). No numeric score (N/A, points abolished). Address/website only independently confirmed for JAN.

**Austria (12 restaurants, Guide 2026):** 9 at 5 Hauben/19pts (Steirereck im Stadtpark Wien, Amador Wien, Landhaus Bacher Mautern, Konstantin Filippou Wien, Silvio Nickol Gourmet Restaurant Wien, Ikarus Salzburg, Obauer Werfen, Döllerer Golling, Stüva Ischgl) + 3 at 4 Hauben/18.5pts (Gourmet Restaurant Hubert Wallner, Taubenkobel, Mraz & Sohn Wien). Only 3 of 12 independently address/website-verified on live profile pages.

## Data access quality — critical for scope decision

- **Switzerland**: stable, working site, clear URL scheme, rich metadata — but score deliberately withheld from profile pages (only in annual round-up articles). No historical archive.
- **Austria**: currently the BEST DACH source — live site, score+toques shown directly on profile pages, visible multi-year news archive (2024-2026).
- **Germany: effectively unusable as a live source right now.** Site down (SSL cert error), no 2026 edition, unresolved licensing dispute with no successor publisher named. Any German data collected today is a secondary-source reconstruction of the STALE 2025 edition, not verifiable against the publisher directly. Structural risk beyond the outage: Germany's post-2022 system has no numeric score at all — a schema assuming a universal 0-20 field across DACH will not fit Germany even once/if the guide resumes.
