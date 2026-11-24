-- Batch 1, part B: village for 24 estates.
-- APPLIED to production 2026-11-24 (product owner: "Yes, apply them"), 24 villages.
-- PREPARED 2026-11-24. Needs the migration
-- (supabase/migrations/20261101740000_add_vineyard_villages_and_search.sql) applied and
-- wine_region_communes loaded first; the composite foreign key then refuses
-- any village that is not a unit of the estate's own region.

begin;

with decided(vineyard_code, region_code, commune_code) as (values
  ('vine_0001', 'wr_0080', 'DE_06439004'),
  ('vine_0002', 'wr_0006', 'ES_01031'),
  ('vine_0003', 'wr_0030', 'CL_COM_06310'),
  ('vine_0004', 'wr_0003', 'FR_51454'),
  ('vine_0006', 'wr_0030', 'CL_COM_06310'),
  ('vine_0008', 'wr_0002', 'FR_33274'),
  ('vine_0009', 'wr_0002', 'FR_33504'),
  ('vine_0010', 'wr_0026', 'AR_DEP_50063'),
  ('vine_0011', 'wr_0003', 'FR_51454'),
  ('vine_0012', 'wr_0007', 'ES_47114'),
  ('vine_0014', 'wr_0002', 'FR_33318'),
  ('vine_0016', 'wr_0008', 'PT_171004'),
  ('vine_0019', 'wr_0030', 'CL_COM_06305'),
  ('vine_0022', 'wr_0010', 'IT_004003'),
  ('vine_0023', 'wr_0029', 'CL_COM_13202'),
  ('vine_0025', 'wr_0006', 'ES_26071'),
  ('vine_0032', 'wr_0026', 'AR_DEP_50063'),
  ('vine_0035', 'wr_0026', 'AR_DEP_50063'),
  ('vine_0036', 'wr_0004', 'FR_26347'),
  ('vine_0037', 'wr_0003', 'FR_51030'),
  ('vine_0040', 'wr_0006', 'ES_26089'),
  ('vine_0042', 'wr_0002', 'FR_33314'),
  ('vine_0044', 'wr_0006', 'ES_26034'),
  ('vine_0049', 'wr_0098', 'ES_08240')
)
update public.vineyards v
   set commune_code = d.commune_code
  from decided d
  join public.wine_regions r on r.region_code = d.region_code
 where v.vineyard_code = d.vineyard_code
   and v.wine_region_id = r.id
   and v.commune_code is null;

do $$
begin
  if (select count(*) from public.vineyards where commune_code is not null) <> 24 then
    raise exception 'expected 24 estates with a village after batch 1, stopping';
  end if;
end $$;

commit;
