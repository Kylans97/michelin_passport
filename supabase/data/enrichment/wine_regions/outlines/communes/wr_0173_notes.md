# montefalco

## Official text
- Montefalco Sagrantino DOCG (header: last amended DM 03.07.2023, G.U. 162 of 13.07.2023) and Montefalco DOC (same zone). Art. 3: whole comune of Montefalco and part of Bevagna, Gualdo Cattaneo, Castel Ritaldi and Giano dell'Umbria, province of Perugia.

## Counts
5 printed names, 5 rows, 4 partial; by province: Perugia 5.
- Four partial rows as the text says.

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. Ratings describe Sagrantino (grape level from Wine Folly plus Vinography on the DOCG wine); Montefalco Rosso DOC is Sangiovese led and lighter, which these ratings do not describe. Acidity nulled: Wine Folly medium high, Vinography only 'reasonably good acid retention'; no second clear rating. Altitude (220 to 472 m) only in the disciplinare, left out. Both Wine Folly pages count as one source. Pairing: Wine Folly Umbria guide (roast boar) and Vinography (roasted wild boar over lentils).
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
