// Publish Venue Photo — replaces the manual "copy the file in the
// Storage dashboard, then paste its URL into approve_venue_photo" step
// documented in docs/Engineering/VENUE_CLAIM_OPERATIONS.md. Takes only a
// submission id and a reviewer id; derives the destination itself.
//
// WHY THIS FUNCTION NEVER ACCEPTS A URL FROM ITS CALLER
// A human-typed URL has a failure mode approve_venue_photo's own prefix/
// existence check cannot catch: copy one file, paste a DIFFERENT
// submission's URL, and the RPC happily publishes a real object at a
// real path — correct SQL, real object, no error, wrong photo on the
// venue's page. That is exactly the "plausible wrong value that looks
// finished" failure this project treats as the worst outcome. A function
// that derives the destination from the submission's own storage_path
// makes that error structurally impossible: there is no second URL for
// a human to mistype or swap. If this function took a URL as an
// argument, it would have solved nothing.
//
// EMPIRICALLY CONFIRMED BEFORE WRITING THIS (2026-09-30, this project's
// live Storage), not assumed: storage-js's
// `.storage.from(bucket).copy(from, to, {destinationBucket})` genuinely
// lands an independent object in the destination bucket on this
// project's current Storage version — tested with a scratch object
// (created, verified present with its own id/version distinct from the
// source, content byte-for-byte confirmed via download, then removed
// from both buckets). The source object was left untouched by copy()
// (as opposed to move()), confirming copy is the right primitive here.
// This project is NOT hitting the historical "destinationBucket is
// silently ignored" bug some other Supabase Storage versions have had.
//
// ORDERING IS THE SAFETY PROPERTY, NOT AN IMPLEMENTATION DETAIL
// copy -> verify -> approve_venue_photo, strictly in that order, and
// nothing before the RPC call touches the database. A copied file with
// no published row is harmless — the submission is still `pending`, and
// calling this function again just re-copies (or finds the object
// already there, see below) and retries the RPC. A published row
// pointing at a file that was never actually verified would not be
// harmless. Copy failures and verification failures are reported as
// clear errors with nothing changed; only a failure surfacing AFTER a
// successful copy+verify (i.e. the RPC call itself failing — an invalid
// reviewer id, or the submission no longer pending) says so explicitly,
// since at that point the file genuinely is sitting in catalogue-media
// unpublished and safe to retry.
//
// A copy() call is not trusted just because it returned no error — the
// documented failure mode elsewhere is exactly a copy call that reports
// success while silently doing the wrong thing. This function always
// independently re-reads the destination bucket afterward (the same
// `.list()`-and-check-the-name approach used in the scratch investigation
// itself) and treats that read, not copy()'s own return value, as the
// only proof the object exists.
//
// RETRIES ARE EXPECTED, NOT AN EDGE CASE: if a prior call already copied
// the file but failed before/at the RPC step, calling this again attempts
// the same copy to the same (deterministic) destination path. copy()
// erroring because the destination already exists is treated as
// informational, not fatal — the independent verification step right
// after is what actually decides, and a leftover object from a genuine
// prior success verifies exactly as if this call had just copied it.
//
// DESTINATION NAMING: <venue_type>/<venue_id>/<filename>, where
// <filename> is the last path segment of the submission's own
// storage_path (e.g. "restaurant/<id>/<user id>/<ts>_<rand>.jpg" ->
// "restaurant/<id>/<ts>_<rand>.jpg") — never a position/display_order-
// based name like the pre-existing "0.jpg" convention on some older
// published rows. display_order changes every time a manager reorders
// photos, via reorder_venue_photos, and a photo's storage object is
// never renamed when that happens — so a name implying position is
// already a lie in that older data, and this function does not repeat
// it. The submission's own filename already carries a submission-time
// timestamp + random suffix (real data confirmed live), which is what
// actually keeps destinations collision-free — not anything this
// function invents.
//
// COSMETIC, NOT A BUG: catalogue-media now holds two path conventions
// side by side — older rows (e.g. private_chef_photos' pre-existing
// "private-chefs/<id>/0.jpg") and everything this function publishes
// (venue_type-based, as above). Nothing reads or depends on the path
// structure of an object once image_url is stored — the URL is used
// verbatim, never parsed back apart — so this is not a migration this
// function performs, and no mapping unifies the two. Anyone browsing the
// bucket later should read the mismatch as history, not damage.
//
// AUTHENTICATION: not triggered by a pg_net database trigger like
// notify-venue-claim/notify-venue-submission — this one is invoked
// directly (by a reviewer, today; potentially some other tool later),
// but there is still no user JWT in that calling context, so the same
// shape applies: verify_jwt = false in config.toml, and this function
// checks its own shared secret (`x-webhook-secret`, compared against
// PUBLISH_VENUE_PHOTO_WEBHOOK_SECRET) before doing anything else — its
// own secret, never reused from the other two functions'.
//
// approve_venue_photo itself is UNCHANGED and still callable by hand
// from the SQL Editor exactly as documented — this function is a layer
// on top of it, not a replacement. If this function is ever down, the
// manual copy-then-call-the-RPC path documented in
// docs/Engineering/VENUE_CLAIM_OPERATIONS.md still works.
//
// Rejection is deliberately out of scope: rejecting a submission copies
// nothing and only needs reject_venue_photo, already callable directly.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// Narrow, structural interface — mirrors NotifyClaimAdminClient/
// NotifySubmissionAdminClient's own convention (kept as its own copy,
// not a shared module — every Edge Function in this project is
// deliberately self-contained), extended with the two Storage
// operations and the RPC call this function actually needs. The real
// SupabaseClient satisfies every one of these by structural typing.
export interface PublishPhotoAdminClient {
  from(table: string): {
    select(columns: string): {
      eq(
        column: string,
        value: string,
      ): {
        maybeSingle(): PromiseLike<{
          data: Record<string, unknown> | null;
          error: { message: string } | null;
        }>;
      };
    };
  };
  rpc(
    fn: string,
    params: Record<string, unknown>,
  ): PromiseLike<{
    data: unknown;
    error: { message: string } | null;
  }>;
  storage: {
    from(bucket: string): {
      copy(
        fromPath: string,
        toPath: string,
        options?: { destinationBucket?: string },
      ): Promise<{
        data: { path: string } | null;
        error: { message: string } | null;
      }>;
      list(path?: string): Promise<{
        data: { name: string }[] | null;
        error: { message: string } | null;
      }>;
    };
  };
}

export interface SubmissionRow {
  id: string;
  status: string;
  venue_type: string;
  venue_id: string;
  storage_path: string;
  replaces_photo_id: string | null;
}

const SUBMISSIONS_BUCKET = 'venue-photo-submissions';
const CATALOGUE_BUCKET = 'catalogue-media';

// The exact literal approve_venue_photo checks against (confirmed
// 2026-10-05 against a real published row, re-confirmed live in
// supabase/migrations/20261005120000_add_venue_approval_rpcs.sql's own
// v_prefix) — kept here as the same constant rather than derived at
// runtime, so this function produces a URL that satisfies that check by
// construction, not one that merely looks right.
const CATALOGUE_MEDIA_PUBLIC_PREFIX =
  'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/';

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function basename(path: string): string {
  const idx = path.lastIndexOf('/');
  return idx === -1 ? path : path.slice(idx + 1);
}

function dirname(path: string): string {
  const idx = path.lastIndexOf('/');
  return idx === -1 ? '' : path.slice(0, idx);
}

/// <venue_type>/<venue_id>/<filename> — see this file's own header for
/// why this is not position-based, and why the submission's own filename
/// is what actually keeps it collision-free.
export function destinationPathFor(submission: SubmissionRow): string {
  return `${submission.venue_type}/${submission.venue_id}/${basename(submission.storage_path)}`;
}

/// Independent proof the object exists at `path` in `bucket` — never
/// inferred from a copy() call's own return value. Lists the containing
/// "directory" and checks for the exact filename, the same technique
/// used to confirm the scratch object's presence during this function's
/// own investigation.
async function objectExistsAt(
  storage: PublishPhotoAdminClient['storage'],
  bucket: string,
  path: string,
): Promise<boolean> {
  const { data, error } = await storage.from(bucket).list(dirname(path));
  if (error || !data) return false;
  return data.some((f) => f.name === basename(path));
}

/// Testable core — accepts an injected client so tests can supply a
/// hand-rolled fake (no mocking framework), mirroring notify-venue-claim/
/// notify-venue-submission's own convention exactly.
export async function handleRequest(
  req: Request,
  admin: PublishPhotoAdminClient,
  webhookSecret: string | undefined,
): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  // Checked before anything else, including body parsing — same
  // reasoning as notify-venue-claim/notify-venue-submission.
  const providedSecret = req.headers.get('x-webhook-secret');
  if (!webhookSecret || providedSecret !== webhookSecret) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  let body: { submission_id?: unknown; reviewed_by?: unknown };
  try {
    body = await req.json();
  } catch (_err) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const submissionId = body?.submission_id;
  const reviewedBy = body?.reviewed_by;
  if (typeof submissionId !== 'string' || typeof reviewedBy !== 'string') {
    return jsonResponse({ error: 'submission_id and reviewed_by are both required' }, 400);
  }

  // Nothing below this point has changed anything yet — a failure from
  // here through the copy/verify steps changes nothing at all.
  const { data: submissionData, error: submissionError } = await admin
    .from('venue_photo_submissions')
    .select('id, status, venue_type, venue_id, storage_path, replaces_photo_id')
    .eq('id', submissionId)
    .maybeSingle();

  if (submissionError) {
    return jsonResponse({ error: `Could not load submission: ${submissionError.message}` }, 502);
  }
  if (!submissionData) {
    return jsonResponse({ error: `No submission found with id ${submissionId}` }, 404);
  }
  const submission = submissionData as unknown as SubmissionRow;

  // Refuses anything not pending — explicitly, before attempting any
  // copy, rather than only relying on approve_venue_photo's own check
  // further down. Covers "calling this twice": the first call flips
  // status to 'approved', so a second call for the same id stops here.
  if (submission.status !== 'pending') {
    return jsonResponse(
      { error: `Submission ${submissionId} is not pending (status: ${submission.status})` },
      409,
    );
  }

  const destPath = destinationPathFor(submission);

  const copyResult = await admin.storage
    .from(SUBMISSIONS_BUCKET)
    .copy(submission.storage_path, destPath, { destinationBucket: CATALOGUE_BUCKET });
  if (copyResult.error) {
    // Not treated as fatal by itself — a retry after a prior call that
    // copied successfully but failed before/at the RPC step will
    // legitimately see "already exists" here. The verification step
    // immediately below is what actually decides.
    console.warn('publish-venue-photo: copy() reported an error, verifying independently before giving up', {
      submissionId,
      destPath,
      message: copyResult.error.message,
    });
  }

  // Never trust copy()'s own success response as proof — the documented
  // failure mode is exactly a copy call that claims success while
  // silently doing the wrong thing. Independently re-read the
  // destination bucket instead.
  const verified = await objectExistsAt(admin.storage, CATALOGUE_BUCKET, destPath);
  if (!verified) {
    return jsonResponse(
      {
        error: `Copy could not be verified: no object at ${destPath} in ${CATALOGUE_BUCKET}` +
          (copyResult.error ? ` (copy error: ${copyResult.error.message})` : ''),
      },
      502,
    );
  }

  const imageUrl = `${CATALOGUE_MEDIA_PUBLIC_PREFIX}${destPath}`;

  // The only state-changing step. Everything before this point was a
  // read plus a Storage copy — a failure here means the file is sitting
  // in catalogue-media unpublished, which is harmless, and says so.
  const { data: rpcData, error: rpcError } = await admin.rpc('approve_venue_photo', {
    p_submission_id: submissionId,
    p_reviewed_by: reviewedBy,
    p_image_url: imageUrl,
  });

  if (rpcError) {
    console.error('publish-venue-photo: approve_venue_photo failed after a verified copy', {
      submissionId,
      destPath,
      message: rpcError.message,
    });
    return jsonResponse(
      {
        error: `File copied to ${destPath} but approve_venue_photo failed: ${rpcError.message}. ` +
          'The file is in catalogue-media but nothing was published — safe to call this function again.',
      },
      502,
    );
  }

  return jsonResponse({ success: true, image_url: imageUrl, published: rpcData }, 200);
}

Deno.serve((req) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Same TS2589 instantiation-depth accommodation as notify-venue-claim/
  // notify-venue-submission's own wiring line — scoped to this one line
  // only; handleRequest's own signature and every test's hand-rolled
  // fake stay fully structurally typed with no cast anywhere else.
  return handleRequest(
    req,
    admin as unknown as PublishPhotoAdminClient,
    Deno.env.get('PUBLISH_VENUE_PHOTO_WEBHOOK_SECRET'),
  );
});
