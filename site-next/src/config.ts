// Site-wide switches, kept in one place so launch day is a short diff.

/** Was true until the site replaced site/ at mantelier.app (2026-11-21).
 *  When true it adds noindex to every page; public/_headers and
 *  public/robots.txt would need their noindex lines back as well. */
export const HIDDEN = false;

/** The App Store listing, without a country, so each visitor lands in
 *  their own store. Null would turn every "in the app" call to action
 *  back into a quiet "Coming to the App Store" label. */
export const APP_STORE_URL: string | null = 'https://apps.apple.com/app/mantelier/id6806217056';

/** Where the site's App Store buttons point: our own /app-store, which
 *  sends the visitor straight on to APP_STORE_URL. Cloudflare Web Analytics
 *  counts page loads on this site, never clicks to another one, so this
 *  one hop is how Studio's "Went to the App Store" is counted (product
 *  owner, 2026-11-25). Null whenever APP_STORE_URL is. */
export const APP_STORE_LINK: string | null = APP_STORE_URL ? '/app-store' : null;

/** Cloudflare Web Analytics, installed by hand (product owner, 2026-11-25:
 *  "Yes, add the snippet"): Cloudflare's automatic setup never reached the
 *  pages this Pages project serves. The site token is public by design; it
 *  only lets a browser report a page view. Also in public/*.html and
 *  app-store.astro, which don't use this layout. */
export const CF_WEB_ANALYTICS_TOKEN = '44aaf7d826304cc1931b518e12e10c6f';

export const CONTACT_EMAIL = 'hello@mantelier.app';

/** Events first, the primary pillar. `nav: false` keeps a section's page
 *  but leaves it out of the header until it has content (Trends, review
 *  of 2026-11-21). */
export const SECTIONS = [
  { slug: 'events', label: 'Events', nav: true },
  { slug: 'guides', label: 'Guides', nav: true },
  { slug: 'news', label: 'News', nav: true },
  { slug: 'behind-the-pass', label: 'Behind the pass', nav: true },
  { slug: 'trends', label: 'Trends', nav: false },
] as const;
