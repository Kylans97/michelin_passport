# Srednja i Južna Dalmacija (podregija; PDO Srednja i Južna Dalmacija)

Prepared 2026-11-20. CSV: srednja-i-juzna-dalmacija.csv (53 LAU rows, 1 partial).

## Boundary source

- **Primary (current national text):** Pravilnik o vinogradarstvu, Narodne novine 81/2022 (13.7.2022), Prilog I "Podjela vinogradarskih podregija na vinogorja i utvrđivanje područja koje obuhvaćaju vinogorja". https://narodne-novine.nn.hr/clanci/sluzbeni/2022_07_81_1184.html (copy: raw/nn_2022_07_81_1184.html)
- It replaced the Pravilnik o zemljopisnim područjima uzgoja vinove loze (NN 76/2019), which itself replaced NN 74/2012 (+80/2012, 48/2013, 159/2013); see its čl. 20. So the "Pravilnik o zemljopisnim područjima" named in the brief is no longer in force; its content now sits in Prilog I of this Pravilnik.
- Only amendment found: NN 153/2025 (17.12.2025), https://narodne-novine.nn.hr/clanci/sluzbeni/2025_12_153_2279.html. It changes čl. 2a, čl. 6 and Prilog IV (grape list) only; **Prilog I is unchanged**. Its own preamble cites the Pravilnik as "broj 81/22." with no earlier amendment. Checked 2026-11-20.
- čl. 3(1): boundaries rest on the administrative boundaries of counties, towns and municipalities. čl. 3(2): islands listed as a whole, without naming their towns and municipalities, join the vinogorje as a whole. čl. 3(3): PDO boundaries in product specifications need not coincide with these.
- **Cross-check (EU):** the PDO product specification in eAmbrosia lists the same units (differences noted below).
- **Boundary dataset:** Eurostat GISCO LAU 2024. Codes are the national LAU codes (GISCO_ID = "HR_" + DZS 5 digit code). County (županija) taken from the official Eurostat correspondence table EU-27-LAU-2024-NUTS-2024.xlsx (raw/lau2024_nuts2024.xlsx; NUTS3 = county); NUTS3 names from GISCO NUTS 2024 (raw/nuts3_names.txt). The official text gives names only, no codes, so every match is by name **within the allowed counties only**; each name resolved to exactly one LAU and every gisco_id was checked against the supplied index.

- PDO: EUGI00000010736 / PDO-HR-A1661, registered, EU protection 2013-07-01. Specification: https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/36383 (Ares(2016)4047351; copy raw/spec_36383.pdf).

## Official text (NN 81/2022, Prilog I)

```
Podregija Srednja i Južna Dalmacija dijeli se na:
 – Vinogorje Kaštela – Trogir (Kaštela, Trogir, Seget, Marina, Solin, Okrug)
 – Vinogorje Split – Omiš – Makarska (Split, Podstrana, Omiš, Makarska, Dugi Rat, Brela, Baška Voda, Podgora, Gradac, Tučepi)
 – Vinogorje Neretva (Metković, Ploče, Opuzen, Kula Norinska, Pojezerje, Zažablje)
 – Vinogorje Komarna (Slivno).
 – Vinogorje Konavle (Konavle)
 – Vinogorje Dubrovačko primorje (Župa dubrovačka, Dubrovnik, otok Šipan, otok Koločep, otok Lopud, otok Jakljan, Dubrovačko primorje)
 – Vinogorje Mljet (otok Mljet)
 – Vinogorje Pelješac (poluotok Pelješac)
 – Vinogorje Korčula (otok Korčula)
 – Vinogorje Hvar (otok Hvar)
 – Vinogorje Brač (otok Brač)
 – Vinogorje Šolta (otok Šolta)
 – Vinogorje Lastovo (otok Lastovo)
 – Vinogorje Vis (otok Vis).
```

## Counts

- Names in the text (islands and the peninsula counted as one entry each): 39 distinct entries.
- LAU rows: 53 (1 partial). Counties allowed for matching: Splitsko-dalmatinska (HR035), Dubrovačko-neretvanska (HR037).
- LAUs in those counties not included: 24 (Cista Provo, Dicmo, Dugopolje, Hrvace, Imotski, Klis, Lećevica, Lokvičići, Lovreć, Muć, Otok, Podbablje, Prgomet, Primorski Dolac, Proložac, Runovići, Sinj, Trilj, Vrgorac, Vrlika, Zadvarje, Zagvozd, Zmijavci, Šestanovac).

## Judgement calls

- Islands and the peninsula are listed as wholes; per čl. 3(2) every municipality on them is included. Island to municipality evidence is in the CSV rows and below; unit membership of each county was confirmed in the LAU/NUTS table, and settlement membership in DZS Popis 2021 (raw/dzs_naselja_2021.xlsx).
- otok Šipan, Koločep, Lopud, Jakljan (Elafiti) lie within Grad Dubrovnik, which is listed in full; they add no unit.
- Ston: marked partial. Text "poluotok Pelješac". Wikipedia places the municipality on Pelješac, but its settlement Zaton Doli is described as "on the border with Neum", i.e. on the mainland, outside the text. That is a small part; Ston is kept. This mainland strip was not mapped; it is not covered by any other listed unit.
- Every LAU of Dubrovačko-neretvanska županija (22) is included. The 24 HR035 units not included are the inland ones listed under Dalmatinska zagora (Sinj, Imotski, Vrgorac etc.).
- PDO spec has 13 vinogorja (it folds Dubrovačko primorje into Konavle); the set of units is identical to the Pravilnik.

## Held back

- Postup: no entry for it in eAmbrosia (checked the full register download, 2026-11-20), so it is not an EU protected name; not listed as an appellation.
- Lumbarda (EUGI00000018802, PDO-HR-02869): status "published", not yet registered; held back.
- Plavina, Trbljan, Maraština, Bogdanuša, Vugava, Vranac, Babić, Grk: in the spec lists but no two independent style sources gathered; not added as grapes. Tribidrag is Zinfandel (Pravilnik Prilog IV synonyms: Zinfandel, Primitivo, Crljenak kaštelanski); noted under Plavac Mali, not a new grape.
- Pairing: only one source (Decanter sponsored list: a Prović wine "great with grilled meats"); held back.

## Why this area was recommended

Vineyard area by county, APPRRR register at 31.12.2016 (raw/apprrr_vinograd_2016.pdf, https://www.apprrr.hr/wp-content/uploads/2018/07/Povrsina-broj-parcela-i-broj-PG-a-na-dan-31.12.2016.-uporaba-%E2%80%93-vinograd.pdf; dated, the newest county table found): Istarska 3,038 ha; Dubrovačko-neretvanska 2,356; Osječko-baranjska 2,386; Splitsko-dalmatinska 1,754; Vukovarsko-srijemska 1,687; Zadarska 1,479; Požeško-slavonska 1,425; Zagrebačka 905 (of 19,989 ha). Istria, Central and Southern Dalmatia, Slavonia and the Croatian Danube are the four largest areas and the ones international writing centres on (Decanter 2023 regional guides; Wine Folly; GuildSomm). Plešivica is smaller (part of Zagrebačka and Karlovačka) and was chosen as the fifth for its prominence in that writing (Decanter 2023 on the Uplands) over Sjeverna Dalmacija (Zadarska is larger by area), which is the closest alternative.

## Style content

See style.json (this slug) for every source per field. Ratings use low=1-2, medium=3, high=4-5 and are set only where two independent sources agree; the PDO specification counts as one official source, and several pages of one site count once.
