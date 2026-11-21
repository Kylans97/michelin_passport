# Vulkanland Steiermark (AT): boundary notes

**Official text:** Weingesetz 2009 § 21 Abs. 3 Z 3 lit. c: "die politischen Bezirke Hartberg-Fürstenfeld, Südoststeiermark und Weiz sowie von den politischen Bezirken Graz-Umgebung und Leibnitz die Gemeinden links der Mur" (https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40254626/NOR40254626.html, raw copy alps_hr/at/raw/WG_21_NOR40254626.txt). DAC-Verordnung § 1 (BGBl. II Nr. 299/2018 idF BGBl. II Nr. 250/2024, NOR40265201): the DAC area equals the Weinbaugebiet. The product specification (alps_hr/at/raw/spec_vulkanland.txt) omits Graz-Umgebung; the law is used.

**Units:** GISCO LAU 2024 (AT_ + Gemeindekennziffer), checked against Statistik Austria Gemeindeliste 2026.
- Whole Bezirke: Weiz (617), Hartberg-Fürstenfeld (622), Südoststeiermark (623): 92 LAU. LAU 2024 still has Fürstenfeld and Söchau separately (merged 2025 as Fürstenfeld 62280); both drawn.
- Leibnitz left of the Mur: from the Südsteiermark split (alps_hr/at/raw/leibnitz_mur_sides.tsv): Allerheiligen bei Wildon, Empersdorf, Gabersdorf (98%), Heiligenkreuz am Waasen, Ragnitz, Sankt Georgen an der Stiefing, Schwarzautal, Sankt Veit in der Südsteiermark; partial Wildon (41% left), Gralla (33%), Straß in Steiermark (78%).
- Graz-Umgebung left of the Mur: same method (OSM Mur centreline split of LAU polygons; script round4/held_tools/mur_sides.py, output raw/grazumgebung_mur_sides.tsv): 18 Gemeinden wholly or almost wholly left (Gössendorf, Gratkorn 99%, Hart bei Graz, Hausmannstätten, Kainbach bei Graz, Kumberg, Laßnitzhöhe, Peggau 97%, Sankt Radegund bei Graz, Semriach, Stattegg, Vasoldsberg, Weinitzen, Eggersdorf bei Graz, Fernitz-Mellach 98%, Nestelbach bei Graz, Raaba-Grambach, Sankt Marein bei Graz); partial Frohnleiten (27% left).

**Rows:** 122; partial 4. "Links der Mur" read as the left bank in the direction of flow (east), as for Südsteiermark.

**Left out (slivers under 3% left, within LAU generalisation):** Feldkirchen bei Graz, Kalsdorf bei Graz, Werndorf, Deutschfeistritz, Gratwein-Straßengel, Wagna, Ehrenhausen an der Weinstraße. Lebring-Sankt Margarethen (13% of the LAU polygon left of the centreline, but described as on the right bank) is left out, unconfirmed.

**Overlap:** Wildon, Gralla and Straß in Steiermark are partial in both Südsteiermark and Vulkanland, as the river split requires. Graz city (601) belongs to Weststeiermark and is not included.

Style: see style.json and work/notes_de_at_si.md (Traminer left out of the grape list: the Austrian term covers several Traminer forms; St. Anna lead variety conflict resolved in favour of the law's annex).
