// Tests for studio-web-analytics: the admin guard, the Cloudflare windows,
// the plain labels and the shape Studio reads. Hand-rolled fakes only, as
// for the other functions; nothing here reaches Cloudflare or Supabase.

import { assert, assertEquals } from 'jsr:@std/assert@1';
import {
  type AdminCheck,
  APP_STORE_PATH,
  type Cloudflare,
  countryLabel,
  type Deps,
  deviceLabel,
  DIRECT,
  handleRequest,
  pageLabel,
  planWindows,
  referrerLabel,
  resetCaches,
  SETTINGS_QUERY,
  TOTAL_QUERY,
  WINDOW_QUERY,
} from './index.ts';

const NOW = new Date('2026-11-25T12:00:00Z');
const DAY = 86_400;
const SIGN_INS = { members_signed_in: 41, sign_ins: 58, members_signed_in_before: 30 };
const ADMIN: AdminCheck = { ok: true, signIns: SIGN_INS };

function req(body: unknown = { days: 30 }, jwt: string | null = 'jwt', method = 'POST'): Request {
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (jwt) headers.set('Authorization', `Bearer ${jwt}`);
  return new Request('http://localhost/studio-web-analytics', {
    method,
    headers,
    body: method === 'POST' ? JSON.stringify(body) : undefined,
  });
}

interface Call {
  query: string;
  variables: Record<string, unknown>;
}

/** A Cloudflare that keeps [notOlderThan] days and spans [maxDays] per query. */
function fakeCloudflare(opts: { maxDays?: number; keepDays?: number; fail?: boolean } = {}) {
  const calls: Call[] = [];
  const cf: Cloudflare = (query, variables) => {
    calls.push({ query, variables });
    if (opts.fail) return Promise.resolve({ errors: [{ message: 'unknown field bot' }] });
    if (query === SETTINGS_QUERY) {
      return Promise.resolve({
        data: { viewer: { accounts: [{ settings: { rumPageloadEventsAdaptiveGroups: {
          enabled: true,
          maxDuration: (opts.maxDays ?? 31) * DAY,
          notOlderThan: (opts.keepDays ?? 183) * DAY,
        } } }] } },
      });
    }
    if (query === TOTAL_QUERY) {
      return Promise.resolve({ data: { viewer: { accounts: [{ total: [{ count: 300, sum: { visits: 100 } }] }] } } });
    }
    assertEquals(query, WINDOW_QUERY);
    return Promise.resolve({
      data: { viewer: { accounts: [{
        total: [{ count: 400, sum: { visits: 120 } }],
        appStore: [{ count: 10 }],
        daily: [
          { count: 150, sum: { visits: 50 }, dimensions: { date: '2026-11-24' } },
          { count: 250, sum: { visits: 70 }, dimensions: { date: '2026-11-25' } },
        ],
        pages: [
          { count: 200, dimensions: { requestPath: '/' } },
          { count: 80, dimensions: { requestPath: '/events/' } },
          { count: 30, dimensions: { requestPath: '/events/four-hands-at-de-librije' } },
          { count: 20, dimensions: { requestPath: '/events/gala-in-ghent' } },
          { count: 10, dimensions: { requestPath: APP_STORE_PATH } },
          { count: 60, dimensions: { requestPath: '/guides' } },
        ],
        referrers: [
          { sum: { visits: 50 }, dimensions: { refererHost: '' } },
          { sum: { visits: 30 }, dimensions: { refererHost: 'www.google.nl' } },
          { sum: { visits: 10 }, dimensions: { refererHost: 'www.google.com' } },
          { sum: { visits: 20 }, dimensions: { refererHost: 'l.instagram.com' } },
          { sum: { visits: 0 }, dimensions: { refererHost: 'mantelier.app' } },
        ],
        countries: [
          { sum: { visits: 90 }, dimensions: { countryName: 'NL' } },
          { sum: { visits: 30 }, dimensions: { countryName: 'BE' } },
        ],
        devices: [
          { sum: { visits: 80 }, dimensions: { deviceType: 'mobile' } },
          { sum: { visits: 40 }, dimensions: { deviceType: 'desktop' } },
        ],
      }] } },
    });
  };
  return { calls, cf };
}

function deps(over: Partial<Deps> = {}): Deps {
  return {
    checkAdmin: () => Promise.resolve(ADMIN),
    cloudflare: fakeCloudflare().cf,
    accountId: 'acc',
    hosts: ['mantelier.app'],
    now: () => NOW,
    ...over,
  };
}

// ---------------------------------------------------------------- guard

Deno.test('OPTIONS answers CORS without checking anyone', async () => {
  resetCaches();
  let checked = false;
  const res = await handleRequest(req({}, null, 'OPTIONS'), deps({ checkAdmin: () => { checked = true; return Promise.resolve(ADMIN); } }));
  assertEquals(res.status, 200);
  assertEquals(checked, false);
});

Deno.test('no JWT is refused before anything else', async () => {
  resetCaches();
  const { calls, cf } = fakeCloudflare();
  const res = await handleRequest(req({}, null), deps({ cloudflare: cf }));
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test('a member who is not an admin never reaches Cloudflare', async () => {
  resetCaches();
  const { calls, cf } = fakeCloudflare();
  const res = await handleRequest(req(), deps({ cloudflare: cf, checkAdmin: () => Promise.resolve({ ok: false, error: 'not_admin' }) }));
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error, 'not_admin');
  assertEquals(calls.length, 0);
});

Deno.test('an admin without two-step gets mfa_required and nothing else', async () => {
  resetCaches();
  const { calls, cf } = fakeCloudflare();
  const res = await handleRequest(req(), deps({ cloudflare: cf, checkAdmin: () => Promise.resolve({ ok: false, error: 'mfa_required' }) }));
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error, 'mfa_required');
  assertEquals(calls.length, 0);
});

Deno.test('the period is clamped to 1..365 and passed to the admin check', async () => {
  resetCaches();
  const seen: number[] = [];
  const check = (_: string, days: number) => { seen.push(days); return Promise.resolve(ADMIN); };
  await handleRequest(req({ days: 9999 }), deps({ checkAdmin: check, cloudflare: null }));
  await handleRequest(req({ days: -4 }), deps({ checkAdmin: check, cloudflare: null }));
  await handleRequest(req('nonsense'), deps({ checkAdmin: check, cloudflare: null }));
  assertEquals(seen, [365, 1, 30]);
});

// ---------------------------------------------------------------- answers

Deno.test('without the token Studio still gets the sign-ins and is told why', async () => {
  resetCaches();
  const res = await handleRequest(req(), deps({ cloudflare: null }));
  const body = await res.json();
  assertEquals(res.status, 200);
  assertEquals(body.website, null);
  assertEquals(body.website_error, 'not_configured');
  assertEquals(body.sign_ins, SIGN_INS);
});

Deno.test('a Cloudflare error is unavailable, never a made-up number', async () => {
  resetCaches();
  const res = await handleRequest(req(), deps({ cloudflare: fakeCloudflare({ fail: true }).cf }));
  const body = await res.json();
  assertEquals(body.website, null);
  assertEquals(body.website_error, 'unavailable');
  assertEquals(body.sign_ins, SIGN_INS);
});

Deno.test('one window: totals, App Store taps and plain labels', async () => {
  resetCaches();
  const { calls, cf } = fakeCloudflare();
  const body = await (await handleRequest(req({ days: 30 }), deps({ cloudflare: cf }))).json();
  const w = body.website;
  assertEquals(w.visits, 120);
  assertEquals(w.app_store, 10);
  assertEquals(w.page_views, 390, 'the App Store hop is not a page read');
  assertEquals(w.visits_before, 100);
  assertEquals(w.history_from, null);

  // Pages: App Store left out, event pages grouped as one row, the rest adds up.
  assertEquals(w.pages[0], { label: 'Home', value: 200, path: '/' });
  assertEquals(w.pages[1], { label: 'Events', value: 80, path: '/events' });
  assertEquals(w.pages[2], { label: 'Guides', value: 60, path: '/guides' });
  assertEquals(w.pages[3], { label: 'An event', value: 50 });
  assert(!w.pages.some((p: { label: string }) => p.label.includes('app-store')));
  assertEquals(w.pages.reduce((s: number, p: { value: number }) => s + p.value, 0), 390);

  // Referrers: one Google, no zero rows, direct in plain words.
  assertEquals(w.referrers[0], { label: DIRECT, value: 50 });
  assertEquals(w.referrers[1], { label: 'Google', value: 40 });
  assertEquals(w.referrers[2], { label: 'Instagram', value: 20 });
  assertEquals(w.referrers[3], { label: 'Other sites', value: 10 });

  assertEquals(w.countries.map((c: { label: string }) => c.label), ['Netherlands', 'Belgium']);
  assertEquals(w.devices, [{ label: 'Phone', value: 80 }, { label: 'Computer', value: 40 }]);

  // Daily: every day of the period, zero where quiet.
  assertEquals(w.daily.length, 31);
  assertEquals(w.daily.at(-1), { date: '2026-11-25', visits: 70, page_views: 250 });
  assertEquals(w.daily[0].visits, 0);

  // The filter Cloudflare got: host, bots out, and the App Store path.
  const win = calls.find((c) => c.query === WINDOW_QUERY)!;
  assertEquals(JSON.stringify(win.variables.filter).includes('"requestHost_in":["mantelier.app"]'), true);
  assertEquals(JSON.stringify(win.variables.filter).includes('"bot":0'), true);
  assertEquals(JSON.stringify(win.variables.appStore).includes(`"requestPath_in":["${APP_STORE_PATH}","${APP_STORE_PATH}.html"]`), true);
});

Deno.test('a second load within five minutes is served from memory', async () => {
  resetCaches();
  const { calls, cf } = fakeCloudflare();
  await handleRequest(req(), deps({ cloudflare: cf }));
  const first = calls.length;
  await handleRequest(req(), deps({ cloudflare: cf }));
  assertEquals(calls.length, first);
});

Deno.test('the admin check runs even when the answer is cached', async () => {
  resetCaches();
  const { cf } = fakeCloudflare();
  await handleRequest(req(), deps({ cloudflare: cf }));
  const res = await handleRequest(req(), deps({ cloudflare: cf, checkAdmin: () => Promise.resolve({ ok: false, error: 'not_admin' }) }));
  assertEquals(res.status, 403);
});

Deno.test('history Cloudflare no longer keeps is reported, not filled in', async () => {
  resetCaches();
  const { calls, cf } = fakeCloudflare({ maxDays: 31, keepDays: 183 });
  const body = await (await handleRequest(req({ days: 365 }), deps({ cloudflare: cf }))).json();
  const w = body.website;
  assert(w.history_from, 'history_from is set');
  assert(Date.parse(w.history_from) >= NOW.getTime() - 183 * DAY * 1000);
  assertEquals(w.visits_before, null, 'no comparison with a period Cloudflare does not keep');
  assertEquals(calls.filter((c) => c.query === TOTAL_QUERY).length, 0);
  assert(w.daily.length <= 184);
});

// ---------------------------------------------------------------- windows

Deno.test('windows cover the period exactly, newest first, within the span', () => {
  const plan = planWindows(NOW, 90, { maxDuration: 31 * DAY, notOlderThan: 183 * DAY });
  assertEquals(plan.historyFrom, null);
  assertEquals(plan.windows.length, 3);
  assertEquals(plan.windows[0].to.getTime(), NOW.getTime());
  assertEquals(plan.windows.at(-1)!.from.getTime(), NOW.getTime() - 90 * DAY * 1000);
  for (let i = 1; i < plan.windows.length; i++) {
    assertEquals(plan.windows[i].to.getTime(), plan.windows[i - 1].from.getTime(), 'no gap, no overlap');
  }
  for (const w of plan.windows) assert(w.to.getTime() - w.from.getTime() <= 31 * DAY * 1000);
});

Deno.test('a short span is capped so one load stays within the rate limit', () => {
  const plan = planWindows(NOW, 365, { maxDuration: DAY, notOlderThan: 400 * DAY });
  assertEquals(plan.windows.length, 24);
  assert(plan.historyFrom, 'what the cap leaves out is said, not hidden');
});

// ---------------------------------------------------------------- labels

Deno.test('labels in plain words', () => {
  assertEquals(referrerLabel(''), DIRECT);
  assertEquals(referrerLabel('www.google.co.uk'), 'Google');
  assertEquals(referrerLabel('lm.facebook.com'), 'Facebook');
  assertEquals(referrerLabel('t.co'), 'X');
  assertEquals(referrerLabel('www.lekkerland.nl'), 'lekkerland.nl');
  assertEquals(deviceLabel('mobile'), 'Phone');
  assertEquals(deviceLabel('desktop'), 'Computer');
  assertEquals(deviceLabel('smarttv'), 'Other devices');
  assertEquals(countryLabel('NL'), 'Netherlands');
  assertEquals(countryLabel('XX'), 'Unknown');
  assertEquals(countryLabel(''), 'Unknown');
  assertEquals(pageLabel('/'), 'Home');
  assertEquals(pageLabel('/events/'), 'Events');
  assertEquals(pageLabel('/news/a-new-season?ref=ig'), 'A news article');
  assertEquals(pageLabel('/something-new'), '/something-new');
});
