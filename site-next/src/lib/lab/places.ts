// Data for the Places try-out (src/pages/lab/places.astro): the member's
// own visits and Wishlist, read-only, plus visits added on the page itself.
// Those added visits live only in this browser (localStorage): the
// undated visit doesn't exist in the database yet, and a try-out never
// writes to the account. Nothing here inserts, updates or deletes a row.
import { supabase } from '../account/client';
import { catalogue } from '../account/catalogue';
import type { AccountCatalogue } from '../../pages/account/catalogue/[shard].json';

// As SHARDS in that file, repeated so the browser bundle never pulls in
// the build-time loaders that file imports.
const SHARDS = '0123456789abcdef'.split('');

export type Kind = 'restaurant' | 'hotel';

export interface Venue {
  id: string;
  kind: Kind;
  name: string;
  city: string;
  countryCode: string;
  stars: number | null;
  keys: number | null;
  latitude: number | null;
  longitude: number | null;
  /** The restaurant's page on this site, when the build made one. */
  slug: string | null;
}

export interface Visit {
  /** YYYY-MM-DD, or null when only the year or nothing is known. */
  date: string | null;
  year: number | null;
  rating: number | null;
  notes: string | null;
  /** Added on this page, so in this browser only. */
  local: boolean;
  localId?: string;
}

export interface Entry { venue: Venue; visits: Visit[] }

const regionNames = (() => {
  try { return new Intl.DisplayNames(['en'], { type: 'region' }); } catch { return null; }
})();
export const countryName = (code: string) => (code && regionNames?.of(code.toUpperCase())) || code || 'Elsewhere';

function venuesFrom(cat: AccountCatalogue): Map<string, Venue> {
  const out = new Map<string, Venue>();
  for (const [id, [slug, name, , stars, cc, lat, lon, city]] of Object.entries(cat.r)) {
    out.set(id, { id, kind: 'restaurant', name, city, countryCode: cc, stars, keys: null, latitude: lat, longitude: lon, slug });
  }
  for (const [id, [name, , keys, cc, lat, lon, city]] of Object.entries(cat.h)) {
    out.set(id, { id, kind: 'hotel', name, city, countryCode: cc, stars: null, keys, latitude: lat, longitude: lon, slug: null });
  }
  return out;
}

let everything: Promise<Venue[]> | null = null;

/** Every restaurant and hotel this build knows, for searching and ticking. */
export function allVenues(): Promise<Venue[]> {
  everything ??= Promise.all(SHARDS.map((s) => fetch(`/account/catalogue/${s}.json`).then((r) => {
    if (!r.ok) throw new Error(`catalogue ${s}: ${r.status}`);
    return r.json() as Promise<AccountCatalogue>;
  }))).then((parts) => {
    const merged: AccountCatalogue = { r: {}, h: {}, e: {} };
    for (const p of parts) { Object.assign(merged.r, p.r); Object.assign(merged.h, p.h); }
    return [...venuesFrom(merged).values()];
  });
  return everything;
}

export async function venuesByIds(ids: string[]): Promise<Map<string, Venue>> {
  return venuesFrom(await catalogue(ids));
}

interface VisitRow { entity_type: Kind; entity_id: string; visited_on: string; rating: number | null; notes: string | null }

/** The member's own visits and stays, read-only, as the app reads them. */
export async function loadOwnVisits(userId: string): Promise<VisitRow[]> {
  const { data, error } = await supabase()
    .from('visits')
    .select('entity_type, entity_id, visited_on, rating, notes')
    .eq('user_id', userId);
  if (error) throw error;
  return (data ?? []) as VisitRow[];
}

// ---- Visits added on this page ------------------------------------------

export interface LocalVisit { localId: string; kind: Kind; venueId: string; date: string | null; year: number | null; friends: boolean; addedAt: number }

const LOCAL_KEY = 'mantelier-lab-places';

export function readLocal(): LocalVisit[] {
  try { return JSON.parse(localStorage.getItem(LOCAL_KEY) ?? '[]') as LocalVisit[]; } catch { return []; }
}

function writeLocal(list: LocalVisit[]) {
  try { localStorage.setItem(LOCAL_KEY, JSON.stringify(list)); } catch { /* the page still works for this visit */ }
}

let memory: LocalVisit[] | null = null;
const local = () => (memory ??= readLocal());

export function addLocal(v: Omit<LocalVisit, 'localId' | 'addedAt'>): LocalVisit {
  const row: LocalVisit = { ...v, localId: `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`, addedAt: Date.now() };
  memory = [...local(), row];
  writeLocal(memory);
  return row;
}

export function updateLocal(localId: string, patch: Partial<Pick<LocalVisit, 'date' | 'year'>>) {
  memory = local().map((v) => (v.localId === localId ? { ...v, ...patch } : v));
  writeLocal(memory);
}

export function removeLocal(localId: string) {
  memory = local().filter((v) => v.localId !== localId);
  writeLocal(memory);
}

export function clearLocal() {
  memory = [];
  writeLocal(memory);
}

export const localVisits = () => local();

// ---- Putting it together ------------------------------------------------

/** One entry per venue, the member's real visits and this page's together. */
export function buildEntries(rows: VisitRow[], venues: Map<string, Venue>): Entry[] {
  const byId = new Map<string, Entry>();
  const add = (venue: Venue | undefined, visit: Visit) => {
    if (!venue) return;
    const e = byId.get(venue.id) ?? { venue, visits: [] };
    e.visits.push(visit);
    byId.set(venue.id, e);
  };
  for (const r of rows) add(venues.get(r.entity_id), { date: r.visited_on, year: Number(r.visited_on.slice(0, 4)), rating: r.rating, notes: r.notes, local: false });
  for (const l of local()) add(venues.get(l.venueId), { date: l.date, year: l.date ? Number(l.date.slice(0, 4)) : l.year, rating: null, notes: null, local: true, localId: l.localId });
  for (const e of byId.values()) e.visits.sort((a, b) => (b.date ?? `${b.year ?? 0}`).localeCompare(a.date ?? `${a.year ?? 0}`));
  return [...byId.values()];
}

export const hasDate = (e: Entry) => e.visits.some((v) => v.date);

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** "Mar 2025", "2019" or "Date unknown". */
export function when(v: Visit): string {
  if (v.date) return `${MONTHS[Number(v.date.slice(5, 7)) - 1]} ${v.date.slice(0, 4)}`;
  if (v.year) return `${v.year}, date unknown`;
  return 'Date unknown';
}

/** "Twice, last Mar 2025" or the single visit's when. */
export function visitsLine(e: Entry): string {
  const n = e.visits.length;
  const last = when(e.visits[0]);
  if (n === 1) return last;
  const times = n === 2 ? 'Twice' : `${n} visits`;
  return `${times}, last ${last}`;
}

export const award = (v: Venue): string | null =>
  v.stars && v.stars > 0 ? '★'.repeat(v.stars) : v.keys ? `${v.keys} Key${v.keys > 1 ? 's' : ''}` : null;

export interface Country { code: string; name: string; entries: Entry[]; undated: number }

export function byCountry(entries: Entry[]): Country[] {
  const map = new Map<string, Country>();
  for (const e of entries) {
    const code = e.venue.countryCode;
    const c = map.get(code) ?? { code, name: countryName(code), entries: [], undated: 0 };
    c.entries.push(e);
    if (!hasDate(e)) c.undated++;
    map.set(code, c);
  }
  return [...map.values()].sort((a, b) => b.entries.length - a.entries.length || a.name.localeCompare(b.name));
}

export function byCity(entries: Entry[]): [string, Entry[]][] {
  const map = new Map<string, Entry[]>();
  for (const e of entries) {
    const city = e.venue.city || 'Elsewhere';
    map.set(city, [...(map.get(city) ?? []), e]);
  }
  return [...map.entries()].sort((a, b) => b[1].length - a[1].length || a[0].localeCompare(b[0]));
}

/** Search on name and city, starred first; names are matched without accents. */
export function search(venues: Venue[], q: string, limit = 30): Venue[] {
  const fold = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const needle = fold(q.trim());
  if (needle.length < 2) return [];
  return venues
    .filter((v) => fold(v.name).includes(needle) || fold(v.city).includes(needle))
    .sort((a, b) => Number(fold(b.name).startsWith(needle)) - Number(fold(a.name).startsWith(needle)) || (b.stars ?? 0) - (a.stars ?? 0) || a.name.localeCompare(b.name))
    .slice(0, limit);
}
