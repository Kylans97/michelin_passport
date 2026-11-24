-- Batch 1, part A: wine region for 40 of the 44 estates on production.
-- APPLIED to production 2026-11-24 (supabase db query --linked --file), 40 updated.
-- PREPARED 2026-11-24. Needs no migration: vineyards.wine_region_id
-- exists since 20261101580000. Keyed on vineyard_code and region_code only,
-- never a name. Review: estate_regions_batch01.csv (status ready or region_only).
-- Fills only an empty wine_region_id and stops as a whole if any row is
-- missing or already set.

begin;

with decided(vineyard_code, region_code) as (values
  ('vine_0001', 'wr_0080'),
  ('vine_0002', 'wr_0006'),
  ('vine_0003', 'wr_0030'),
  ('vine_0004', 'wr_0003'),
  ('vine_0005', 'wr_0259'),
  ('vine_0006', 'wr_0030'),
  ('vine_0007', 'wr_0041'),
  ('vine_0008', 'wr_0002'),
  ('vine_0009', 'wr_0002'),
  ('vine_0010', 'wr_0026'),
  ('vine_0011', 'wr_0003'),
  ('vine_0012', 'wr_0007'),
  ('vine_0013', 'wr_0031'),
  ('vine_0014', 'wr_0002'),
  ('vine_0016', 'wr_0008'),
  ('vine_0017', 'wr_0051'),
  ('vine_0018', 'wr_0115'),
  ('vine_0019', 'wr_0030'),
  ('vine_0020', 'wr_0117'),
  ('vine_0022', 'wr_0010'),
  ('vine_0023', 'wr_0029'),
  ('vine_0025', 'wr_0006'),
  ('vine_0027', 'wr_0022'),
  ('vine_0030', 'wr_0118'),
  ('vine_0031', 'wr_0053'),
  ('vine_0032', 'wr_0026'),
  ('vine_0034', 'wr_0021'),
  ('vine_0035', 'wr_0026'),
  ('vine_0036', 'wr_0004'),
  ('vine_0037', 'wr_0003'),
  ('vine_0038', 'wr_0022'),
  ('vine_0039', 'wr_0054'),
  ('vine_0040', 'wr_0006'),
  ('vine_0041', 'wr_0051'),
  ('vine_0042', 'wr_0002'),
  ('vine_0043', 'wr_0037'),
  ('vine_0044', 'wr_0006'),
  ('vine_0045', 'wr_0044'),
  ('vine_0046', 'wr_0037'),
  ('vine_0049', 'wr_0098')
), upd as (
  update public.vineyards v
     set wine_region_id = r.id
    from decided d
    join public.wine_regions r on r.region_code = d.region_code
   where v.vineyard_code = d.vineyard_code
     and v.wine_region_id is null
  returning v.vineyard_code
)
select count(*) as updated from upd;

do $$
begin
  if (select count(*) from public.vineyards where wine_region_id is not null) <> 40 then
    raise exception 'expected 40 estates with a region after batch 1, stopping';
  end if;
end $$;

commit;
