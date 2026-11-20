# Journey route stops: held back and flagged (2026-11-20)

Companion to `journey_route_stops_20261120.csv` and
`journey_route_stops_seed_20261120.sql`. Nothing here is applied.
25 of 38 routes have stops; 13 are held back. Stops were read from each
operator's own pages on 2026-11-20; coordinates from Wikipedia (station
article where the operator names a station, else the town) or
OpenStreetMap, as each row's `coord_source` says.

## Held back (no rows)

| Route | Reason |
|---|---|
| train_001_r07 Paris – Portofino | The train ends at Santa Margherita Ligure, not Portofino (transfer to the hotel). Route row's end differs. |
| train_001_r08 Paris – Amalfi Coast | The train ends at Pompeii, then a car to Ravello. Route row's end differs. |
| train_003_r01 The Highlands | The 2, 3 and 4 night versions have different stops; the 3 night page contradicts itself. |
| train_003_r04 Wild Scotland | Text does not settle the order of Strathcarron, Kyle of Lochalsh, Boat of Garten and Carrbridge. |
| train_003_r07 Clans, Castles & Isles | Day 4 heading and text disagree; map and text name different stations. |
| train_003_r08 Grand Tour of Scotland | Text says Wick and Wemyss Bay, the map says Georgemas and Ayr. |
| train_004_r03 Tiger Express | The operator does not name where the train ends; guests transfer by road and boat from Butterworth to The Datai Langkawi, which is not a train stop. Researched rows kept out of the CSV. |
| train_005_r03 Wales | Operator map (Haverfordwest, Barmouth, Kingham) and day text (Llandrindod Wells, near Blaenau Ffestiniog, Llandudno Junction, Kingham) disagree. |
| train_005_r04 Cornwall & Wales | Its Wales leg is the same disputed sequence as train_005_r03. |
| train_005_r05 The Lake District & Wales | Same as train_005_r04. |
| ship_002_r01 Corinthian Marseille – Rome | Not currently published. The only match sailed 19 to 22 July 2026; none of the 88 listed voyages is a 3 night Marseille to Rome. **The route row itself looks stale**; logged, not changed. |
| ship_011_r01, ship_011_r02 Napoléon | Belmond's itinerary pages repeat day numbers, skip days 5 to 7, and the map puts every marker in Champagne. |

## Kept, but flagged for review

- **train_001_r05 Paris – Vienna:** sold "via Budapest" and "via Prague";
  both name only Paris and Vienna, so the two stops are the same either way.
- **train_008_r02 Treasures of India:** day by day and route header give
  Delhi, Jaipur, Sawai Madhopur, Agra, Delhi; the homepage summary lists
  the reverse. Day by day used.
- **train_007_r03 Balkan Explorer:** from the live page (2027 and 2028
  dates). The 2026 departure links to a page that now returns 404, so its
  order could not be checked.
- **train_009_r01/r02 Mizukaze:** JR West names only the first and last
  station; everything between is a bus excursion. Two stops each, so a
  drawn route is a straight Kyoto to Shimonoseki arc, not the coast.
- **Map-only stops** (named on the operator's route map, not in the day
  text): St Erth, Princes Risborough, Gemas, Bridge of Orchy, Keith,
  Puno station ("Lake Titicaca station" in the text).
- **Town coordinates, not a station,** wherever the operator names no
  station; each row's note says so. Sawai Madhopur's Wikipedia point is
  coarse (26.0, 76.35).
- **Saracocha** (Andean Explorer) has no station; the lake's coordinates.

## Prerequisite

Romania, Bulgaria and Bosnia and Herzegovina are not in `countries`;
`journey_route_stops_countries_prereq.sql` adds them and must run first.

## Ships with no routes yet (list only)

From the operators' own sites, 2026-11-20: Four Seasons I
(fourseasonsyachts.com) and Evrima (ritzcarltonyachtcollection.com)
publish per-voyage itineraries; the four Aqua Expeditions ships have
destination pages, day by day not confirmed; Amandira has sample PDFs
only (voyages are bespoke); ponant.com blocks automated reading, so Le
Commandant Charcot and Le Ponant are unchecked.

---

# Research notes as written per group


## vsoe

### Held back: Venice Simplon-Orient-Express (Belmond)

#### train_001_r07 Paris – Portofino (3 nights)
Checked: https://www.belmond.com/en/trains/europe/venice-simplon-orient-express/journeys/paris-to-portofino-and-splendido-2026 (also 2027 package exists)
The train journey ends at **Santa Margherita Ligure** station (operator package data: arrivalStation labelled "Portofino", station "Santa Margherita Ligure"; page: shared transfer from Santa Margherita Ligure station to Splendido). 1 night on the train, then 2 nights at Splendido, Portofino. The train's last station (Santa Margherita Ligure) differs from the row's to_place (Portofino), so held back per instructions. Not fixed.

#### train_001_r08 Paris – Amalfi Coast (3 nights)
Checked: https://www.belmond.com/en/trains/europe/venice-simplon-orient-express/journeys/paris-to-the-amalfi-coast-and-caruso
The train journey ends at **Pompeii** (operator package data: arrivalStation labelled "Amalfi Coast", station "Pompeii"; itinerary Day 2 "Estimated Arrival, Pompeii", then car to Caruso, Ravello for 2 nights; departure Day 3 by transfer to Naples). The train's last station (Pompeii) differs from the row's to_place (Amalfi Coast), so held back. Not fixed.

## andean_scotsman

### Held back: andean_scotsman

All pages read on 2026-11-20. Operator pages sit under `https://www.belmond.com/en/trains/europe/uk/royal-scotsman/journeys/`. The URLs in the brief, under `/trains/europe/scotland/belmond-royal-scotsman/`, point to the same site.

#### train_003_r01 The Highlands ("2, 3 or 4 nights")
The operator has three separate pages, and their stops differ:
- 2 nights (`.../the-highlands-2-nights`): Edinburgh, Boat of Garten (overnight), Carrbridge (rejoin), Dundee (map marker), Edinburgh.
- 3 nights (`.../the-highlands-3-nights`): Edinburgh, Boat of Garten (overnight), Kyle of Lochalsh (overnight stabling), Aviemore (Rothiemurchus), Boat of Garten (rejoin), Perth (Day 4 departure), Edinburgh. The page also has an internal inconsistency: Day 1 says the train stops overnight at Boat of Garten, but Day 2 opens "Departing Keith", and the map shows Keith.
- 4 nights (`.../the-highlands-4-nights`): Edinburgh, Keith, Kyle of Lochalsh, Garve, Carrbridge, Boat of Garten, Kingussie, Perth, Dundee, Edinburgh.
The brief says to hold this route back when the stops differ by length. One option is to split it into three route rows.

#### train_003_r04 Wild Scotland (3 nights)
URL: `.../wild-scotland`. The endpoints and night count match, but the stop order cannot be read from the operator text:
- Day 2: the train runs "to Kyle of Lochalsh. After lunch on board, disembark at Strathcarron." Kyle is a terminus with Strathcarron on the line before it, so guests could leave the train at Strathcarron on the way in or on the way back. The page does not say which.
- Day 3: the text names only Carrbridge ("travel from Carrbridge to Rothiemurchus"). The map adds Boat of Garten and Perth, and Day 4 departs Perth. The text never says where guests rejoin the train or whether it reaches Boat of Garten before or after Carrbridge.
Map markers in order: Keith, Kyle of Lochalsh, Boat of Garten, Perth.

#### train_003_r07 Clans, Castles & Isles (5 nights)
URL: `.../clans-castles-isles`. The day text and the operator map contradict each other:
- The Day 4 heading reads "Boat of Garten", but the Day 4 text describes travelling to Dumfriesshire for Drumlanrig Castle in the far south.
- Day 5 starts by coach to Rothiemurchus (Cairngorms), returns to the train at Kingussie, disembarks at Stirling and ends at Dundee.
- Map markers: Spean Bridge, Oban, Kilmarnock, Sanquhar, Dundee. There is no Boat of Garten, Kingussie or Stirling, and Kilmarnock and Sanquhar never appear in the text.
The overnight places for nights 3 and 4, and the order of Kilmarnock and Sanquhar against the Highland stops, cannot be settled without guessing.

#### train_003_r08 Grand Tour of Scotland (7 nights)
URL: `.../grand-tour-of-scotland`. The endpoints and night count (8 days) match, but the text and map name different stations:
- Day 2 text: the train "continues to Wick". The map shows Georgemas instead, and Wick does not appear on it.
- Day 6 text: overnight stabling at Wemyss Bay. The map has no Wemyss Bay but shows Ayr, which the text never mentions.
- The map also shows Inverurie (Day 5 "disembark" for Crathes), Leuchars (St Andrews), Dumbarton (Loch Lomond) and Drumlanrig (not a station). None of these is named in the text as a place where the train halts.
Text-only sequence, for reference: Edinburgh, Boat of Garten, Tain, Wick, Dingwall, Kyle of Lochalsh, Dundee, Wemyss Bay, Kilmarnock, Edinburgh. It was not written because the operator's own map contradicts two of these stations.

## britannic_eo

### Held back: britannic_eo.csv

#### train_005_r03 Wales (London to London, 3 nights)
Checked: https://www.belmond.com/en/trains/europe/uk/britannic-explorer/journeys/wales

The operator's two sources on the same page disagree. Its route map lists the stops as London Victoria, Haverfordwest, Barmouth, Kingham, London Victoria. Its day-by-day text names a different set:
- Day 1: west to Pembrokeshire
- Day 2: disembark at Llandrindod Wells, then an "overnight stop near Blaenau Ffestiniog"
- Day 3: Llandudno Junction, then Kingham

The text never mentions Barmouth. The map leaves out Llandrindod Wells, Blaenau Ffestiniog and Llandudno Junction. The second night is at Blaenau Ffestiniog in the text and at Barmouth on the map. I can't tell which version is current, so I held the route back rather than choose. Endpoints (London Victoria) and nights (3) do match the row.

## dolcevita_eagle_mizukaze

### Held back: dolcevita_eagle_mizukaze

No route held back. Caveats the reviewer should see:

- train_009_r01 / train_009_r02 (Twilight Express Mizukaze, Sanin Course): JR West's course pages
  (https://twilightexpress-mizukaze.jp/en/journey/course/sanin_outbound.html and sanin_inbound.html,
  plus the Japanese versions) name only the departure and final stations. Excursions are given as
  AREAS reached by the MIZUKAZE bus, and view spots as "between X Station and Y Station", never as
  stations where the train halts. Per the brief, no intermediate station was invented; each route
  has 2 stops (start and end) and the areas are listed in verification_note. A drawn line will be
  a straight Kyoto to Shimonoseki segment, not the San'in coast route. Consider holding these back
  from the globe if two points are not useful.
- train_009_r01 has two seasonal variants (Mar to Sep via Kinosaki Onsen; Jan to Feb and Oct to Dec
  via Kasumi/Daijo-ji). Both share the same stations, so the output is identical either way.
- train_007_r03 (Balkan Explorer): the URL in the row's source list, /balkan-explorer-2025/, now
  returns 404; the 2026 timetable still links its 02/10/2026 departure there. The live page
  https://www.goldeneagleluxurytrains.com/balkan-explorer/ (2027 and 2028 dates, Venice to Istanbul,
  12 days) was used. Whether the 2026 departure follows the same order could not be verified; an
  older 2024 operator PDF brochure is reported to include Bar, Podgorica and Skopje instead.
- Golden Eagle and La Dolce Vita pages name cities, not stations (except Rome Ostiense and Istanbul
  Sirkeci); city coordinates were used and each such row says so.
- train_006_r01: row nights unknown; operator states 5 days / 4 nights.

## maharajas_ships

### Held back: maharajas_ships.csv

Checked 2026-11-20.

#### ship_002_r01: Orient Express Corinthian, Marseille to Rome, 3 nights

Held back because the voyage is not currently published.

- The only Marseille to Rome 3-night voyage on the operator's site is "Mediterranean Charms: Corsica & Rome", dated 19 to 22 July 2026, so it has already sailed:
  https://www.orient-express.com/en/sailing-yachts/destinations/mediterranean/mediterranean-charms-corsica-rome/190726-3-nights
  That page still loads. Its stops were Marseille, Propriano, Pianottoli, Calvi, then Rome (Civitavecchia). The ship anchored at Pianottoli overnight.
- None of the 88 voyages in the current listing (https://www.orient-express.com/en/sailing-yachts/itineraries, pages 0 to 8, December 2026 to 2027) sails from Marseille to Rome or Civitavecchia in 3 nights. The nearest are "Cannes to Rome featuring Porto Cervo & Bonifacio" (4 nights, 6 June 2027) and "Jet-Set Isles... Portofino to Rome" (6 nights, 4 August 2027). Neither one matches the row.
- If the 2026 stops are wanted as a historical route, a reviewer has to decide that. Rome would be Civitavecchia, as the page names it.

#### ship_011_r01: Napoléon, Avignon to La Voulte-sur-Rhône, 6 nights
#### ship_011_r02: Napoléon, La Voulte-sur-Rhône to Avignon, 6 nights

Both held back because the operator's itinerary is internally inconsistent and incomplete, so the order of stops cannot be read from it.

Pages:
- https://www.belmond.com/en/boats/europe/france/les-bateaux-belmond/journeys/napoleon-avignon-to-la-voulte-sur-rhone
- https://www.belmond.com/en/boats/europe/france/les-bateaux-belmond/journeys/napoleon-la-voulte-sur-rhone-to-avignon
- https://www.belmond.com/en/boats/europe/france/les-bateaux-belmond/journeys/napoleon-la-voulte-sur-rhone-to-avignon-open-sailing

The endpoints and the 6 nights do match the rows. The problems are elsewhere:
- **Avignon to La Voulte:** the day-by-day goes "Day 1", "Days 2 & 3 Vallabrègues to Arles", "Day 4 Arles to Roquemaure", then "Day 3 & 4 Roquemaure to La Voulte-sur-Rhône". Days 3 and 4 appear twice, nothing covers days 5 to 7, and the last block calls Viviers and Grignan the "last night onboard" with no day number.
- **La Voulte to Avignon:** the day-by-day reuses the header from the opposite direction ("Day 3 & 4 Roquemaure to La Voulte-sur-Rhône") and covers only days 1 to 4.
- **Embedded map data on all three pages:** every marker shares one coordinate pair, 49.0240, 4.2357, which is in Champagne and not on the Rhône. One marker is titled "Vraux", a Marne village that looks like a leftover from a Champagne barge template. The return-direction map lists La Voulte, Vraux, Arles, Avignon, Vallabrègues, Arles, Avignon, which is not a usable order.
- **Places named without days or order:** Grignan, Viviers, Pont du Gard (passed by boat), Châteauneuf-du-Pape, Roquemaure (a "rural mooring"), Arles, Les Baux-de-Provence and Vallabrègues. Grignan, Châteauneuf-du-Pape and Les Baux are inland excursions, not moorings.
- **Two variants for r02:** the charter page and the open-sailing page carry the same text, so this point is minor next to the problems above.

#### Extra: ships with no routes in our database (list only)

| Ship | Operator site publishes itineraries? | Example URL |
|---|---|---|
| Four Seasons I | Yes. Each voyage has its own page on the brand's yacht domain, fourseasonsyachts.com, not fourseasons.com, with named ports. | https://www.fourseasonsyachts.com/voyages/the-rivieras-featuring-sardinia-and-monte-carlo |
| Evrima | Yes. Dated voyage pages carry an /itinerary tab. | https://www.ritzcarltonyachtcollection.com/luxury-caribbean-cruises/sanjuan-to-panamacity-11261112/itinerary (that sailing is past; it shows the pattern) |
| Aqua Nera | Probably. There is a destination page per cruise; I did not confirm a day-by-day on it. | https://www.aquaexpeditions.com/destinations/amazon-river-cruise |
| Aqua Mekong | Probably, as for Aqua Nera. | https://www.aquaexpeditions.com/destinations/mekong-river-cruise |
| Aqua Blu | Probably, as for Aqua Nera. | https://www.aquaexpeditions.com/destinations/indonesia-cruise/bali-komodo-national-park |
| Aqua Lares | Probably, as for Aqua Nera. | https://www.aquaexpeditions.com/destinations/svalbard-arctic-cruise |
| Amandira | Only as sample journeys. Aman says voyages are bespoke and flexible, so these are weak candidates for fixed routes. | https://www.aman.com/sites/default/files/2021-06/Amandira-Alor_Journey.pdf |
| Le Commandant Charcot | Not confirmed. ponant.com blocks automated fetching: its paths redirect to the homepage and the search tool refuses the domain. Ponant does sell dated voyages, but I found no ponant.com example URL. | none confirmed |
| Le Ponant | Not confirmed, for the same reason as Le Commandant Charcot. Dated 2027 voyages exist, seen only on agent sites. | none confirmed |
