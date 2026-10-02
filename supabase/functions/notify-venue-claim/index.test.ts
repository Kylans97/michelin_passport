// Tests for the notify-venue-claim Edge Function's testable core
// (handleRequest). Hand-rolled fakes only, no mocking framework — same
// convention as delete-account/index.test.ts. `handleRequest` accepts a
// NotifyClaimAdminClient (a narrow structural interface, not the full
// Supabase SDK) plus a SendEmail function, so these fakes are plain
// object/function literals satisfying only the operations actually used.

import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { type EmailMessage, handleRequest, type NotifyClaimAdminClient } from './index.ts';

const SECRET = 'test-webhook-secret';

const VALID_CLAIM = {
  id: 'claim-1',
  user_id: 'user-1',
  restaurant_id: 'restaurant-1',
  role: 'owner',
  business_email: 'owner@flore.example',
  phone: '+31 6 1234 5678',
  notes: 'I have run this restaurant since 2019.',
  requested_at: '2026-09-29T13:00:00Z',
};

function req(opts: {
  method?: string;
  body?: unknown;
  rawBody?: string;
  secret?: string | null;
} = {}): Request {
  const method = opts.method ?? 'POST';
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (opts.secret !== null) {
    headers.set('x-webhook-secret', opts.secret ?? SECRET);
  }
  const canHaveBody = method !== 'GET' && method !== 'HEAD';
  return new Request('http://localhost/notify-venue-claim', {
    method,
    headers,
    body: canHaveBody
      ? opts.rawBody ?? JSON.stringify(opts.body === undefined ? VALID_CLAIM : opts.body)
      : undefined,
  });
}

interface FakeOptions {
  venue?: Record<string, unknown> | null;
  venueTable?: string;
  venueError?: string;
  profile?: { display_name: string | null; username: string | null } | null;
  profileError?: string;
  accountEmail?: string | null;
  userError?: string;
}

function fakeAdmin(opts: FakeOptions = {}): {
  admin: NotifyClaimAdminClient;
  fromCalls: string[];
  getUserByIdCalls: string[];
} {
  const fromCalls: string[] = [];
  const getUserByIdCalls: string[] = [];
  const venueTable = opts.venueTable ?? 'restaurants_full';

  const admin: NotifyClaimAdminClient = {
    from(table: string) {
      fromCalls.push(table);
      return {
        select(_columns: string) {
          return {
            eq(_column: string, _value: string) {
              return {
                maybeSingle: () => {
                  if (table === venueTable) {
                    if (opts.venueError) {
                      return Promise.resolve({ data: null, error: { message: opts.venueError } });
                    }
                    return Promise.resolve({
                      data: opts.venue === undefined
                        ? { name: 'Flore Amsterdam', restaurant_code: 'FLR-NL-001' }
                        : opts.venue,
                      error: null,
                    });
                  }
                  if (table === 'profiles') {
                    if (opts.profileError) {
                      return Promise.resolve({ data: null, error: { message: opts.profileError } });
                    }
                    return Promise.resolve({
                      data: opts.profile === undefined
                        ? { display_name: 'Kylan', username: 'kylan' }
                        : opts.profile,
                      error: null,
                    });
                  }
                  return Promise.resolve({ data: null, error: null });
                },
              };
            },
          };
        },
      };
    },
    auth: {
      admin: {
        getUserById(id: string) {
          getUserByIdCalls.push(id);
          if (opts.userError) {
            return Promise.resolve({
              data: { user: null },
              error: { message: opts.userError },
            });
          }
          return Promise.resolve({
            data: {
              user: {
                email: opts.accountEmail === undefined ? 'owner@flore.example' : opts.accountEmail,
              },
            },
            error: null,
          });
        },
      },
    },
  };

  return { admin, fromCalls, getUserByIdCalls };
}

function fakeSendEmail(opts: { ok?: boolean; error?: string } = {}): {
  sendEmail: (message: EmailMessage) => Promise<{ ok: boolean; error?: string }>;
  calls: EmailMessage[];
} {
  const calls: EmailMessage[] = [];
  return {
    calls,
    sendEmail: (message: EmailMessage) => {
      calls.push(message);
      return Promise.resolve(
        opts.ok === false ? { ok: false, error: opts.error ?? 'send failed' } : { ok: true },
      );
    },
  };
}

Deno.test('a non-POST method is rejected before checking the secret', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req({ method: 'GET' }), admin, sendEmail, SECRET);
  assertEquals(res.status, 405);
  assertEquals(calls.length, 0);
});

Deno.test('a missing x-webhook-secret header is rejected — no lookups, no email sent', async () => {
  const { admin, fromCalls, getUserByIdCalls } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req({ secret: null }), admin, sendEmail, SECRET);
  assertEquals(res.status, 401);
  assertEquals(fromCalls.length, 0);
  assertEquals(getUserByIdCalls.length, 0);
  assertEquals(calls.length, 0);
});

Deno.test('a wrong x-webhook-secret is rejected the same way as a missing one', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req({ secret: 'wrong' }), admin, sendEmail, SECRET);
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test('an unconfigured expected secret (undefined) rejects every request, never falls open', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req({ secret: SECRET }), admin, sendEmail, undefined);
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test('invalid JSON body is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req({ rawBody: 'not json' }), admin, sendEmail, SECRET);
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('a body missing a required claim field is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const { business_email: _omit, ...incomplete } = VALID_CLAIM;
  const res = await handleRequest(req({ body: incomplete }), admin, sendEmail, SECRET);
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('a valid claim sends exactly one email with venue, claimant, and claim details', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);

  const email = calls[0];
  assertEquals(email.to, 'claimedvenues@mantelier.app');
  assertEquals(email.from, 'notifications@mantelier.app');
  assertStringIncludes(email.subject, 'Flore Amsterdam');
  assertStringIncludes(email.subject, 'FLR-NL-001');
  assertStringIncludes(email.text, 'Kylan');
  assertStringIncludes(email.text, 'owner@flore.example');
  assertStringIncludes(email.text, 'owner');
  assertStringIncludes(email.text, '+31 6 1234 5678');
  assertStringIncludes(email.text, 'I have run this restaurant since 2019.');
  assertStringIncludes(email.text, 'claim-1');
  assertStringIncludes(email.html, 'Flore Amsterdam');
});

Deno.test('the submitted timestamp is rendered in Europe/Amsterdam, not UTC', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  // 2026-09-29T13:00:00Z is 15:00 in Amsterdam (CEST, UTC+2) — proves the
  // formatter isn't just echoing the raw UTC string.
  await handleRequest(req(), admin, sendEmail, SECRET);
  assertStringIncludes(calls[0].text, '15:00');
});

Deno.test('the dashboard link is a SQL Editor deep link scoped to this claim id', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req(), admin, sendEmail, SECRET);
  assertStringIncludes(calls[0].text, 'https://supabase.com/dashboard/project/');
  assertStringIncludes(calls[0].text, 'sql/new?content=');
  // The claim id must appear somewhere in the (URL-encoded) query, or the
  // link doesn't actually point at the row this email is about.
  assertStringIncludes(decodeURIComponent(calls[0].text), "id = 'claim-1'");
});

Deno.test('a business email on a different domain than the account email is flagged in the body', async () => {
  const { admin } = fakeAdmin({ accountEmail: 'kylan@personal.example' });
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req(), admin, sendEmail, SECRET); // business_email is @flore.example
  assertStringIncludes(calls[0].text, 'Domain mismatch');
  assertStringIncludes(calls[0].text, 'flore.example');
  assertStringIncludes(calls[0].text, 'personal.example');
  assertStringIncludes(calls[0].html, 'Domain mismatch');
});

Deno.test('a business email on the SAME domain as the account email is not flagged', async () => {
  const { admin } = fakeAdmin({ accountEmail: 'owner@flore.example' });
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(calls[0].text.includes('Domain mismatch'), false);
  assertEquals(calls[0].html.includes('Domain mismatch'), false);
});

Deno.test('an unresolvable account email never falsely flags a mismatch', async () => {
  const { admin } = fakeAdmin({ accountEmail: null });
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(calls[0].text.includes('Domain mismatch'), false);
  assertStringIncludes(calls[0].text, 'unknown');
});

Deno.test('empty notes render as an em dash, never the literal word "null"', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req({ body: { ...VALID_CLAIM, notes: null } }), admin, sendEmail, SECRET);
  assertStringIncludes(calls[0].text, '—');
  assertEquals(calls[0].text.includes('null'), false);
});

Deno.test('a venue lookup failure degrades gracefully instead of crashing — email still sends with a fallback label', async () => {
  const { admin } = fakeAdmin({ venue: null });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);
  assertStringIncludes(calls[0].subject, 'Unknown venue');
});

Deno.test('a profile with no display_name falls back to username, then to a generic label', async () => {
  const { admin: adminUsernameOnly } = fakeAdmin({
    profile: { display_name: null, username: 'kylan' },
  });
  const { sendEmail: sendA, calls: callsA } = fakeSendEmail();
  await handleRequest(req(), adminUsernameOnly, sendA, SECRET);
  assertStringIncludes(callsA[0].text, 'kylan');

  const { admin: adminNoProfile } = fakeAdmin({ profile: null });
  const { sendEmail: sendB, calls: callsB } = fakeSendEmail();
  await handleRequest(req(), adminNoProfile, sendB, SECRET);
  assertStringIncludes(callsB[0].text, 'Unknown claimant');
});

Deno.test('a Resend failure is reported as a 502 and never thrown as an unhandled error', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail } = fakeSendEmail({ ok: false, error: 'Resend responded 500' });
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 502);
});

// ============================================================
// Genericization (20261007120000_genericize_venue_claim_admin_email_and_
// pending_indexes.sql): the trigger now sends an enveloped
// {claim_type, row} body for all three claims tables, and this function
// must render a correct email for each — not just the restaurant case
// above, which was the only one with real production data behind it
// before this change.
// ============================================================

const HOTEL_CLAIM = {
  id: 'claim-hotel-1',
  user_id: 'user-2',
  hotel_id: 'hotel-1',
  role: 'manager',
  business_email: 'manager@chateau.example',
  phone: '+31 6 9876 5432',
  notes: null,
  requested_at: '2026-09-29T13:00:00Z',
};

const PRIVATE_CHEF_CLAIM = {
  id: 'claim-chef-1',
  user_id: 'user-3',
  private_chef_id: 'chef-1',
  role: 'chef',
  business_email: 'lucas@lucascooks.example',
  phone: '+31 6 1111 2222',
  notes: 'This is my own profile.',
  requested_at: '2026-09-29T13:00:00Z',
};

Deno.test('an enveloped hotel claim queries hotels_full and renders a correct email', async () => {
  const { admin, fromCalls } = fakeAdmin({
    venueTable: 'hotels_full',
    venue: { name: 'Château Neercanne', hotel_code: 'CHN-NL-001' },
  });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(
    req({ body: { claim_type: 'claims_hotels', row: HOTEL_CLAIM } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);
  assertEquals(fromCalls.includes('hotels_full'), true);

  const email = calls[0];
  assertStringIncludes(email.subject, 'hotel claim');
  assertStringIncludes(email.subject, 'Château Neercanne');
  assertStringIncludes(email.subject, 'CHN-NL-001');
  assertStringIncludes(email.text, 'manager@chateau.example');
  assertStringIncludes(decodeURIComponent(email.text), 'claims_hotels');
  assertStringIncludes(decodeURIComponent(email.text), "id = 'claim-hotel-1'");
});

Deno.test('an enveloped private-chef claim queries private_chefs_full and renders display_name/slug, not name/code', async () => {
  const { admin, fromCalls } = fakeAdmin({
    venueTable: 'private_chefs_full',
    venue: { display_name: 'Lucas', slug: 'lucas' },
  });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(
    req({ body: { claim_type: 'claims_private_chefs', row: PRIVATE_CHEF_CLAIM } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);
  assertEquals(fromCalls.includes('private_chefs_full'), true);

  const email = calls[0];
  assertStringIncludes(email.subject, 'private chef claim');
  assertStringIncludes(email.subject, 'Lucas');
  assertStringIncludes(email.subject, 'lucas');
  assertStringIncludes(email.text, 'lucas@lucascooks.example');
  assertStringIncludes(decodeURIComponent(email.text), 'claims_private_chefs');
});

Deno.test('a venue lookup failure degrades gracefully for a hotel claim too', async () => {
  const { admin } = fakeAdmin({ venueTable: 'hotels_full', venue: null });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(
    req({ body: { claim_type: 'claims_hotels', row: HOTEL_CLAIM } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 200);
  assertStringIncludes(calls[0].subject, 'Unknown venue');
});

Deno.test('an unknown claim_type is rejected with 400 before any lookup runs', async () => {
  const { admin, fromCalls } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(
    req({ body: { claim_type: 'claims_wineries', row: HOTEL_CLAIM } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 400);
  assertEquals(fromCalls.length, 0);
  assertEquals(calls.length, 0);
});

Deno.test('a legacy un-enveloped restaurant payload (pre-genericization trigger) is still accepted', async () => {
  // This is VALID_CLAIM itself — a bare row, no {claim_type, row} wrapper
  // — proving the dual-payload tolerance window actually works, not just
  // that the new enveloped shape works. Every test above this section
  // already exercises this path implicitly; this test names it so the
  // tolerance isn't only incidentally covered.
  const { admin, fromCalls } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertEquals(fromCalls.includes('restaurants_full'), true);
  assertStringIncludes(calls[0].subject, 'restaurant claim');
});
