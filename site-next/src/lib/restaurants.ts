// Restaurants and their guides on the public site, read once per build
// with the rules the app uses (lib/data/repositories/award_history_
// repository.dart, gault_millau_ranking.dart, editorial_selection_
// repository.dart). Only verified, factual data: no descriptive text of
// our own, and no guide we don't hold the data for.
import { selectAll } from './supabase';
import { slugify } from './news';

export interface GaultMillau {
  year: number;
  score: number | null;
  toques: number | null;
  label: string | null;
  url: string | null;
}

/** A guide from the shared guide tables (guides / guide_awards /
 *  guide_coverage): today the regional 50 Best lists. */
export interface OtherGuide {
  code: string;
  name: string;
  /** Every edition this restaurant appears in, newest first. */
  history: { year: number; value: string }[];
  /** The guide's latest edition, when this restaurant is in it. */
  current: { year: number; value: string } | null;
  /** The guide's own coverage note for its latest edition: what we hold. */
  coverageNote: string | null;
}

export interface Restaurant {
  id: string;
  code: string;
  name: string;
  slug: string;
  city: string | null;
  region: string | null;
  country: string | null;
  countryCode: string | null;
  address: string | null;
  /** The verified location, for the signed-in member's globe. */
  latitude: number | null;
  longitude: number | null;
  cuisine: string | null;
  websiteUrl: string | null;
  michelinUrl: string | null;
  closed: boolean;
  /** The hotel it sits in, from the verified hotel_restaurants link. */
  hotelName: string | null;
  /** A property outside our hotel list: free text, shown, never joined on. */
  propertyName: string | null;

  /** Current MICHELIN stars; 0 is a real value (listed without a star), null is no current MICHELIN award. */
  stars: number | null;
  michelinHistory: { year: number; stars: number | null }[];

  /** Rank on the latest World's 50 Best list we hold (1–100), else null. */
  w50bRank: number | null;
  w50bHallOfFame: boolean;
  w50bUrl: string | null;
  w50bHistory: { year: number; rank: number | null; list: 'top_50' | 'extended_51_100' | 'hall_of_fame' }[];

  /** The latest Gault&Millau edition for this restaurant, else null. */
  gaultMillau: GaultMillau | null;

  /** Current member of the Mantelier Selection (editorial_selections, removed_on is null). */
  inSelection: boolean;

  /** Guides from the shared tables this restaurant appears in. */
  otherGuides: OtherGuide[];
}

export interface Catalogue {
  restaurants: Restaurant[];
  bySlug: Map<string, Restaurant>;
  /** The newest World's 50 Best year in worlds_50_best. */
  w50bYear: number | null;
}

/** An http(s) URL as stored, else null: placeholders such as "not found"
 *  are never linked, repaired or rebuilt from a name. */
function httpUrl(raw: string | null | undefined): string | null {
  const v = raw?.trim();
  if (!v) return null;
  try {
    const u = new URL(v);
    return u.protocol === 'https:' || u.protocol === 'http:' ? v : null;
  } catch {
    return null;
  }
}

interface RestaurantRow {
  id: string; restaurant_code: string; name: string; michelin_stars: number | null;
  country_code: string | null; address: string | null; website_url: string | null;
  michelin_url: string | null; worlds_50_best_url: string | null; status: string | null;
  is_expired: boolean | null; hotel_name: string | null; property_name: string | null;
  city_name: string | null; region: string | null; country_name: string | null;
  worlds_50_best_rank: number | null; is_hall_of_fame: boolean | null; cuisine_names: string | null;
  latitude: number | null; longitude: number | null;
}

let cache: Promise<Catalogue> | null = null;

export function loadCatalogue(): Promise<Catalogue> {
  cache ??= (async () => {
    const [rows, michelin, w50b, gm, selection, guides, guideAwards, coverage] = await Promise.all([
      selectAll<RestaurantRow>(
        'restaurants_full',
        'select=id,restaurant_code,name,michelin_stars,country_code,address,website_url,michelin_url,worlds_50_best_url,status,is_expired,hotel_name,property_name,city_name,region,country_name,worlds_50_best_rank,is_hall_of_fame,cuisine_names,latitude,longitude&order=restaurant_code',
      ),
      selectAll<{ entity_id: string; guide_year: number; award_value: number | null }>(
        'award_history',
        'select=entity_id,guide_year,award_value&entity_type=eq.restaurant&award_type=eq.michelin_stars&order=id',
      ),
      selectAll<{ restaurant_id: string; year: number; rank: number | null; list_type: string }>(
        'worlds_50_best', 'select=restaurant_id,year,rank,list_type&order=id',
      ),
      selectAll<{
        restaurant_id: string; guide_year: number; score: number | null; toque_count: number | null;
        distinction_label: string | null; gault_millau_url: string | null;
      }>('gault_millau_awards', 'select=restaurant_id,guide_year,score,toque_count,distinction_label,gault_millau_url&order=id'),
      selectAll<{ restaurant_id: string }>('editorial_selections', 'select=restaurant_id&removed_on=is.null&order=restaurant_id'),
      selectAll<{ guide_code: string; name: string; measure: string; tier_labels: Record<string, string> | null }>('guides', 'select=guide_code,name,measure,tier_labels&order=guide_code'),
      selectAll<{
        restaurant_id: string | null; guide_code: string; edition_year: number; rank: number | null;
        score: number | null; tier: number | null; distinction_label: string | null;
      }>('guide_awards', 'select=restaurant_id,guide_code,edition_year,rank,score,tier,distinction_label&restaurant_id=not.is.null&order=id'),
      selectAll<{ guide_code: string; edition_year: number; note: string }>(
        'guide_coverage', 'select=guide_code,edition_year,note&country_code=is.null&order=id',
      ),
    ]);

    const historyBy = new Map<string, Restaurant['michelinHistory']>();
    for (const h of michelin) {
      if (!historyBy.has(h.entity_id)) historyBy.set(h.entity_id, []);
      historyBy.get(h.entity_id)!.push({ year: h.guide_year, stars: h.award_value });
    }

    const w50bBy = new Map<string, Restaurant['w50bHistory']>();
    let w50bYear: number | null = null;
    for (const w of w50b) {
      if (w.list_type !== 'top_50' && w.list_type !== 'extended_51_100' && w.list_type !== 'hall_of_fame') continue;
      if (!w50bBy.has(w.restaurant_id)) w50bBy.set(w.restaurant_id, []);
      w50bBy.get(w.restaurant_id)!.push({ year: w.year, rank: w.rank, list: w.list_type });
      if (w50bYear === null || w.year > w50bYear) w50bYear = w.year;
    }

    // Latest edition per restaurant, as latestGaultMillauAwardPerRestaurant.
    const gmBy = new Map<string, GaultMillau>();
    for (const g of gm) {
      const existing = gmBy.get(g.restaurant_id);
      if (existing && existing.year >= g.guide_year) continue;
      gmBy.set(g.restaurant_id, {
        year: g.guide_year,
        score: g.score === null ? null : Number(g.score),
        toques: g.toque_count,
        label: g.distinction_label,
        url: httpUrl(g.gault_millau_url),
      });
    }

    const selected = new Set(selection.map((s) => s.restaurant_id));

    // Shared-table guides. A guide's current edition is its own latest one,
    // as guide_awards_current reads it; each value in the guide's own
    // measure, and nothing shown that the row doesn't hold.
    const guideBy = new Map(guides.map((g) => [g.guide_code, g]));
    const latestEdition = new Map<string, number>();
    for (const a of guideAwards) {
      latestEdition.set(a.guide_code, Math.max(latestEdition.get(a.guide_code) ?? a.edition_year, a.edition_year));
    }
    const noteBy = new Map<string, string>();
    for (const c of coverage) if (c.edition_year === latestEdition.get(c.guide_code)) noteBy.set(c.guide_code, c.note);
    const valueOf = (a: (typeof guideAwards)[number]): string | null => {
      const measure = guideBy.get(a.guide_code)?.measure;
      if (measure === 'rank' && a.rank !== null) return `#${a.rank}`;
      if (measure === 'score' && a.score !== null) return String(Number(a.score));
      if (measure === 'tier' && a.tier !== null) return guideBy.get(a.guide_code)?.tier_labels?.[String(a.tier)] ?? String(a.tier);
      return a.distinction_label;
    };
    const otherBy = new Map<string, Map<string, OtherGuide>>();
    for (const a of guideAwards) {
      const value = valueOf(a);
      const guide = guideBy.get(a.guide_code);
      if (!value || !guide || !a.restaurant_id) continue;
      if (!otherBy.has(a.restaurant_id)) otherBy.set(a.restaurant_id, new Map());
      const forRestaurant = otherBy.get(a.restaurant_id)!;
      if (!forRestaurant.has(a.guide_code)) {
        forRestaurant.set(a.guide_code, {
          code: a.guide_code, name: guide.name, history: [], current: null,
          coverageNote: noteBy.get(a.guide_code) ?? null,
        });
      }
      const og = forRestaurant.get(a.guide_code)!;
      og.history.push({ year: a.edition_year, value });
      if (a.edition_year === latestEdition.get(a.guide_code)) og.current = { year: a.edition_year, value };
    }
    for (const m of otherBy.values()) for (const og of m.values()) og.history.sort((x, y) => y.year - x.year);

    const restaurants: Restaurant[] = rows
      .filter((r) => !r.is_expired)
      .map((r) => ({
        id: r.id,
        code: r.restaurant_code,
        name: r.name,
        slug: '',
        city: r.city_name,
        region: r.region,
        country: r.country_name,
        countryCode: r.country_code,
        address: r.address,
        latitude: r.latitude,
        longitude: r.longitude,
        cuisine: r.cuisine_names,
        websiteUrl: httpUrl(r.website_url),
        michelinUrl: httpUrl(r.michelin_url),
        closed: r.status === 'permanently_closed',
        hotelName: r.hotel_name,
        propertyName: r.hotel_name ? null : r.property_name,
        stars: r.michelin_stars,
        michelinHistory: (historyBy.get(r.id) ?? []).sort((a, b) => b.year - a.year),
        w50bRank: r.worlds_50_best_rank,
        w50bHallOfFame: !!r.is_hall_of_fame,
        w50bUrl: httpUrl(r.worlds_50_best_url),
        w50bHistory: (w50bBy.get(r.id) ?? []).sort((a, b) => b.year - a.year),
        gaultMillau: gmBy.get(r.id) ?? null,
        inSelection: selected.has(r.id),
        otherGuides: [...(otherBy.get(r.id)?.values() ?? [])].sort((a, b) => a.name.localeCompare(b.name)),
      }));

    // Addresses: name and city. Two restaurants that would share one both
    // get their code appended, so neither address depends on build order.
    const base = (r: Restaurant) => slugify([r.name, r.city].filter(Boolean).join(' ')) || r.code.toLowerCase();
    const counts = new Map<string, number>();
    for (const r of restaurants) counts.set(base(r), (counts.get(base(r)) ?? 0) + 1);
    for (const r of restaurants) {
      const b = base(r);
      r.slug = counts.get(b)! > 1 ? `${b}-${slugify(r.code)}` : b;
    }
    const bySlug = new Map(restaurants.map((r) => [r.slug, r]));
    if (bySlug.size !== restaurants.length) throw new Error('Two restaurants share one address.');

    return { restaurants, bySlug, w50bYear };
  })();
  return cache;
}

/** How many guides currently recognise this restaurant. */
export function guideCount(r: Restaurant): number {
  return (r.stars !== null ? 1 : 0) + (r.w50bRank !== null ? 1 : 0) + (r.gaultMillau ? 1 : 0) + (r.inSelection ? 1 : 0);
}

export const place = (r: Restaurant) => [r.city, r.country].filter(Boolean).join(', ');

/** "18/20", "18.5/20", or the edition's own label when it has no score. */
export function gaultMillauText(g: GaultMillau): string {
  if (g.score !== null) return `${Number.isInteger(g.score) ? g.score : g.score.toFixed(1)}/20`;
  if (g.label) return g.label;
  if (g.toques !== null) return `${g.toques} toque${g.toques === 1 ? '' : 's'}`;
  return 'Listed';
}
