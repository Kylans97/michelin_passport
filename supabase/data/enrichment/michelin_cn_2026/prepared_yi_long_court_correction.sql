-- QA-299: Yi Long Court (rest_2799, Shanghai) — website and phone.
-- Written 2026-10-30. Commit eaea651 confirmed both on The Peninsula
-- Shanghai's own dining page after prepared_cn_stars_2026.sql had already
-- been applied, so production still holds the older website (a URL that
-- now redirects to the hotel's home page) and no phone.
--
-- Evidence: peninsula.com's Shanghai dining page lists Yi Long Court with
-- its own page (2/F, One MICHELIN Star, +86 21 2327 6742); recorded in
-- _source/cn_restaurant_phone_confirmations.csv and README.md.
--
-- One transaction; aborts unless the row is still exactly as it was left.

begin;

do $$
begin
  if not exists (
    select 1 from public.restaurants
     where restaurant_code = 'rest_2799' and country_code = 'CN'
       and name = 'Yi Long Court'
       and website_url = 'https://www.peninsula.com/en/shanghai/hotel-fine-dining/yi-long-court-chinese-restaurant'
       and phone is null
  ) then
    raise exception 'rest_2799 is not the Yi Long Court row as applied -- re-check';
  end if;
end $$;

update public.restaurants
   set website_url = 'https://www.peninsula.com/en/shanghai/hotel-fine-dining/yi-long-court',
       phone       = '+86 21 2327 6742',
       updated_at  = now()
 where restaurant_code = 'rest_2799' and country_code = 'CN' and name = 'Yi Long Court';

commit;
