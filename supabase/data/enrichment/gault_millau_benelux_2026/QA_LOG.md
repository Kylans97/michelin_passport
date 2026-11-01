# QA log — Gault&Millau Benelux batch 1 (2026-10-31)

Working ids `GMB-n`, mapped to `supabase/data/qa_issues.csv` on 2026-10-31:
the batch itself QA-377 (applied); GMB-1 → QA-378; GMB-3, GMB-4, GMB-6 and
the held rows → QA-379; GMB-5 → QA-380; GMB-7 → QA-381; GMB-9 → QA-382.
GMB-2, GMB-8, GMB-10 and GMB-11 are recorded here only. Nothing listed here
was fixed in production — every item is held or logged.

## Findings

**GMB-1 — NL catalogue addresses differ from Gault&Millau for 62 of the
original NL rows (Data quality, Medium).** For 62 Dutch restaurants (55
proposed in tier A2, 6 already in production, Nami held) the website and
phone agree with G&M but the street address does not — often a different
street altogether (Fred: ours Honingerdijk 95, G&M Boompjes 41; Restaurant
212: ours Amsteldijk 212, G&M Amstel 212; De Librije: ours Broerenkerkplein
13, G&M Spinhuisplein 1; Herberg Onder de Linden: 9.2 km apart). Some look
swapped between venues: our Zoldering carries Lastage's address
(Geldersekade 29), our De Juwelier carries Zoldering's (Utrechtsestraat
141). Almost all are `rest_0001`–`rest_0122`, the launch import.
**Checked against the stored Google Place IDs (2026-10-31, Google Maps
`place_id:` lookup):** `rest_0122` Zoldering's Place ID
(`ChIJ-7KWKfIJxkcRjSc9EMSbNOQ`) resolves to Zoldering, Utrechtsestraat
141H, 1017 VM — zoldering.nl, 020 765 1212, pin 52.36135, 4.89935, about
1.4 km from our stored point. `rest_0032` De Juwelier's Place ID
(`ChIJBXvoaX8JxkcRuWOWTJHtcKc`) resolves to De Juwelier, Utrechtsestraat
51, 1017 VJ — restaurant-dejuwelier.nl, 020 247 1007, pin 52.36426,
4.89835, about 460 m from ours. Both agree with Gault&Millau on address,
website and phone. So the Place IDs are right, and our `address` and
`location` are wrong for both: Zoldering's row holds Lastage's address
(Geldersekade 29, a G&M-only restaurant not in the catalogue), and De
Juwelier's row holds Zoldering's. The Place IDs give a third, independent
source for the address fix. Not fixed
here — a G&M page is not a source for our location fields. Recommended: a
separate address/coordinate verification of the NL launch rows against
MICHELIN and the venues' own sites. (This also resolves the old `gm_024`
REVIEW: the conflict was our address, not a different restaurant.)

**GMB-2 — Sibling venues share website, phone or building (Matching,
Info).** 19 G&M entries were removed as candidates by the name veto because
they are a second venue of the same house: e.g. Goeie Louisa (Karel 5),
Grand Bistro Echo (Wild Atelier), Franky's Grill (FG), Marie (Flore), Maes
(Create), L'Auberge and Les Salons (Château Neercanne), Sazanka and Serre
(Okura), Bar Bulot Antwerpen (Hertog Jan), Moonstone (De Kristalijn). None
is imported. Logged so nobody "fixes" them onto the main restaurant later.

**GMB-3 — Ambiguous one-house pairs held (Matching, Low).** 10 rows where
two G&M entries legitimately claim one code: Alma / Alma Bodega
(rest_0005), De Kromme Watergang / De Kromme Bistro (rest_0035), Ron
Gastrobar / three Ron Gastrobar Indonesia pages (rest_0095), and others in
the table below. A human picks which entry is our restaurant (usually
obvious from MICHELIN's page), then they move to PROPOSE.

**GMB-4 — Single-signal matches held (Matching, Low).** 10 rows where only
the website (8) or only the phone (2) agrees and the address does not:
Vinkeles, Vista, Voltaire, CUE, Lizz, 't Ganzenest, De Heeren van
Harinxma, Create by Guido Braeken, Lutum, and one BE row. Likely correct,
but one signal is not enough under the never-guess rule.

**GMB-5 — Unscored entries (Data, Info).** 5 matched restaurants have a
G&M page with no score and no toques (Chambres d'Amis, d'Eugénie à Émilie,
La Table – Lasne, 't Fornuis, Nami); 151 such pages appear across the three
sites. They are not imported: what an unscored page means (new, under
review, not yet visited) is not stated on the page, and `recognition_type`
has no value for it. Not H!P — H!P lives under `/en/hip/`, not crawled.

**GMB-6 — Phone conflict (Matching, Low).** Le Grand Verre (rest_0889):
address matches but our phone differs from G&M's. Held.

**GMB-7 — Belgian 2027 edition launches 9 Nov 2026 (Timing, Medium).**
The 111 BE rows are 2026 values. Decide before applying whether BE goes in
now (as 2026 history, with 2027 added after launch) or only after 9 Nov.

**GMB-8 — 16 catalogue restaurants have no G&M page (Coverage, Info).**
Listed in `catalogue_without_gm_match.csv`. Mostly restaurants whose star
is NULL (lost or closed) — consistent with QA-216/QA-376 — plus Kommilfoo
(BE, 1★), La Table de Manon (BE, 1★), Bij Sidney, Le Epifaan, SUIS (NL).
Not searched by name, by design.

**GMB-9 — 2,012 G&M restaurants are not in the catalogue (Scope, Info).**
`gault_millau_benelux_2026_not_in_catalogue.csv`. None scores 17 or more;
92 score 15–16.5. Not created. Adding G&M-only restaurants is a product
decision (`inclusion_reason = 'gault_millau'` already exists) and a
separate batch with its own identity checks.

**GMB-10 — Near-miss: map pins alone (Method, Info).** Within 150 m pairs
like Vermeer/MOS, CUE/Spectrum, Lastage/Zoldering, 6&24/Zheng — so
coordinates are never a candidate on their own. Recorded per the
log-near-misses standard.

**GMB-11 — Near-miss: scratch database port (Process, Info).** The first
local test of the SQL connected to port 55432, which another session's
scratch PostgreSQL was already using; the two test tables were created
there. They did not exist there before (the CREATE succeeded), held only
this test's data, and were dropped again at once; the test was then rerun
on its own instance. No production contact. Pick an unused port and check
`show data_directory` before testing.

## Held rows

| staging_id | class | G&M entry | score | catalogue candidate(s) / reason |
|---|---|---|---|---|
| gm26_be_0009 | REVIEW_NAME_CONFLICT | Bar Bulot (BE) | 14.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0159 Hertog Jan at Botanic [address+coords<=150m] |
| gm26_be_0017 | REVIEW_NAME_CONFLICT | Bistrôt Le Ciel (BE) | 12.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0167 Ralf Berendsen [address+coords<=150m] |
| gm26_be_0026 | MATCH_B_ADDRESS_ONLY | Chambres d'Amis (BE) | — | no score published on profile (unscored entry) - not imported |
| gm26_be_0038 | MATCH_A3_CONTACT_AND_LOCATION | d'Eugénie à Émilie (BE) | — | no score published on profile (unscored entry) - not imported / catalogue address differs from G&M: "Pl. de la Résistance 1, 7331 Saint-Ghislain" |
| gm26_be_0061 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | L' Impératif d'Éole (BE) | 14.0 | candidates: rest_0868 l'Impératif d'Éole [phone+address+coords<=150m] / code also matched by: https://www.gaultmillau.be/en/restaurants/la-brasserie-deole-quevy-quevy-le-grand |
| gm26_be_0064 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | La Brasserie d’Éole (BE) | 12.5 | candidates: rest_0868 l'Impératif d'Éole [phone+address+coords<=150m] / code also matched by: https://www.gaultmillau.be/en/restaurants/l-imperatif-deole-quevy-quevy-le-grand |
| gm26_be_0067 | REVIEW_SINGLE_SIGNAL_PHONE | La Paix (BE) | — | no score published on profile (unscored entry) - not imported / candidates: rest_0836 La Paix [phone] |
| gm26_be_0069 | REVIEW_NAME_CONFLICT | La Source (BE) | 15.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0167 Ralf Berendsen [address+coords<=150m] |
| gm26_be_0071 | MATCH_A | La Table - Lasne (BE) | — | no score published on profile (unscored entry) - not imported |
| gm26_be_0079 | REVIEW_PHONE_CONFLICT | Le Grand Verre (BE) | 16.0 | candidates: rest_0889 Le Grand Verre [address+coords<=150m] |
| gm26_be_0088 | REVIEW_NAME_CONFLICT | Lounge by Château de Vignée (BE) | 13.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0882 Arden [address+coords<=150m] |
| gm26_be_0095 | REVIEW_NAME_CONFLICT | Moonstone (BE) | 13.5 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0847 De Kristalijn [phone+address+coords<=150m] |
| gm26_be_0117 | MATCH_A3_CONTACT_AND_LOCATION | 't Fornuis (BE) | — | no score published on profile (unscored entry) - not imported / catalogue address differs from G&M: "Reyndersstraat 24, 2000 Antwerpen, Belgium" |
| gm26_nl_0150 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | Alma Bodega (NL) | 13.5 | candidates: rest_0005 Alma [website+phone] / code also matched by: https://www.gault-millau.nl/en/restaurants/alma-oisterwijk |
| gm26_nl_0151 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | Alma (NL) | 15.0 | candidates: rest_0005 Alma [website+phone] / code also matched by: https://www.gault-millau.nl/en/restaurants/alma-bodega-oisterwijk |
| gm26_nl_0162 | REVIEW_NAME_CONFLICT | Bistro LOF (NL) | 14.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0116 Voltaire [website] |
| gm26_nl_0163 | REVIEW_NAME_CONFLICT | Bistro Nijeholt (NL) | 12.5 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0031 De Heeren van Harinxma [website] |
| gm26_nl_0175 | REVIEW_SINGLE_SIGNAL_WEBSITE | Create by Guido Braeken (NL) | 17.0 | candidates: rest_0027 Create by Guido Braeken [website] |
| gm26_nl_0176 | REVIEW_SINGLE_SIGNAL_WEBSITE | CUE (NL) | 15.0 | candidates: rest_0028 CUE [website] |
| gm26_nl_0184 | REVIEW_SINGLE_SIGNAL_WEBSITE | De Heeren van Harinxma (NL) | 16.5 | candidates: rest_0031 De Heeren van Harinxma [website] |
| gm26_nl_0187 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | De Kromme Bistro (NL) | 14.0 | candidates: rest_0035 De Kromme Watergang [website+phone] / code also matched by: https://www.gault-millau.nl/en/restaurants/de-kromme-watergang-hoofdplaat |
| gm26_nl_0189 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | De Kromme Watergang (NL) | 16.0 | candidates: rest_0035 De Kromme Watergang [website+phone] / code also matched by: https://www.gault-millau.nl/en/restaurants/de-kromme-bistro-hoofdplaat |
| gm26_nl_0201 | REVIEW_NAME_CONFLICT | Franky's Grill (NL) | 13.5 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0046 FG - François Geurds [phone+coords<=150m] |
| gm26_nl_0204 | REVIEW_NAME_CONFLICT | Goeie Louisa (NL) | 13.5 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0055 Karel 5 [website+address] |
| gm26_nl_0205 | REVIEW_NAME_CONFLICT | Grand Bistro Echo (NL) | 14.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_1404 Wild Atelier [website+phone+address+coords<=150m] |
| gm26_nl_0206 | REVIEW_NAME_CONFLICT | Grand Café Bourgogne (NL) | 12.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0784 Merlet [website+phone+address+coords<=150m] |
| gm26_nl_0216 | REVIEW_NAME_CONFLICT | Lastage (NL) | 15.5 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0122 Zoldering [address] |
| gm26_nl_0218 | REVIEW_NAME_CONFLICT | L'Auberge (NL) | 12.5 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0022 Chateau Neercanne [website+phone+address] |
| gm26_nl_0219 | REVIEW_NAME_CONFLICT | Les Salons (NL) | 14.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0022 Chateau Neercanne [website] |
| gm26_nl_0220 | REVIEW_SINGLE_SIGNAL_WEBSITE | Lizz (NL) | 14.5 | candidates: rest_0062 Lizz [website] |
| gm26_nl_0221 | REVIEW_SINGLE_SIGNAL_PHONE | Lutum (NL) | 15.5 | candidates: rest_0063 Lutum [phone] |
| gm26_nl_0222 | REVIEW_NAME_CONFLICT | Maes (NL) | 13.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0027 Create by Guido Braeken [phone] |
| gm26_nl_0224 | REVIEW_NAME_CONFLICT | Marie (NL) | 13.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0047 Flore [phone+address] |
| gm26_nl_0230 | MATCH_A2_WEBSITE_PHONE_ADDRESS_DIFFERS | Nami (NL) | — | no score published on profile (unscored entry) - not imported / catalogue address differs from G&M: "Molenstraat 7, 5113 AL Cromvoirt" |
| gm26_nl_0246 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | Ron Gastrobar (NL) | 15.0 | candidates: rest_0095 Ron Gastrobar [website+phone+address] / code also matched by: https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-amstelveen, https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-laren, https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-bloemendaal |
| gm26_nl_0247 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | Ron Gastrobar Indonesia (NL) | 13.5 | candidates: rest_0095 Ron Gastrobar [website] / code also matched by: https://www.gault-millau.nl/en/restaurants/ron-gastrobar-amsterdam, https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-laren, https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-bloemendaal |
| gm26_nl_0248 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | Ron Gastrobar Indonesia (NL) | 12.5 | candidates: rest_0095 Ron Gastrobar [website] / code also matched by: https://www.gault-millau.nl/en/restaurants/ron-gastrobar-amsterdam, https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-amstelveen, https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-laren |
| gm26_nl_0249 | REVIEW_CODE_CLAIMED_BY_OTHER_GM | Ron Gastrobar Indonesia (NL) | 13.5 | candidates: rest_0095 Ron Gastrobar [website] / code also matched by: https://www.gault-millau.nl/en/restaurants/ron-gastrobar-amsterdam, https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-amstelveen, https://www.gault-millau.nl/en/restaurants/ron-gastrobar-indonesia-bloemendaal |
| gm26_nl_0252 | REVIEW_NAME_CONFLICT | Sazanka (NL) | 14.5 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0025 Ciel Bleu [address+coords<=150m]; rest_0119 Yamazato [website+phone+address+coords<=150m] |
| gm26_nl_0253 | REVIEW_NAME_CONFLICT | Serre (NL) | 13.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0025 Ciel Bleu [address+coords<=150m]; rest_0119 Yamazato [website+phone+address+coords<=150m] |
| gm26_nl_0257 | REVIEW_NAME_CONFLICT | Spencer’s (NL) | 12.0 | NOT a match: a sibling venue sharing address/website/phone with a catalogue restaurant (name veto) / candidates: rest_0022 Chateau Neercanne [website] |
| gm26_nl_0261 | REVIEW_SINGLE_SIGNAL_WEBSITE | ‘T Ganzenest (NL) | 15.5 | candidates: rest_0104 t Ganzenest [website] |
| gm26_nl_0272 | REVIEW_SINGLE_SIGNAL_WEBSITE | Vinkeles (NL) | 17.5 | candidates: rest_0114 Vinkeles [website] |
| gm26_nl_0273 | REVIEW_SINGLE_SIGNAL_WEBSITE | Vista (NL) | 15.0 | candidates: rest_0115 Vista [website] |
| gm26_nl_0274 | REVIEW_SINGLE_SIGNAL_WEBSITE | Voltaire (NL) | 16.0 | candidates: rest_0116 Voltaire [website] |

## Catalogue rows with no G&M page

| code | name | stars | reason |
|---|---|---|---|
| rest_0163 | La Durée (BE) | NULL | Leenstraat 28, 8870 Izegem |
| rest_0167 | Ralf Berendsen (BE) | NULL | Paalsteenlaan 90, 3620 Lanaken |
| rest_0798 | Kommilfoo (BE) | 1 | Vlaamse Kaai 17, 2000 Antwerpen, Belgium |
| rest_0830 | Mémoire (BE) | NULL | Dijver 7, 8000 Brugge, Belgium |
| rest_0846 | Aurum by Gary Kirchens (BE) | NULL | Ordingen-Dorp 5, 3800 Sint-Truiden, Belgium |
| rest_0890 | La Table de Manon (BE) | 1 | Rue de Givet 79, 6940 Grandhan, Belgium |
| rest_0043 | Demain (NL) | NULL | Visserijweg 1, 4506 CH Cadzand |
| rest_0098 | Sense (NL) | NULL | Taalstraat 100, 5261 BH Vught |
| rest_0144 | Spectrum (NL) | NULL | Herengracht 542-556, 1017 CG Amsterdam |
| rest_0149 | De Groene Lantaarn (NL) | NULL | Gemeenteweg 364, 7951 PG Staphorst |
| rest_0781 | Graphite by Peter Gast (NL) | NULL | Paardenstraat 15III, 1017 CX Amsterdam |
| rest_1398 | Bij Sidney (NL) | 1 | Kerkstraat 5, 3632 EL Loenen aan de Vecht |
| rest_1400 | Le Epifaan (NL) | 1 | Bloemberg 5, 7924 PW Veeningen |
| rest_1403 | SUIS (NL) | 2 | Strucht 77, 6305 AH Schin op Geul |
| rest_1840 | Tacite (NL) | NULL | Cornelis Krusemanstraat 15, 1075 NB Amsterdam |
| rest_1841 | Petit Péché (NL) | NULL | Nicolaas Beetsstraat 51h, 1053 RJ Amsterdam |
