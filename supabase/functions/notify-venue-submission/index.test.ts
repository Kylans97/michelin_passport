// Tests for the notify-venue-submission Edge Function's testable core
// (handleRequest). Hand-rolled fakes only, no mocking framework — same
// convention as notify-venue-claim/index.test.ts.

import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import {
  type EmailMessage,
  handleRequest,
  type NotifySubmissionAdminClient,
  type SubmissionPayload,
} from './index.ts';

const SECRET = 'test-webhook-secret';

const VALID_ABOUT_PAYLOAD: SubmissionPayload = {
  submission_type: 'venue_about_submissions',
  row: {
    id: 'about-1',
    user_id: 'user-1',
    venue_type: 'restaurant',
    venue_id: 'restaurant-1',
    status: 'pending',
    submitted_at: '2026-09-29T13:00:00Z',
    about_text: 'A quiet dining room overlooking the canal, tasting menu only.',
  },
};

const VALID_PHOTO_PAYLOAD: SubmissionPayload = {
  submission_type: 'venue_photo_submissions',
  row: {
    id: 'photo-1',
    user_id: 'user-1',
    venue_type: 'private_chef',
    venue_id: 'chef-1',
    status: 'pending',
    submitted_at: '2026-09-29T13:00:00Z',
    storage_path: 'venue-photo-submissions/chef-1/abc123.jpg',
    replaces_photo_id: null,
  },
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
  return new Request('http://localhost/notify-venue-submission', {
    method,
    headers,
    body: canHaveBody
      ? opts.rawBody ?? JSON.stringify(opts.body === undefined ? VALID_ABOUT_PAYLOAD : opts.body)
      : undefined,
  });
}

interface FakeOptions {
  venue?: Record<string, unknown> | null;
  venueError?: string;
  profile?: { display_name: string | null; username: string | null } | null;
  profileError?: string;
  accountEmail?: string | null;
  userError?: string;
}

function fakeAdmin(opts: FakeOptions = {}): {
  admin: NotifySubmissionAdminClient;
  fromCalls: string[];
  getUserByIdCalls: string[];
} {
  const fromCalls: string[] = [];
  const getUserByIdCalls: string[] = [];

  const admin: NotifySubmissionAdminClient = {
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
                  // Any *_full venue view.
                  if (opts.venueError) {
                    return Promise.resolve({ data: null, error: { message: opts.venueError } });
                  }
                  return Promise.resolve({
                    data: opts.venue === undefined
                      ? { name: 'Flore Amsterdam', restaurant_code: 'FLR-NL-001' }
                      : opts.venue,
                    error: null,
                  });
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

Deno.test('an unknown submission_type is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(
    req({ body: { ...VALID_ABOUT_PAYLOAD, submission_type: 'something_else' } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('a row missing a required field is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const { id: _omit, ...incompleteRow } = VALID_ABOUT_PAYLOAD.row;
  const res = await handleRequest(
    req({ body: { submission_type: 'venue_about_submissions', row: incompleteRow } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('an about submission missing about_text is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const { about_text: _omit, ...rowWithoutText } = VALID_ABOUT_PAYLOAD.row;
  const res = await handleRequest(
    req({ body: { submission_type: 'venue_about_submissions', row: rowWithoutText } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('a photo submission missing storage_path is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const { storage_path: _omit, ...rowWithoutPath } = VALID_PHOTO_PAYLOAD.row;
  const res = await handleRequest(
    req({ body: { submission_type: 'venue_photo_submissions', row: rowWithoutPath } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('an unrecognized venue_type is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(
    req({
      body: { ...VALID_ABOUT_PAYLOAD, row: { ...VALID_ABOUT_PAYLOAD.row, venue_type: 'bogus' } },
    }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('a valid about submission sends one email containing the submitted text verbatim', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req({ body: VALID_ABOUT_PAYLOAD }), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);

  const email = calls[0];
  assertEquals(email.to, 'claimedvenues@mantelier.app');
  assertEquals(email.from, 'notifications@mantelier.app');
  assertStringIncludes(email.subject, 'about');
  assertStringIncludes(email.subject, 'Flore Amsterdam');
  assertStringIncludes(email.subject, 'FLR-NL-001');
  assertStringIncludes(email.text, 'Kylan');
  assertStringIncludes(
    email.text,
    'A quiet dining room overlooking the canal, tasting menu only.',
  );
  assertStringIncludes(
    email.html,
    'A quiet dining room overlooking the canal, tasting menu only.',
  );
});

Deno.test('a valid photo submission identifies it without linking the image, and notes the dashboard-only view', async () => {
  const { admin } = fakeAdmin({ venue: { display_name: 'Chef Amara', slug: 'chef-amara' } });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req({ body: VALID_PHOTO_PAYLOAD }), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);

  const email = calls[0];
  assertStringIncludes(email.subject, 'photo');
  assertStringIncludes(email.subject, 'Chef Amara');
  assertStringIncludes(email.subject, 'chef-amara');
  assertStringIncludes(email.text, 'photo-1');
  assertStringIncludes(email.text, 'venue-photo-submissions/chef-1/abc123.jpg');
  assertStringIncludes(email.text, 'must be viewed in the dashboard');
  assertStringIncludes(email.html, 'must be viewed in the dashboard');
  // Never a direct link/reference into the private bucket's public URL form.
  assertEquals(email.text.includes('createSignedUrl'), false);
  assertEquals(email.text.includes('storage/v1/object'), false);
});

Deno.test('a photo submission that replaces an existing photo names which one', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(
    req({
      body: {
        ...VALID_PHOTO_PAYLOAD,
        row: { ...VALID_PHOTO_PAYLOAD.row, replaces_photo_id: 'old-photo-9' },
      },
    }),
    admin,
    sendEmail,
    SECRET,
  );
  assertStringIncludes(calls[0].text, 'old-photo-9');
});

Deno.test('the submitted timestamp is rendered in Europe/Amsterdam, not UTC', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  // 2026-09-29T13:00:00Z is 15:00 in Amsterdam (CEST, UTC+2).
  await handleRequest(req({ body: VALID_ABOUT_PAYLOAD }), admin, sendEmail, SECRET);
  assertStringIncludes(calls[0].text, '15:00');
});

Deno.test('the dashboard link is a SQL Editor deep link scoped to the correct table and row id', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req({ body: VALID_PHOTO_PAYLOAD }), admin, sendEmail, SECRET);
  assertStringIncludes(calls[0].text, 'https://supabase.com/dashboard/project/');
  assertStringIncludes(calls[0].text, 'sql/new?content=');
  const decoded = decodeURIComponent(calls[0].text);
  assertStringIncludes(decoded, 'venue_photo_submissions');
  assertStringIncludes(decoded, "id = 'photo-1'");
});

Deno.test('a private_chef venue looks up display_name/slug, not name/restaurant_code', async () => {
  const { admin, fromCalls } = fakeAdmin({ venue: { display_name: 'Chef Amara', slug: 'chef-amara' } });
  const { sendEmail, calls } = fakeSendEmail();
  await handleRequest(req({ body: VALID_PHOTO_PAYLOAD }), admin, sendEmail, SECRET);
  assertEquals(fromCalls.includes('private_chefs_full'), true);
  assertStringIncludes(calls[0].subject, 'Chef Amara');
  assertStringIncludes(calls[0].subject, 'chef-amara');
});

Deno.test('a hotel venue looks up hotels_full', async () => {
  const { admin, fromCalls } = fakeAdmin({ venue: { name: 'Hotel Ivy', hotel_code: 'IVY-BE-001' } });
  const { sendEmail } = fakeSendEmail();
  await handleRequest(
    req({ body: { ...VALID_ABOUT_PAYLOAD, row: { ...VALID_ABOUT_PAYLOAD.row, venue_type: 'hotel' } } }),
    admin,
    sendEmail,
    SECRET,
  );
  assertEquals(fromCalls.includes('hotels_full'), true);
});

Deno.test('a venue lookup failure degrades gracefully instead of crashing — email still sends with a fallback label', async () => {
  const { admin } = fakeAdmin({ venue: null });
  const { sendEmail, calls } = fakeSendEmail();
  const res = await handleRequest(req({ body: VALID_ABOUT_PAYLOAD }), admin, sendEmail, SECRET);
  assertEquals(res.status, 200);
  assertEquals(calls.length, 1);
  assertStringIncludes(calls[0].subject, 'Unknown venue');
});

Deno.test('a profile with no display_name falls back to username, then to a generic label', async () => {
  const { admin: adminUsernameOnly } = fakeAdmin({
    profile: { display_name: null, username: 'kylan' },
  });
  const { sendEmail: sendA, calls: callsA } = fakeSendEmail();
  await handleRequest(req({ body: VALID_ABOUT_PAYLOAD }), adminUsernameOnly, sendA, SECRET);
  assertStringIncludes(callsA[0].text, 'kylan');

  const { admin: adminNoProfile } = fakeAdmin({ profile: null });
  const { sendEmail: sendB, calls: callsB } = fakeSendEmail();
  await handleRequest(req({ body: VALID_ABOUT_PAYLOAD }), adminNoProfile, sendB, SECRET);
  assertStringIncludes(callsB[0].text, 'Unknown submitter');
});

Deno.test('a Resend failure is reported as a 502 and never thrown as an unhandled error', async () => {
  const { admin } = fakeAdmin();
  const { sendEmail } = fakeSendEmail({ ok: false, error: 'Resend responded 500' });
  const res = await handleRequest(req({ body: VALID_ABOUT_PAYLOAD }), admin, sendEmail, SECRET);
  assertEquals(res.status, 502);
});
