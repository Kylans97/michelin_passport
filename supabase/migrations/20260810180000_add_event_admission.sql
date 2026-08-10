-- Event admission model: an event's ticket_url (20260810160000_create_events.sql)
-- only ever expressed "here is a link", never whether the event itself
-- requires payment to attend. 't Preuvenemint is exactly this gap in
-- practice — general admission is free, but the row also carries a
-- ticket_url for the separate, optional, paid "'t PreuveneMeet" add-on,
-- and nothing in the schema said the free/paid distinction applied to two
-- different things.
--
-- admission_type + admission_note follow this schema's established
-- text + check taxonomy convention (see events.event_type/status in the
-- migration above) rather than a native Postgres enum, for the same
-- newer-and-likely-to-grow reasoning already documented there.
--
--   free    — no cost to attend the event itself.
--   paid    — a ticket/cost is required to attend.
--   mixed   — free to attend, but part of the event (a specific session,
--             add-on, or area) is separately ticketed — 't Preuvenemint's
--             actual case.
--   unknown — not yet verified; the safe default for existing/future rows
--             so nothing is asserted about admission without confirming it.
--
-- admission_note is a short optional human-readable qualifier (e.g. "Free
-- entry; VIP add-on ticketed separately") for exactly the cases too
-- specific for the four-value type to capture on its own — never required,
-- never a substitute for admission_type.
--
-- Additive only. No existing column changes type or drops. Genuinely new
-- migration file — 20260810160000_create_events.sql is already applied to
-- the remote database, so it is never edited after the fact.
--
-- PREPARED, NOT APPLIED.

alter table public.events
  add column admission_type text not null default 'unknown'
    check (admission_type in ('free', 'paid', 'mixed', 'unknown')),
  add column admission_note text;

-- 't Preuvenemint: free general admission; ticket_url is the optional paid
-- "'t PreuveneMeet" networking add-on, not a requirement to attend the
-- festival itself.
update public.events
set
  admission_type = 'mixed',
  admission_note = 'Free general admission. The optional ''t PreuveneMeet'' '
    'networking evening is separately ticketed.'
where name = '''t Preuvenemint';
