# cerasuolo-di-vittoria

## Official text
- Cerasuolo di Vittoria DOCG (header: last amended D.M. 17.02.2020, G.U.U.E. C 216 of 30.06.2020). Art. 3: whole comuni of Vittoria, Comiso, Acate, Chiaramonte Gulfi, Santa Croce Camerina; part of Ragusa; part of Niscemi, Gela, Riesi, Butera, Mazzarino (Caltanissetta); part of Caltagirone, Licodia Eubea, Mazzarrone (Catania).

## Counts
14 printed names, 14 rows, 9 partial; by province: Caltanissetta 5, Catania 3, Ragusa 6.
- Nine partial rows as the text says. The Classico subzone (Art. 3, by cadastral sheets) is not drawn.

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. All ratings nulled: only The Buyer (the-buyer.net) gives wine level style (medium body, easy tannins, moderate acidity); other hits were single bottle reviews or retailers, and Falstaff and Jancis Robinson returned 403. Pairing nulled: fish or pork from The Buyer only; Falstaff and Jancis Robinson (fish) could not be fetched to verify. Fresh: Decanter (fine, elegant and fresh) and James Suckling (some of Sicily's freshest wines). Soils: disciplinare (terra rossa on calcarenite, sandy soils), Decanter (red earth, limestone), James Suckling (sandy, iron oxides, over limestone). Decanter's 'fragrant, juicy, cherry red' held back as single source; the 'cooling sea breezes' (James Suckling only) not used.
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
