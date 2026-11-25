// Studio Web Analytics — mantelier.app's visitor numbers from Cloudflare
// Web Analytics, for Studio's Website tab. Written 2026-11-25.
//
// Product owner, 2026-11-25: "de web analytics staat aan op cloudflare,
// maar de taal is best technisch. Kunnen we wat we op cloudflare zien niet
// naar het dashboard halen van mij in mantelier studio?", and on the plan:
// "Ja helemaal goed en eens met het plan".
//
// Called by Studio (studio/studio.js) with the signed-in admin's own JWT.
// The first thing it does is call admin_studio_website_report as that
// user (20261101810000): the same guard as every Studio report, aal2 then
// is_admin(), so a password-only session or a member who isn't an admin
// gets nothing, and never reaches Cloudflare. That RPC also returns the
// website sign-in counts.
//
// The Cloudflare token lives only in this function's secrets:
//   CLOUDFLARE_ANALYTICS_TOKEN  Account > Account Analytics > Read
//   CLOUDFLARE_ACCOUNT_ID       the account mantelier.app's Pages project is in
//   SITE_HOSTS (optional)       comma separated, default mantelier.app,www.mantelier.app
// Without them the function still answers, with website_error
// 'not_configured', so Studio can say so.
//
// Cloudflare limits how long one query may span and how far back it
// keeps data (its settings node says how much). The period is split into
// windows that fit, newest first; what lies beyond the kept history is
// left out and reported as history_from, never filled in. Only totals
// leave this function: Web Analytics holds no person.

import { createClient } from 'jsr:@supabase/supabase-js@2';

export interface Window {
  from: Date;
  to: Date;
}

export interface WindowPlan {
  windows: Window[];
  /** Set when the period reaches further back than Cloudflare keeps. */
  historyFrom: Date | null;
}

export interface CloudflareLimits {
  /** Longest span of one query, in seconds. */
  maxDuration: number;
  /** How far back data can be asked for, in seconds. */
  notOlderThan: number;
}

export interface Row {
  label: string;
  value: number;
  path?: string;
}

export interface WebsiteNumbers {
  visits: number;
  page_views: number;
  app_store: number;
  /** Visits in the same number of days before; null when not kept. */
  visits_before: number | null;
  daily: { date: string; visits: number; page_views: number }[];
  pages: Row[];
  referrers: Row[];
  countries: Row[];
  devices: Row[];
  history_from: string | null;
}

export interface SignInNumbers {
  members_signed_in: number;
  sign_ins: number;
  members_signed_in_before: number;
}

export type AdminCheck =
  | { ok: true; signIns: SignInNumbers }
  | { ok: false; error: 'not_admin' | 'mfa_required' | 'failed'; message?: string };

/** Posts one GraphQL query to Cloudflare. */
export type Cloudflare = (query: string, variables: Record<string, unknown>) => Promise<GraphQLResult>;

export interface GraphQLResult {
  data?: unknown;
  errors?: { message: string }[] | null;
}

export interface Deps {
  checkAdmin: (jwt: string, days: number) => Promise<AdminCheck>;
  /** Null when the token or account id is not set. */
  cloudflare: Cloudflare | null;
  accountId: string;
  hosts: string[];
  now: () => Date;
}

export const APP_STORE_PATH = '/app-store';
const DAY = 86_400;
/** Keeps one Studio load well inside Cloudflare's 300 queries per 5 minutes. */
const MAX_WINDOWS = 24;
const TOP = 5;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

// ------------------------------------------------------------ windows

/** Splits [now - days, now] into windows Cloudflare accepts, newest first. */
export function planWindows(now: Date, days: number, limits: CloudflareLimits, maxWindows = MAX_WINDOWS): WindowPlan {
  const to = now.getTime();
  const wanted = to - days * DAY * 1000;
  // A minute's margin: "not older than" is checked when Cloudflare runs it.
  const oldest = to - (limits.notOlderThan - 60) * 1000;
  const step = Math.max(limits.maxDuration, 3600) * 1000;
  const windows: Window[] = [];
  let end = to;
  const start = Math.max(wanted, oldest);
  while (end > start && windows.length < maxWindows) {
    const from = Math.max(end - step, start);
    windows.push({ from: new Date(from), to: new Date(end) });
    end = from;
  }
  const reached = windows.length ? windows[windows.length - 1].from.getTime() : to;
  return { windows, historyFrom: reached > wanted ? new Date(reached) : null };
}

// ------------------------------------------------------------ labels

const REFERRERS: [RegExp, string][] = [
  [/(^|\.)google\.[a-z.]+$/, 'Google'],
  [/(^|\.)instagram\.com$/, 'Instagram'],
  [/(^|\.)facebook\.com$|(^|\.)fb\.me$/, 'Facebook'],
  [/(^|\.)whatsapp\.(com|net)$|^wa\.me$/, 'WhatsApp'],
  [/(^|\.)linkedin\.com$|^lnkd\.in$/, 'LinkedIn'],
  [/^t\.co$|(^|\.)twitter\.com$|(^|\.)x\.com$/, 'X'],
  [/(^|\.)bing\.com$/, 'Bing'],
  [/(^|\.)duckduckgo\.com$/, 'DuckDuckGo'],
  [/(^|\.)ecosia\.org$/, 'Ecosia'],
  [/(^|\.)yahoo\.com$/, 'Yahoo'],
  [/(^|\.)chatgpt\.com$|(^|\.)openai\.com$/, 'ChatGPT'],
  [/(^|\.)perplexity\.ai$/, 'Perplexity'],
  [/(^|\.)apple\.com$/, 'Apple'],
];

export const DIRECT = 'Typed in or bookmarked';

export function referrerLabel(host: string): string {
  const h = host.trim().toLowerCase().replace(/^www\./, '');
  if (!h) return DIRECT;
  for (const [pattern, label] of REFERRERS) if (pattern.test(h)) return label;
  return h;
}

const DEVICES: Record<string, string> = { mobile: 'Phone', desktop: 'Computer', tablet: 'Tablet' };

export function deviceLabel(type: string): string {
  return DEVICES[type.trim().toLowerCase()] ?? 'Other devices';
}

const regionNames = new Intl.DisplayNames(['en-GB'], { type: 'region' });

export function countryLabel(code: string): string {
  const c = code.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(c) || c === 'XX' || c === 'T1') return 'Unknown';
  try {
    return regionNames.of(c) ?? c;
  } catch {
    return c;
  }
}

const PAGES: Record<string, string> = {
  '/': 'Home',
  '/events': 'Events',
  '/guides': 'Guides',
  '/news': 'News',
  '/app': 'The app',
  '/i': 'An invitation from a friend',
  '/off-the-beaten-track': 'Off the beaten track',
  '/behind-the-pass': 'Behind the pass',
  '/privacy': 'Privacy policy',
  '/privacy.html': 'Privacy policy',
  '/terms': 'Terms',
  '/terms.html': 'Terms',
  '/support': 'Support',
  '/support.html': 'Support',
  '/account': 'Your account',
  '/account/sign-in': 'Sign in',
};

const SECTIONS: [string, string][] = [
  ['/events/', 'An event'],
  ['/news/', 'A news article'],
  ['/guides/', 'A guide'],
  ['/restaurants/', 'A restaurant'],
  ['/hotels/', 'A hotel'],
  ['/i/', 'An invitation from a friend'],
  ['/account/', 'Your account'],
];

export function normalisePath(path: string): string {
  const p = (path.split(/[?#]/)[0] || '/').replace(/\/+$/, '');
  return p === '' ? '/' : p;
}

export function pageLabel(path: string): string {
  const p = normalisePath(path);
  if (PAGES[p]) return PAGES[p];
  for (const [prefix, label] of SECTIONS) if (p.startsWith(prefix)) return label;
  return p;
}

// ------------------------------------------------------------ query

const FILTER_TYPE = 'AccountRumPageloadEventsAdaptiveGroupsFilter_InputObject';

export const SETTINGS_QUERY = `query Settings($account: string!) {
  viewer { accounts(filter: { accountTag: $account }) {
    settings { rumPageloadEventsAdaptiveGroups { enabled maxDuration notOlderThan } }
  } }
}`;

export const WINDOW_QUERY = `query Website($account: string!, $filter: ${FILTER_TYPE}!, $appStore: ${FILTER_TYPE}!) {
  viewer { accounts(filter: { accountTag: $account }) {
    total: rumPageloadEventsAdaptiveGroups(filter: $filter, limit: 1) { count sum { visits } }
    appStore: rumPageloadEventsAdaptiveGroups(filter: $appStore, limit: 1) { count }
    daily: rumPageloadEventsAdaptiveGroups(filter: $filter, limit: 1000, orderBy: [date_ASC]) { count sum { visits } dimensions { date } }
    pages: rumPageloadEventsAdaptiveGroups(filter: $filter, limit: 50, orderBy: [count_DESC]) { count dimensions { requestPath } }
    referrers: rumPageloadEventsAdaptiveGroups(filter: $filter, limit: 50, orderBy: [sum_visits_DESC]) { sum { visits } dimensions { refererHost } }
    countries: rumPageloadEventsAdaptiveGroups(filter: $filter, limit: 50, orderBy: [sum_visits_DESC]) { sum { visits } dimensions { countryName } }
    devices: rumPageloadEventsAdaptiveGroups(filter: $filter, limit: 10, orderBy: [sum_visits_DESC]) { sum { visits } dimensions { deviceType } }
  } }
}`;

export const TOTAL_QUERY = `query Before($account: string!, $filter: ${FILTER_TYPE}!) {
  viewer { accounts(filter: { accountTag: $account }) {
    total: rumPageloadEventsAdaptiveGroups(filter: $filter, limit: 1) { count sum { visits } }
  } }
}`;

/** Known bots left out, as the dashboard's "Exclude bots". */
export function windowFilter(w: Window, hosts: string[], path?: string): Record<string, unknown> {
  const and: Record<string, unknown>[] = [
    { datetime_geq: w.from.toISOString(), datetime_lt: w.to.toISOString() },
    { requestHost_in: hosts },
    { bot: 0 },
  ];
  // The site serves /app-store; the .html form is the same page.
  if (path) and.push({ requestPath_in: [path, `${path}.html`] });
  return { AND: and };
}

interface Group {
  count?: number;
  sum?: { visits?: number };
  dimensions?: Record<string, string>;
}

type Account = Record<string, Group[] | undefined>;

function account(result: GraphQLResult): Account {
  if (result.errors?.length) throw new Error(result.errors.map((e) => e.message).join('; '));
  const accounts = (result.data as { viewer?: { accounts?: Account[] } } | undefined)?.viewer?.accounts;
  if (!accounts?.length) throw new Error('no account in the answer');
  return accounts[0];
}

const views = (g: Group) => g.count ?? 0;
const visits = (g: Group) => g.sum?.visits ?? 0;

function add(map: Map<string, number>, key: string, value: number) {
  map.set(key, (map.get(key) ?? 0) + value);
}

/** The top rows, then everything else as one row, so the list adds up. */
export function topRows(map: Map<string, number>, total: number, otherLabel: string, paths?: Map<string, string>): Row[] {
  const rows = [...map.entries()]
    .filter(([, v]) => v > 0)
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, TOP)
    .map(([label, value]) => (paths?.has(label) ? { label, value, path: paths.get(label) } : { label, value }));
  const rest = total - rows.reduce((s, r) => s + r.value, 0);
  if (rest > 0) rows.push({ label: otherLabel, value: rest });
  return rows;
}

export async function readLimits(cf: Cloudflare, accountId: string): Promise<CloudflareLimits> {
  const a = account(await cf(SETTINGS_QUERY, { account: accountId })) as unknown as {
    settings?: { rumPageloadEventsAdaptiveGroups?: { enabled?: boolean; maxDuration?: number; notOlderThan?: number } };
  };
  const s = a.settings?.rumPageloadEventsAdaptiveGroups;
  if (!s || s.enabled === false || !s.maxDuration || !s.notOlderThan) {
    throw new Error('Web Analytics data is not available to this token');
  }
  return { maxDuration: s.maxDuration, notOlderThan: s.notOlderThan };
}

export async function readWebsite(
  cf: Cloudflare,
  accountId: string,
  hosts: string[],
  now: Date,
  days: number,
  limits: CloudflareLimits,
): Promise<WebsiteNumbers> {
  const plan = planWindows(now, days, limits);
  const answers = await Promise.all(plan.windows.map((w) =>
    cf(WINDOW_QUERY, {
      account: accountId,
      filter: windowFilter(w, hosts),
      appStore: windowFilter(w, hosts, APP_STORE_PATH),
    }).then(account)
  ));

  let totalVisits = 0, totalViews = 0, appStore = 0;
  const daily = new Map<string, { visits: number; page_views: number }>();
  const pages = new Map<string, number>();
  const pagePaths = new Map<string, string>();
  const referrers = new Map<string, number>();
  const countries = new Map<string, number>();
  const devices = new Map<string, number>();

  for (const a of answers) {
    for (const g of a.total ?? []) {
      totalVisits += visits(g);
      totalViews += views(g);
    }
    for (const g of a.appStore ?? []) appStore += views(g);
    for (const g of a.daily ?? []) {
      const date = g.dimensions?.date ?? '';
      const d = daily.get(date) ?? { visits: 0, page_views: 0 };
      d.visits += visits(g);
      d.page_views += views(g);
      daily.set(date, d);
    }
    for (const g of a.pages ?? []) {
      const path = normalisePath(g.dimensions?.requestPath ?? '/');
      if (path === APP_STORE_PATH || path === `${APP_STORE_PATH}.html`) continue; // counted as App Store, not a page read
      const label = pageLabel(path);
      add(pages, label, views(g));
      // A label that stands for one path shows it; a section does not.
      if (!pagePaths.has(label)) pagePaths.set(label, path);
      else if (pagePaths.get(label) !== path) pagePaths.set(label, '');
    }
    for (const g of a.referrers ?? []) add(referrers, referrerLabel(g.dimensions?.refererHost ?? ''), visits(g));
    for (const g of a.countries ?? []) add(countries, countryLabel(g.dimensions?.countryName ?? ''), visits(g));
    for (const g of a.devices ?? []) add(devices, deviceLabel(g.dimensions?.deviceType ?? ''), visits(g));
  }
  for (const [label, path] of [...pagePaths]) if (!path) pagePaths.delete(label);

  // Every day of the period that Cloudflare still keeps, zero where quiet.
  const firstDay = (plan.historyFrom ?? new Date(now.getTime() - days * DAY * 1000)).toISOString().slice(0, 10);
  const lastDay = now.toISOString().slice(0, 10);
  const series: WebsiteNumbers['daily'] = [];
  for (let t = Date.parse(`${firstDay}T00:00:00Z`); t <= Date.parse(`${lastDay}T00:00:00Z`); t += DAY * 1000) {
    const date = new Date(t).toISOString().slice(0, 10);
    const d = daily.get(date);
    series.push({ date, visits: d?.visits ?? 0, page_views: d?.page_views ?? 0 });
  }

  // The same number of days before, only when Cloudflare keeps all of it.
  let visitsBefore: number | null = null;
  const before = planWindows(new Date(now.getTime() - days * DAY * 1000), days, {
    ...limits,
    notOlderThan: limits.notOlderThan - days * DAY,
  });
  if (!plan.historyFrom && !before.historyFrom && before.windows.length) {
    try {
      const totals = await Promise.all(before.windows.map((w) =>
        cf(TOTAL_QUERY, { account: accountId, filter: windowFilter(w, hosts) }).then(account)
      ));
      visitsBefore = totals.reduce((s, a) => s + (a.total ?? []).reduce((t, g) => t + visits(g), 0), 0);
    } catch {
      visitsBefore = null; // a comparison is a nicety; the period stands without it
    }
  }

  const pageViewsShown = totalViews - appStore;
  return {
    visits: totalVisits,
    page_views: pageViewsShown,
    app_store: appStore,
    visits_before: visitsBefore,
    daily: series,
    pages: topRows(pages, pageViewsShown, 'Other pages', pagePaths),
    referrers: topRows(referrers, totalVisits, 'Other sites'),
    countries: topRows(countries, totalVisits, 'Other countries'),
    devices: topRows(devices, totalVisits, 'Other devices'),
    history_from: plan.historyFrom ? plan.historyFrom.toISOString() : null,
  };
}

// ------------------------------------------------------------ handler

let limitsCache: CloudflareLimits | null = null;
const answerCache = new Map<number, { at: number; body: WebsiteNumbers }>();
const CACHE_MS = 5 * 60 * 1000;

/** For tests: forget what a previous call learned. */
export function resetCaches() {
  limitsCache = null;
  answerCache.clear();
}

export async function handleRequest(req: Request, deps: Deps): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405);

  const jwt = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? '';
  if (!jwt) return jsonResponse({ error: 'not_signed_in' }, 401);

  let days = 30;
  try {
    const body = await req.json();
    if (Number.isFinite(body?.days)) days = Math.round(body.days);
  } catch { /* the default period */ }
  days = Math.min(Math.max(days, 1), 365);

  // Admin and two-step first; nothing below runs for anyone else.
  const check = await deps.checkAdmin(jwt, days);
  if (!check.ok) {
    if (check.error === 'failed') return jsonResponse({ error: 'failed', message: check.message }, 502);
    return jsonResponse({ error: check.error }, 403);
  }

  const now = deps.now();
  const base = {
    days,
    until: now.toISOString(),
    sign_ins: check.signIns,
  };

  if (!deps.cloudflare || !deps.accountId) {
    return jsonResponse({ ...base, website: null, website_error: 'not_configured' }, 200);
  }

  const cached = answerCache.get(days);
  if (cached && now.getTime() - cached.at < CACHE_MS) {
    return jsonResponse({ ...base, website: cached.body, website_error: null }, 200);
  }

  try {
    limitsCache ??= await readLimits(deps.cloudflare, deps.accountId);
    const website = await readWebsite(deps.cloudflare, deps.accountId, deps.hosts, now, days, limitsCache);
    answerCache.set(days, { at: now.getTime(), body: website });
    return jsonResponse({ ...base, website, website_error: null }, 200);
  } catch (e) {
    // Logged for us; Studio only says the numbers could not be fetched.
    console.error('studio-web-analytics: Cloudflare', e instanceof Error ? e.message : e);
    limitsCache = null;
    return jsonResponse({ ...base, website: null, website_error: 'unavailable' }, 200);
  }
}

// ------------------------------------------------------------ wiring

Deno.serve((req) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const token = Deno.env.get('CLOUDFLARE_ANALYTICS_TOKEN') ?? '';
  const accountId = Deno.env.get('CLOUDFLARE_ACCOUNT_ID') ?? '';
  const hosts = (Deno.env.get('SITE_HOSTS') ?? 'mantelier.app,www.mantelier.app')
    .split(',').map((h) => h.trim()).filter(Boolean);

  const checkAdmin = async (jwt: string, days: number): Promise<AdminCheck> => {
    const asCaller = createClient(supabaseUrl, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data, error } = await asCaller.rpc('admin_studio_website_report', { p_days: days });
    if (error) {
      if (error.message.includes('mfa_required')) return { ok: false, error: 'mfa_required' };
      if (error.message.includes('not_admin')) return { ok: false, error: 'not_admin' };
      return { ok: false, error: 'failed', message: error.message };
    }
    return { ok: true, signIns: data as SignInNumbers };
  };

  const cloudflare: Cloudflare | null = token
    ? async (query, variables) => {
      const res = await fetch('https://api.cloudflare.com/client/v4/graphql', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, variables }),
      });
      if (!res.ok) return { errors: [{ message: `HTTP ${res.status}` }] };
      return await res.json() as GraphQLResult;
    }
    : null;

  return handleRequest(req, { checkAdmin, cloudflare, accountId, hosts, now: () => new Date() });
});
