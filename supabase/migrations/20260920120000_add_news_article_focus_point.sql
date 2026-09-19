-- News V1 — a crop focus point on news_articles, matching
-- restaurant_photos/hotel_photos/private_chef_photos' own focus_x/
-- focus_y exactly (20260828130000_add_photo_duplicate_detection_and_
-- focus_point.sql): normalized 0..1 coordinates, default 0.5/0.5
-- (center) — correct for every article published before this column
-- existed. Unlike the venue photo tables, there is no separate stored
-- crop variant here: news_articles has exactly one image per article,
-- displayed directly via Image.network(fit: BoxFit.cover, alignment:
-- ...) in the app, so the focus point is applied client-side as a
-- BoxFit.cover alignment rather than a server-side pre-cropped object —
-- there is no Supabase Transform-endpoint limitation to work around
-- here, since nothing generates size variants for News images today.

begin;

alter table public.news_articles
  add column focus_x numeric not null default 0.5 check (focus_x between 0 and 1),
  add column focus_y numeric not null default 0.5 check (focus_y between 0 and 1);

commit;
