// What the signed-in pages need to name and link what a member saved,
// written once per build: the member's own rows (wishlist,
// event_attendance) hold only ids. Read from the build's own data so a
// name always links to the page this build made for it; anything newer
// than the build is looked up live (src/lib/account/data.ts).
//
// Split into 16 files by the id's first hex digit, so a member's page
// loads only the parts holding what they saved (all of it would be about
// 260 kB compressed).
import type { APIRoute, GetStaticPaths } from 'astro';
import { loadCatalogue, place } from '../../../lib/restaurants';
import { formatWhen, loadEvents, place as eventPlace } from '../../../lib/events';
import { selectAll } from '../../../lib/supabase';

export interface AccountCatalogue {
  /** id → [page slug, name, place, current MICHELIN stars or null] */
  r: Record<string, [string, string, string, number | null]>;
  /** id → [name, place, MICHELIN Keys or null]. Hotels have no pages yet. */
  h: Record<string, [string, string, number | null]>;
  /** id → [page slug, name, when, place, cancelled] */
  e: Record<string, [string, string, string, string, boolean]>;
}

export const SHARDS = '0123456789abcdef'.split('');

let all: Promise<AccountCatalogue> | null = null;

function loadAll(): Promise<AccountCatalogue> {
  all ??= (async () => {
    const [{ restaurants }, events, hotels] = await Promise.all([
      loadCatalogue(),
      loadEvents(),
      selectAll<{ id: string; name: string; city_name: string | null; country_name: string | null; michelin_keys: number | null }>(
        'hotels_full', 'select=id,name,city_name,country_name,michelin_keys&order=id'),
    ]);
    const out: AccountCatalogue = { r: {}, h: {}, e: {} };
    for (const r of restaurants) out.r[r.id] = [r.slug, r.name, place(r), r.stars];
    for (const h of hotels) out.h[h.id] = [h.name, [h.city_name, h.country_name].filter(Boolean).join(', '), h.michelin_keys];
    for (const e of events) out.e[e.id] = [e.slug, e.name, formatWhen(e), eventPlace(e), e.cancelled];
    return out;
  })();
  return all;
}

export const getStaticPaths: GetStaticPaths = () => SHARDS.map((shard) => ({ params: { shard } }));

export const GET: APIRoute = async ({ params }) => {
  const full = await loadAll();
  const pick = <T>(map: Record<string, T>) =>
    Object.fromEntries(Object.entries(map).filter(([id]) => id[0] === params.shard));
  const out: AccountCatalogue = { r: pick(full.r), h: pick(full.h), e: pick(full.e) };
  return new Response(JSON.stringify(out), { headers: { 'Content-Type': 'application/json' } });
};
