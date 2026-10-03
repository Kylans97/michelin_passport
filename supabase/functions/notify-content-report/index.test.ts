// Tests for the notify-content-report Edge Function's testable core
// (handleRequest). Hand-rolled fakes only, no mocking framework — same
// convention as notify-venue-claim/index.test.ts.

import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { type EmailMessage, handleRequest, type NotifyContentReportAdminClient } from './index.ts';

const SECRET = 'test-webhook-secret';

const VALID_REPORT = {
  id: 'report-1',
  reporter_id: 'user-1',
  content_type: 'photo',
  content_id: 'photo-1',
  reason: 'inappropriate',
  details: 'This photo does not show the venue.',
  created_at: '2026-09-29T13:00:00Z',
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
  return new Request('http://localhost/notify-content-report', {
    method,
    headers,
    body: canHaveBody
      ? opts.rawBody ?? JSON.stringify(opts.body === undefined ? VALID_REPORT : opts.body)
      : undefined,
  });
}

interface FakeOptions {
  profile?: { display_name: string | null; username: string | null } | null;
  profileError?: string;
  accountEmail?: string | null;
  userError?: string;
  // Which of the three photo tables (if any) "knows" the reported photo
  // id, and the venue row its own `_full` view resolves to. Omitted
  // entirely (the default) means none of the three tables has a match —
  // the "could not locate this photo" fallback path.
  photoTable?: 'restaurant_photos' | 'hotel_photos' | 'private_chef_photos';
  photoFkColumn?: string;
  photoFkValue?: string;
  venueView?: string;
  venueRow?: Record<string, unknown>;
}

function fakeAdmin(opts: FakeOptions = {}): {
  admin: NotifyContentReportAdminClient;
  fromCalls: string[];
  getUserByIdCalls: string[];
} {
  const fromCalls: string[] = [];
  const getUserByIdCalls: string[] = [];

  const admin: NotifyContentReportAdminClient = {
    from(table: string) {
      fromCalls.push(table);
      return {
        select(_columns: string) {
          return {
            eq(_column: string, _value: string) {
              return {
                maybeSingle: () => {
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
                  if (table === opts.photoTable) {
                    return Promise.resolve({
                      data: { [opts.photoFkColumn!]: opts.photoFkValue },
                      error: null,
                    });
                  }
                  if (table === opts.venueView) {
                    return Promise.resolve({ data: opts.venueRow ?? null, error: null });
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
                email: opts.accountEmail === undefined ? 'kylan@example.com' : opts.accountEmail,
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

Deno.test('a body missing a required report field is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const { reason: _omit, ...incomplete } = VALID_REPORT;
  const res = await handleRequest(req({ body: incomplete }), admin, sendEmail, SECRET);
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('a valid photo report sends exactly one email with reporter, content, and reason details', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);

  const email = calls[0];
  assertEquals(email.to, 'claimedvenues@mantelier.app');
  assertEquals(email.from, 'notifications@mantelier.app');
  assertStringIncludes(email.subject, 'photo');
  assertStringIncludes(email.text, 'Kylan');
  assertStringIncludes(email.text, 'kylan@example.com');
  assertStringIncludes(email.text, 'photo-1');
  assertStringIncludes(email.text, 'inappropriate');
  assertStringIncludes(email.text, 'This photo does not show the venue.');
  assertStringIncludes(email.text, 'report-1');
});

Deno.test('generic over content_type: a rating report and a profile report both send correctly, no type-specific resolution attempted', async () => {
  for (const contentType of ['rating', 'profile', 'event']) {
    const { admin } = fakeAdmin();
    const { sendEmail, calls } = fakeSendEmail();
    const res = await handleRequest(
      req({ body: { ...VALID_REPORT, content_type: contentType } }),
      admin,
      sendEmail,
      SECRET,
    );
    assertEquals(res.status, 200);
    assertStringIncludes(calls[0].subject, contentType);
    assertStringIncludes(calls[0].text, `Content type: ${contentType}`);
  }
});

Deno.test('the dashboard link is a SQL Editor deep link scoped to this report id', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req(), admin, sendEmail, SECRET);
  assertStringIncludes(calls[0].text, 'https://supabase.com/dashboard/project/');
  assertStringIncludes(calls[0].text, 'sql/new?content=');
  assertStringIncludes(decodeURIComponent(calls[0].text), "content_reports where id = 'report-1'");
});

Deno.test('empty/null details render as an em dash, never the literal word "null"', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req({ body: { ...VALID_REPORT, details: null } }), admin, sendEmail, SECRET);
  assertStringIncludes(calls[0].text, '—');
  assertEquals(calls[0].text.includes('null'), false);
});

Deno.test('a reporter identity lookup failure degrades gracefully instead of crashing — email still sends with a fallback label', async () => {
  const { admin } = fakeAdmin({ profile: null, accountEmail: null });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);
  assertStringIncludes(calls[0].text, 'Unknown reporter');
  assertStringIncludes(calls[0].text, 'unknown');
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
  assertStringIncludes(callsB[0].text, 'Unknown reporter');
});

// ============================================================
// Photo context resolution — the "three places to look" fix. A photo
// report's content_id alone doesn't say which of three tables it lives
// in; these prove the email actually tells the admin which one, and
// names the venue, rather than leaving that lookup to do by hand.
// ============================================================

Deno.test('a restaurant photo report resolves and names the restaurant', async () => {
  const { admin } = fakeAdmin({
    photoTable: 'restaurant_photos',
    photoFkColumn: 'restaurant_id',
    photoFkValue: 'r1',
    venueView: 'restaurants_full',
    venueRow: { name: 'Flore', restaurant_code: 'FLR-NL-001' },
  });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertStringIncludes(calls[0].text, 'What: restaurant: Flore (FLR-NL-001)');
});

Deno.test('a hotel photo report resolves and names the hotel, not the restaurant table', async () => {
  const { admin } = fakeAdmin({
    photoTable: 'hotel_photos',
    photoFkColumn: 'hotel_id',
    photoFkValue: 'h1',
    venueView: 'hotels_full',
    venueRow: { name: 'Château Neercanne', hotel_code: 'CHN-NL-001' },
  });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertStringIncludes(calls[0].text, 'What: hotel: Château Neercanne (CHN-NL-001)');
});

Deno.test('a private chef photo report resolves display_name/slug, not name/code', async () => {
  const { admin } = fakeAdmin({
    photoTable: 'private_chef_photos',
    photoFkColumn: 'private_chef_id',
    photoFkValue: 'c1',
    venueView: 'private_chefs_full',
    venueRow: { display_name: 'Lucas', slug: 'lucas' },
  });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertStringIncludes(calls[0].text, 'What: private chef: Lucas (lucas)');
});

Deno.test('a photo id matching none of the three tables states that plainly, rather than a silent blank', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertStringIncludes(calls[0].text, 'Could not locate this photo');
});

Deno.test('a rating report never attempts photo-table resolution — no "What:" line at all', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(
    req({ body: { ...VALID_REPORT, content_type: 'rating' } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 200);
  assertEquals(calls[0].text.includes('What:'), false);
});

Deno.test('a Resend failure is reported as a 502 and never thrown as an unhandled error', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail } = fakeSendEmail({ ok: false, error: 'Resend responded 500' });
  const res = await handleRequest(req(), admin, sendEmail, SECRET);
  assertEquals(res.status, 502);
});
