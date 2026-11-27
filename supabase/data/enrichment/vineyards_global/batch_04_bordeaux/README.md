# Batch 4: the Bordeaux classifications

Prepared 2026-11-25 (product owner: "Oke, laten we doorgaan", on the
official classifications tier; "One section per list" for the collection).
**APPLIED to production 2026-11-27 (product owner: "Yes, apply both")**, right after batch 3: 340 estates in all, 154 recognitions on 153
estates. QA-557 to QA-562 are in qa_issues.csv.

## What is in it

| List | Official source | Recognitions | Held back |
|---|---|---|---|
| Bordeaux 1855, Médoc (incl. Haut-Brion, Mouton 1973) | Conseil des Grands Crus Classés en 1855, gcc-1855.fr | 58 | 2 (Durfort-Vivens, Giscours: the Conseil's links are broken) |
| Bordeaux 1855, Sauternes and Barsac | same | 23 | 4 (Suau, Doisy-Védrines, Nairac, de Malle: no own site, or the link is wrong) |
| Graves 1959 | Pessac-Léognan appellation body (decree not read) | 14 | 2 (Laville and La Tour Haut-Brion, now La Mission wines) |
| Saint-Émilion 2022, Premiers A and B | INAO (Journal officiel order not read) | 14 | 0 |
| Saint-Émilion 2022, Grands Crus Classés | INAO, 45 of 71 in list order | 45 | 0 |
| **Total** | | **154** | **8** |

154 recognitions are spread over 153 estates: 145 new (vine_0207 onward)
and the 8 Bordeaux estates already in the catalogue. Haut-Brion is one
estate on two lists. 114 of the new estates get a village. Afterwards
production would hold 247 estates. Guides would show a Bordeaux
Classifications card, one row per list.

## Method

Research rules as in batches 2 and 3. On top of them:
- **Existing estates** are linked by the code the research confirmed
  through the website domain or the address, never by name.
- **Two rows are one estate** only with the same website domain *and* the
  same printed name on two different lists; in this batch that is only
  Haut-Brion. A shared domain alone is not identity: owner groups run one
  site for several classified châteaux (Lafite and Duhart-Milon, Léoville
  and Langoa Barton). A first version of the script merged those, and I
  corrected it before it was tested.
- **Display name:** each estate's own spelling, read from its own site
  (`names/own_names_*.csv`; product owner, 2026-11-25: "use the estates own
  spelling"). It is used only when it is the same name as the official
  print once accents, case and punctuation are folded, so "Château
  LEOVILLE-POYFERRE" becomes "Château Léoville Poyferré". The printed form
  is kept in aliases for search.
  - 125 of 145 estates now have their own spelling.
  - 18 keep the print in title case: their site did not load, gave no URL,
    or wrote the name two ways.
  - 2 keep the print because the estate's own name differs: "Château
    Marquis d'Alesme" drops "Becker", and "La Fleur Morange" has no
    "Château".
- **Class order** within a list: Premier 1 through Cinquième 5; Sauternes
  Premier Cru Supérieur 1, Premier 2, Second 3; Saint-Émilion A 1, B 2,
  Grand Cru Classé 3.

**Needs** migration `20261101890000_add_vineyard_recognitions.sql`.

**Tested** on a scratch stack with production's data: the migration, then
this file. Result: 247 estates, 154 recognitions, and Haut-Brion with
both. A second run is refused. The app, run in the simulator against that
stack, shows the Bordeaux Classifications card and each list with the class
and the village under each estate.

## For you to decide

1. ~~The Guides entry~~: decided 2026-11-25. A separate "Bordeaux
   Classifications" card with a row per list; the 50 Best row stays the 50
   Best alone.
2. ~~Names without accents~~: decided 2026-11-25, own spelling (above).

## Proposed QA log entries

```
QA-557,Source,Medium,vineyard_recognitions,bordeaux_1855_medoc,"The Conseil des Grands Crus Classés en 1855 lists its members: Château Léoville Las Cases, a Second Cru of 1855, is not on it, so it has no row (60 Médoc rows instead of 61)",Find an official source naming all 1855 growths (the 1855 list itself, or INAO) and add Léoville Las Cases,Open
QA-558,Access,Low,vineyard_recognitions,8 rows,"Held back: Durfort-Vivens (Conseil link shows an unrelated club page) and Giscours (link redirects to a hosting error); Suau (link points to Domaine de Chevalier), Doisy-Védrines (link is a négociant), Nairac (domain does not resolve), de Malle (domain serves unrelated content); Laville Haut-Brion and La Tour Haut-Brion (now made as La Mission wines)",Find the estates' own sites by hand; decide whether discontinued classified names stay,Open
QA-559,Naming,Low,vineyards batch 4,20 of 145 new estates,"Product owner chose each estate's own spelling (2026-11-25). 125 read from the estates' own sites. 18 keep the title-cased print: the site was unreachable (Latour, Rauzan-Ségla 403, Saint-Pierre, Talbot, Belgrave, Cos Labory, Canon, Grand-Puy Ducasse, Lafaurie-Peyraguey, Beau-Séjour Bécot, Badette), had no URL (Berliquet, Guadet, La Tour Figeac, Couhins-Lurton, Beauséjour Héritiers Duffau-Lagarrosse) or wrote the name two ways (Ferrière, La Tour Blanche, Rieussec, Myrat). 2 differ from the print beyond accents: Marquis d'Alesme (no Becker), La Fleur Morange (no Château); print kept",Fill the 18 by hand; decide on the 2,Open
QA-560,Scope,Low,vineyard_recognitions,saint_emilion,"Saint-Émilion Grands Crus Classés: 45 of 71 researched (stopped after Le Chatelet; Le Prieuré next). Ausone, Cheval Blanc, Angélus and La Gaffelière left the classification before 2022 (press only, not an official source) and are not added",Next pass: the remaining 26,Open
QA-561,Data conflict,Low,vineyards batch 4,see notes,"Logged per row: Lafite gives only the group office; Croizet-Bages and Haut-Bages Libéral link owner group pages; Talbot, Saint-Pierre, Cos Labory and Belgrave share a server that refused every connection; Pouget's two pins 230 m apart (withheld); Montrose's listed domain is dead (own site used); d'Issan's contact and legal pages disagree; Romer and Romer-du-Hayot links look swapped; Doisy-Dubroca's owner says it merged into Doisy Daëne in 2014 though the list keeps both; Fombrauge's legal notice gives Pape Clément's Pessac seat; Duhart-Milon's address read under an unanswered age overlay",Review notes before applying,Open
QA-562,Source,Low,vineyard_recognitions,graves_1959;saint_emilion,"Graves list read from the Pessac-Léognan appellation body's page (the decree and the Graves union's site could not be read); Saint-Émilion from INAO's page on the 8 Sept 2022 approval (the Journal officiel order could not be retrieved; INAO's archived English page has errors and was not used)",Check against the decree and the JO order when reachable,Open
```
