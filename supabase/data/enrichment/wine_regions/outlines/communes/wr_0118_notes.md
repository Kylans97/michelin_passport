# Tokaj (HU) — boundary notes

**Official text (primary):** A Tokaj oltalom alatt álló eredetmegjelölés termékleírása, 10. változat (applies to wine from grapes harvested after 1 August 2025), section IV "Körülhatárolt terület". https://boraszat.kormany.hu/download/b/85/53000/TOKAJ%20term%C3%A9kle%C3%ADr%C3%A1s%20%2810%20v%C3%A1ltozat%29%20kn.pdf (copy: raw/hu_tokaj_v10.pdf, raw/hu_tokaj_v10.txt). Retrieved 2026-11-21.
**Cross-check:** EU single document of the Union amendment, OJ C/2026/1380 (6.3.2026), approved by Implementing Regulation (EU) 2026/1556 (6.7.2026): http://data.europa.eu/eli/C/2026/1380/oj (raw/eu_tokaj_2026_1380.txt), item 7 lists the same 27 municipalities. Version 10a (2024 harvest, raw/hu_tokaj_v10a.txt) has an identical list. eAmbrosia EUGI00000005787 / PDO-HU-A1254.

**Wording:** "Abaújszántó, Bekecs, Bodrogkeresztúr, Bodrogkisfalud, Bodrogolaszi, Erdőbénye, Erdőhorváti, Golop, Hercegkút, Legyesbénye, Makkoshotyka, Mád, Mezőzombor, Monok, Olaszliszka, Rátka, Sárazsadány, Sárospatak, Sátoraljaújhely, Szegi, Szegilong, Szerencs, Tarcal, Tállya, Tokaj, Tolcsva, Vámosújfalu településeknek a szőlő termőhelyi kataszter szerint I. és II. osztályú határrészei" (the class I and II vineyard-cadastre land of these settlements).

**Units:** 27 named settlements → 27 LAU (HU_ + KSH code). All in Borsod-Abaúj-Zemplén county.

**Method:** each name looked up in the KSH Helységnévtár 2024 (raw/ksh_hnt_2024.xlsx, https://www.ksh.hu/docs/helysegnevtar/hnt_letoltes_2024.xlsx); every name is unique nationally, gives one KSH code and county; GISCO_ID = "HU_" + that code, and the LAU 2024 name was checked equal to the official name (accent-sensitive). No mismatches.

**Judgement calls:**
- The cadastre-class restriction (class I and II land only) applies to every settlement alike; it is the standard Hungarian formula, so the settlements are recorded whole and `partial` is left empty (not a "one village of a large unit" case).
- Only the Hungarian Tokaj PDO is mapped; the Slovak Tokaj area is a separate designation and is not part of this text.
- No merged or renamed settlements: all 27 exist under the same name in KSH 2024 and LAU 2024.

**Held back:** none.

**Style notes:** label_note is from section VIII.1 of the spec (Aszú "(3)(4)(5)(6) puttonyos", "6 puttonyos" only from 150 g/l; vintage compulsory, 85% rule) and the Aszú minimum of 120 g/l from section II; the EU text gives the same wording. Grape order follows GuildSomm (Furmint, Hárslevelű, Sárga Muskotály) and bor.hu (Furmint 65%).
