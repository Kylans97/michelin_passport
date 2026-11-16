// The four guides the site lists, each as a filter over the catalogue
// plus the order its own list uses.
import type { Catalogue, Restaurant } from './restaurants';

export type GuideSlug = 'michelin' | 'worlds-50-best' | 'gault-millau' | 'mantelier-selection';

export interface Guide {
  slug: GuideSlug;
  name: string;
  intro: string;
  /** Grouped by country, or one ranked list (World's 50 Best). */
  grouped: boolean;
  members: (c: Catalogue) => Restaurant[];
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
];

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
