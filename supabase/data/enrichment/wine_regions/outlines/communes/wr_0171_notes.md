# lambrusco-grasparossa

## Official text
- Lambrusco Grasparossa di Castelvetro DOC (header: last amended Decreto 05.11.2024). Art. 3: whole territory of 13 comuni and part of Modena.

## Counts
14 printed names, 14 rows, 1 partial; by province: Modena 14.
- "Prignano sul Secchia" in the list is Prignano sulla Secchia (the same article's boundary text spells it so). Castelfranco Emilia, Modena and San Cesario sul Panaro are also in Sorbara; the two regions overlap there.

## Name resolution
- ALIAS: Castelvetro -> Castelvetro di Modena (short form; the only comune in the province of Modena whose name starts with Castelvetro)
- ALIAS: Fiorano -> Fiorano Modenese (short form; the only comune in the province of Modena whose name starts with Fiorano)
- ALIAS: Prignano sul Secchia -> Prignano sulla Secchia (spelling variant; the same Art. 3 delimitation spells it Prignano sulla Secchia)
- ALIAS: S. Cesario sul Panaro -> San Cesario sul Panaro (abbreviation of San; the Sorbara text spells it in full)

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. All three ratings nulled. Body: italianwinecentral says full bodied, but Wine Folly rates Lambrusco light to medium and retail notes say medium; only relative claims (fullest Lambrusco) agree. Tannin: italianwinecentral 'tannic' and Wine Folly 'moderately high' versus Wine Folly's deep dive 'moderate' and a Decanter note of light, softer tannins; no third settles it. Acidity: disciplinare says low acidity, Wine Folly rates Lambrusco medium plus to high. Soils (clay and silt per Cellar Tours, varied per disciplinare) left out. Pairing held back: only Wine Folly names dishes (sausages, lasagna, ribs).
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
