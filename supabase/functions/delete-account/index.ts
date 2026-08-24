// Account Deletion — deletes the CALLING user's own Chasing Stars account.
//
// Security model: identity comes ONLY from the caller's own JWT (verified
// via supabaseAdmin.auth.getUser(jwt)). There is no field anywhere in
// this function — request body, query string, header — that accepts a
// client-supplied target user id. A malicious authenticated user cannot
// request deletion of another account through this endpoint; there is
// structurally no parameter for one. The platform's own JWT-verification
// gateway (default `verify_jwt = true`, unchanged in config.toml) already
// rejects requests with no/invalid Supabase-issued token before this code
// runs at all — this function's own getUser() check is a second,
// independent verification against the service-role client.
//
// Deletion order (see docs/Architecture/ACCOUNT_DELETION.md for the full
// audited dependency map):
//   1. Authenticate the caller from their JWT.
//   2. Purge that user's objects in the `visit-photos` Storage bucket —
//      the ONLY user-owned Storage content (confirmed by schema audit),
//      and NOT covered by any Postgres FK cascade. **This is now a HARD
//      PRECONDITION, not best-effort**: if listing or removing those
//      objects fails for any reason, the function returns failure
//      immediately and NEVER proceeds to step 3 — the auth account (and
//      the caller's session) is left fully intact, so the same
//      authenticated user can simply retry. This was deliberately
//      changed from an earlier best-effort design: once `auth.users` is
//      deleted, the user's own JWT is invalidated, so THEY can no longer
//      retry Storage cleanup under their own identity — any leftover
//      personal media would then require manual/admin intervention to
//      remove, which is a materially worse privacy outcome than asking
//      the user to tap "Delete my account" again after a transient
//      Storage failure.
//   3. supabase.auth.admin.deleteUser(userId) — only reached after step 2
//      succeeds. `profiles.id` is `ON DELETE CASCADE` from
//      `auth.users(id)`, and every one of the 16 user-owned tables this
//      app has (visits, wishlist, planned_trips, planned_venues, photos,
//      event_attendance, event_confirmed_attendance, follows,
//      follows_hotels, follows_private_chefs, follows_restaurants,
//      friendships [requester/addressee CASCADE; blocked_by SET NULL —
//      benign, leaves the other party's row intact with a nulled
//      blocker reference], private_chef_enquiries) cascades from
//      `profiles.id` in turn — this one call is sufficient for all
//      Postgres-side data, confirmed via a live, read-only
//      information_schema/pg_constraint audit against production. No
//      manual per-table DELETE is issued; the cascade is trusted because
//      it was independently verified, not assumed.
//
// Success is reported ONLY after step 3 itself succeeds — never before,
// so the client never hears "deleted" while the auth account still
// exists. A Storage failure now means the account is NOT deleted at all
// (step 2 blocks step 3) — there is no longer any window where auth
// deletion succeeds but Storage cleanup didn't.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// A narrow, structural dependency interface — only the operations this
// function actually performs, not the full Supabase SDK surface. The
// real `SupabaseClient` satisfies this by structural typing (no cast
// needed); tests supply a small hand-rolled fake object literal instead
// (no mocking framework — same testing philosophy the Flutter side of
// this feature already uses for DeleteAccountScreen).
export interface DeletionAdminClient {
  auth: {
    getUser(jwt: string): Promise<{
      data: { user: { id: string } | null };
      error: { message: string } | null;
    }>;
    admin: {
      deleteUser(id: string): Promise<{ error: { message: string } | null }>;
    };
  };
  storage: {
    from(bucket: string): {
      list(
        prefix: string,
        opts: { limit: number },
      ): Promise<{
        data: Array<{ id: string | null; name: string }> | null;
        error: { message: string } | null;
      }>;
      remove(paths: string[]): Promise<{ error: { message: string } | null }>;
    };
  };
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

// Supabase Storage's list() represents a "folder" (a grouping prefix,
// not a real object) as an entry with `id: null` — recursing into those
// is the standard, documented workaround for the SDK having no native
// recursive delete. `visit-photos` is keyed `{user_id}/{visit_id}/
// {filename}`, so a plain one-level list() only returns visit_id
// "folders," not the files themselves.
//
// A listing failure THROWS rather than silently returning an empty
// list — under the hard-precondition policy below, "I couldn't verify
// whether files exist" must never be treated the same as "no files
// exist."
async function listAllFiles(
  admin: DeletionAdminClient,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const { data: entries, error } = await admin.storage.from(bucket).list(prefix, {
    limit: 1000,
  });
  if (error) {
    throw new Error(error.message);
  }
  if (!entries) return [];

  const files: string[] = [];
  for (const entry of entries) {
    const path = `${prefix}/${entry.name}`;
    if (entry.id === null) {
      files.push(...(await listAllFiles(admin, bucket, path)));
    } else {
      files.push(path);
    }
  }
  return files;
}

type PurgeResult = { ok: true } | { ok: false; message: string };

// Storage cleanup is a HARD PRECONDITION for account deletion — see this
// file's own top-of-file doc comment for why. Returns `{ ok: false }` on
// ANY listing or removal failure; the caller must not proceed to delete
// the auth user when that happens.
async function purgeVisitPhotos(
  admin: DeletionAdminClient,
  userId: string,
): Promise<PurgeResult> {
  try {
    const paths = await listAllFiles(admin, 'visit-photos', userId);
    if (paths.length === 0) return { ok: true };
    const { error } = await admin.storage.from('visit-photos').remove(paths);
    if (error) {
      console.error('delete-account: storage remove failed', {
        userId,
        message: error.message,
      });
      return { ok: false, message: error.message };
    }
    return { ok: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('delete-account: storage cleanup failed', { userId, message });
    return { ok: false, message };
  }
}

/// Testable core — accepts an injected admin client so tests can supply a
/// hand-rolled fake (no mocking framework), mirroring the same
/// constructor-injection pattern the Flutter side of this feature already
/// uses (DeleteAccountScreen). `Deno.serve` below wires this to the real
/// service-role client; this function never constructs one itself.
export async function handleRequest(
  req: Request,
  admin: DeletionAdminClient,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401);
  }

  const jwt = authHeader.replace(/^Bearer\s+/i, '');

  let userId: string;
  try {
    const {
      data: { user },
      error: userError,
    } = await admin.auth.getUser(jwt);
    if (userError || !user) {
      return jsonResponse({ error: 'Invalid or expired session' }, 401);
    }
    userId = user.id;
  } catch (_err) {
    return jsonResponse({ error: 'Invalid or expired session' }, 401);
  }

  const purgeResult = await purgeVisitPhotos(admin, userId);
  if (!purgeResult.ok) {
    // Hard precondition: Storage cleanup failed, so the auth account is
    // NEVER touched — the caller's session remains valid and they can
    // simply retry. See this file's own top doc comment for why.
    return jsonResponse({ error: 'Could not delete account. Please try again.' }, 500);
  }

  try {
    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error('delete-account: auth admin deleteUser failed', {
        userId,
        message: deleteError.message,
      });
      return jsonResponse({ error: 'Could not delete account. Please try again.' }, 500);
    }
  } catch (err) {
    console.error('delete-account: auth admin deleteUser threw', {
      userId,
      message: err instanceof Error ? err.message : String(err),
    });
    return jsonResponse({ error: 'Could not delete account. Please try again.' }, 500);
  }

  return jsonResponse({ success: true }, 200);
}

Deno.serve((req) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  // Service-role client — privileged, lives only in this function's
  // environment, never sent to or reachable from the Flutter client.
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return handleRequest(req, admin);
});
