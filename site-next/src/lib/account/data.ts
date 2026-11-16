// The member's own Wishlist and Interested/Going, with the same tables and
// writes as the app (lib/data/repositories/wishlist_repository.dart,
// event_attendance_repository.dart). Every call names the member's own
// user_id as the app does; RLS is still what decides. Everything signed-in
// goes through this file, so a later per-plan check has one place to sit.
import { supabase } from './client';

export type WishlistEntity = 'restaurant' | 'hotel' | 'event';
export type Intent = 'interested' | 'going';

export interface WishlistRow { entity_type: WishlistEntity; entity_id: string }

export async function loadWishlist(userId: string): Promise<WishlistRow[]> {
  const { data, error } = await supabase()
    .from('wishlist')
    .select('entity_type, entity_id')
    .eq('user_id', userId)
    .order('added_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as WishlistRow[];
}

export async function isWishlisted(userId: string, type: WishlistEntity, id: string): Promise<boolean> {
  const { data, error } = await supabase()
    .from('wishlist')
    .select('user_id')
    .eq('user_id', userId)
    .eq('entity_type', type)
    .eq('entity_id', id)
    .limit(1);
  if (error) throw error;
  return (data ?? []).length > 0;
}

export async function addToWishlist(userId: string, type: WishlistEntity, id: string): Promise<void> {
  const { error } = await supabase().from('wishlist').insert({ user_id: userId, entity_type: type, entity_id: id });
  // 23505: already on the wishlist, which is what was asked for.
  if (error && error.code !== '23505') throw error;
}

export async function removeFromWishlist(userId: string, type: WishlistEntity, id: string): Promise<void> {
  const { error } = await supabase()
    .from('wishlist')
    .delete()
    .eq('user_id', userId)
    .eq('entity_type', type)
    .eq('entity_id', id);
  if (error) throw error;
}

export async function myIntent(userId: string, eventId: string): Promise<Intent | null> {
  const { data, error } = await supabase()
    .from('event_attendance')
    .select('status')
    .eq('event_id', eventId)
    .eq('user_id', userId)
    .limit(1);
  if (error) throw error;
  return (data?.[0]?.status as Intent | undefined) ?? null;
}

export async function myIntents(userId: string): Promise<{ event_id: string; status: Intent }[]> {
  const { data, error } = await supabase()
    .from('event_attendance')
    .select('event_id, status')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as { event_id: string; status: Intent }[];
}

/** As setEventIntent: insert, and on the unique (event_id, user_id) clash
 *  update the existing row. Visibility follows the status the way
 *  visibilityForIntent does: friends, for both. */
export async function setIntent(userId: string, eventId: string, status: Intent): Promise<void> {
  const row = { event_id: eventId, user_id: userId, status, visibility: 'friends' };
  const { error } = await supabase().from('event_attendance').insert(row);
  if (!error) return;
  if (error.code !== '23505') throw error;
  const { error: updateError } = await supabase()
    .from('event_attendance')
    .update({ status, visibility: 'friends' })
    .eq('event_id', eventId)
    .eq('user_id', userId);
  if (updateError) throw updateError;
}

export async function removeIntent(userId: string, eventId: string): Promise<void> {
  const { error } = await supabase().from('event_attendance').delete().eq('event_id', eventId).eq('user_id', userId);
  if (error) throw error;
}

/** Tapping the chosen status again removes it; another status switches
 *  (resolveIntentTap). */
export const resolveIntentTap = (current: Intent | null, tapped: Intent): Intent | null =>
  current === tapped ? null : tapped;

/** Published events by id, for anything the last build didn't include
 *  (one published since, or one that has ended). Same filter as the
 *  app's loadEventsByIds. */
export async function publishedEvents(ids: string[]) {
  if (ids.length === 0) return [];
  const { data, error } = await supabase()
    .from('events')
    .select('id, name, start_date, end_date, end_at, timezone, cancelled_at, city')
    .eq('moderation_status', 'published')
    .in('id', ids);
  if (error) throw error;
  return data ?? [];
}

/** Restaurants and hotels by id that the last build didn't include. */
export async function venuesById(table: 'restaurants_full' | 'hotels_full', ids: string[]) {
  if (ids.length === 0) return [];
  const { data, error } = await supabase().from(table).select('id, name, city_name, country_name').in('id', ids);
  if (error) throw error;
  return data ?? [];
}

/** As eventHasEnded (lib/core/utils/event_time.dart): the exact end when
 *  it is known, else the end of the last day where the event takes place. */
export function eventHasEnded(e: { endAt: string | null; endDate: string; timezone: string | null }, now = new Date()): boolean {
  if (e.endAt) return now.getTime() >= new Date(e.endAt).getTime();
  let today: string;
  try { today = new Intl.DateTimeFormat('en-CA', { timeZone: e.timezone ?? 'Europe/Amsterdam' }).format(now); }
  catch { today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Amsterdam' }).format(now); }
  return e.endDate < today;
}
