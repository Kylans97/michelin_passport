// Site-wide switches, kept in one place so launch day is a short diff.

/** True until the site replaces site/ at mantelier.app. Adds noindex to
 *  every page; public/_headers and public/robots.txt say the same. */
export const HIDDEN = true;

/** The App Store listing. Null until the app is public: every "in the
 *  app" call to action then reads "Coming to the App Store" instead of
 *  linking anywhere. */
export const APP_STORE_URL: string | null = null;

export const CONTACT_EMAIL = 'hello@mantelier.app';

export const SECTIONS = [
  { slug: 'news', label: 'News' },
  { slug: 'guides', label: 'Guides' },
  { slug: 'behind-the-pass', label: 'Behind the pass' },
  { slug: 'events', label: 'Events' },
  { slug: 'trends', label: 'Trends' },
] as const;
