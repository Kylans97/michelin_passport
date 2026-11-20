# wr_0009 Mosel (Anbaugebiet / g.U. Mosel): source notes

**Source:** "Mosel" Qualitätswein, Prädikatswein, Sekt b.A. und Qualitätsperlwein: Produktspezifikation für eine geschützte Ursprungsbezeichnung (Land Rheinland-Pfalz; file gU_Mosel_111219.pdf, dated 19.12.2011; eAmbrosia dossier PDO-DE-A1270), section 3 "Abgrenzung des Gebietes".
URL: https://api.edoweb-rlp.de/resource/edoweb:5424622/data (archived by edoweb, the Rheinland-Pfalz state library repository). Retrieved 2026-11-20.

**Cross-check:** The Gemeinde list in Anlage 1 of the Landesverordnung über Qualitätswein b.A. Mosel (RLP, 18.07.1995; version shown valid from 30.09.2001, via lexaris.de) confirms the spellings Hockweiler, Wiltingen and Mülheim an der Mosel.

**Not checked:**
- No current consolidated specification could be retrieved. The eAmbrosia API search did not respond, and EUR-Lex returned an empty response to automated download.
- A DLR Rheinpfalz presentation (January 2021) reports 128 Kommunen with 197 Gemarkungen and a planned parcel-level delimitation (Gemarkungen). That count differs from this 2011 document. Any later amendment is not reflected here.
- The wording is "Rebflächen der Gemeinden", meaning the vineyard areas of these Gemeinden. A union of whole Gemeinde polygons therefore overstates the planted area. This applies especially to the cities: Koblenz, Trier, Wittlich, Konz and Saarburg.

## Counts
- Rheinland-Pfalz: 131 Gemeinden listed, 131 matched. Each maps to a distinct GISCO_ID in Kreis 07231, 07135, 07137, 07235, 07211 or 07111.
- Saarland: 1 Gemeinde with 4 Ortsteile listed ("Gemeinde/Ortsteile Perl, Oberperl, Nennig, Sehndorf"). All 4 map to Gemeinde Perl (DE_10042115), marked partial: Ortsteile are not LAU units, so the Perl polygon is larger than the area listed.
- Total: 135 rows, 132 distinct GISCO_IDs.
- Held back: **none**.

## Corrections to the source text
- Two punctuation typos in the PDF were repaired before parsing: "Wasserliesch. Wawern" and "Zell (Mosel, )Zeltingen-Rachtig".
- The Kreis qualifiers in the document were used to disambiguate: Burgen (Bernkastel-Wittlich) vs Burgen (Mayen-Koblenz); Esch (Bernkastel-Wittlich); Wawern (Trier-Saarburg).

## Spelling differences accepted (each had one candidate in its Kreis and is confirmed by the 1995 Landesverordnung list)
- Hochweiler -> Hockweiler (DE_07235048)
- Witlingen -> Wiltingen (DE_07235148)
- Mülheim (Mosel) -> Mülheim an der Mosel (DE_07231090)
- Flussbach -> Flußbach

## Held back
None.
