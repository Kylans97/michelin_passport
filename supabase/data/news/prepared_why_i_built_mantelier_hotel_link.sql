-- "Why I built Mantelier" (ee9af51e-eadc-4717-9ae7-117bb2c78b73): add
-- Mandarin Oriental Barcelona to "Mentioned in this article".
-- Written 2026-10-29, at the product owner's request.
--
-- The body names "Moments at the Mandarin Oriental, Barcelona". Moments
-- (rest_0067) is already linked; the hotel is hotel_541 (ES, Barcelona,
-- 2 Keys), and hotel_restaurants already holds the verified hotel_541 ↔
-- rest_0067 link (Passeig de Gracia 38). Keyed on hotel_code + country, never
-- on the name alone (hotel_540 is Mandarin Oriental Ritz, Madrid).
--
-- One transaction; aborts unless the article and hotel are as expected and
-- the link does not exist yet.

begin;

do $$
begin
  if not exists (
    select 1 from public.news_articles
     where id = 'ee9af51e-eadc-4717-9ae7-117bb2c78b73'
       and title = 'Why I built Mantelier'
  ) then
    raise exception 'article ee9af51e is not "Why I built Mantelier" -- re-check';
  end if;
  if not exists (
    select 1 from public.hotels h
      join public.cities c on c.id = h.city_id
     where h.hotel_code = 'hotel_541' and h.country_code = 'ES'
       and h.name = 'Mandarin Oriental Barcelona' and c.name = 'Barcelona'
  ) then
    raise exception 'hotel_541 is not Mandarin Oriental Barcelona (ES) -- re-check';
  end if;
  if exists (
    select 1 from public.news_article_hotels nah
      join public.hotels h on h.id = nah.hotel_id
     where nah.news_article_id = 'ee9af51e-eadc-4717-9ae7-117bb2c78b73'
       and h.hotel_code = 'hotel_541'
  ) then
    raise exception 'hotel_541 is already linked to this article';
  end if;
end $$;

insert into public.news_article_hotels (news_article_id, hotel_id)
select 'ee9af51e-eadc-4717-9ae7-117bb2c78b73', h.id
  from public.hotels h
 where h.hotel_code = 'hotel_541' and h.country_code = 'ES';

commit;
