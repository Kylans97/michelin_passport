-- Moved into supabase/migrations on 2026-10-28 with the product owner's
-- go-ahead. Not yet applied. Filename timestamp is a sequence number only
-- (named after the highest existing migration, 20261018130000), not a date.
--
-- MICHELIN Guide France 2026: city-only prerequisite for 110 of the 173
-- restaurants in supabase/data/enrichment/michelin_fr_stars_2026/
-- prepared_fr_stars_2026.sql. Written 2026-10-28.
--
-- Adds ONLY public.cities rows. Checked read-only against production on
-- 2026-10-28: these 82 names returned 0 FR rows by exact name, and none
-- differs from an existing FR row by accents alone (the two that did --
-- Saint-Emilion, Bretignolles-sur-Mer -- use the existing rows). Names are
-- MICHELIN's destination names from each restaurant's guide.michelin.com page.
-- Their absence fits the August import's gap: whole regions (Rhône-Alpes,
-- Brittany, Pays de la Loire) were missing from the screenshots.
--
-- region and postal_municipality are left NULL, matching 325 of the 329
-- existing FR rows (region is only used to separate homonyms inside the
-- table, and no new name collides with an existing one).
--
-- Idempotent: ON CONFLICT targets cities_unique_key
-- (country_code, name, coalesce(region, '')).

begin;

insert into public.cities (country_code, name, region)
values
  ('FR', 'Abondance', NULL),
  ('FR', 'Angers', NULL),
  ('FR', 'Annecy', NULL),
  ('FR', 'Ardon', NULL),
  ('FR', 'Azay-le-Rideau', NULL),
  ('FR', 'Bellevigne-en-Layon', NULL),
  ('FR', 'Bidarray', NULL),
  ('FR', 'Binic', NULL),
  ('FR', 'Bouchemaine', NULL),
  ('FR', 'Carantec', NULL),
  ('FR', 'Chaintré', NULL),
  ('FR', 'Chamalières', NULL),
  ('FR', 'Chamonix Mont-Blanc', NULL),
  ('FR', 'Charolles', NULL),
  ('FR', 'Chassagne-Montrachet', NULL),
  ('FR', 'Chasselay', NULL),
  ('FR', 'Chazelles-sur-Lyon', NULL),
  ('FR', 'Châtel-Guyon', NULL),
  ('FR', 'Clermont-Ferrand', NULL),
  ('FR', 'Collonges-au-Mont-d''Or', NULL),
  ('FR', 'Douvaine', NULL),
  ('FR', 'Fleurie', NULL),
  ('FR', 'Fontevraud-l''Abbaye', NULL),
  ('FR', 'Fuissé', NULL),
  ('FR', 'Guer', NULL),
  ('FR', 'Hauteluce', NULL),
  ('FR', 'Jongieux', NULL),
  ('FR', 'La Clusaz', NULL),
  ('FR', 'Lannion', NULL),
  ('FR', 'Le Bourget-du-Lac', NULL),
  ('FR', 'Le Petit-Pressigny', NULL),
  ('FR', 'Le Touquet-Paris-Plage', NULL),
  ('FR', 'Lembach', NULL),
  ('FR', 'Les Sorinières', NULL),
  ('FR', 'Lucinges', NULL),
  ('FR', 'Lumio', NULL),
  ('FR', 'Lyon', NULL),
  ('FR', 'Machilly', NULL),
  ('FR', 'Marcq-en-Barœul', NULL),
  ('FR', 'Margencel', NULL),
  ('FR', 'Marlenheim', NULL),
  ('FR', 'Megève', NULL),
  ('FR', 'Montaigu', NULL),
  ('FR', 'Montbellet', NULL),
  ('FR', 'Montluçon', NULL),
  ('FR', 'Mûr-de-Bretagne', NULL),
  ('FR', 'Nantes', NULL),
  ('FR', 'Noyal-sur-Vilaine', NULL),
  ('FR', 'Ouches', NULL),
  ('FR', 'Piré-Chancé', NULL),
  ('FR', 'Plomeur', NULL),
  ('FR', 'Plérin', NULL),
  ('FR', 'Poncin', NULL),
  ('FR', 'Pont-de-Vaux', NULL),
  ('FR', 'Pont-du-Château', NULL),
  ('FR', 'Pontoise', NULL),
  ('FR', 'Pouilly-sous-Charlieu', NULL),
  ('FR', 'Puymoyen', NULL),
  ('FR', 'Rennes', NULL),
  ('FR', 'Replonges', NULL),
  ('FR', 'Rives-en-Seine', NULL),
  ('FR', 'Roscoff', NULL),
  ('FR', 'Saint-Avé', NULL),
  ('FR', 'Saint-Brieuc', NULL),
  ('FR', 'Saint-Genis-Laval', NULL),
  ('FR', 'Saint-Gervais-les-Bains', NULL),
  ('FR', 'Saint-Grégoire', NULL),
  ('FR', 'Saint-Pol-de-Léon', NULL),
  ('FR', 'Seytroux', NULL),
  ('FR', 'Talloires-Montmin', NULL),
  ('FR', 'Tresserve', NULL),
  ('FR', 'Trébeurden', NULL),
  ('FR', 'Vailly', NULL),
  ('FR', 'Vaux-en-Beaujolais', NULL),
  ('FR', 'Ventabren', NULL),
  ('FR', 'Ventron', NULL),
  ('FR', 'Veyras', NULL),
  ('FR', 'Veyrier-du-Lac', NULL),
  ('FR', 'Vichy', NULL),
  ('FR', 'Vonnas', NULL),
  ('FR', 'Écully', NULL),
  ('FR', 'Évian-les-Bains', NULL)
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
