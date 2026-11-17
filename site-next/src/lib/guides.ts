// The guides the site lists, each as a filter over the catalogue plus the
// order its own list uses. The last four come from the shared guide tables
// (restaurant.otherGuides), each in its own latest edition.
import type { Catalogue, Restaurant } from './restaurants';

export type GuideSlug = 'michelin' | 'worlds-50-best' | 'gault-millau' | 'mantelier-selection'
  | 'asia-50-best' | 'latin-america-50-best' | 'north-america-50-best' | 'guia-repsol';

export interface Guide {
  slug: GuideSlug;
  name: string;
  intro: string;
  /** Grouped by country, or one list (ranked when [rankOf] is set). */
  grouped: boolean;
  members: (c: Catalogue) => Restaurant[];
  /** A ranked list's rank, shown in order with gaps for ranks we lack. */
  rankOf?: (r: Restaurant) => number | null;
  /** What leads each row of an unranked list, in the guide's own words. */
  leadOf?: (r: Restaurant) => string | null;
  /** The shared-table guide code, for its edition year and coverage note. */
  code?: string;
}

const current = (r: Restaurant, code: string) => r.otherGuides.find((g) => g.code === code)?.current ?? null;

function regional50(slug: GuideSlug, code: string, name: string): Guide {
  return {
    slug, code, name,
    intro: 'The most recent list, in its own order.',
    grouped: false,
    members: (c) => c.restaurants
      .filter((r) => current(r, code)?.rank != null)
      .sort((a, b) => current(a, code)!.rank! - current(b, code)!.rank!),
    rankOf: (r) => current(r, code)?.rank ?? null,
  };
}

const byName = (a: Restaurant, b: Restaurant) => a.name.localeCompare(b.name);
const starsOf = (r: Restaurant) => r.stars ?? 0;
const gmScore = (r: Restaurant) => r.gaultMillau?.score ?? -1;

export const GUIDES: Guide[] = [
  {
    slug: 'michelin',
    name: 'MICHELIN Guide',
    intro: 'Every restaurant holding MICHELIN stars in the current guide, by country.',
    grouped: true,
    members: (c) => c.restaurants
      .filter((r) => starsOf(r) > 0 && !r.closed)
      .sort((a, b) => starsOf(b) - starsOf(a) || byName(a, b)),
  },
  {
    slug: 'worlds-50-best',
    name: 'The World’s 50 Best Restaurants',
    intro: 'The most recent list, from 1 to 100.',
    grouped: false,
    members: (c) => c.restaurants
      .filter((r) => r.w50bRank !== null)
      .sort((a, b) => a.w50bRank! - b.w50bRank!),
  },
  {
    slug: 'gault-millau',
    name: 'Gault&Millau',
    intro: 'The Gault&Millau scores we have so far, highest first, from each restaurant’s latest edition. Not every country is in yet.',
    grouped: true,
    members: (c) => c.restaurants
      .filter((r) => r.gaultMillau !== null && !r.closed)
      .sort((a, b) => gmScore(b) - gmScore(a) || (b.gaultMillau!.toques ?? -1) - (a.gaultMillau!.toques ?? -1) || byName(a, b)),
  },
  {
    slug: 'mantelier-selection',
    name: 'Mantelier Selection',
    intro: 'Restaurants we pick ourselves, one at a time. Our opinion, not an award.',
    grouped: true,
    members: (c) => c.restaurants.filter((r) => r.inSelection && !r.closed).sort(byName),
  },
  regional50('asia-50-best', 'asia_50_best', 'Asia’s 50 Best Restaurants'),
  regional50('latin-america-50-best', 'latin_america_50_best', 'Latin America’s 50 Best Restaurants'),
  regional50('north-america-50-best', 'north_america_50_best', 'North America’s 50 Best Restaurants'),
  {
    slug: 'guia-repsol',
    code: 'guia_repsol',
    name: 'Guía Repsol',
    intro: 'Restaurants in Spain awarded Repsol Soles, most Soles first.',
    grouped: false,
    members: (c) => c.restaurants
      .filter((r) => current(r, 'guia_repsol') !== null && !r.closed)
      .sort((a, b) => (current(b, 'guia_repsol')!.tier ?? 0) - (current(a, 'guia_repsol')!.tier ?? 0) || byName(a, b)),
    leadOf: (r) => current(r, 'guia_repsol')?.value ?? null,
  },
];

/** A shared-table guide's latest edition year and coverage note. */
export function guideEdition(guide: Guide, c: Catalogue): { year: number | null; note: string | null } {
  if (!guide.code) return { year: null, note: null };
  for (const r of c.restaurants) {
    const g = r.otherGuides.find((o) => o.code === guide.code && o.current);
    if (g) return { year: g.current!.year, note: g.coverageNote };
  }
  return { year: null, note: null };
}

/** [list] grouped by country (alphabetical), keeping each group's order. */
export function byCountry(list: Restaurant[]): [string, Restaurant[]][] {
  const groups = new Map<string, Restaurant[]>();
  for (const r of list) {
    const key = r.country ?? 'Elsewhere';
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(r);
  }
  return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b));
}
