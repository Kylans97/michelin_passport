# Hrvatsko Podunavlje (podregija; PDO Hrvatsko Podunavlje)

Prepared 2026-11-20. CSV: hrvatsko-podunavlje.csv (59 LAU rows, 0 partial).

## Boundary source

- **Primary (current national text):** Pravilnik o vinogradarstvu, Narodne novine 81/2022 (13.7.2022), Prilog I "Podjela vinogradarskih podregija na vinogorja i utvrđivanje područja koje obuhvaćaju vinogorja". https://narodne-novine.nn.hr/clanci/sluzbeni/2022_07_81_1184.html (copy: raw/nn_2022_07_81_1184.html)
- It replaced the Pravilnik o zemljopisnim područjima uzgoja vinove loze (NN 76/2019), which itself replaced NN 74/2012 (+80/2012, 48/2013, 159/2013); see its čl. 20. So the "Pravilnik o zemljopisnim područjima" named in the brief is no longer in force; its content now sits in Prilog I of this Pravilnik.
- Only amendment found: NN 153/2025 (17.12.2025), https://narodne-novine.nn.hr/clanci/sluzbeni/2025_12_153_2279.html. It changes čl. 2a, čl. 6 and Prilog IV (grape list) only; **Prilog I is unchanged**. Its own preamble cites the Pravilnik as "broj 81/22." with no earlier amendment. Checked 2026-11-20.
- čl. 3(1): boundaries rest on the administrative boundaries of counties, towns and municipalities. čl. 3(2): islands listed as a whole, without naming their towns and municipalities, join the vinogorje as a whole. čl. 3(3): PDO boundaries in product specifications need not coincide with these.
- **Cross-check (EU):** the PDO product specification in eAmbrosia lists the same units (differences noted below).
- **Boundary dataset:** Eurostat GISCO LAU 2024. Codes are the national LAU codes (GISCO_ID = "HR_" + DZS 5 digit code). County (županija) taken from the official Eurostat correspondence table EU-27-LAU-2024-NUTS-2024.xlsx (raw/lau2024_nuts2024.xlsx; NUTS3 = county); NUTS3 names from GISCO NUTS 2024 (raw/nuts3_names.txt). The official text gives names only, no codes, so every match is by name **within the allowed counties only**; each name resolved to exactly one LAU and every gisco_id was checked against the supplied index.

- PDO: EUGI00000010726 / PDO-HR-A1655, registered, EU protection 2013-07-01. Specification: https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/36303 (Ares(2016)4047098; copy raw/spec_36303.pdf).

## Official text (NN 81/2022, Prilog I)

```
Podregija Hrvatsko Podunavlje dijeli se na:
 – Vinogorje Srijem (Ilok, Vukovar, Lovas, Tovarnik, Tompojevci, Bogdanovci, Nuštar, Nijemci, Stari Jankovci, Vinkovci, Ivankovo, Vođinci, Stari Mikanovci, Jarmina, Bošnjaci, Gradište, Trpinja, Tordinci, Markušica, Borovo, Drenovci, Otok, Privlaka, Andrijaševci, Županja, Gunja, Vrbanja, Negoslavci, Cerna, Štitar, Babina Greda)
 – Vinogorje Erdut (Erdut, Osijek, Ernestinovo, Semeljci, Šodolovci, Vuka, Bizovac, Čepin, Koška, Bizovac, Valpovo, Petrijevci, Magadenovac, Donji Miholjac, Podravska Moslavina, Viljevo, Marijanci, Belišće, Vladislavci, Antunovac)
 – Vinogorje Baranja (Beli Manastir, Kneževi Vinogradi, Popovac, Draž, Čeminac, Jagodnjak, Bilje, Petlovac, Darda).
```

## Counts

- Names in the text (islands and the peninsula counted as one entry each): 59 distinct entries.
- LAU rows: 59 (0 partial). Counties allowed for matching: Osječko-baranjska (HR025), Vukovarsko-srijemska (HR026).
- LAUs in those counties not included: 14 (Donja Motičina, Drenje, Feričanci, Gorjani, Levanjska Varoš, Našice, Podgorač, Punitovci, Satnica Đakovačka, Strizivojna, Trnava, Viškovci, Đakovo, Đurđenovac).

## Judgement calls

- "Bizovac" appears twice in the Erdut list (also in the PDO spec); counted once.
- "Otok" and "Privlaka" each exist twice in Croatia (Otok also in Splitsko-dalmatinska, Privlaka also in Zadarska); restricting to HR025/HR026 leaves exactly one each, the Vukovarsko-srijemska units.
- All 31 units of Vukovarsko-srijemska are included; together with 28 Osječko-baranjska units, 59 in total. Text and PDO spec agree name for name.

## Held back

- Red ratings: only the PDO spec (moderate acidity, balanced tannin); null.
- "Ilok" is not a registered PDO (only a vinogorje-level place name); not listed as an appellation.

## Why this area was recommended

Vineyard area by county, APPRRR register at 31.12.2016 (raw/apprrr_vinograd_2016.pdf, https://www.apprrr.hr/wp-content/uploads/2018/07/Povrsina-broj-parcela-i-broj-PG-a-na-dan-31.12.2016.-uporaba-%E2%80%93-vinograd.pdf; dated, the newest county table found): Istarska 3,038 ha; Dubrovačko-neretvanska 2,356; Osječko-baranjska 2,386; Splitsko-dalmatinska 1,754; Vukovarsko-srijemska 1,687; Zadarska 1,479; Požeško-slavonska 1,425; Zagrebačka 905 (of 19,989 ha). Istria, Central and Southern Dalmatia, Slavonia and the Croatian Danube are the four largest areas and the ones international writing centres on (Decanter 2023 regional guides; Wine Folly; GuildSomm). Plešivica is smaller (part of Zagrebačka and Karlovačka) and was chosen as the fifth for its prominence in that writing (Decanter 2023 on the Uplands) over Sjeverna Dalmacija (Zadarska is larger by area), which is the closest alternative.

## Style content

See style.json (this slug) for every source per field. Ratings use low=1-2, medium=3, high=4-5 and are set only where two independent sources agree; the PDO specification counts as one official source, and several pages of one site count once.
