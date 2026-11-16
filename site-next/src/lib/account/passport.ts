// The member's Passport, read-only, built the way the app builds it
// (lib/features/passport/own_passport_loader.dart, passport_stamp_source
// .dart, passport_booklet_data.dart): one stamp per visit, stay and
// confirmed event attendance, never per venue; awards as they were at the
// visit; the last five calendar years. Nothing here writes: a stamp is made
// only in the app, when a visit is recorded or attendance confirmed.
import { supabase } from './client';
import { catalogue } from './catalogue';
import { TYPE_LABELS } from '../event-dates';

export type StampKind = 'restaurant' | 'hotel' | 'event';

export interface Stamp {
  /** The visits / event_confirmed_attendance row id: every stamp's look hangs off it. */
  id: string;
  kind: StampKind;
  name: string;
  city: string;
  countryCode: string;
  /** YYYY-MM-DD: the visit date, or the event's first day. */
  date: string;
  stars: number | null;
  keys: number | null;
  eventType: string | null;
  /** The visit's own page for a visit or stay; the event's page when this build has one. */
  href: string | null;
  latitude: number | null;
  longitude: number | null;
  /** The venue or event id, so repeat visits collapse to one pin on the globe. */
  placeId: string;
}

export interface Passport {
  name: string;
  memberNumber: number | null;
  stamps: Stamp[];
  countryCodes: string[];
  stars: number;
  firstYear: number | null;
}

interface VisitRow { id: string; entity_type: 'restaurant' | 'hotel'; entity_id: string; visited_on: string; stars_at_visit: number | null; keys_at_visit: number | null }
interface EventRow { id: string; name: string; start_date: string; city: string | null; country_code: string; event_type: string | null; latitude: number | null; longitude: number | null }

export async function loadPassport(userId: string): Promise<Passport> {
  const db = supabase();
  const [profile, visits, attendance] = await Promise.all([
    db.from('profiles').select('display_name, username, member_number').eq('id', userId).maybeSingle(),
    db.from('visits').select('id, entity_type, entity_id, visited_on, stars_at_visit, keys_at_visit').eq('user_id', userId),
    db.from('event_confirmed_attendance').select('id, event_id').eq('user_id', userId),
  ]);
  for (const r of [profile, visits, attendance]) if (r.error) throw r.error;
  const visitRows = (visits.data ?? []) as VisitRow[];
  const attendanceRows = (attendance.data ?? []) as { id: string; event_id: string }[];

  // Published events only, as loadPassportEventAttendance: an attendance
  // whose event was later unpublished drops out rather than showing a blank.
  const eventIds = attendanceRows.map((a) => a.event_id);
  const events = eventIds.length
    ? await db.from('events').select('id, name, start_date, city, country_code, event_type, latitude, longitude').eq('moderation_status', 'published').in('id', eventIds)
    : { data: [], error: null };
  if (events.error) throw events.error;
  const eventById = new Map(((events.data ?? []) as EventRow[]).map((e) => [e.id, e]));

  const cat = await catalogue([...visitRows.map((v) => v.entity_id), ...eventIds]);
  // Venues this build doesn't hold (expired, or newer than the build).
  const missing = (type: 'restaurant' | 'hotel', known: Record<string, unknown>) =>
    [...new Set(visitRows.filter((v) => v.entity_type === type && !known[v.entity_id]).map((v) => v.entity_id))];
  const live = async (table: 'restaurants_full' | 'hotels_full', ids: string[]) => {
    if (ids.length === 0) return new Map<string, { name: string; city_name: string | null; country_code: string; latitude: number | null; longitude: number | null }>();
    const { data, error } = await db.from(table).select('id, name, city_name, country_code, latitude, longitude').in('id', ids);
    if (error) throw error;
    return new Map((data ?? []).map((v) => [v.id as string, v]));
  };
  const [liveRestaurants, liveHotels] = await Promise.all([
    live('restaurants_full', missing('restaurant', cat.r)),
    live('hotels_full', missing('hotel', cat.h)),
  ]);

  const stamps: Stamp[] = [];
  for (const v of visitRows) {
    const base = { id: v.id, date: v.visited_on, href: `/account/visit?id=${v.id}`, placeId: v.entity_id, eventType: null };
    if (v.entity_type === 'restaurant') {
      const built = cat.r[v.entity_id];
      const other = liveRestaurants.get(v.entity_id);
      if (!built && !other) continue;
      stamps.push({
        ...base, kind: 'restaurant', stars: v.stars_at_visit, keys: null,
        name: built ? built[1] : other!.name,
        city: built ? built[7] : other!.city_name ?? '',
        countryCode: built ? built[4] : other!.country_code,
        latitude: built ? built[5] : other!.latitude,
        longitude: built ? built[6] : other!.longitude,
      });
    } else {
      const built = cat.h[v.entity_id];
      const other = liveHotels.get(v.entity_id);
      if (!built && !other) continue;
      stamps.push({
        ...base, kind: 'hotel', stars: null, keys: v.keys_at_visit,
        name: built ? built[0] : other!.name,
        city: built ? built[6] : other!.city_name ?? '',
        countryCode: built ? built[3] : other!.country_code,
        latitude: built ? built[4] : other!.latitude,
        longitude: built ? built[5] : other!.longitude,
      });
    }
  }
  for (const a of attendanceRows) {
    const e = eventById.get(a.event_id);
    if (!e) continue;
    const built = cat.e[e.id];
    stamps.push({
      id: a.id, kind: 'event', name: e.name, city: e.city ?? '', countryCode: e.country_code, date: e.start_date,
      stars: null, keys: null, eventType: TYPE_LABELS[e.event_type ?? ''] ?? 'Event',
      href: built ? `/events/${built[0]}` : null, latitude: e.latitude, longitude: e.longitude, placeId: e.id,
    });
  }

  // "Tot vijf jaar terug": this year and the four before it, as the app.
  const cutoff = new Date().getFullYear() - 4;
  const kept = stamps.filter((s) => Number(s.date.slice(0, 4)) >= cutoff).sort((a, b) => a.date.localeCompare(b.date));
  const p = profile.data as { display_name: string | null; username: string | null; member_number: number | null } | null;
  return {
    name: p?.display_name?.trim() || p?.username || '',
    memberNumber: p?.member_number ?? null,
    stamps: kept,
    countryCodes: [...new Set(kept.map((s) => s.countryCode).filter(Boolean))].sort(),
    // A sum over stamps, not venues, as PassportVolume.stars.
    stars: kept.reduce((sum, s) => sum + (s.kind === 'restaurant' ? s.stars ?? 0 : 0), 0),
    firstYear: kept.length ? Number(kept[0].date.slice(0, 4)) : null,
  };
}
