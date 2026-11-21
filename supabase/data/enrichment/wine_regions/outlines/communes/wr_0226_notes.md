# Patras (GR): boundary notes

**Drawn as one region, the union of four PDOs whose areas overlap but do not nest.** PDO Patra (the hill country, Roditis) is far larger and mostly separate from the three sweet wine zones; Muscat of Rio Patra lies inside Muscat of Patra; Mavrodaphni of Patra overlaps both. The brief asked for one region only if the areas coincide or nest; they do not, so this is a decision for the coordinator. official_name records every PDO per unit, so the CSV can be split by PDO.

**Official texts (section 5 of each):** Patra PDO-GR-A1239 https://ec.europa.eu/geographical-indications-register/eambrosia-public-api/api/v1/attachments/11783 (RD 539/1971 as amended by PD 257/1998, Kapodistrias ΔΔ by municipality); Mavrodaphni of Patra PDO-GR-A1048 https://ec.europa.eu/geographical-indications-register/eambrosia-public-api/api/v1/attachments/11842 (RD 386/1971 as amended by PD 201/1993, 1971 communities in three road-bounded zones); Muscat of Patra PDO-GR-A1087 https://ec.europa.eu/geographical-indications-register/eambrosia-public-api/api/v1/attachments/11084 (RD 386/1971 as amended by PD 242/1982, localities by area); Muscat of Rio Patra PDO-GR-A1316 https://ec.europa.eu/geographical-indications-register/eambrosia-public-api/api/v1/attachments/11558 (same decrees, Rio localities plus a small part of NE Patras). English names are the specs' own equivalents.

**Resolution:** ELSTAT 2021 / GISCO, Achaea (code 37); dump in work/achaia.txt, mapping in tools/build_gr.py. Spelling variants accepted: Σενεβρού to Σινεβρού, Μυχοίου to Μιχοΐου, Οβρυάς to Οβριάς, Ροΐτικων to Ρογιτίκων, Άνω Σουδανέικων to Άνω Σουδεναιίκων, Αργυρός to Αργυράς. Κρήνης resolved by the text's municipality (Συμπολιτεία: EL_37020609; Mavrodaphne's Patras province: EL_37010304). ΔΔ Μαζαρακίου's three named settlements (Γαλαναίικα, Γκανέικα, Κάτω Μαζαράκι) are separate communities today and are drawn whole; Άνω Μαζαράκι (Λεοντίου) likewise.

**Partial (23 units):** where the text names only settlements, a part above a road, railway, village or channel, or the cadastral areas of the road-bounded Mavrodaphne main zone, and no other PDO covers the unit whole. The city of Patras (EL_37010100) is partial (named outlying settlements only, and a small NE area).

**Held back (not drawn, text could not be resolved without guessing):**
- Patra: ΔΔ Χρυσαμπέλων (Αιγείρα). No such unit or settlement in ELSTAT 2021; Wines of Greece writes "Chrysambela or Chrysanthio", but Χρυσάνθιο's former name is given as Βερσοβά (Wikipedia, unverified), and no rename record linking it to Χρυσάμπελα was found, so the identity is unproven.
- Patra: ΔΔ Ερινεού (Ερινεός). No unit of that name today; Νέος Ερινεός is listed separately, and the EETAA record found (id 6532) is the 1835 municipality, not the 1997 ΔΔ.
- Mavrodaphni of Patra: "Αγ. Νικολάου" (two candidates in Patras province: Αγίου Νικολάου Σπάτων and Αγίου Νικολάου Κράλης) and "Αγ. Στεφάνου" (the ΔΚ in Ωλενία, or the settlement in Σαραβάλι). Wines of Greece places them in Larissos and Messatis, a secondary reading only.
- Mavrodaphni of Patra and both Muscats: Αγίου Γεωργίου and Βερναρδέικων (Rio area). Neither exists as a community or settlement in ELSTAT 2021 Rio; likely renamed, rename not found.

**Rows:** 125 (Patra 88 entries, Mavrodaphni 38, Muscat of Patra 34, Muscat of Rio Patra 9); partial 23.

**Near-miss:** the Patra spec's Réserve clause says "οίνους Π.Ο.Π. Πάτρα (Anchialos)", a copy error in the official text (like the Paros slip in the Candia file); the ageing rule was not used.

**Style:** summary from Wines of Greece (four PDO pages), the Patra and Mavrodaphne specs, The Wine Society and Wine Folly's map page. label_note from the Mavrodaphne spec (Wines of Greece's Grand Reserve wording differs; the spec was followed).
