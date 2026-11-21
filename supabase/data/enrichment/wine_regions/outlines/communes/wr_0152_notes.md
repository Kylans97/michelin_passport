# Württemberg (DE): boundary notes

**Official text:** Single document after standard amendment PDO-DE-A1276-AM02, Official Journal C/2025/5177, 25.9.2025, section 6 (http://data.europa.eu/eli/C/2025/5177/oj; text on disk at classics/de/raw/am_wuer2.html.txt). Wording: "die Rebflächen folgender Gemeinden (Gemarkungen) und deren Ortsteile", 275 entries in Baden-Württemberg, each with a Gemarkung number; in Bayern "Die Gemeinden Nonnenhorn, Wasserburg und Bodholz und die Gemarkungen Hoyren und Aeschach der Großen Kreisstadt Lindau". The amendment says the area itself did not change; the list was brought up to date and numbered.

**Gemarkung register and geometry:** LGL Baden-Württemberg, ALKIS Gemarkungen, OGC API collection `gemarkung` (https://ogcapi-test.lgl-bw.de/pygeoapi/collections/gemarkung; 3,380 Gemarkungen, each with gemarkung_id, Gemeinde AGS and Kreis; state 2025-01-01). Licence: Datenlizenz Deutschland Namensnennung 2.0, attribution "Datenquelle: LGL, www.lgl-bw.de, dl-de/by-2-0" (stated on https://www.lgl-bw.de/Produkte/Open-Data/). Caveat: the API host is LGL's test server; the same product is also offered as download on the LGL Open GeoData portal. Raw: raw/lgl_gemarkungen.json (attributes), raw/lgl_geom/<number>.json (one file per listed Gemarkung).

**Method:** each entry was looked up by its Gemarkung number (numbers are unique statewide). 274 of 275 numbers exist, and for all 274 the LGL Gemarkung name equals the name in the text (accent-insensitive). The 274 Gemarkungen are drawn themselves (held_units.geojson, unit_id `DE_BW_GMK_<number>`, simplified to about 100 m) rather than whole Gemeinden; they fall in 128 Gemeinden. Bayern is drawn at Gemeinde level from GISCO LAU 2024 (no open Bavarian Gemarkung layer was fetched).

**Rows:** 278 (274 Gemarkungen + 4 Bavarian LAU). Partial: 1 (Lindau, only the Gemarkungen Hoyren and Aeschach).

**Judgement calls:**
- "Bodholz" read as the Gemeinde Bodolz (DE_09776111), the only similar name in Landkreis Lindau. Supporting evidence: a Bodolz estate (Weingut Lanz) labels its "Bodolz weiß" as Württemberg (falstaff.com). This is a spelling resolution, not a text match; drop the row if that is not acceptable.
- "Wasserburg" in the Bayern sentence is Wasserburg (Bodensee), Landkreis Lindau.

**Held back:**
- Stetten (761): no Gemarkung 761 in the LGL register. Stetten am Heuchelberg is Gemarkung 768 (Schwaigern), which may be the intended entry, but the number does not match, so it is not drawn. Schwaigern itself is covered by Schwaigern (765) and Niederhofen (767).

**Overlap with Baden:** checked spatially against classics/de/baden.csv (drawn as whole Gemeinden). Only three Gemeinden are shared, and in each the texts split them by Gemarkung, with no shared Gemarkung: Eppingen (Württemberg: Kleingartach 753, Richen 755; Baden: 752, 754, 756), Bad Mergentheim (Württemberg: Mergentheim 150, Markelsheim 158; Baden: Dainbach 153), Oberderdingen (Württemberg: 3490; Baden: Flehingen 3491). The map will show overlap only because Baden draws those three Gemeinden whole; those Baden rows should be marked partial. Tauberfranken otherwise does not overlap (Krautheim, listed in the 2011 Württemberg text, is no longer in the 2025 list). Bodensee: Württemberg has Kressbronn, Ravensburg and Taldorf; none is in baden.csv.

**Side finding:** the same LGL register resolves Baden's held-back Malsch (Gemarkung 3260); not acted on here.
