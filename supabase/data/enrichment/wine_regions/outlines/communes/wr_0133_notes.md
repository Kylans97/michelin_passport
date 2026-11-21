# Kakheti (Appellation of Origin "Kakheti (Kakhuri)", Georgia)

## Official basis
- Sakpatenti (National Intellectual Property Center of Georgia), state registry, "Appellations of Origin
  registered in Georgia": **Kakheti, registration 789, 10/12/2007**, applicant LEPL National Wine Agency.
  Register: https://www.sakpatenti.gov.ge/en/state_registry/ ; specification:
  https://www.sakpatenti.gov.ge/media/django-summernote/2025-11-18/9e436e4c-2036-4549-bda6-d691935a4162.pdf
  (copy `raw/sakpatenti/kakheti.pdf`). The same text is published by DEFRA for the UK-Georgia agreement:
  https://assets.publishing.service.gov.uk/media/641461b6d3bf7f79dbd3db34/Kakheti__Kakhuri_wine.pdf
- Area, verbatim: "Viticulture zone Kakheti includes administrative borders of: Akhmeta, Telavi, Gurjaani,
  Sighnaghi, Dedoplistskaro, Kvareli, Lagodekhi and Sagarejo municipalities." These are exactly the eight
  municipalities of the Kakheti mkhare in the COD-AB data (adm1 pcode GE29), so the appellation and the
  administrative region coincide.
- The UK register lists all these Georgian names as "Protected Geographical Indication (PGI)" protected under
  the UK-Georgia agreement (registered there 31 December 2020). In Georgia they are Appellations of Origin and
  the specification's label wording is "Protected Designation of Origin and/or PDO". Use the Georgian status.

## How the area is drawn (9 rows)
- Dataset: OCHA COD-AB Georgia, `cod-ab-geo` v01 on HDX, admin level 2 (`geo_admin2.geojson` from
  `geo_admin_boundaries.geojson.zip`). HDX methodology: "Accessed from 'administraciuli erTeulebi', National
  Statistics Office of Georgia; modifications by OCHA"; names reviewed by the Ministry of Emergency Situations.
  Boundaries created by the source 28 August 2019, valid on 18 October 2019, reviewed 31 January 2024.
  Licence CC BY-IGO. https://data.humdata.org/dataset/cod-ab-geo
  So: Geostat geometry, repackaged by OCHA. Geostat and NAPR offer no openly licensed download I could find,
  which is why the HDX package is used. geoBoundaries was checked and not used: its Georgia ADM2 is sourced
  from Wikimedia Commons (2007 units, public domain), a weaker source than Geostat.
- Units: GE2924 Akhmeta, GE2930 Telavi, GE2911 Telavi City, GE2926 Gurjaani, GE2936 Sighnaghi,
  GE2928 Dedoplistskaro, GE2938 Kvareli, GE2932 Lagodekhi, GE2934 Sagarejo. Their areas sum to the GE29
  Kakheti admin-1 area (11,408.6 km²).
- **Telavi City is a separate polygon in COD-AB** (an enclave inside Telavi, 12 km²). The specification names
  only "Telavi" municipality, which today includes the town, so the enclave row carries `official_name`
  "Telavi" and `lau_name` "Telavi City". Without it there would be a hole in the middle of the region.
- Simplification: shared-arc Douglas-Peucker at 100 m in a local metric projection; neighbours meet edge to
  edge (pairwise overlap 0 m², union has no holes), area change under 0.1% per unit (Telavi City -0.3%).
- Near-miss logged: the specification's soil paragraph says Outer Kakheti "includes the regions of Sagarejo,
  Gurjaani and Gardabani". Gardabani is in Kvemo Kartli. The binding area clause lists only the eight
  municipalities above, so Gardabani is not drawn.

## Appellations (only names on the Sakpatenti register, specification read for each)
All twenty are wine appellations whose specification places them in Kakheti: Kakheti (789), Tsinandali (3),
Mukuzani (2), Napareuli (790), Kindzmarauli (787), Kvareli (798), Akhasheni (4), Teliani (791), Gurjaani (5),
Vazisubani (794), Manavi (788), Tibaani (796), Kardenakhi (795), Kotekhi (799), Saperavi Khashmi (975),
Tsarapi (978), Akhmeta / Akhmetis Mtsvane (979), Akhoebi (980), Kisi Magraani (981), Zegaani (982).
- Amber wines (Tibaani, Kardenakhi, Tsarapi; Akhmeta and Kisi Magraani in part) are given colour "white"
  because the colour list has no amber; the note says amber.
- Kotekhi's specification names no municipality; its stated point (41°45' N, 45°48' E, right bank of the
  Alazani) falls in Gurjaani on the COD-AB polygons.
- Near-misses: several specifications print latitude as "longitude" and the reverse, and some points are
  rough (Kvareli and Kindzmarauli give 41°30' N, which falls in Sighnaghi, not Kvareli; Napareuli's point falls
  in Kvareli, 45 m from the Telavi boundary, although its text says Telavi; Saperavi Khashmi's point falls
  about 2.4 km outside Sagarejo, which its text names).
  The text of each specification, not its coordinates, was used to place it. The register gives Saperavi
  Khashmi's date as 04/06/2018 and its specification 06/04/2018 (day and month swapped somewhere); not used.
- Not included: Khvanchkara (Racha), Tvishi and Okureshis Usakhelouri (Lechkhumi), Sviri (Imereti), Ateni and
  Okami (Shida Kartli), Bolnisi (Kvemo Kartli), Salkhino Ojaleshi (Samegrelo), Racha and Lechkhumi (2025), all
  outside Kakheti. Obcha (986, 19/12/2024) has no specification published on the register, so its place
  could not be checked: held back.

## Content
- Summary sources: WSET ("Eastern Georgia, particularly Kakheti, is the country's largest and most
  influential wine region"; Saperavi "Kakheti's most important red grape"), Decanter ("Kakheti ... produces
  around three-quarters of the country's wine"), SevenFifty Daily (70% of Georgian wine; Kakhetian skin-contact
  amber wines), UNESCO (qvevri). Share figures differ by source (70%, three quarters, about 80%), so the
  summary says "most of its wine".
- Red structure (Saperavi dominates the reds): body 4 from the Kakheti specification (red dry "full,
  extracted, velvet") and Halliday's Wine Companion ("full-bodied"); acidity 4 from Tim Atkin's Kakheti notes
  ("racy acidity", "plenty of refreshing acidity"), Decanter (a Kakheti Saperavi with "elevated acidity") and
  Halliday ("high in acidity"); tannin 4 from Tim Atkin ("tannic", "rather brutal tannins" when young),
  Halliday ("high in ... tannin") and Decanter's grape entry ("firm"). Some Decanter notes describe softer,
  modern bottlings ("approachable", "middling" tannin), so 4, not 5.
- Pairing: Decanter (Saperavi with "kebabi (lamb kebabs)") and Tim Atkin (a Kakheti Saperavi "a great match
  with lamb").
- Label note: specification section 10 (label wording) and section 8 (made inside Kakheti, bottling allowed
  elsewhere in Georgia).
- Grape order: Rkatsiteli then Saperavi by national harvest share (Decanter: about 57.5% and 33.6%;
  SevenFifty: Rkatsiteli over 60%, Saperavi 33% of production). Mtsvane Kakhuri, Kisi and Cabernet Sauvignon
  follow in the order the Kakheti specification lists them; no source ranks them against each other.

## Held back
- Khikhvi, Mtsvivani Kakhuri, Chitistvala, Saperavi Budeshuri, Rkatsiteli Rose: permitted by the Kakheti
  specification but not added to the grape list (would each be a new grape needing two sourced profiles).
- Obcha (see above).
- Other Georgian regions (Kartli, Imereti, Racha-Lechkhumi): outside this brief.
