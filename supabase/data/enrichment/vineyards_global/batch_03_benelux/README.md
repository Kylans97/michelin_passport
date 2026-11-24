# Batch 3: the Benelux, from official producer lists

Prepared 2026-11-25 (product owner: "ja is goed", on the Benelux tier).
**Nothing here is applied.** It waits for two things: the product owner's
review, and a build with server search in the app's hands. Until then,
shipped builds list every estate in the Wine Estates collection, and this
batch would add 93 there.

## What is in it

| Country | Official source | Rows | Loaded | Held back |
|---|---|---|---|---|
| Netherlands | RVO BOB documents, Staatscourant notices (`research/nl_sources.md`) | 11 | 9 | 2 |
| Belgium | Flanders: "Vlaamse Wijnproducenten met appellatiewijnen in 2025" (Agentschap Landbouw & Zeevisserij, 10/02/2026). Wallonia: the 2016 APAQ-W list (`research/be_sources.md`) | 45 | 39 | 6 |
| Luxembourg | vins-cremants.lu "Nos vignerons" (Fonds de Solidarité Viticole, IVV) (`research/lu_sources.md`) | 45 | 45 | 0 |
| **Total** | | **101** | **93** | **8** |

Of the 93: 32 get region and village, 39 region only, 22 no region (Flemish
producers whose only designations cover all of Flanders). Codes vine_0106
to vine_0206. After this batch production would hold 195 estates, still 97
ranked, so the collection is unchanged.

`inclusion_reason = 'official_register'`, a new value
(`supabase/migrations/20261101760000_add_vineyard_official_register_reason.sql`).
Not `official_classification`: that is for rankings such as 1855 or VDP,
which belong in the collection. Being registered to use a BOB is not one.

## Method

Research rules as in batch 2: website, address and pin from the estate's
own pages; coordinates only from the estate's own pin or, in the
Netherlands, the BAG address point; age checks never clicked.

Region comes from the protected designation the estate uses, mapped to an
atlas region in `assemble_batch03.py`. Village comes from the municipality:
- **Netherlands:** the gemeente code inside the BAG nummeraanduiding, an
  official id rather than a name.
- **Belgium and Luxembourg:** the municipality the address gives, which must
  match exactly one unit of the region's list. A Luxembourg locality that is
  not itself a commune (Ahn, Ehnen, Machtum) gets no village rather than a
  guessed one.

Estate pins are checked against the region outline. Outlines are
simplified to about 1 km, so a pin up to 1 km outside is accepted and its
distance logged.

**Tested** on a scratch stack holding production's data after batch 2: the
migration, then this file. Result: 195 estates, 163 with a region, 93 with
a village, 93 `official_register`, 97 ranked. Search finds them. A second
run is refused.

## Proposed QA log entries

```
QA-550,Source,Medium,vineyards batch 3,NL rows,"RVO's current BOB dossiers black out the applicant names. Producers came from figure captions the redaction missed, Staatscourant application notices, and older RVO copies read through the Wayback Machine (official documents, archived). Mergelland and Maasvallei Limburg have no official producer list (the latter names only the applicant association); Apostelhoeve, Wijngaardsberg and Thorn stay estate-stated only. St. Martinus is now officially confirmed for Vijlen",Accept archived official copies as a source, or ask RVO for the producer lists,Open
QA-551,Source,Medium,vineyards batch 3,BE Wallonia rows,"No current official producer list for Wallonia: the decrees say an approval commission keeps one, but it is unpublished; the only official naming is a 2016 list on the APAQ-W site, so no Walloon row is better than partial",Ask SPW Agriculture or APAQ-W for the current list,Open
QA-552,Access,Low,vineyards batch 3,vine_0107;vine_0111;vine_0147;vine_0150;vine_0152;vine_0155;vine_0159;vine_0161,"Held back: De Reeborghesch (own site: stopped making wine in 2026; address differs from the official one); 't Heekenbroek (own site: vines dug up for trees in 2025); Gorsco (no estate site, only a fruit company); Vidaigne (vidaigne.be is an unrelated holiday cottage); Celiandre and Coteaux de Dame Palate (no trace); Vignoble de la Mazelle (own site: no longer a vineyard since 2020); Domaine de Mellemont (site refuses automated access)",Leave out; recheck Mellemont by hand,Open
QA-553,Scope,Low,vineyards batch 3,LU and BE lists,"Not finished: Luxembourg list has 69 entries; 45 researched in list order (to #64 Pundel), #69 Jeff Konsbrück not, 17 with no website on the list skipped, 4 not estates, 2 duplicates merged. Belgium: five producers holding only BGA Vlaamse landwijn, La Ferme Bleue (IGP jardins de Wallonie) and BGP SPRL (a company name) not researched",Next Benelux pass,Open
QA-554,Near-miss,Low,vineyards wine_region_id,vine_0115;vine_0117;vine_0174;vine_0175;vine_0199;vine_0200;vine_0205,"Placed by designation: estate pins 0.02 to 0.78 km outside the simplified outlines, accepted within the outlines' ~1 km accuracy (Holset 0.67, Cep d'Or 0.22, Max-Lahr 0.09, Schlink 0.78, Schmit-Fohl 0.02); Aldeneyck (BE) in Maasvallei Limburg, a cross-border BOB the atlas files under NL; Domaine 64's seat is in Echternach, outside the Moselle communes, placed by its AOP",Confirm on review,Open
QA-555,Data conflict,Low,vineyards batch 3,LU and NL rows,"Logged per row: Luxembourg postcodes differ from the official list (Leuck-Thull, Gloden, Claude Bentz); addresses differ (Clos des Rochers, Häremillen, Domaine 64 Echternach vs Remerschen); estate sites refuse access (Bernard-Massard, Château de Schengen); Sunnen-Hoffmann's listed site is dead, its own site found separately; the list misspells A. Gloden & Fils as 'Golden'. De Wijnmakers: official address in Mariaparochie, own site in Geesteren",Review notes before applying,Open
QA-556,Missing data,Low,vineyards commune,39 region_only rows,"No village where the address gives a locality that is not itself a municipality (most Luxembourg addresses: Ahn, Ehnen, Machtum, Wellenstein, Remerschen...); no official locality-to-commune table was used, so none was guessed. 22 Flemish estates hold only country-wide designations and get no region",Add an official locality table (STATEC for Luxembourg) in a later pass,Open
```
