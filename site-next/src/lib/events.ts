// Events on the public site, with the app's own rules
// (lib/models/event.dart, lib/features/events/event_date_format.dart,
// lib/data/repositories/events_repository.dart): published only, dates and
// times in the event's own timezone, and a time that isn't known is never
// shown, guessed or labelled as missing.
import { inList, selectAll } from './supabase';
import { slugify } from './news';
import { loadCatalogue } from './restaurants';

const TYPE_LABELS: Record<string, string> = {
  festival: 'Festival', dinner: 'Dinner', lunch: 'Lunch', tasting: 'Tasting', gala: 'Gala',
  brunch: 'Brunch', party: 'Party', market: 'Market', experience: 'Experience',
};
const ADMISSION_LABELS: Record<string, string> = {
  free: 'Free entry', paid: 'Ticketed', mixed: 'Free entry, optional ticket', unknown: 'Admission not confirmed',
};

export type LinkRole = 'host' | 'venue' | 'participant';

export interface EventVenueLink {
  name: string;
  /** The restaurant's page on this site; hotels have none yet. */
  href: string | null;
  kind: 'Restaurant' | 'Hotel';
  roles: LinkRole[];
}

export interface SiteEvent {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  type: string;
  startDate: string; // YYYY-MM-DD, the event's own calendar date
  endDate: string;
  startTime: string | null; // HH:MM, local to the event
  endTime: string | null;
  timezone: string | null;
  city: string | null;
  country: string | null;
  venueName: string | null;
  address: string | null;
  officialUrl: string | null;
  ticketUrl: string | null;
  cancelled: boolean;
  admission: string;
  admissionNote: string | null;
  tags: string[];
  venues: EventVenueLink[];
}

interface EventRow {
  id: string; name: string | null; description: string | null; event_type: string | null;
  start_date: string; end_date: string; start_time: string | null; end_time: string | null;
  timezone: string | null; city: string | null; country_code: string | null; venue_name: string | null;
  address: string | null; official_url: string | null; ticket_url: string | null;
  cancelled_at: string | null; admission_type: string | null; admission_note: string | null;
}

const countryNames = new Intl.DisplayNames(['en'], { type: 'region' });
const countryName = (code: string | null) => {
  if (!code) return null;
  try { return countryNames.of(code) ?? code; } catch { return code; }
};

function httpUrl(raw: string | null): string | null {
  const v = raw?.trim();
  if (!v) return null;
  try { const u = new URL(v); return u.protocol === 'https:' || u.protocol === 'http:' ? v : null; } catch { return null; }
}

/** Today's calendar date in Amsterdam, as YYYY-MM-DD. */
function todayInAmsterdam(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Amsterdam' }).format(new Date());
}

let cache: Promise<SiteEvent[]> | null = null;

/** Every published event that hasn't ended at build time, soonest first.
 *  Like the app's browse window, an event ending yesterday still counts,
 *  so no timezone ahead of Amsterdam loses an event too early; the page
 *  itself hides ended events by each event's own date (see EventList). */
export function loadEvents(): Promise<SiteEvent[]> {
  cache ??= (async () => {
    const yesterday = new Date(`${todayInAmsterdam()}T00:00:00Z`);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const from = yesterday.toISOString().slice(0, 10);

    const rows = await selectAll<EventRow>(
      'events',
      'select=id,name,description,event_type,start_date,end_date,start_time,end_time,timezone,city,country_code,venue_name,address,official_url,ticket_url,cancelled_at,admission_type,admission_note'
        + `&moderation_status=eq.published&end_date=gte.${from}&order=start_date,id`,
    );
    const ids = rows.map((r) => r.id);
    if (ids.length === 0) return [];

    // Batched per link table, never one query per event. inList is
    // chunked to keep each URL short.
    const chunks: string[][] = [];
    for (let i = 0; i < ids.length; i += 150) chunks.push(ids.slice(i, i + 150));
    const byChunks = async <T>(table: string, cols: string) =>
      (await Promise.all(chunks.map((c) => selectAll<T>(table, `select=${cols}&event_id=${inList(c)}&order=id`)))).flat();

    const [restaurantLinks, hotelLinks, tagLinks, tags, catalogue] = await Promise.all([
      byChunks<{ event_id: string; restaurant_id: string; is_host: boolean; is_venue: boolean }>('event_restaurants', 'id,event_id,restaurant_id,is_host,is_venue'),
      byChunks<{ event_id: string; hotel_id: string; is_host: boolean; is_venue: boolean }>('event_hotels', 'id,event_id,hotel_id,is_host,is_venue'),
      byChunks<{ event_id: string; tag_id: string }>('event_tag_assignments', 'id,event_id,tag_id'),
      selectAll<{ id: string; name: string }>('event_tags', 'select=id,name&order=name'),
      loadCatalogue(),
    ]);

    const hotelIds = [...new Set(hotelLinks.map((l) => l.hotel_id))];
    const hotels = hotelIds.length
      ? await selectAll<{ id: string; name: string }>('hotels_full', `select=id,name&id=${inList(hotelIds)}&order=id`)
      : [];
    const hotelName = new Map(hotels.map((h) => [h.id, h.name]));
    const restaurantById = new Map(catalogue.restaurants.map((r) => [r.id, r]));
    const tagName = new Map(tags.map((t) => [t.id, t.name]));

    const roles = (l: { is_host: boolean; is_venue: boolean }): LinkRole[] =>
      l.is_host || l.is_venue
        ? [...(l.is_host ? ['host' as const] : []), ...(l.is_venue ? ['venue' as const] : [])]
        : ['participant'];

    const events = rows.map((r): SiteEvent => {
      const venues: EventVenueLink[] = [];
      for (const l of restaurantLinks.filter((x) => x.event_id === r.id)) {
        const rest = restaurantById.get(l.restaurant_id);
        if (rest) venues.push({ name: rest.name, href: `/restaurants/${rest.slug}`, kind: 'Restaurant', roles: roles(l) });
      }
      for (const l of hotelLinks.filter((x) => x.event_id === r.id)) {
        const name = hotelName.get(l.hotel_id);
        if (name) venues.push({ name, href: null, kind: 'Hotel', roles: roles(l) });
      }
      return {
        id: r.id,
        slug: '',
        name: r.name ?? '',
        description: r.description?.trim() || null,
        type: TYPE_LABELS[r.event_type ?? ''] ?? 'Event',
        startDate: r.start_date,
        endDate: r.end_date,
        startTime: r.start_time ? r.start_time.slice(0, 5) : null,
        endTime: r.end_time ? r.end_time.slice(0, 5) : null,
        timezone: r.timezone,
        city: r.city,
        country: countryName(r.country_code),
        venueName: r.venue_name,
        address: r.address,
        officialUrl: httpUrl(r.official_url),
        ticketUrl: httpUrl(r.ticket_url),
        cancelled: r.cancelled_at !== null,
        admission: ADMISSION_LABELS[r.admission_type ?? 'unknown'] ?? ADMISSION_LABELS.unknown,
        admissionNote: r.admission_note?.trim() || null,
        tags: tagLinks.filter((t) => t.event_id === r.id).map((t) => tagName.get(t.tag_id)).filter((t): t is string => !!t),
        venues,
      };
    });

    // Address: name and start date; a clash adds the id's first block.
    const base = (e: SiteEvent) => `${slugify(e.name) || 'event'}-${e.startDate}`;
    const counts = new Map<string, number>();
    for (const e of events) counts.set(base(e), (counts.get(base(e)) ?? 0) + 1);
    for (const e of events) e.slug = counts.get(base(e))! > 1 ? `${base(e)}-${e.id.slice(0, 8)}` : base(e);
    return events;
  })();
  return cache;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MONTHS_LONG = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const parts = (d: string) => d.split('-').map(Number) as [number, number, number];

/** formatEventDateRange: "27 Aug 2026", "27–30 Aug 2026", "30 Aug – 2 Sep 2026". */
export function formatDateRange(e: SiteEvent): string {
  const [sy, sm, sd] = parts(e.startDate);
  const [ey, em, ed] = parts(e.endDate);
  if (sy === ey && sm === em && sd === ed) return `${sd} ${MONTHS[sm - 1]} ${sy}`;
  if (sy === ey && sm === em) return `${sd}–${ed} ${MONTHS[sm - 1]} ${sy}`;
  if (sy === ey) return `${sd} ${MONTHS[sm - 1]} – ${ed} ${MONTHS[em - 1]} ${sy}`;
  return `${sd} ${MONTHS[sm - 1]} ${sy} – ${ed} ${MONTHS[em - 1]} ${ey}`;
}

/** formatEventDateAndTime: only the precision actually known, never a placeholder. */
export function formatWhen(e: SiteEvent): string {
  const range = formatDateRange(e);
  if (!e.startTime) return range;
  if (!e.endTime) return `${range} · ${e.startTime}`;
  return `${range} · ${e.startTime}–${e.endTime}`;
}

export const monthKey = (e: SiteEvent) => e.startDate.slice(0, 7);
export const monthLabel = (key: string) => {
  const [y, m] = key.split('-').map(Number);
  return `${MONTHS_LONG[m - 1]} ${y}`;
};

export const place = (e: SiteEvent) => [e.city, e.country].filter(Boolean).join(', ');
