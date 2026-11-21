# Crete (GR): boundary notes

**Drawn:** the union of the seven Cretan wine PDOs: Peza, Archanes, Dafnes, Handakas - Candia, Malvasia Handakas - Candia (Heraklion), Sitia, Malvasia Sitia (Lasithi). Technical files from eAmbrosia (https://ec.europa.eu/geographical-indications-register/eambrosia-public-api/api/v1/attachments/<id>): Peza 11095, Archanes 11305, Dafnes 11308, Sitia 10701, Handakas - Candia 15904, Malvasia Handakas - Candia 15927, Malvasia Sitia 19219; section 5 of each. Texts in raw/gr_style/att_*.txt.

**Resolution:** ELSTAT, 2021 census, resident population by settlement (https://www.statistics.gr/documents/20181/17286366/MON_PLI_DHM_OIKISN_2021.xlsx, raw/elstat/, flattened to work/elstat_mon2021.tsv). Its geographic codes are the GISCO LAU ids (EL_ + 8 digits), and it names every municipality, municipal unit (ΔΕ), community and settlement, so whole-ΔΕ entries and settlement-level entries resolve from it directly. Script: tools/crete_build.py.

- Handakas - Candia and Malvasia Handakas - Candia (PD 129 and 131/2011, ΦΕΚ 260/Α/13.12.2011) are written in Kallikratis units. Their unit lists are identical (word-count check). 9 whole ΔΕ (Αρχανών, Νίκου Καζαντζάκη, Αγίας Βαρβάρας, Γοργολαΐνη, Παλιανής, Τεμένους, Κρούσωνα, Θραψανού, Επισκοπής: 49 communities) plus 41 named communities plus ten named settlements of the city community of Heraklion: 91 units.
- Sitia and Malvasia Sitia (Kallikratis wording): 17 communities plus the settlement of Άγιος Σπυρίδων of Πραισός.
- Peza, Archanes, Dafnes keep 1971 community names (RD 539/1971 as amended). All map to today's communities of the same name, with these judgement calls: Άνω Αρχανών to Δημοτική Κοινότητα Αρχανών (its settlement is Επάνω Αρχάναι in ELSTAT); Δαφνών to Δαφνέ (settlement Δαφνές); Σίββας to Σίβας (EL_71010404 in ΔΕ Παλιανής, not Σίβα in Tympaki, since it is listed among the Paliani communities); Πύργου in Dafnes to Πυργούς (EL_71010206, settlement Πυργού), since it is listed with the other five Gorgolaini communities, not Πύργου in Asterousia. Every one of these 1971 communities also lies whole in Handakas - Candia, so none of the judgement calls changes the drawn area.

**Partial (2):** EL_71010100 Ψευδοδημοτική Κοινότητα Ηρακλείου (only the settlements Αθάνατοι, Γούρναι, Δρακουλιάρης, Λοφούπολις, Σέμελη, Φοινικιά, Αγία Ειρήνη, Βλυχιά, Κνωσός, Μαραθίτης; not the city itself); EL_72040112 Πραισού (only Άγιος Σπυρίδων). Dafnes covers only parts (τμήματα) of its communities and Peza excludes land under 300 m for whites, but all those communities are whole in Handakas - Candia, so they are not partial for the region.

**Rows:** 109; partial 2. official_name lists every PDO and the name it uses for that unit.

**Not checked:** whether today's communities gained settlements since 1971 (does not matter here, as above); later national amendments to the decrees.

Style: work/notes_gr.md. Note from the style work: the webgate eAmbrosia host and the ec.europa.eu public host both serve the same attachment ids today (both returned 202 with a PDF on 21 Nov 2026).
