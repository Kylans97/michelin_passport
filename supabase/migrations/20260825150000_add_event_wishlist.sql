-- EVENT WISHLIST V1
--
-- Adds Events as a third public.wishlist entity_type, alongside the
-- existing 'restaurant'/'hotel'. Additive only — nothing removed, no
-- existing row affected.
--
-- public.wishlist is already the exact "user <-> entity" polymorphic
-- shape this feature needs (user_id, entity_type, entity_id, added_at;
-- entity_id deliberately NOT a foreign key, same reasoning as
-- public.visits — see DATABASE_ARCHITECTURE.md section 4: entity_id is
-- a plain uuid pointing at whichever catalogue table entity_type names,
-- resolved by the application layer, not by a join). No new table is
-- needed: a saved Event is simply a wishlist row with
-- entity_type = 'event' and entity_id = events.id, exactly mirroring
-- how a saved restaurant/hotel already works. The `unique (user_id,
-- entity_type, entity_id)` constraint already defined on the table
-- applies unchanged, and continues to make the insert path safe to
-- retry for the new entity_type exactly as it already does for the
-- other two.
--
-- RLS is untouched: every wishlist_* policy already reads/writes by
-- user_id alone, with no entity_type-specific predicate anywhere, so
-- Event Wishlist rows are already covered by the existing
-- read/insert/update/delete policies with zero policy changes.
--
-- Orphan handling: entity_id has no foreign key (by design, matching
-- the existing restaurant/hotel rows), so an Event later being
-- unpublished/archived/deleted can never violate a constraint or block
-- that operation. The application layer resolves wishlist rows against
-- `events` by id and silently skips any id that no longer resolves
-- (see WishlistRepository.getWishlistEvents) — the same "skip
-- unresolvable ids, never crash" behavior WishlistRepository.
-- loadWishlistVenues already uses for restaurants/hotels today.

alter table public.wishlist drop constraint wishlist_entity_type_check;
alter table public.wishlist add constraint wishlist_entity_type_check
  check (entity_type in ('hotel', 'restaurant', 'event'));
