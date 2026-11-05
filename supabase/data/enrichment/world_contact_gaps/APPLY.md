# Toepassen op productie: world contact gaps (2026-11-04)

Goedgekeurd door de product owner op 2026-11-05 ("ja pas maar toe op productie").
**Nog niet uitgevoerd.** De sessie die dit voorbereidde had geen Supabase CLI en geen
inloggegevens voor productie.

Vanuit de root van de repo, met een gelinkt project (`supabase link`):

1. **Controle vooraf (read-only).** Verwacht: 0 rijen.

       supabase db query --linked -f "$PWD/supabase/data/enrichment/world_contact_gaps/check_place_id_collisions.sql"

   Geeft hij een rij terug, dan stopt het bestand van dat land. Draai die dan niet, en noteer het.
   De andere landen kunnen wel.

2. **De 41 bestanden.** Elk bestand is één transactie en fill-only, dus opnieuw draaien kan geen kwaad.

       for f in supabase/data/enrichment/world_contact_gaps/prepared_*_contact_fill.sql; do
         echo "== $f"; supabase db query --linked -f "$PWD/$f" || echo "ABORTED: $f"
       done

   Een `ABORTED` betekent dat een guard is afgegaan. Dan is er niets geschreven voor dat land.
   De melding noemt de code: hernoemd, of een Place ID dat al bij een andere rij staat.
   **Niet opnieuw proberen op basis van uitvoer alleen.** Controleer eerst de echte staat van
   productie.

3. **Achteraf.** Vergelijk met de CSV's: 300 Place IDs, 394 telefoons en 262 websites,
   minus wat productie na de export van 2026-11-04 22:10 UTC zelf al had gevuld.
   Werk daarna `README.md` (status) en de Unreleased-sectie van `docs/Plannnig/CHANGELOG.md` bij.
