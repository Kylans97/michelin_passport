with r as (select country_code cc,
  count(*) filter (where michelin_stars between 1 and 3 and status='open') r_open,
  count(*) filter (where michelin_stars=3 and status='open') s3,
  count(*) filter (where michelin_stars=2 and status='open') s2,
  count(*) filter (where michelin_stars=1 and status='open') s1,
  count(*) filter (where michelin_stars between 1 and 3) r_all,
  string_agg(distinct status::text, '|') rst
 from restaurants group by 1),
h as (select country_code cc,
  count(*) filter (where michelin_keys between 1 and 3 and status='open') h_open,
  count(*) filter (where michelin_keys=3 and status='open') k3,
  count(*) filter (where michelin_keys=2 and status='open') k2,
  count(*) filter (where michelin_keys=1 and status='open') k1,
  count(*) filter (where michelin_keys between 1 and 3) h_all,
  string_agg(distinct status::text, '|') hst
 from hotels group by 1)
select coalesce(r.cc,h.cc) cc, s3,s2,s1,r_open,r_all,rst,k3,k2,k1,h_open,h_all,hst
from r full join h on r.cc=h.cc order by coalesce(r_open,0)+coalesce(h_open,0) desc;
