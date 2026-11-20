# wr_0010 Piedmont — comuni notes

Compiled 2026-11-20. Output: `wr_0010.csv` — **681 rows**, one per GISCO LAU 2024 id (`IT_` + ISTAT code). All 681 matched an entry in the LAU index.

## Sources (all downloaded 2026-11-20 from MASAF "Elenchi e disciplinari vini", https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625)
| Denomination | File in MASAF archive | Latest amendment in header |
|---|---|---|
| DOC **Piemonte** (defines the outline) | "Disciplinari DOP dalla lettera O alla lettera Z" (https://www.masaf.gov.it/flex/cm/pages/ServeAttachment.php/L/IT/D/1%252F9%252F5%252FD.d00b2121a0e2582372bf/P/BLOB%3AID%3D4625/E/7z?mode=download) → `Piemonte.pdf` | DM 08.08.2019 (rettificato DM 12.09.2019), GUUE C/91 20.03.2020 |
| DOCG Barolo | "Disciplinari DOP dalla lettera A alla lettera D" (https://www.masaf.gov.it/flex/cm/pages/ServeAttachment.php/L/IT/D/1%252F2%252Ff%252FD.f3246fc0caf2ec5feb45/P/BLOB%3AID%3D4625/E/7z?mode=download) → `Barolo.pdf` | DM 17.04.2015 |
| DOCG Barbaresco | same archive → `Barbaresco.pdf` | DM 17.04.2015 |
| DOC Barbera d'Alba | same archive → `Barbera d'Alba.pdf` | DM 06.08.2021 |
| DOCG Asti (covers Asti and Moscato d'Asti) | same archive → `Asti.pdf` | DM 13.03.2026 (GU 68, 23.03.2026) |

`source_url` in the CSV is the MASAF page with a fragment naming the PDF inside the archive. Every row's first source is DOC Piemonte: **every comune of Barolo, Barbaresco, Barbera d'Alba and Asti/Moscato d'Asti is also in DOC Piemonte Art. 3 para 1**, so the named wines lie inside the outline.

ISTAT files used to resolve name changes and mergers (downloaded 2026-11-20): https://www.istat.it/storage/codici-unita-amministrative/Elenco-comuni-italiani.csv, .../Elenco-comuni-soppressi.zip, .../Variazioni-amministrative-e-territoriali-dal-1991.zip.

## How the area is defined
DOC Piemonte Art. 3 defines the area as **whole comuni listed by province** (not whole provinces). Paragraph 1 (the broadest list, AL/AT/CN/TO/NO/BI/VCO/VC) is a superset of paras 2–4 (Barbera/Dolcetto/…, Freisa, Moscato/Brachetto) — checked: every para 2–4 name resolves to a comune already in para 1. Allegato 1 ("vigneti di montagna") and Allegato 2 (Cortese "Storico") are also subsets.

## Counts
| Source | Names in document (distinct, per province) | Distinct comuni matched |
|---|---|---|
| Piemonte Art.3 para 1 | AL 164, AT 117 (+1: "Costigliole d'Asti Cunico" is two), CN 143 (+1: "Neive Neviglie" is two), TO 191, NO 29, BI 21, VCO 18, VC 7 = 692 names | 681 (692 − 2 held back − 9 merged into a successor already counted) |
| Barolo | 11 (3 whole, 8 partial) | 11 |
| Barbaresco | 3 whole + part of Alba | 4 |
| Barbera d'Alba | 41 whole + 13 partial | 53 (Camo and S. Stefano Belbo → Santo Stefano Belbo) |
| Asti / Moscato d'Asti | AL 9 + AT 28 + CN 13 whole + frazioni of Alba | 51 |

## partial
Only **1 row** is partial: IT_103078 Borgomezzavalle — the document lists Viganella, merged 2016 with the unlisted Seppiana into Borgomezzavalle; the LAU polygon over-covers.
Barolo, Barbaresco, Barbera d'Alba and Asti partial comuni (e.g. La Morra, Alba, Bra) are all listed **whole** in DOC Piemonte, so they are `partial=no` in the union.

## Mergers (successor comune, per ISTAT Elenco comuni soppressi)
- Alice Superiore + Lugnacco + Pecco → Val di Chy (IT_001317, 2019) — all listed
- Gattico + Veruno → Gattico-Veruno (IT_003166, 2019) — both listed
- Castellar → Saluzzo (IT_004203, 2019) — both listed
- Camo → Santo Stefano Belbo (IT_004213, 2019) — both listed
- Moransengo + Tonengo → Moransengo-Tonengo (IT_005122, 2023) — both listed
- Cassano Spinola + Gavazzana → Cassano Spinola (IT_006191, 2018) — both listed
- Lu ("Lu Monferrato") + Cuccaro Monferrato → Lu e Cuccaro Monferrato (IT_006193, 2019) — both listed
- Cerreto Castello + Quaregna → Quaregna Cerreto (IT_096087, 2019) — both listed
- Viganella (+ unlisted Seppiana) → Borgomezzavalle (IT_103078, 2016) — **partial**
- Renamed, same code: Castellania → Castellania Coppi, Fubine → Fubine Monferrato, Calliano/Casorzo/Montemagno → "… Monferrato", Grana → Grana Monferrato, Castellinaldo → Castellinaldo d'Alba.

**Ambiguities kept as whole (flag for review):** the text names the current comune, but the comune absorbed an unlisted one after the list was probably written — **Lessona** (IT_096085, absorbed Crosa 2016) and **Busca** (IT_004034, absorbed Valmala 2019). The text says "intero territorio" of Lessona / Busca, so kept `partial=no`; the polygon may include former Crosa / Valmala, which the list may not have intended.

## Spelling / name fixes applied (each one candidate in the right province)
- Alessandria Borghetto Borbera -> official name Borghetto di Borbera (Allegato 1 of the same text spells it so)
- Alessandria Camagna -> official name Camagna Monferrato
- Alessandria Cerrina -> official name Cerrina Monferrato
- Alessandria Lu Monferrato -> ISTAT name Lu (merged 2019 into Lu e Cuccaro Monferrato)
- Alessandria Mongiardino -> official name Mongiardino Ligure (Allegato 1 spells it so)
- Alessandria Ottiglio Monferrato -> official name Ottiglio
- Alessandria Ozzano -> official name Ozzano Monferrato
- Alessandria Ponzano -> official name Ponzano Monferrato
- Alessandria Roccaforte -> official name Roccaforte Ligure
- Alessandria Valenza Po -> official name Valenza
- Asti Berzano San Pietro -> official name Berzano di San Pietro
- Asti Castagnole Lanze -> official name Castagnole delle Lanze
- Asti Castello d'Annone -> official name Castello di Annone
- Asti Costigliole d'Asti Cunico -> missing comma; Costigliole d'Asti and Cunico are separate AT comuni
- Asti Viale d'Asti -> official name Viale
- Cuneo Albaretto Torre -> official name Albaretto della Torre
- Cuneo Bagnolo -> official name Bagnolo Piemonte (Allegato 1 spells it so)
- Cuneo Canale d'Alba -> official name Canale
- Cuneo Martignana Po -> no "Martignana Po" exists in CN (Martignana di Po is in Cremona, Lombardy); the same disciplinare's Allegato 1 lists "Martiniana Po" in CN at the same alphabetical slot
- Cuneo Monta' d'Alba -> official name Montà
- Cuneo Neive Neviglie -> missing comma; Neive and Neviglie are separate CN comuni, both listed separately in para 4
- Cuneo Sale Langhe -> official name Sale delle Langhe (Allegato 1 spells it so)
- Torino Barone -> official name Barone Canavese
- Torino Borgone di Susa -> official name Borgone Susa
- Torino Coassolo -> official name Coassolo Torinese
- Torino Salerano -> official name Salerano Canavese
- Verbano-Cusio-Ossola Premosello -> official name Premosello-Chiovenda; only VCO comune of that name
- Alessandria Basaluzzo Bassignana -> missing comma (para 2/3)
- Alessandria Cartosio Casaleggio Boiro -> missing comma (para 2/3)
- Alessandria Castelletto d'Ero -> typo for Castelletto d'Erro (spelt correctly in para 1)
- Alessandria Gavi Grognardo -> missing comma (para 2/3)
- Alessandria Mirabello Monferrato Molare -> missing comma (para 2/3)
- Asti Morasengo -> typo for Moransengo (para 1)
- Cuneo Prunetto Roascio -> missing comma (para 2/3)
- Cuneo Treiso Trezzo Tinella -> missing comma (para 2/3)
- Torino Mombello torinese -> official name Mombello di Torino (para 1)
- Alessandria Cavatore Grognardo -> missing comma (para 4)
- Asti Vinchio d'Asti -> official name Vinchio
- Cuneo Borgomale Camo -> missing comma (para 4)
- Asti Azzano -> official name Azzano d'Asti
- Asti Cassinasco Castagnole Lanze -> missing comma (para 4)
- Cuneo S. Vittoria d'Alba -> abbreviation
- Cuneo S. Stefano Belbo -> abbreviation
- Cuneo Montà d'Alba -> official name Montà
- Cuneo S. Stefano Roero -> abbreviation

## Held back (not in the CSV)
- **"San Giorgio di Susa"** (Provincia di Torino, Piemonte Art.3 para 1): no comune of this name exists in the province (ISTAT current, suppressed and renamed lists since 1991). Probably San Giorio di Susa (ISTAT 001245 / IT_001245), but nothing in the text confirms it.
- **"Landonia"** (Provincia di Novara, Piemonte Art.3 para 1): no comune of this name exists in the province. Probably Landiona (ISTAT 003083 / IT_003083), but nothing in the text confirms it.

Not checked: the eAmbrosia single document for PDO Piemonte. Its public API refuses direct access, so these two typos could not be settled against a second official text.
