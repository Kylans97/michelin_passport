// Tests for the delete-account Edge Function's testable core
// (handleRequest). Hand-rolled fakes only, no mocking framework — the
// same convention the Flutter side of this codebase uses throughout.
// `handleRequest` accepts a DeletionAdminClient (a narrow structural
// interface, not the full Supabase SDK), so these fakes are plain object
// literals satisfying only the operations actually used.

import { assertEquals } from 'jsr:@std/assert@1';
import { handleRequest, type DeletionAdminClient } from './index.ts';

function req(opts: { method?: string; authorization?: string } = {}): Request {
  const headers = new Headers();
  if (opts.authorization !== undefined) {
    headers.set('Authorization', opts.authorization);
  }
  return new Request('http://localhost/delete-account', {
    method: opts.method ?? 'POST',
    headers,
  });
}

interface FakeOptions {
  validUserId?: string | null;
  getUserError?: string;
  // Keyed by bucket, then by list() prefix — lets a test give
  // `visit-photos` and `profile-photos` independently different (or
  // identically empty) contents.
  storageEntries?: Record<string, Record<string, Array<{ id: string | null; name: string }>>>;
  // Per-bucket list()/remove() failure — lets a test prove EITHER bucket
  // independently blocks deletion, not just the first one checked.
  storageListError?: Partial<Record<string, string>>;
  storageRemoveError?: Partial<Record<string, string>>;
  deleteUserError?: string;
}

function fakeAdmin(opts: FakeOptions = {}): {
  admin: DeletionAdminClient;
  deleteUserCalls: string[];
  removeCalls: Array<{ bucket: string; paths: string[] }>;
} {
  const deleteUserCalls: string[] = [];
  const removeCalls: Array<{ bucket: string; paths: string[] }> = [];

  const admin: DeletionAdminClient = {
    auth: {
      getUser(_jwt: string) {
        if (opts.validUserId === null || opts.validUserId === undefined) {
          return Promise.resolve({
            data: { user: null },
            error: { message: opts.getUserError ?? 'invalid token' },
          });
        }
        return Promise.resolve({
          data: { user: { id: opts.validUserId } },
          error: null,
        });
      },
      admin: {
        deleteUser(id: string) {
          deleteUserCalls.push(id);
          if (opts.deleteUserError) {
            return Promise.resolve({ error: { message: opts.deleteUserError } });
          }
          return Promise.resolve({ error: null });
        },
      },
    },
    storage: {
      from(bucket: string) {
        return {
          list(prefix: string, _o: { limit: number }) {
            const listError = opts.storageListError?.[bucket];
            if (listError) {
              return Promise.resolve({
                data: null,
                error: { message: listError },
              });
            }
            return Promise.resolve({
              data: opts.storageEntries?.[bucket]?.[prefix] ?? [],
              error: null,
            });
          },
          remove(paths: string[]) {
            removeCalls.push({ bucket, paths });
            const removeError = opts.storageRemoveError?.[bucket];
            if (removeError) {
              return Promise.resolve({ error: { message: removeError } });
            }
            return Promise.resolve({ error: null });
          },
        };
      },
    },
  };

  return { admin, deleteUserCalls, removeCalls };
}

Deno.test('OPTIONS request returns a CORS ok response without touching auth', async () => {
  const { admin, deleteUserCalls } = fakeAdmin();
  const res = await handleRequest(req({ method: 'OPTIONS' }), admin);
  assertEquals(res.status, 200);
  assertEquals(deleteUserCalls.length, 0);
});

Deno.test('non-POST method is rejected', async () => {
  const { admin } = fakeAdmin({ validUserId: 'user-1' });
  const res = await handleRequest(req({ method: 'GET', authorization: 'Bearer x' }), admin);
  assertEquals(res.status, 405);
});

Deno.test('missing Authorization header is rejected — never falls back to a body/query user id', async () => {
  const { admin, deleteUserCalls } = fakeAdmin({ validUserId: 'user-1' });
  const res = await handleRequest(req(), admin);
  assertEquals(res.status, 401);
  assertEquals(deleteUserCalls.length, 0);
});

Deno.test('invalid or expired token is rejected — no deletion is attempted', async () => {
  const { admin, deleteUserCalls } = fakeAdmin({ validUserId: null });
  const res = await handleRequest(req({ authorization: 'Bearer bad-token' }), admin);
  assertEquals(res.status, 401);
  assertEquals(deleteUserCalls.length, 0);
  const body = await res.json();
  // Never a raw Supabase/Postgres error surfaced to the caller.
  assertEquals(typeof body.error, 'string');
});

Deno.test('a valid caller deletes exactly their own id — derived from the JWT, never a client-supplied value (there is no field for one)', async () => {
  const { admin, deleteUserCalls } = fakeAdmin({ validUserId: 'user-1' });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body, { success: true });
  assertEquals(deleteUserCalls, ['user-1']);
});

Deno.test('storage cleanup purges nested visit-photos files (folder recursion) before deleting the user', async () => {
  const { admin, removeCalls, deleteUserCalls } = fakeAdmin({
    validUserId: 'user-1',
    storageEntries: {
      'visit-photos': {
        'user-1': [{ id: null, name: 'visit-1' }], // a "folder" (no id)
        'user-1/visit-1': [{ id: 'file-id', name: 'private.jpg' }],
      },
    },
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 200);
  assertEquals(removeCalls[0], {
    bucket: 'visit-photos',
    paths: ['user-1/visit-1/private.jpg'],
  });
  assertEquals(deleteUserCalls, ['user-1']);
});

Deno.test('a visit-photos list failure BLOCKS account deletion — hard precondition, the account is NOT deleted, the session stays valid so the user can retry', async () => {
  const { admin, deleteUserCalls } = fakeAdmin({
    validUserId: 'user-1',
    storageListError: { 'visit-photos': 'network error' },
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 500);
  assertEquals(deleteUserCalls.length, 0);
  const body = await res.json();
  assertEquals(body.error, 'Could not delete account. Please try again.');
  // The raw backend error message must never reach the client.
  assertEquals(JSON.stringify(body).includes('network error'), false);
});

Deno.test('a visit-photos remove failure BLOCKS account deletion — hard precondition, the account is NOT deleted, the session stays valid so the user can retry', async () => {
  const { admin, deleteUserCalls } = fakeAdmin({
    validUserId: 'user-1',
    storageEntries: { 'visit-photos': { 'user-1': [{ id: 'f1', name: 'a.jpg' }] } },
    storageRemoveError: { 'visit-photos': 'network error' },
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 500);
  assertEquals(deleteUserCalls.length, 0);
});

// PROFILE UI REDESIGN V1 (proposed) — profile-photos is the second hard
// precondition, purged only after visit-photos succeeds, and must
// independently block deletion on its own failure — never masked by, or
// mistaken for, the visit-photos check above.

Deno.test('storage cleanup also purges profile-photos, after visit-photos, before deleting the user', async () => {
  const { admin, removeCalls, deleteUserCalls } = fakeAdmin({
    validUserId: 'user-1',
    storageEntries: {
      'visit-photos': { 'user-1': [{ id: 'v1', name: 'a.jpg' }] },
      'profile-photos': { 'user-1': [{ id: 'p1', name: 'avatar.jpg' }] },
    },
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 200);
  assertEquals(removeCalls, [
    { bucket: 'visit-photos', paths: ['user-1/a.jpg'] },
    { bucket: 'profile-photos', paths: ['user-1/avatar.jpg'] },
  ]);
  assertEquals(deleteUserCalls, ['user-1']);
});

Deno.test('a user who never set an avatar (empty profile-photos listing) deletes normally — an empty listing is a successful no-op, never a failure', async () => {
  const { admin, removeCalls, deleteUserCalls } = fakeAdmin({
    validUserId: 'user-1',
    storageEntries: { 'profile-photos': { 'user-1': [] } },
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 200);
  assertEquals(
    removeCalls.some((c) => c.bucket === 'profile-photos'),
    false,
  );
  assertEquals(deleteUserCalls, ['user-1']);
});

Deno.test('a profile-photos list failure BLOCKS account deletion, even though visit-photos succeeded', async () => {
  const { admin, deleteUserCalls } = fakeAdmin({
    validUserId: 'user-1',
    storageListError: { 'profile-photos': 'network error' },
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 500);
  assertEquals(deleteUserCalls.length, 0);
  const body = await res.json();
  assertEquals(body.error, 'Could not delete account. Please try again.');
  assertEquals(JSON.stringify(body).includes('network error'), false);
});

Deno.test('a profile-photos remove failure BLOCKS account deletion, even though visit-photos succeeded', async () => {
  const { admin, deleteUserCalls } = fakeAdmin({
    validUserId: 'user-1',
    storageEntries: { 'profile-photos': { 'user-1': [{ id: 'p1', name: 'avatar.jpg' }] } },
    storageRemoveError: { 'profile-photos': 'network error' },
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 500);
  assertEquals(deleteUserCalls.length, 0);
});

Deno.test('Storage cleanup success (both buckets) is required before — and precedes — auth deletion', async () => {
  const { admin, removeCalls, deleteUserCalls } = fakeAdmin({
    validUserId: 'user-1',
    storageEntries: { 'visit-photos': { 'user-1': [{ id: 'f1', name: 'a.jpg' }] } },
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 200);
  assertEquals(removeCalls[0], { bucket: 'visit-photos', paths: ['user-1/a.jpg'] });
  assertEquals(deleteUserCalls, ['user-1']);
});

Deno.test('an auth.admin.deleteUser failure is reported honestly — never a false success', async () => {
  const { admin } = fakeAdmin({
    validUserId: 'user-1',
    deleteUserError: 'internal error: connection to auth service lost',
  });
  const res = await handleRequest(req({ authorization: 'Bearer good-token' }), admin);
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error, 'Could not delete account. Please try again.');
  // The raw backend error message must never reach the client.
  assertEquals(JSON.stringify(body).includes('connection to auth service'), false);
});

Deno.test('two different callers each delete only their own account', async () => {
  const { admin, deleteUserCalls } = fakeAdmin({ validUserId: 'user-1' });
  await handleRequest(req({ authorization: 'Bearer token-for-user-1' }), admin);

  const { admin: admin2, deleteUserCalls: calls2 } = fakeAdmin({ validUserId: 'user-2' });
  await handleRequest(req({ authorization: 'Bearer token-for-user-2' }), admin2);

  assertEquals(deleteUserCalls, ['user-1']);
  assertEquals(calls2, ['user-2']);
});
