# Vineyards: editorial staging

Wine estates chosen individually, outside The World's 50 Best Vineyards
(product owner, 2026-11-20: "I am thinking of adding more vineyards ... Maybe
we can start with a database whilst we think how vineyards come back in the
app"; storage decided as "Staging file first").

**Nothing here is in production.** Today every row in `public.vineyards`
shows at once in search, + Add and wine logging, so estates wait here,
verified, until the app side is decided. Loading them later is one step;
codes continue from the live maximum (`vine_0050` on 2026-11-20).

- `vineyards_editorial_staging.csv` — one row per estate, every value from
  the estate's own site or an official source (address points from BAG via
  PDOK, never geocoded). `inclusion_reason = editorial_selection`, as for
  Mantelier Selection restaurants.
- `research_apostelhoeve.md` — field-by-field sources for De Apostelhoeve.
- `research_candidates_nl.md` — Dutch estates proposed on evidence (MICHELIN
  wine lists, competitions, press), for the product owner to choose from.
  Two claims there were seen only in search excerpts and must be opened
  before use.
