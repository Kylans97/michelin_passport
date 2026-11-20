# Slavonija (podregija; PDO Slavonija)

Prepared 2026-11-20. CSV: slavonija.csv (73 LAU rows, 0 partial).

## Boundary source

- **Primary (current national text):** Pravilnik o vinogradarstvu, Narodne novine 81/2022 (13.7.2022), Prilog I "Podjela vinogradarskih podregija na vinogorja i utvrđivanje područja koje obuhvaćaju vinogorja". https://narodne-novine.nn.hr/clanci/sluzbeni/2022_07_81_1184.html (copy: raw/nn_2022_07_81_1184.html)
- It replaced the Pravilnik o zemljopisnim područjima uzgoja vinove loze (NN 76/2019), which itself replaced NN 74/2012 (+80/2012, 48/2013, 159/2013); see its čl. 20. So the "Pravilnik o zemljopisnim područjima" named in the brief is no longer in force; its content now sits in Prilog I of this Pravilnik.
- Only amendment found: NN 153/2025 (17.12.2025), https://narodne-novine.nn.hr/clanci/sluzbeni/2025_12_153_2279.html. It changes čl. 2a, čl. 6 and Prilog IV (grape list) only; **Prilog I is unchanged**. Its own preamble cites the Pravilnik as "broj 81/22." with no earlier amendment. Checked 2026-11-20.
- čl. 3(1): boundaries rest on the administrative boundaries of counties, towns and municipalities. čl. 3(2): islands listed as a whole, without naming their towns and municipalities, join the vinogorje as a whole. čl. 3(3): PDO boundaries in product specifications need not coincide with these.
- **Cross-check (EU):** the PDO product specification in eAmbrosia lists the same units (differences noted below).
- **Boundary dataset:** Eurostat GISCO LAU 2024. Codes are the national LAU codes (GISCO_ID = "HR_" + DZS 5 digit code). County (županija) taken from the official Eurostat correspondence table EU-27-LAU-2024-NUTS-2024.xlsx (raw/lau2024_nuts2024.xlsx; NUTS3 = county); NUTS3 names from GISCO NUTS 2024 (raw/nuts3_names.txt). The official text gives names only, no codes, so every match is by name **within the allowed counties only**; each name resolved to exactly one LAU and every gisco_id was checked against the supplied index.

- PDO: EUGI00000010735 / PDO-HR-A1660, registered, EU protection 2013-07-01. Specification: https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/36373 (Ares(2016)4046976; copy raw/spec_36373.pdf).

## Official text (NN 81/2022, Prilog I)

```
Podregija Slavonija dijeli se na:
 – Vinogorje Đakovo (Đakovo, Trnava, Drenje, Levanjska Varoš, Satnica Đakovačka, Gorjani, Punitovci, Viškovci)
 – Vinogorje Slavonski Brod (Garčin, Podcrkavlje, Slavonski Brod, Sibinj, Brodski Stupnik, Oriovac, Bukovlje, Klakar, Bebrina, Donji Andrijevci, Vrpolje, Slavonski Šamac, Strizivojna, Gornja Vrba, Oprisavci, Gundinci, Velika Kopanica, Sikirevci)
 – Vinogorje Nova Gradiška (Nova Gradiška, Nova Kapela, Staro Petrovo Selo, Rešetari, Cernik, Gornji Bogičevci, Dragalić, Okučani, Stara Gradiška, Vrbje, Davor)
 – Vinogorje Požega – Pleternica (Požega, Pleternica, Brestovac, Jakšić)
 – Vinogorje Kutjevo (Čaglin, Kutjevo, Kaptol, Velika)
 – Vinogorje Daruvar (Daruvar, Dežanovac, Konačnica, Sirač, Đulovac)
 – Vinogorje Pakrac (Pakrac, Lipik)
 – Vinogorje Feričanci (Našice, Feričanci, Podgorač, Donja Motičina, Đurđenovac)
 – Vinogorje Orahovica – Slatina (Orahovica, Slatina, Čačinci, Mikleuš, Nova Bukovica, Voćin, Sopje, Čađavica, Crnac, Zdenci)
 – Vinogorje Virovitica (Virovitica, Suhopolje, Pitomača, Špišić Bukovica, Lukač, Gradina).
```

## Counts

- Names in the text (islands and the peninsula counted as one entry each): 73 distinct entries.
- LAU rows: 73 (0 partial). Counties allowed for matching: Bjelovarsko-bilogorska (HR021), Virovitičko-podravska (HR022), Požeško-slavonska (HR023), Brodsko-posavska (HR024), Osječko-baranjska (HR025).
- LAUs in those counties not included: 46 (Antunovac, Beli Manastir, Belišće, Berek, Bilje, Bizovac, Bjelovar, Darda, Donji Miholjac, Draž, Erdut, Ernestinovo, Garešnica, Grubišno Polje, Hercegovac, Ivanska, Jagodnjak, Kapela, Kneževi Vinogradi, Koška, Magadenovac, Marijanci, Nova Rača, Osijek, Petlovac, Petrijevci, Podravska Moslavina, Popovac, Rovišće, Semeljci, Severin, Valpovo, Velika Pisanica, Velika Trnovitica, Veliki Grđevac, Veliko Trojstvo, Viljevo, Vladislavci, Vuka, Zrinski Topolovac, Čazma, Čeminac, Čepin, Šandrovac, Šodolovci, Štefanje).

## Judgement calls

- "Konačnica" (Pravilnik and the PDO vinogorje list) does not exist as a unit; the PDO spec's own full list spells it "Končanica", a municipality in Bjelovarsko-bilogorska next to Daruvar and Dežanovac. Matched to Končanica (HR_01996). Recorded as a typo correction backed by the spec, not inferred from the map.
- "Gornji Bogičevci" (č) matched to the LAU "Gornji Bogićevci" (ć), Brodsko-posavska; no other similarly named unit exists in Croatia.
- Osječko-baranjska is split between Slavonija (Đakovo, Našice area) and Hrvatsko Podunavlje; no unit appears in both CSVs.
- Text and PDO spec otherwise agree name for name (73 units).

## Held back

- Red ratings: only the PDO spec describes Slavonian reds (moderate acidity, moderate tannin, medium to high alcohol); no second source, so all three are null.
- Sauvignon Blanc, Ružica crvena, Rizvanac (Müller-Thurgau), Zweigelt, Pinot crni, Merlot are in the spec's most planted lists but were left off the short grape list to keep it to the leading varieties.

## Why this area was recommended

Vineyard area by county, APPRRR register at 31.12.2016 (raw/apprrr_vinograd_2016.pdf, https://www.apprrr.hr/wp-content/uploads/2018/07/Povrsina-broj-parcela-i-broj-PG-a-na-dan-31.12.2016.-uporaba-%E2%80%93-vinograd.pdf; dated, the newest county table found): Istarska 3,038 ha; Dubrovačko-neretvanska 2,356; Osječko-baranjska 2,386; Splitsko-dalmatinska 1,754; Vukovarsko-srijemska 1,687; Zadarska 1,479; Požeško-slavonska 1,425; Zagrebačka 905 (of 19,989 ha). Istria, Central and Southern Dalmatia, Slavonia and the Croatian Danube are the four largest areas and the ones international writing centres on (Decanter 2023 regional guides; Wine Folly; GuildSomm). Plešivica is smaller (part of Zagrebačka and Karlovačka) and was chosen as the fifth for its prominence in that writing (Decanter 2023 on the Uplands) over Sjeverna Dalmacija (Zadarska is larger by area), which is the closest alternative.

## Style content

See style.json (this slug) for every source per field. Ratings use low=1-2, medium=3, high=4-5 and are set only where two independent sources agree; the PDO specification counts as one official source, and several pages of one site count once.
