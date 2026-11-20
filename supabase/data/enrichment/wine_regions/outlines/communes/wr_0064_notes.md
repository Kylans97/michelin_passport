# Plešivica (podregija; PDO Plešivica)

Prepared 2026-11-20. CSV: plesivica.csv (11 LAU rows, 1 partial).

## Boundary source

- **Primary (current national text):** Pravilnik o vinogradarstvu, Narodne novine 81/2022 (13.7.2022), Prilog I "Podjela vinogradarskih podregija na vinogorja i utvrđivanje područja koje obuhvaćaju vinogorja". https://narodne-novine.nn.hr/clanci/sluzbeni/2022_07_81_1184.html (copy: raw/nn_2022_07_81_1184.html)
- It replaced the Pravilnik o zemljopisnim područjima uzgoja vinove loze (NN 76/2019), which itself replaced NN 74/2012 (+80/2012, 48/2013, 159/2013); see its čl. 20. So the "Pravilnik o zemljopisnim područjima" named in the brief is no longer in force; its content now sits in Prilog I of this Pravilnik.
- Only amendment found: NN 153/2025 (17.12.2025), https://narodne-novine.nn.hr/clanci/sluzbeni/2025_12_153_2279.html. It changes čl. 2a, čl. 6 and Prilog IV (grape list) only; **Prilog I is unchanged**. Its own preamble cites the Pravilnik as "broj 81/22." with no earlier amendment. Checked 2026-11-20.
- čl. 3(1): boundaries rest on the administrative boundaries of counties, towns and municipalities. čl. 3(2): islands listed as a whole, without naming their towns and municipalities, join the vinogorje as a whole. čl. 3(3): PDO boundaries in product specifications need not coincide with these.
- **Cross-check (EU):** the PDO product specification in eAmbrosia lists the same units (differences noted below).
- **Boundary dataset:** Eurostat GISCO LAU 2024. Codes are the national LAU codes (GISCO_ID = "HR_" + DZS 5 digit code). County (županija) taken from the official Eurostat correspondence table EU-27-LAU-2024-NUTS-2024.xlsx (raw/lau2024_nuts2024.xlsx; NUTS3 = county); NUTS3 names from GISCO NUTS 2024 (raw/nuts3_names.txt). The official text gives names only, no codes, so every match is by name **within the allowed counties only**; each name resolved to exactly one LAU and every gisco_id was checked against the supplied index.

- PDO: EUGI00000010730 / PDO-HR-A1654, registered, EU protection 2013-07-01. Specification: https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/36343 (Ares(2016)4048179; copy raw/spec_36343.pdf).

## Official text (NN 81/2022, Prilog I)

```
Podregija Plešivica dijeli se na:
 – Vinogorje Samobor (Samobor, Sv. Nedjelja, Žumberak, Stupnik)
 – Vinogorje Plešivica – Okić (Klinča Sela, Jastrebarsko – katastarske općine Desinec, Plešivica, Plešivička Reka, Jastrebarsko, Cvetković, dio katastarske općine Okić)
 – Vinogorje Sveta Jana (Jastrebarsko – katastarske općine Sveta Jana, Slavetić, Petrovina, Volavje, Gornja Kupčina, Čaglje, Domagović)
 – Vinogorje Krašić (Krašić)
 – Vinogorje Ozalj – Vivodina (Ozalj, Kamanje, Žakanje, Ribnik).
```

## Counts

- Names in the text (islands and the peninsula counted as one entry each): 11 distinct entries.
- LAU rows: 11 (1 partial). Counties allowed for matching: Zagrebačka (HR065), Karlovačka (HR027).
- LAUs in those counties not included: 45 (Barilović, Bedenica, Bistra, Bosiljevo, Brckovljani, Brdovec, Cetingrad, Draganić, Dubrava, Dubravica, Duga Resa, Dugo Selo, Farkaševac, Generalski Stol, Gradec, Ivanić-Grad, Jakovlje, Josipdol, Karlovac, Kloštar Ivanić, Kravarsko, Križ, Krnjak, Lasinja, Luka, Marija Gorica, Netretić, Ogulin, Orle, Pisarovina, Plaški, Pokupsko, Preseka, Pušća, Rakovec, Rakovica, Rugvica, Saborsko, Slunj, Sveti Ivan Zelina, Tounj, Velika Gorica, Vojnić, Vrbovec, Zaprešić).

## Judgement calls

- "Sv. Nedjelja" matched to the LAU "Sveta Nedelja" in Zagrebačka županija only (the Istrian unit of that name is excluded by county).
- Jastrebarsko is included **by cadastral municipalities**: 12 named KOs, including KO Jastrebarsko itself. Marked partial with the text's wording. The share of the city's area these cover was **not verified** (no official KO list for the city was reached); review before deciding whether to keep the whole LAU. It is kept here because the named KOs include the town and the hill villages the subregion is named after.
- "dio katastarske općine Okić" (part of KO Okić): the municipality this KO belongs to was not verified. It cannot add a new LAU in any case if it lies in Klinča Sela, Samobor or Jastrebarsko, all already listed; if it lies elsewhere it would be a small partial and is left out.
- Ozalj, Kamanje, Žakanje, Ribnik are in Karlovačka županija; the other units in Zagrebačka.
- The PDO spec lists the same units; its narrative section also describes a wider area (south of the Sava, west of Ježdovec to Lasinja); the unit list is taken as the boundary.

## Held back

- Portugizac (the leading red per the spec, made as young wine) and Kraljevina (third white): no two independent style sources found; not added as grapes, and Portugizac is left out of the summary.
- Red ratings: spec only (medium alcohol, moderate to high acidity, moderate tannin); null.
- Pairing: none sourced.
- Sparkling wine is in the label note (official rule) but not in the summary, which needed two sources.

## Why this area was recommended

Vineyard area by county, APPRRR register at 31.12.2016 (raw/apprrr_vinograd_2016.pdf, https://www.apprrr.hr/wp-content/uploads/2018/07/Povrsina-broj-parcela-i-broj-PG-a-na-dan-31.12.2016.-uporaba-%E2%80%93-vinograd.pdf; dated, the newest county table found): Istarska 3,038 ha; Dubrovačko-neretvanska 2,356; Osječko-baranjska 2,386; Splitsko-dalmatinska 1,754; Vukovarsko-srijemska 1,687; Zadarska 1,479; Požeško-slavonska 1,425; Zagrebačka 905 (of 19,989 ha). Istria, Central and Southern Dalmatia, Slavonia and the Croatian Danube are the four largest areas and the ones international writing centres on (Decanter 2023 regional guides; Wine Folly; GuildSomm). Plešivica is smaller (part of Zagrebačka and Karlovačka) and was chosen as the fifth for its prominence in that writing (Decanter 2023 on the Uplands) over Sjeverna Dalmacija (Zadarska is larger by area), which is the closest alternative.

## Style content

See style.json (this slug) for every source per field. Ratings use low=1-2, medium=3, high=4-5 and are set only where two independent sources agree; the PDO specification counts as one official source, and several pages of one site count once.
