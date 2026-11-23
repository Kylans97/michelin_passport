# Grape notes, round 5

Prepared 2026-11-23, not started. Round 5 only checks and sources what
rounds 2 to 4 left open; it adds no new countries. Product owner,
2026-11-23: "zet de punten voor een volgende ronde klaar als ronde 5".

Everything to do is in `round5_queue.csv`, one row per field or grape,
with the point it comes from, the task, the text in production today
(`current_value`), the candidate text found earlier (`candidate_value`) and
the sources cited for it so far.

| Point | Rows | What to do |
|---|---|---|
| W3 | 81 | Region fields with one good source and one lower tier source (tourism, importers, single wine reviews, trade fair pages). Find a second good, independent source. |
| W2 | 51 | Fields with two good sources that the checking pass of 2026-11-23 could not confirm: a paywalled or unreadable page, a source about the wider region, a single wine review, a sponsored piece, or two pages of one body. Each row's task says which. Two were held at review because one source is a tourism site (Valle del Elqui Sauvignon Blanc, Ștefan Vodă Cabernet Sauvignon). The full checking notes are in `../grape_notes_open/w2_check_*.csv`. |
| W1 | 3 | Rules the specification check could not settle. Vale dos Vinhedos Cabernet Franc and Tannat: the INPI caderno PDF needs reading by eye or with a renderer. Cotnari Muscat Blanc à Petits Grains: the specification names only Tămâioasă românească, and Dealu Mare's lists it apart from Moscato Bianco, so whether the link is the same grape needs a decision first. |
| D7 | 8 | South African regions where Syrah is labelled Shiraz. One national source (SAWIS, WOSA, the Wine of Origin scheme) covers all eight. Write `Shiraz`, without a full stop. |
| D8 | 11 | Held texts resting on one organisation: tastes in Baden, Mittelrhein, Württemberg, Wachau, Rutherglen, Moselle Luxembourgeoise and the Colli Orientali (Merlot, Pinot Gris), and Durbanville's three roles. |
| F11, F21, F32 | 3 | Cafayate Malbec taste (one source says the style is moving to juicier wines), Maldonado Albariño "most planted white", Vaud Chasselas "Dorin". |
| N1 to N3 | 3 | Found in passing on 2026-11-23: Cigales Tempranillo's planting share, Friuli Merlot's "most planted red", and Mudgee Syrah's role and taste now repeating each other. |
| G1, G2 | 11 | Grape level tastes: Lambrusco Grasparossa (Black cherry has no top tier source; the Consorzio names sour cherry and blackberry) and ten grapes whose missing tastes have one body each. |

## Rules, unchanged from rounds 2 to 4

- Two independent organisations per claim. Two pages of one body, or a
  piece made with or sponsored by a body, count as that body once.
- A rule from an official specification needs only the specification, and
  the sentence states only what it says.
- Fill only empty fields; a rewrite of an existing text is a separate,
  guarded statement on the exact current text.
- No dashes in our own words; official proper names keep their own hyphen
  (Hemel-en-Aarde, Saint-Émilion, Riesling-Silvaner).
- No shares or rankings by planted area. A percentage that is a rule may
  stay.
- Each research agent works in its own folder. Results are tiered strong,
  weak or held, tested on a scratch stack, and applied only on the product
  owner's yes.
