# Baden: source notes

**Source:** Single document published with the approved standard amendment PDO-DE-A1264-AM02, Official Journal C, C/2026/5957, 10.11.2026, section 9. Gemeinden are listed per Bereich with Gemarkung numbers.
URL: http://data.europa.eu/eli/C/2026/5957/oj (retrieved 2026-11-21).

**Wording:** "die Rebflächen folgender Gemeinden (Gemarkungen) und deren Ortsteile". A union of whole Gemeinde polygons therefore overstates the planted area.

## Counts
- Entries listed in the text: 167 (Baden: counted per Gemeinde and Bereich)
- Rows written: 161, distinct GISCO_IDs: 161
- Rows marked partial: 0

## Partials
- None marked.

## Left out
- None.

## Held back
- Malsch: two Gemeinden of this name lie in the Bereich Kraichgau Kreise (DE_08215046 Malsch, DE_08226046 Malsch); the text gives only Gemarkung number 3260, which cannot be resolved without a Gemarkung register.

## Matching notes
- Matching was done per Bereich, inside the Kreise that Bereich lies in, so that same-named Gemeinden are kept apart: "Sasbach" in Bereich Ortenau is Sasbach (Ortenaukreis), "Sasbach" in Bereich Kaiserstuhl is Sasbach am Kaiserstuhl (Landkreis Emmendingen).
- Short names in the text mapped to the full LAU name, each the only Gemeinde of that stem in the Bereich Kreise: Gailingen -> Gailingen am Hochrhein, Eichstetten -> Eichstetten am Kaiserstuhl, Endingen -> Endingen am Kaiserstuhl, Riegel -> Riegel am Kaiserstuhl, Sasbach (Kaiserstuhl) -> Sasbach am Kaiserstuhl, Müllheim -> Müllheim im Markgräflerland.
- Freiburg im Breisgau appears under Breisgau, Markgräflerland and Tuniberg; Teningen under Breisgau and Kaiserstuhl; Breisach am Rhein under Kaiserstuhl and Tuniberg; Schallstadt under Markgräflerland and Tuniberg. Each is one row.
- Partial column: the text lists each Gemeinde by Gemarkung number(s) only. Whether those are all the Gemarkungen of the Gemeinde was not checked (no Gemarkung register at hand), so no row is marked partial. Cities listed with one Gemarkung (e.g. Karlsruhe 3621, Heidelberg 3320, Konstanz 6660, Lörrach 7350, Mosbach 2881) are likely only partly covered.
- Bereich Tauberfranken (Main-Tauber-Kreis, Krautheim) and the Bodensee shore are also near Württemberg/Franken; Württemberg was not mapped, so overlap with it was not checked.
- Every match was made by name inside the Kreise the region lies in (Kreis codes checked against each Kreis seat in the GISCO LAU 2024 index), and each name resolved to exactly one LAU.
