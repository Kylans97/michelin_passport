# morava (Morava / Moravia, CZ): municipality mapping notes

Prepared 2026-11-21. CSV: morava.csv.

## Official text
- Vyhláška č. 254/2010 Sb., kterou se stanoví seznam vinařských podoblastí, vinařských obcí a viničních tratí, ve znění vyhlášky č. 80/2018 Sb. a vyhlášky č. 75/2025 Sb.; consolidated version effective 2025-04-01, read from the official e-Sbírka API (https://www.e-sbirka.cz/sb/2010/254/2025-04-01; raw/esb_frag0.json, the four Morava tables of the Příloha, part B). Issued under § 4 odst. 4 of Act 321/2004 Sb. e-Sbírka lists no later amendment (checked 2026-11-21).
- Cross-check: PDO Morava specification (EUGI00000005161, PDO-CZ-A0899, eAmbrosia attachment 17074, raw/cz_morava_17074.txt), § 4: the area is the vinařské obce of vyhláška 254/2010 Sb. (312 obce at 31.12.2010; the current text has 310).

## How resolved
- The decree lists each vinařská obec with the katastrální území (k.ú.) it covers. Parsed (tools: cz_parse.py) to 356 (obec, k.ú.) pairs: mikulovská 30 obce, slovácká 119, velkopavlovická 71, znojemská 90 = 310 obce. An empty obec cell under a numbered obec (Horní Dunajovice, Ivančice in znojemská) continues the obec above (table layout), checked against the numbering 1..N per podoblast with no gaps.
- Each k.ú. resolved by name within the obec of the same name, restricted to the Moravian kraje, using ČÚZK RÚIAN code lists UI_KATASTRALNI_UZEMI / UI_OBEC / UI_OKRES (services.cuzk.gov.cz/sestavy/cis/, downloaded 2026-11-21, current records only). GISCO_ID = CZ_ + RÚIAN obec code; all 310 present in the LAU 2024 index (tools: cz_resolve.py).
- Name qualifiers: "Němčičky (okr. Břeclav)", "Němčičky (okr. Brno-venkov)", "Ořechov (okr. Brno-venkov)" resolved with the okres checked. "Kobeřice" (velkopavlovická): RÚIAN obec 593141 is named "Kobeřice u Brna" and holds the only k.ú. "Kobeřice u Brna" named in the decree.
- partial = the obec has k.ú. the decree does not list for it. 16 obce partial: Lednice, Pohořelice, Hradčovice, Koryčany, Mistřice, Ostrožská Nová Ves, Uherské Hradiště, Uherský Ostroh, Brno (9 of 48 k.ú.), Bučovice, Senice na Hané, Hostěradice, Ivančice, Moravský Krumlov, Vedrovice, Znojmo. Brno and Senice na Hané (okres Olomouc) are vinařské obce of the decree.
- No obec appears in two podoblasti. The per-obec podoblast is kept in ce_se_tools/cz_resolved.json for later appellation drawing.

## Judgement calls
- Drew the whole vinařská oblast Morava as one region (about 96% of Czech vineyard) with the four podoblasti as appellations, rather than one podoblast.

## Counts
- Rows: 310
- Partial: 16
- Provinces: okres Brno-město, okres Brno-venkov, okres Břeclav, okres Hodonín, okres Kroměříž, okres Olomouc, okres Přerov, okres Třebíč, okres Uherské Hradiště, okres Vyškov, okres Zlín, okres Znojmo

## Held back / left out (style)
- Morava red_body: Conflicting: spec and Vinařský fond call reds full in higher categories, spec calls quality reds light ruby with fine acid; no consistent second source.
- Morava red_acidity: Only the PDO spec ('kyselina je jemná'); no independent second source.
- Morava pairing: No two independent sources for a region level pairing.
- Morava appellations: VOC Mikulovsko, VOC Hustopečsko, VOC Velkopavlovicko, VOC vinice Velké Pavlovice, VOC Slovácko, Cech blatnických vinařů (Blatnice): Listed as VOC associations in the MZe SVZ 2025 table, but the appellation name is an area name or differs from the association name; could not confirm the exact registered VOC designation and its boundary officially.
- Morava appellations: VOC Pálava, VOC Modré Hory, VOC Kraví Hora, VOC Růžové hory, VOC Přítlucká hora: In the official MZe VOC list, but the name is not a wine municipality in the Morava spec list, so location inside Morava not confirmed from an official text.
- Morava grapes beyond the top 15 (Hibernal 415 ha, Modrý Portugal 392 ha, Cabernet Sauvignon, Merlot, Neuburské 207 ha, André): Smaller shares (under 2.6% each); Neuburské and André not main grapes, so not proposed as new grapes.

## Style content
See style.json. A claim was kept only where two independent sources agree; an EU single document and its national specification count as one government source.
