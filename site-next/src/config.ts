// Site-wide switches, kept in one place so launch day is a short diff.

/** Was true until the site replaced site/ at mantelier.app (2026-11-21).
 *  When true it adds noindex to every page; public/_headers and
 *  public/robots.txt would need their noindex lines back as well. */
export const HIDDEN = false;

/** The App Store listing, without a country, so each visitor lands in
 *  their own store. Null would turn every "in the app" call to action
 *  back into a quiet "Coming to the App Store" label. */
export const APP_STORE_URL: string | null = 'https://apps.apple.com/app/mantelier/id6806217056';

export const CONTACT_EMAIL = 'hello@mantelier.app';

export const SECTIONS = [
  { slug: 'news', label: 'News' },
  { slug: 'guides', label: 'Guides' },
  { slug: 'behind-the-pass', label: 'Behind the pass' },
  { slug: 'events', label: 'Events' },
  { slug: 'trends', label: 'Trends' },
] as const;
