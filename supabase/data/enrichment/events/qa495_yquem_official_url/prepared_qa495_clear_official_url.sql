-- QA-495: the Château d'Yquem Wine Dinner (Anne-Sophie Pic at Le Normandie,
-- Mandarin Oriental Bangkok, 18 Nov 2026) has as official_url a 7 MB PDF
-- on Mandarin Oriental's Frontify asset store, not a web page; the app and
-- the site show it as "Event website". No event page of its own was found
-- (2026-11-16), so the value is cleared, not replaced.
-- Product owner, 2026-11-16: "Haal de website van het Château
-- d'Yquem-evenement weg (official_url leeg maken) en leg het vast in de logs."
--
-- One row, only while it still holds exactly this value; anything else
-- changes nothing and fails the check below.
do $$
declare
  n int;
begin
  update public.events
     set official_url = null
   where id = '2c1f25cd-d160-58ef-af05-25188dc4fd9c'
     and official_url = 'https://cdn-assets-dynamic.frontify.com/4001946/eyJhc3NldF9pZCI6NjM1MTUsInNjb3BlIjoiYXNzZXQ6dmlldyJ9:mandarin-oriental-hotel-group:tVkSC3bDoMQAJ3qLoo6fXnkH0xjpePgnvuJvnTVxvbc';
  get diagnostics n = row_count;
  if n <> 1 then
    raise exception 'QA-495: expected 1 row, matched %', n;
  end if;
end $$;

select id, name, official_url, ticket_url
  from public.events
 where id = '2c1f25cd-d160-58ef-af05-25188dc4fd9c';
