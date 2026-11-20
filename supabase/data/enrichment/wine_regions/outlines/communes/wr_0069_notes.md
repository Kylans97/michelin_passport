# Ticino (DOC Ticino)

## Official texts
- Regolamento sulla viticoltura (RViti) of 11.09.2024, Bollettino ufficiale delle leggi 2024 n. 29
  (13.09.2024), in force immediately. It repeals the 2015 regulation, and its art. 16 leaves the
  DOC details to directives (`raw/ti_BU_2024_029.pdf`).
- Direttive sulla viticoltura of 02.09.2025 (Sezione dell'agricoltura), point 3.3:
  "Possono essere vini DOC quelli vinificati nel Cantone Ticino, ottenuti da uve prodotte sui
  territori del Cantone Ticino e della Mesolcina."
  https://www4.ti.ch/fileadmin/DFE/DE-SA/viticoltura/direttive_viticoltura.pdf
- Graubünden, Kantonale Weinverordnung BR 917.400 (version in force since 01.07.2019, current per
  gr-lex): art. 2 let. b defines the wine region "Misox mit den Gemeinden Lostallo, Cama,
  Castaneda, Grono, Roveredo, San Vittore". Art. 34: wines from the Misox may use "DOC Ticino"
  when the grapes come from the Misox or Ticino.
  https://www.gr-lex.gr.ch/app/de/texts_of_law/917.400
- The superseded 2015 regulation (art. 22) had the same wording (`raw/lexfind_225039.pdf`).

## How the area is defined
Whole canton of Ticino plus the Mesolcina. The Ticino texts say only "Mesolcina". The Graubünden
text names the six Misox wine communes, and those are used. The federal ordinance (art. 20 c) also
names "la région de la Mesolcina" without listing communes.

## Counts
114 rows: 106 Ticino communes + 2 Ticino comunanze (5391 Comunanza Cadenazzo/Monteceneri,
5394 Comunanza Capriasca/Lugano) + 6 Graubünden Misox communes (3821 Lostallo, 3831 Cama,
3805 Castaneda, 3832 Grono, 3834 Roveredo (GR), 3835 San Vittore). Excluded: 9710 Lago di
Lugano, 9711 Lago Maggiore.

## Judgement calls
- The comunanze are jointly owned land without a commune. They are inside the canton, so they
  are included under "territorio del Cantone Ticino".
- Misox communes taken from GR art. 2 let. b, not from the wider Moesa region. Mesocco, Soazza,
  Buseno, Calanca, Rossa and Santa Maria in Calanca are excluded, because no wine text lists them.
  Castaneda sits at the mouth of the Val Calanca but is listed by GR, so it is included.
- `province` for these rows reads "GR (Misox/Mesolcina)", and their `source_url` is the GR text.

## Style sourcing
- "About three quarters Merlot": BLW statistics (Merlot ≈833 ha of 1,143 ha ≈73%) and Swiss Wine
  Promotion (897 ha, 76%). Ticinowine says 80%. "About three quarters" covers the first two;
  the 80% figure is not used.
- red_tannin = 2 (low): Swiss Wine Promotion ("Swiss Merlot has a soft tannin structure") and
  Ticinowine ("eleganza e morbidezza" for Ticino Merlot). Judgement call: "morbidezza" (softness)
  is read as soft tannins.
- North and south of Monte Ceneri are described differently by Swiss Wine Promotion (lighter,
  more elegant in the north) and Ticinowine (austere and long-lived in the north). Because the
  two conflict, the summary says nothing about north and south.

## Held back
- Body and acidity for Ticino reds (one source each, or conflicting).
- Bondola (single source, small area).
