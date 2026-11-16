// News on the public site: the same rows, rules and body format the app
// reads (lib/models/news_article.dart). Loaded once per build; a new or
// changed article needs a rebuild and deploy to appear.
import { inList, select } from './supabase';

export type NewsSection = 'about' | 'interview' | 'story';

export interface NewsArticle {
  id: string;
  section: NewsSection;
  title: string;
  shortTitle: string;
  slug: string;
  body: string;
  imageUrl: string | null;
  linkUrl: string | null;
  publishedAt: Date;
  focusX: number;
  focusY: number;
}

export interface NewsPhoto {
  imageUrl: string;
  caption: string | null;
  afterParagraph: number;
  displayOrder: number;
  focusX: number;
  focusY: number;
  isSmall: boolean;
}

export type BlockKind = 'text' | 'question' | 'quote';
export interface NewsBlock { kind: BlockKind; text: string; }

export interface LinkedChef { name: string; businessName: string | null; city: string | null; }
export interface LinkedVenue { id: string; name: string; city: string | null; country: string | null; }
export interface LinkedVenues { chefs: LinkedChef[]; restaurants: LinkedVenue[]; hotels: LinkedVenue[]; }

interface ArticleRow {
  id: string; section: string | null; title: string; card_title: string | null; body: string;
  image_url: string | null; link_url: string | null; published_at: string;
  focus_x: number | null; focus_y: number | null;
}

/** An article's address: its card title (or title), lowercased, accents
 *  dropped, anything else to single hyphens. Changing the title changes
 *  the address. */
export function slugify(text: string): string {
  return text
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

let cache: Promise<NewsArticle[]> | null = null;

/** Every published article, newest first. RLS on news_articles is the
 *  only filter: published, and published_at in the past at build time. */
export function loadArticles(): Promise<NewsArticle[]> {
  cache ??= (async () => {
    const rows = await select<ArticleRow>(
      'news_articles',
      'select=id,section,title,card_title,body,image_url,link_url,published_at,focus_x,focus_y&order=published_at.desc',
    );
    const articles = rows.map((r): NewsArticle => {
      const short = r.card_title?.trim() || r.title;
      return {
        id: r.id,
        section: r.section === 'about' || r.section === 'interview' ? r.section : 'story',
        title: r.title,
        shortTitle: short,
        slug: slugify(short),
        body: r.body,
        imageUrl: r.image_url,
        linkUrl: r.link_url,
        publishedAt: new Date(r.published_at),
        focusX: r.focus_x ?? 0.5,
        focusY: r.focus_y ?? 0.5,
      };
    });
    const seen = new Set<string>();
    for (const a of articles) {
      if (!a.slug || seen.has(a.slug)) {
        throw new Error(`Two articles share the address "/news/${a.slug}"; give one a different card title.`);
      }
      seen.add(a.slug);
    }
    return articles;
  })();
  return cache;
}

/** The body split on blank lines, each paragraph read for "Q: " (a
 *  question) and "> " (a pull quote), exactly as the app does. */
export function blocks(body: string): NewsBlock[] {
  return body
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0)
    .map((p): NewsBlock => {
      if (p.startsWith('Q:')) return { kind: 'question', text: p.slice(2).trim() };
      if (p.startsWith('>')) return { kind: 'quote', text: p.slice(1).trim() };
      return { kind: 'text', text: p };
    });
}

export async function loadPhotos(articleId: string): Promise<NewsPhoto[]> {
  const rows = await select<{
    image_url: string; caption: string | null; after_paragraph: number | null; display_order: number | null;
    focus_x: number | null; focus_y: number | null; size: string | null;
  }>(
    'news_article_photos',
    `select=image_url,caption,after_paragraph,display_order,focus_x,focus_y,size&news_article_id=eq.${articleId}&order=after_paragraph,display_order`,
  );
  return rows.map((r) => ({
    imageUrl: r.image_url,
    caption: r.caption,
    afterParagraph: r.after_paragraph ?? 0,
    displayOrder: r.display_order ?? 0,
    focusX: r.focus_x ?? 0.5,
    focusY: r.focus_y ?? 0.5,
    isSmall: r.size === 'small',
  }));
}

/** Photos grouped by place, as groupNewsPhotos in the app: 0 is before
 *  the first paragraph, n after paragraph n, past the end moves to the end. */
export function groupPhotos(photos: NewsPhoto[], paragraphCount: number): Map<number, NewsPhoto[]> {
  const sorted = [...photos].sort((a, b) => a.afterParagraph - b.afterParagraph || a.displayOrder - b.displayOrder);
  const groups = new Map<number, NewsPhoto[]>();
  for (const photo of sorted) {
    const place = Math.min(photo.afterParagraph, paragraphCount);
    if (!groups.has(place)) groups.set(place, []);
    groups.get(place)!.push(photo);
  }
  return groups;
}

/** The chefs, restaurants and hotels an article links to. Unpublished
 *  ones are invisible to the anon key and simply left out. */
export async function loadLinkedVenues(articleId: string): Promise<LinkedVenues> {
  const filter = `news_article_id=eq.${articleId}`;
  const [chefLinks, restaurantLinks, hotelLinks] = await Promise.all([
    select<{ chef_id: string }>('news_article_chefs', `select=chef_id&${filter}`),
    select<{ restaurant_id: string }>('news_article_restaurants', `select=restaurant_id&${filter}`),
    select<{ hotel_id: string }>('news_article_hotels', `select=hotel_id&${filter}`),
  ]);
  const chefIds = chefLinks.map((l) => l.chef_id);
  const restaurantIds = restaurantLinks.map((l) => l.restaurant_id);
  const hotelIds = hotelLinks.map((l) => l.hotel_id);

  const [chefs, restaurants, hotels] = await Promise.all([
    chefIds.length
      ? select<{ display_name: string; business_name: string | null; home_city: string | null }>(
          'private_chefs_full', `select=display_name,business_name,home_city&id=${inList(chefIds)}`)
      : [],
    restaurantIds.length
      ? select<{ id: string; name: string; city_name: string | null; country_name: string | null }>(
          'restaurants_full', `select=id,name,city_name,country_name&id=${inList(restaurantIds)}`)
      : [],
    hotelIds.length
      ? select<{ id: string; name: string; city_name: string | null; country_name: string | null }>(
          'hotels_full', `select=id,name,city_name,country_name&id=${inList(hotelIds)}`)
      : [],
  ]);
  return {
    chefs: chefs.map((c) => ({ name: c.display_name, businessName: c.business_name, city: c.home_city })),
    restaurants: restaurants.map((r) => ({ id: r.id, name: r.name, city: r.city_name, country: r.country_name })),
    hotels: hotels.map((h) => ({ id: h.id, name: h.name, city: h.city_name, country: h.country_name })),
  };
}

/** Every restaurant mentioned in a published article, with those
 *  articles newest first: "In the news" on a restaurant's page. */
let mentionsCache: Promise<Map<string, NewsArticle[]>> | null = null;

export function loadRestaurantMentions(): Promise<Map<string, NewsArticle[]>> {
  mentionsCache ??= buildRestaurantMentions();
  return mentionsCache;
}

async function buildRestaurantMentions(): Promise<Map<string, NewsArticle[]>> {
  const [articles, links] = await Promise.all([
    loadArticles(),
    select<{ news_article_id: string; restaurant_id: string }>('news_article_restaurants', 'select=news_article_id,restaurant_id'),
  ]);
  const byId = new Map(articles.map((a) => [a.id, a]));
  const mentions = new Map<string, NewsArticle[]>();
  for (const link of links) {
    const article = byId.get(link.news_article_id);
    if (!article) continue;
    if (!mentions.has(link.restaurant_id)) mentions.set(link.restaurant_id, []);
    mentions.get(link.restaurant_id)!.push(article);
  }
  for (const list of mentions.values()) list.sort((a, b) => +b.publishedAt - +a.publishedAt);
  return mentions;
}

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/** "6 November 2026", the app's formatNewsDate, on the Amsterdam calendar. */
export function formatNewsDate(date: Date): string {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Amsterdam', day: 'numeric', month: 'numeric', year: 'numeric',
  }).formatToParts(date);
  const get = (t: string) => Number(parts.find((p) => p.type === t)!.value);
  return `${get('day')} ${MONTHS[get('month') - 1]} ${get('year')}`;
}

export const sectionLabel = (s: NewsSection) =>
  s === 'interview' ? 'Interview' : s === 'about' ? 'From the founder' : 'Story';

/** Rough reading time at 230 words a minute, never under one. */
export function readingMinutes(body: string): number {
  return Math.max(1, Math.round(body.split(/\s+/).filter(Boolean).length / 230));
}
