begin;

-- Six new cuisine values surfaced while backfilling cuisine_id for the
-- ~100 Belgian restaurants imported without location/cuisine enrichment
-- (see supabase/data/enrichment/michelin_belgium_cuisine/). Each is a
-- literal MICHELIN Guide "Cuisine:" label with no existing equivalent in
-- the table — confirmed against the full existing taxonomy before adding,
-- not aliased to a near-synonym (see "Modern Cuisine" -> existing
-- "Contemporary" (id 170) and "Fish and Seafood"/"Creative French" ->
-- existing "Seafood" (267)/"French" (197), which did NOT need new rows).
--
-- cuisines.id is `GENERATED ALWAYS AS IDENTITY` (confirmed via a failed
-- validation attempt, not assumed) — OVERRIDING SYSTEM VALUE is required
-- to insert explicit ids rather than deferring to the identity sequence,
-- which the staging CSVs below were already built against (continuing
-- on from the existing max of 313).
insert into cuisines (id, name) overriding system value values
  (314, 'Traditional Cuisine'),
  (315, 'Classic Cuisine'),
  (316, 'Meats and Grills'),
  (317, 'Country cooking'),
  (318, 'Organic'),
  (319, 'Farm to table');

-- OVERRIDING SYSTEM VALUE does not advance the identity sequence.
-- Confirmed before this migration: cuisines_id_seq.last_value was 313,
-- exactly matching the pre-existing max(id) — sequence and data were in
-- sync. Without this, the next ordinary insert would generate id 314
-- and collide with the row just inserted above.
select setval(pg_get_serial_sequence('cuisines', 'id'), (select max(id) from cuisines));

commit;
