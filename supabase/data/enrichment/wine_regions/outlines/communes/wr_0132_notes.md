# Sussex (PDO, England)

## Official basis
- UK GI register (DEFRA): "Sussex", Protected Designation of Origin, wine, registered on the UK GI register
  (decision notice: entry 5 July 2022). https://www.gov.uk/protected-food-drink-names/sussex
- Product specification (PDO GB number W0006), linked from the register page as
  https://assets.publishing.service.gov.uk/media/64198e2ce90e0769f47f4755/Product_specification_for_Sussex_final_.docx
  (the same file is also served under a `.pdf` name, `.../Product_specification_for_Sussex_final_1.pdf`, but it
  is a Word document; copy in `raw/sussex_spec.pdf`, text in `raw/txt/sussex_spec.txt`).
- Demarcation, verbatim headings: "Demarcation: East and West Sussex"; section 6: grapes "grown within the
  administrative boundaries of the counties of East and West Sussex"; section 8: "Definition of the
  demarcated area: East and West Sussex". Grapes, vinification, lees ageing and finishing must all take place
  inside the area. The applicant notes that, being administrative, the area may be reconsidered if boundaries
  change.

## How the area is drawn (3 rows)
- Dataset: ONS Open Geography Portal, **Counties and Unitary Authorities (December 2025) Boundaries UK BGC**
  (generalised 20 m, clipped to the coastline at Mean High Water), item ac443ef4c1de497a9675a6e72290f9cc,
  FeatureServer `Counties_and_Unitary_Authorities_December_2025_Boundaries_UK_BGC/FeatureServer/0`, queried with
  outSR=4326. Licence: Open Government Licence v3.0. Required attribution: "Source: Office for National
  Statistics licensed under the Open Government Licence v.3.0" and "Contains OS data © Crown copyright and
  database right 2025". https://www.ons.gov.uk/methodology/geography/licences
- Units: East Sussex (E10000011), West Sussex (E10000032), Brighton and Hove (E06000043).
- **Brighton and Hove is an interpretation, flag for review.** Since 1997 Brighton and Hove has been a unitary
  authority, so the administrative counties of East Sussex and West Sussex as ONS draws them leave a gap on
  the coast between Shoreham and Newhaven. The specification's own map (section 8, `raw/sussex_docx/word/media/
  image1.png`) draws one red outline whose coastal edge runs continuously past Brighton, and its text traces
  only the outer boundary (Emsworth, Haslemere, Crawley, East Grinstead, Tunbridge Wells, Rye). I read that as
  the whole of historic Sussex, Brighton and Hove included, and drew it so the area has no hole. In the CSV the
  row carries `official_name` "East Sussex" and `lau_name` "Brighton and Hove". If the reviewer reads "the
  counties of East and West Sussex" strictly as the two administrative counties, drop this one row; nothing
  else changes.
- Simplification: shared-arc Douglas-Peucker at 100 m (topology preserving per arc) in a local metric
  projection, so the three units meet edge to edge (pairwise overlap 0 m², no slivers in the union). Area
  change under 0.1% per unit. Two side effects, both within the ~100 m brief:
  - 37 tiny West Sussex islands, each under 0.03 km² (largest about 27,000 m²), mostly in Chichester Harbour,
    collapse and are dropped (largest source-vertex deviation about 370 m, at one of those islands);
  - the narrow tidal channel of the River Adur, up to about 3 km inland, closes up at 100 m. One pinch hole it
    left inside West Sussex (0.27 km², 62% of it land in the source) was filled. No sea is painted.
- Build script and report: `europe2/gb_ge_tools/build_units.py`, `europe2/gb_ge_tools/build_report.txt`.

## Content
- Summary: specification (chalk of the South Downs and greensand; traditional method sparkling; still wine)
  plus WineGB's regions page (Sussex: "traditional method sparkling remains its flagship product", Chardonnay,
  Pinot Noir and Pinot Meunier, chalky South Downs). https://winegb.co.uk/wines/regions/
- Grape order (Chardonnay, Pinot Noir, Meunier): no Sussex-only planting table exists. WineGB 2025 Industry
  Report (Food Standards Agency Wine Team data) gives the same top three for the South East region, which
  contains Sussex (974 / 793 / 268 ha), and for the UK as a whole; Decanter's report on the WineGB figures gives
  the same order (31% / 29% / 9%). The specification lists these three first among its sparkling varieties.
- Label note: specification section 11.
- Appellations: Sussex (PDO), English (PDO, demarcation England, vines below 220 m), English Regional (PGI).
  "English Quality Sparkling Wine" is not a separate GI on the register; the register lists "Quality
  (sparkling) wine" and "Regional (sparkling) wine" as traditional terms only, so they are left out.
- Red structure, pairing: held back (see below).

## Kent
- **Not recommended as a region.** The UK GI register lists, for UK wine: English (PDO), English Regional (PGI),
  Welsh (PDO), Welsh Regional (PGI), Sussex (PDO), Darnibole (PDO, Cornwall), plus The Crouch Valley (PDO, Essex,
  applied for 7 March 2023, "Ready for consultation: No"). No name for Kent, registered or applied for
  (register search and the applications page, last updated 27 January 2026). Kent is the largest county by
  vineyard area (WineGB 2025: 1,239 ha), but with no official designation there is no area to draw.

## Held back
- Sussex `red_body`, `red_acidity`, `red_tannin`: only the specification describes the reds ("lighter in style
  with soft tannins"); no second independent source. Reds are a small part of output.
- Sussex `pairing`: nothing found in two independent sources.
- "Sussex" as England's first regional PDO (WineGB says so); not repeated in the summary without a second source.
- Darnibole (PDO, a single vineyard area in Cornwall): real and registered but outside this brief.
- The Crouch Valley (Essex): applied for only, not protected.
