# primitivo-di-manduria

## Official text
- Primitivo di Manduria DOC (header: last amended DM 07.03.2014). Art. 3: "i terreni vocati alla qualità di tutto o parte dei Comuni" then the list for Taranto and Brindisi, including only the frazione of Talsano and the administrative islands of the comune of Taranto.

## Counts
19 printed names, 19 rows, 19 partial; by province: Brindisi 3, Taranto 16.
- All rows partial: the text says "tutto o parte" without saying which, as with Valpolicella earlier. Taranto is partial in any case (only Talsano and the islands). The Dolce Naturale DOCG has the same Art. 3 list.

## Name resolution
- ALIAS: San Giorgio Jonico -> San Giorgio Ionico (spelling variant (J for I); the only comune in the province of Taranto whose name starts with San Giorgio)
- ALIAS: Torre S. Susanna -> Torre Santa Susanna (abbreviation of Santa)

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. Tannin 2: vino.com (Primitivo di Manduria: soft and pleasant tannins) and Gilbert & Gaillard (soft tannins) agree; Wine Folly's grape level Zinfandel/Primitivo says medium-high, outvoted two to one but worth knowing. Body nulled: vino.com full (5) vs Wine Folly medium-full (4), no third. Acidity nulled: only Wine Folly (medium-low), grape level. Soils: disciplinare clay loam, Gilbert & Gaillard limestone, vino.com clay-calcareous (grape level). Pairing partly grape level (Wine Folly Zinfandel). Italy Magazine's 'needs a few years in barrel or bottle' and the Dolce Naturale DOCG not used.
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
