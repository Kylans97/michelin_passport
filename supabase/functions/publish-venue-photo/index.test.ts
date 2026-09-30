// Tests for the publish-venue-photo Edge Function's testable core
// (handleRequest). Hand-rolled fakes only, no mocking framework — same
// convention as notify-venue-claim/notify-venue-submission's own test
// files. The storage fake actually tracks bucket contents (a Set of
// "bucket:path" strings) rather than just recording calls, so
// list()-based verification exercises the real logic instead of a
// stubbed true/false — including simulating the exact "copy() reports
// success but the object never lands" failure mode this function is
// built not to trust.

import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import {
  destinationPathFor,
  handleRequest,
  type PublishPhotoAdminClient,
  type SubmissionRow,
} from './index.ts';

const SECRET = 'test-webhook-secret';

const VALID_SUBMISSION: SubmissionRow = {
  id: 'sub-1',
  status: 'pending',
  venue_type: 'restaurant',
  venue_id: 'restaurant-1',
  storage_path: 'restaurant/restaurant-1/user-1/1790632353731603_1673915327.jpg',
  replaces_photo_id: null,
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
  const defaultBody = { submission_id: VALID_SUBMISSION.id, reviewed_by: 'reviewer-1' };
  return new Request('http://localhost/publish-venue-photo', {
    method,
    headers,
    body: canHaveBody ? opts.rawBody ?? JSON.stringify(opts.body === undefined ? defaultBody : opts.body) : undefined,
  });
}

type CopyBehavior =
  | 'land' // copy succeeds and the object genuinely lands
  | 'silent-fail' // copy reports success but nothing actually lands (the bug this function distrusts)
  | 'error-but-already-there' // copy errors (e.g. "already exists"), but the object IS there (a retry)
  | 'error-and-absent'; // copy errors and nothing is there

function fakeAdmin(opts: {
  submission?: SubmissionRow | null;
  submissionError?: string;
  copyBehavior?: CopyBehavior;
  rpcError?: string;
  rpcData?: unknown;
  preExistingCatalogueContents?: string[]; // "bucket:path" entries present before the call
} = {}) {
  const catalogueContents = new Set<string>(opts.preExistingCatalogueContents ?? []);
  const copyCalls: { from: string; to: string; destinationBucket?: string }[] = [];
  const rpcCalls: { fn: string; params: Record<string, unknown> }[] = [];
  const listCalls: { bucket: string; path?: string }[] = [];

  function dirname(path: string): string {
    const idx = path.lastIndexOf('/');
    return idx === -1 ? '' : path.slice(0, idx);
  }
  function basename(path: string): string {
    const idx = path.lastIndexOf('/');
    return idx === -1 ? path : path.slice(idx + 1);
  }

  const admin: PublishPhotoAdminClient = {
    from(_table: string) {
      return {
        select(_columns: string) {
          return {
            eq(_column: string, _value: string) {
              return {
                maybeSingle: () => {
                  if (opts.submissionError) {
                    return Promise.resolve({ data: null, error: { message: opts.submissionError } });
                  }
                  return Promise.resolve({
                    data: (opts.submission === undefined ? VALID_SUBMISSION : opts.submission) as unknown as Record<
                      string,
                      unknown
                    > | null,
                    error: null,
                  });
                },
              };
            },
          };
        },
      };
    },
    rpc(fn: string, params: Record<string, unknown>) {
      rpcCalls.push({ fn, params });
      if (opts.rpcError) return Promise.resolve({ data: null, error: { message: opts.rpcError } });
      return Promise.resolve({ data: opts.rpcData ?? { published_id: 'pub-1' }, error: null });
    },
    storage: {
      from(bucket: string) {
        return {
          copy(fromPath: string, toPath: string, copyOpts?: { destinationBucket?: string }) {
            copyCalls.push({ from: fromPath, to: toPath, destinationBucket: copyOpts?.destinationBucket });
            const destBucket = copyOpts?.destinationBucket ?? bucket;
            const behavior = opts.copyBehavior ?? 'land';
            switch (behavior) {
              case 'land':
                catalogueContents.add(`${destBucket}:${toPath}`);
                return Promise.resolve({ data: { path: toPath }, error: null });
              case 'silent-fail':
                return Promise.resolve({ data: { path: toPath }, error: null });
              case 'error-but-already-there':
                catalogueContents.add(`${destBucket}:${toPath}`);
                return Promise.resolve({ data: null, error: { message: 'The resource already exists' } });
              case 'error-and-absent':
                return Promise.resolve({ data: null, error: { message: 'copy failed' } });
            }
          },
          list(path?: string) {
            listCalls.push({ bucket, path });
            const dir = path ?? '';
            const names = [...catalogueContents]
              .filter((entry) => entry.startsWith(`${bucket}:`))
              .map((entry) => entry.slice(bucket.length + 1))
              .filter((fullPath) => dirname(fullPath) === dir)
              .map((fullPath) => ({ name: basename(fullPath) }));
            return Promise.resolve({ data: names, error: null });
          },
        };
      },
    },
  };

  return { admin, copyCalls, rpcCalls, listCalls };
}

Deno.test('a non-POST method is rejected before checking the secret', async () => {
  const { admin, rpcCalls } = fakeAdmin();
  const res = await handleRequest(req({ method: 'GET' }), admin, SECRET);
  assertEquals(res.status, 405);
  assertEquals(rpcCalls.length, 0);
});

Deno.test('a missing x-webhook-secret header is rejected — no lookups, no copy, no RPC', async () => {
  const { admin, copyCalls, rpcCalls } = fakeAdmin();
  const res = await handleRequest(req({ secret: null }), admin, SECRET);
  assertEquals(res.status, 401);
  assertEquals(copyCalls.length, 0);
  assertEquals(rpcCalls.length, 0);
});

Deno.test('a wrong x-webhook-secret is rejected the same way as a missing one', async () => {
  const { admin } = fakeAdmin();
  const res = await handleRequest(req({ secret: 'wrong' }), admin, SECRET);
  assertEquals(res.status, 401);
});

Deno.test('an unconfigured expected secret (undefined) rejects every request, never falls open', async () => {
  const { admin } = fakeAdmin();
  const res = await handleRequest(req({ secret: SECRET }), admin, undefined);
  assertEquals(res.status, 401);
});

Deno.test('invalid JSON body is rejected with 400', async () => {
  const { admin } = fakeAdmin();
  const res = await handleRequest(req({ rawBody: 'not json' }), admin, SECRET);
  assertEquals(res.status, 400);
});

Deno.test('a missing submission_id or reviewed_by is rejected with 400', async () => {
  const { admin, copyCalls } = fakeAdmin();
  const res = await handleRequest(req({ body: { submission_id: 'sub-1' } }), admin, SECRET);
  assertEquals(res.status, 400);
  assertEquals(copyCalls.length, 0);
});

Deno.test('a submission lookup failure is reported, nothing attempted', async () => {
  const { admin, copyCalls, rpcCalls } = fakeAdmin({ submissionError: 'connection reset' });
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 502);
  assertEquals(copyCalls.length, 0);
  assertEquals(rpcCalls.length, 0);
});

Deno.test('a nonexistent submission id is reported as 404, nothing attempted', async () => {
  const { admin, copyCalls, rpcCalls } = fakeAdmin({ submission: null });
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 404);
  assertEquals(copyCalls.length, 0);
  assertEquals(rpcCalls.length, 0);
});

Deno.test('a submission that is not pending is refused before any copy is attempted — this is what makes calling it twice fail on the second call', async () => {
  const { admin, copyCalls, rpcCalls } = fakeAdmin({
    submission: { ...VALID_SUBMISSION, status: 'approved' },
  });
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 409);
  const body = await res.json();
  assertStringIncludes(body.error, 'not pending');
  assertEquals(copyCalls.length, 0);
  assertEquals(rpcCalls.length, 0);
});

Deno.test('destinationPathFor derives <venue_type>/<venue_id>/<filename> from the submission\'s own storage_path — never a position-based name', () => {
  const path = destinationPathFor(VALID_SUBMISSION);
  assertEquals(path, 'restaurant/restaurant-1/1790632353731603_1673915327.jpg');
});

Deno.test('a successful copy, verified, publishes via approve_venue_photo with the derived URL — never one supplied by a caller, since none exists', async () => {
  const { admin, copyCalls, rpcCalls } = fakeAdmin();
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 200);

  assertEquals(copyCalls.length, 1);
  assertEquals(copyCalls[0].from, VALID_SUBMISSION.storage_path);
  assertEquals(copyCalls[0].to, 'restaurant/restaurant-1/1790632353731603_1673915327.jpg');
  assertEquals(copyCalls[0].destinationBucket, 'catalogue-media');

  assertEquals(rpcCalls.length, 1);
  assertEquals(rpcCalls[0].fn, 'approve_venue_photo');
  assertEquals(rpcCalls[0].params.p_submission_id, 'sub-1');
  assertEquals(rpcCalls[0].params.p_reviewed_by, 'reviewer-1');
  assertEquals(
    rpcCalls[0].params.p_image_url,
    'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/' +
      'restaurant/restaurant-1/1790632353731603_1673915327.jpg',
  );
});

Deno.test('a copy() that reports success but never actually lands is NOT trusted — verification fails, the RPC is never called', async () => {
  const { admin, rpcCalls } = fakeAdmin({ copyBehavior: 'silent-fail' });
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 502);
  const body = await res.json();
  assertStringIncludes(body.error, 'could not be verified');
  assertEquals(rpcCalls.length, 0);
});

Deno.test('a copy() that errors and truly is absent fails clearly, the RPC is never called', async () => {
  const { admin, rpcCalls } = fakeAdmin({ copyBehavior: 'error-and-absent' });
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 502);
  const body = await res.json();
  assertStringIncludes(body.error, 'could not be verified');
  assertStringIncludes(body.error, 'copy failed');
  assertEquals(rpcCalls.length, 0);
});

Deno.test('a retry after a prior successful copy proceeds anyway: copy() erroring "already exists" is not fatal once verification confirms the object is really there', async () => {
  const { admin, rpcCalls } = fakeAdmin({ copyBehavior: 'error-but-already-there' });
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 200);
  assertEquals(rpcCalls.length, 1);
});

Deno.test('a leftover object from a genuinely prior successful call (no copy() call needed to re-verify it) still publishes', async () => {
  const { admin, rpcCalls } = fakeAdmin({
    copyBehavior: 'land',
    preExistingCatalogueContents: [
      'catalogue-media:restaurant/restaurant-1/1790632353731603_1673915327.jpg',
    ],
  });
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 200);
  assertEquals(rpcCalls.length, 1);
});

Deno.test('a verified copy but a failing RPC call reports the file is already copied and safe to retry, never a bare RPC error', async () => {
  const { admin, rpcCalls } = fakeAdmin({ rpcError: 'p_reviewed_by must be a real profiles.id, got reviewer-1' });
  const res = await handleRequest(req(), admin, SECRET);
  assertEquals(res.status, 502);
  const body = await res.json();
  assertStringIncludes(body.error, 'p_reviewed_by must be a real profiles.id');
  assertStringIncludes(body.error, 'safe to call this function again');
  assertEquals(rpcCalls.length, 1);
});

Deno.test('a hotel submission derives its destination under hotel/, and a private_chef submission under private_chef/ — the venue_type branch is real, not hardcoded to restaurant', () => {
  const hotelSubmission: SubmissionRow = {
    ...VALID_SUBMISSION,
    venue_type: 'hotel',
    venue_id: 'hotel-1',
    storage_path: 'hotel/hotel-1/user-1/999_888.jpg',
  };
  assertEquals(destinationPathFor(hotelSubmission), 'hotel/hotel-1/999_888.jpg');

  const chefSubmission: SubmissionRow = {
    ...VALID_SUBMISSION,
    venue_type: 'private_chef',
    venue_id: 'chef-1',
    storage_path: 'private_chef/chef-1/user-1/111_222.jpg',
  };
  assertEquals(destinationPathFor(chefSubmission), 'private_chef/chef-1/111_222.jpg');
});
