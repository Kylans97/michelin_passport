**Not drawn:** Rivierenland is 5 km either side of the river centrelines, clipped at borders; the 13 municipalities the dossier names are only part of it, and no official geometry exists.

# BOB Rivierenland (PDO, NL)

## Sources
- RVO productdossier: https://www.rvo.nl/sites/default/files/2026-08/Productdossier-BOB-Rivierenland.pdf (local: dl_nl/Productdossier-BOB-Rivierenland.pdf)
  - **Version:** "April 2022 (herzien in de ALV van BOB Rivierenland op 9 april 2025)" plus "Mei 2026 standaardwijzigingen toegevoegd => ras Satin Noir, Monarch maximale opbrengst herzien en minimale aantal dagen pulpgisting van rode wijn". Page headers say "April 2025". This is the only BOB dossier carrying a 2026 change.
- RVO "Gewijzigd enig document": https://www.rvo.nl/sites/default/files/2026-08/Gewijzigd-enig-document-BOB-Rivierenland.pdf (local: dl_nl/Gewijzigd-enig-document-BOB-Rivierenland.pdf)
  - Standard amendment under Reg. (EU) 2024/1143 art. 24 (Satin Noir added; red maceration minimum cut from 4 to 3 days; Monarch yield raised from 40 to 60 hl/ha; Satin Noir yield 40 hl/ha). Includes the full single document, EU ref PDO-NL-02774, "Datum van toepassing: 10.06.2021".
- eAmbrosia: EUGI00000017964, PDO-NL-02774, registered, protection 2021-06-10. OJ C315 19.8.2022; OJ L323 19.12.2022.

## Part 1: area
Single document §6 (the productdossier §2.1.1 is the same):
> "Het oorsprongsgebied “Rivierenland” bestrijkt een aaneengesloten gebied tussen en langs de rivieren die vanuit Duitsland en Limburg de provincie Gelderland instromen tot aan Gorinchem … Voor de buitengrenzen van dit gebied geldt dat deze doorlopen tot 5 km hemelsbreed aan de overzijde van de rivier, waarbij het midden van de rivier als peilafstand wordt aangehouden. Het gebied wordt aan de noordzijde begrensd door (van oost naar west) de Oude IJsel, IJsel, Nederrijn en Lek, in het oosten door de landsgrenzen met Duitsland tussen Gendringen en Bredeweg. Aan de zuidkant wordt het gebied begrensd door de provinciale grens met Limburg – tussen Bredeweg en Molenhoek – en de provinciale grens met Noord-Brabant tot en met Heusden, welke de loop van de rivier de Maas volgt. De westgrens wordt afgebakend met het Heusdensch kanaal en de afgedamde Maas richting Woudrichem … Vanaf Woudrichem wordt de Gelderse provinciale grens gevolgd over de Linge richting de Lek …"

Productdossier: "Het afgebakende gebied is in totaal ongeveer 300.000 hectare groot."

Soil restriction (productdossier §2.1.3.1):
> "In dit afgebakende gebied is het oorsprongsgebied Rivierenland enkel van toepassing op riviergronden bestaande uit polder- en ooivaaggronden (zie Tabel 1 …)"

Tabel 1 lists the soil-map codes: Rn52A, Rn82A, Rn66A, Rn46A, Rn15A, Rn95A, Rn45A, Rn62C, Rn42C, Rn14C, Rn67C, Rn94C, Rn47C, Rn44C, bRn46C, Rn15C, Rn95C, Rn45C, KRn1, KRn2, KRn8, Rd10A, Rd90A, Rd40A, Rd10C, Rd90C, Rd40C, KRd1, KRd7.

Figure 1 (a map on a PDOK base) shows the outer line 5 km beyond the river centrelines, including strips north of the IJssel/Rijn/Lek and, on the map, south of the Maas into Noord-Brabant. The text and the map are not fully consistent on the south edge: the text says "begrensd door de provinciale grens met Noord-Brabant", while the map's thin outer line runs south of the Maas near Heesch and Rosmalen.

Smaller named areas (85% rule):
- "Betuwe" consists of the gemeenten Buren, Culemborg, Lingewaard, Neder-Betuwe, Overbetuwe, Tiel and West Betuwe, plus the parts of Arnhem and Nijmegen between the Rijn and the Waal, and "ligt volledig in het oorsprongsgebied".
- "Achterhoek" covers the gemeenten Bronckhorst, Doetinchem, Montferland and Oude IJsselstreek, "die ook (deels) binnen Rivierenland vallen".

### Units used: INCOMPLETE by design
- **No administrative unit set matches this delineation faithfully.** It is a geometric construction (5 km from river centrelines, clipped by provincial and national borders) plus a soil filter. No official geometry of the BOB area exists in PDOK, RVO or eAmbrosia as far as I could find.
- The CSV lists **only the 13 municipalities the dossier itself names**, all LAU 2024 and all `partial=yes`. Even the "fully inside" Betuwe municipalities are subject to the polder/ooivaag soil filter, and Arnhem and Nijmegen count only between the Rijn and the Waal.
  - Betuwe: NL_GM0214 Buren, NL_GM0216 Culemborg, NL_GM1705 Lingewaard, NL_GM1740 Neder-Betuwe, NL_GM1734 Overbetuwe, NL_GM0281 Tiel, NL_GM1960 West Betuwe, NL_GM0202 Arnhem, NL_GM0268 Nijmegen
  - Achterhoek: NL_GM1876 Bronckhorst, NL_GM0222 Doetinchem, NL_GM1955 Montferland, NL_GM1509 Oude IJsselstreek
- **This is NOT the whole area.** Clearly missing are the Gelderland river municipalities the dossier does not name (for example along the Maas and Waal, around Arnhem, Duiven and Zevenaar), plus the 5 km strips in Utrecht, Overijssel(?) and Noord-Brabant. Deciding which municipalities the 5 km buffer touches needs the buffer to be built. That would be my derivation, not an official boundary, so I held it back.
- Overstatement and understatement: not assessable without building the buffer.

## Part 2: content (single document as amended, 2026)
- Categories: 1 Wijn, 5 Mousserende kwaliteitswijn, 9 Parelwijn waaraan koolzuurgas is toegevoegd, 15 Wijn van ingedroogde druiven.
- Grapes (§7, 15 varieties):
  - White: Cabernet Blanc, Johanniter, Merzling, Muscaris, Sauvignac (Cal 6-04), Solaris, Souvignier Gris, Villaris.
  - Red: Cabaret Noir, Cabernet Cantor, Cabernet Cortis, Monarch, Pinotin, Regent, Satin Noir.
- 13 wine types:
  - red dry fruity; red dry wood-aged (at least 9 months)
  - white dry fruity; white dry wood-aged; white medium-sweet; sweet wine (incl. ice wine)
  - rosé dry
  - sparkling white and rosé (traditional method)
  - pearl wine white, rosé and red
  - dried-grape sweet white
  - Blanc de noir is allowed within the white types.
- Max yields:
  - 40 hl/ha: Cabernet Cantor, Cabernet Cortis, Cabaret Noir, Pinotin, Regent, Satin Noir
  - 50 hl/ha: Cabernet Blanc, Muscaris, Sauvignac
  - 60 hl/ha: Johanniter, Merzling, Solaris, Souvignier Gris, Villaris, Monarch
- Soil, climate and style (single document §8):
  - Fertile, mineral-rich river clay and silty clay (zavel) with high water retention.
  - A "cool climate" with ripening into Sept–Oct.
  - In the rain shadow of the Utrechtse Heuvelrug and the Veluwe (800–825 mm/yr), with above-average wind drying the canopy.
  - Wines: "volfruitige aroma’s en frisse zuren"; reds with "zachte textuur en soepele tanninen".
- First vines in the area in 2004.

## Held back
- A full outline, which would require constructing the 5 km river-centreline buffer.
- The south-edge inconsistency between the text and Figure 1.
- The soil-filter polygons (Tabel 1 codes would need the Bodemkaart 1:50.000 overlay).
