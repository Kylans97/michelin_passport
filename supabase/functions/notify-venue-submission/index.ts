// Notify Venue Submission — sends an admin-facing email the moment a
// venue manager submits new "about" text or a new photo, so pending
// manager-submitted content (which only ever reaches the catalogue after
// a human approves it — see venue_about_current/the photo-publish flow)
// never sits unseen in the review queue.
//
// Called ONLY by the shared venue_about_submissions/venue_photo_
// submissions insert trigger
// (notify_admin_of_pending_venue_submission(), added in
// 20261004120000_add_venue_submission_admin_email_notification.sql) via
// pg_net — never by the Flutter app, and there is no user JWT to verify
// in that calling context. Same shape as notify-venue-claim: this
// function sets `verify_jwt = false` in config.toml and instead checks
// its own shared secret (the `x-webhook-secret` header, compared against
// NOTIFY_VENUE_SUBMISSION_WEBHOOK_SECRET) before doing anything else.
// That secret is its own — never reused from notify-venue-claim's — and
// is duplicated in `vault.secrets` under a different name, which is the
// only place the trigger can read it from to send it.
//
// ONE FUNCTION FOR BOTH SUBMISSION TABLES, NOT TWO: venue_about_
// submissions and venue_photo_submissions share an identical core shape
// (id, user_id, venue_type, venue_id, submitted_at) and differ only in
// their one content-specific field. The trigger sends `submission_type`
// (the firing table's own name, via TG_TABLE_NAME) alongside the row, and
// everything below branches on that once — see the migration's own
// header for the fuller reasoning on why this isn't folded into
// notify-venue-claim instead (a genuinely different question: who gets
// to manage a venue, vs what an already-approved manager submitted).
//
// Best-effort by construction — identical to notify-venue-claim: pg_net's
// net.http_post() is fire-and-forget from the trigger's perspective, and
// the trigger itself wraps the whole call in its own exception handler,
// so nothing this function does can ever roll back the submission insert
// that triggered it. Failures are surfaced only via `console.error` (->
// Supabase Edge Function logs) and this function's own HTTP status.
//
// Photo submissions deliberately never embed or link the image itself:
// venue-photo-submissions is a private storage bucket, and the image
// must be reviewed in the dashboard — this email identifies the
// submission (id, storage_path, what it would replace) and points at the
// row, nothing more.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// Narrow, structural interface — mirrors NotifyClaimAdminClient
// (notify-venue-claim/index.ts) exactly, kept as its own copy rather than
// a shared module since each Edge Function here is deliberately
// self-contained (matches delete-account/notify-venue-claim's own
// convention — no shared lib between functions in this project).
export interface NotifySubmissionAdminClient {
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
  auth: {
    admin: {
      getUserById(id: string): Promise<{
        data: { user: { email?: string | null } | null };
        error: { message: string } | null;
      }>;
    };
  };
}

export type SubmissionType = 'venue_about_submissions' | 'venue_photo_submissions';
export type VenueType = 'restaurant' | 'hotel' | 'private_chef';

// The venue_about_submissions/venue_photo_submissions row, sent verbatim
// as the trigger's own to_jsonb(new) — same reasoning as ClaimPayload:
// avoids a second, redundant lookup here, and is exactly the state at
// insert time.
export interface SubmissionRow {
  id: string;
  user_id: string;
  venue_type: VenueType;
  venue_id: string;
  status: string;
  submitted_at: string;
  about_text?: string;
  storage_path?: string;
  replaces_photo_id?: string | null;
}

export interface SubmissionPayload {
  submission_type: SubmissionType;
  row: SubmissionRow;
}

export interface EmailMessage {
  from: string;
  to: string;
  subject: string;
  html: string;
  text: string;
}

export type SendEmail = (message: EmailMessage) => Promise<{ ok: boolean; error?: string }>;

const ADMIN_EMAIL = 'claimedvenues@mantelier.app';
const FROM_EMAIL = 'notifications@mantelier.app';
const DASHBOARD_PROJECT_REF = 'wcmxugunvwsrulcpeyrc';

// Per venue_type, which *_full view/columns identify the venue. Private
// chefs have no code-equivalent column (confirmed live: private_chefs_full
// has id/slug/display_name, no "code" column) — slug is the closest
// stable identifier and is used the same way restaurant_code/hotel_code
// are for the other two types.
const VENUE_LOOKUP: Record<VenueType, { table: string; nameColumn: string; codeColumn: string }> = {
  restaurant: { table: 'restaurants_full', nameColumn: 'name', codeColumn: 'restaurant_code' },
  hotel: { table: 'hotels_full', nameColumn: 'name', codeColumn: 'hotel_code' },
  private_chef: {
    table: 'private_chefs_full',
    nameColumn: 'display_name',
    codeColumn: 'slug',
  },
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// A SQL Editor deep link, same reasoning as notify-venue-claim's own
// dashboardLink: Table Editor has no reliable per-row URL scheme this
// function can resolve, while the SQL Editor's `content` query param only
// needs the table name and row id.
function dashboardLink(submissionType: SubmissionType, id: string): string {
  const query = `select * from public.${submissionType} where id = '${id}';`;
  return `https://supabase.com/dashboard/project/${DASHBOARD_PROJECT_REF}/sql/new?content=${
    encodeURIComponent(query)
  }`;
}

function formatAmsterdamTime(iso: string): string {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Amsterdam',
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(iso));
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/// Testable core — accepts injected dependencies so tests can supply
/// hand-rolled fakes (no mocking framework), mirroring notify-venue-
/// claim's own convention exactly. `Deno.serve` below wires this to the
/// real service-role client and the real Resend call.
export async function handleRequest(
  req: Request,
  admin: NotifySubmissionAdminClient,
  sendEmail: SendEmail,
  webhookSecret: string | undefined,
): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  // Checked before anything else, including body parsing — same reasoning
  // as notify-venue-claim.
  const providedSecret = req.headers.get('x-webhook-secret');
  if (!webhookSecret || providedSecret !== webhookSecret) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  let payload: SubmissionPayload;
  try {
    payload = await req.json();
  } catch (_err) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  if (
    payload?.submission_type !== 'venue_about_submissions' &&
    payload?.submission_type !== 'venue_photo_submissions'
  ) {
    return jsonResponse({ error: 'Unknown submission_type' }, 400);
  }

  const row = payload.row;
  if (
    !row ||
    typeof row.id !== 'string' ||
    typeof row.user_id !== 'string' ||
    typeof row.venue_type !== 'string' ||
    !(row.venue_type in VENUE_LOOKUP) ||
    typeof row.venue_id !== 'string' ||
    typeof row.submitted_at !== 'string'
  ) {
    return jsonResponse({ error: 'Missing required submission fields' }, 400);
  }
  if (payload.submission_type === 'venue_about_submissions' && typeof row.about_text !== 'string') {
    return jsonResponse({ error: 'Missing about_text' }, 400);
  }
  if (payload.submission_type === 'venue_photo_submissions' && typeof row.storage_path !== 'string') {
    return jsonResponse({ error: 'Missing storage_path' }, 400);
  }

  const venueLookup = VENUE_LOOKUP[row.venue_type];

  // Venue and submitter lookups are independent of each other and of the
  // submission row itself (already fully known from the payload) —
  // best-effort each, same reasoning as notify-venue-claim: a lookup
  // failure degrades the email's content, it never blocks sending it.
  const [venueResult, profileResult, userResult] = await Promise.all([
    admin.from(venueLookup.table)
      .select(`${venueLookup.nameColumn}, ${venueLookup.codeColumn}`)
      .eq('id', row.venue_id)
      .maybeSingle(),
    admin.from('profiles').select('display_name, username').eq('id', row.user_id).maybeSingle(),
    admin.auth.admin.getUserById(row.user_id),
  ]);

  if (venueResult.error) {
    console.error('notify-venue-submission: venue lookup failed', {
      submissionId: row.id,
      venueType: row.venue_type,
      venueId: row.venue_id,
      message: venueResult.error.message,
    });
  }
  if (profileResult.error) {
    console.error('notify-venue-submission: profile lookup failed', {
      submissionId: row.id,
      userId: row.user_id,
      message: profileResult.error.message,
    });
  }
  if (userResult.error) {
    console.error('notify-venue-submission: account email lookup failed', {
      submissionId: row.id,
      userId: row.user_id,
      message: userResult.error.message,
    });
  }

  const venueName = (venueResult.data?.[venueLookup.nameColumn] as string | undefined) ??
    'Unknown venue';
  const venueIdentifier = (venueResult.data?.[venueLookup.codeColumn] as string | undefined) ??
    'unknown identifier';
  const displayName = (profileResult.data?.display_name as string | undefined) ??
    (profileResult.data?.username as string | undefined) ?? 'Unknown submitter';
  const accountEmail = userResult.data.user?.email ?? null;

  const submittedAt = formatAmsterdamTime(row.submitted_at);
  const link = dashboardLink(payload.submission_type, row.id);

  const isAbout = payload.submission_type === 'venue_about_submissions';
  const subject = isAbout
    ? `New "about" text submitted: ${venueName} (${venueIdentifier})`
    : `New venue photo submitted: ${venueName} (${venueIdentifier})`;

  const contentTextLines = isAbout
    ? [
      'Submitted text:',
      '"""',
      row.about_text as string,
      '"""',
    ]
    : [
      `Submission id: ${row.id}`,
      `Storage path: ${row.storage_path}`,
      `Replaces existing photo id: ${row.replaces_photo_id ?? '— (new photo, no replacement)'}`,
      '',
      'The image itself must be viewed in the dashboard — this email does not link it directly ' +
      '(venue-photo-submissions is a private bucket).',
    ];

  const text = `A new ${isAbout ? '"about" text' : 'photo'} submission was made for ${venueName} (${venueIdentifier}).

Venue type: ${row.venue_type}
Submitted by: ${displayName} (${accountEmail ?? 'unknown email'})
Submitted: ${submittedAt} (Europe/Amsterdam)

${contentTextLines.join('\n')}

Review in the dashboard: ${link}`;

  const contentHtml = isAbout
    ? `<p style="white-space:pre-wrap;">${escapeHtml(row.about_text as string)}</p>`
    : `
      <table cellpadding="4" cellspacing="0">
        <tr><td><strong>Submission id</strong></td><td>${escapeHtml(row.id)}</td></tr>
        <tr><td><strong>Storage path</strong></td><td>${escapeHtml(row.storage_path as string)}</td></tr>
        <tr><td><strong>Replaces existing photo id</strong></td><td>${
      escapeHtml(row.replaces_photo_id ?? '— (new photo, no replacement)')
    }</td></tr>
      </table>
      <p><em>The image itself must be viewed in the dashboard — this email does not link it
      directly (venue-photo-submissions is a private bucket).</em></p>
    `;

  const html = `
    <p>A new ${
    isAbout ? '"about" text' : 'photo'
  } submission was made for <strong>${escapeHtml(venueName)}</strong> (${
    escapeHtml(venueIdentifier)
  }).</p>
    <table cellpadding="4" cellspacing="0">
      <tr><td><strong>Venue type</strong></td><td>${escapeHtml(row.venue_type)}</td></tr>
      <tr><td><strong>Submitted by</strong></td><td>${escapeHtml(displayName)} (${
    escapeHtml(accountEmail ?? 'unknown email')
  })</td></tr>
      <tr><td><strong>Submitted</strong></td><td>${submittedAt} (Europe/Amsterdam)</td></tr>
    </table>
    ${contentHtml}
    <p><a href="${link}">Review in the dashboard</a></p>
  `;

  const result = await sendEmail({
    from: FROM_EMAIL,
    to: ADMIN_EMAIL,
    subject,
    html,
    text,
  });

  if (!result.ok) {
    console.error('notify-venue-submission: email send failed', {
      submissionId: row.id,
      submissionType: payload.submission_type,
      message: result.error,
    });
    return jsonResponse({ error: 'Email send failed' }, 502);
  }

  return jsonResponse({ success: true }, 200);
}

Deno.serve((req) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const resendApiKey = Deno.env.get('RESEND_API_KEY');
  const sendEmail: SendEmail = async (message) => {
    if (!resendApiKey) {
      return { ok: false, error: 'RESEND_API_KEY is not configured' };
    }
    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      });
      if (!res.ok) {
        const body = await res.text();
        return { ok: false, error: `Resend responded ${res.status}: ${body}` };
      }
      return { ok: true };
    } catch (err) {
      return { ok: false, error: err instanceof Error ? err.message : String(err) };
    }
  };

  // Same TS2589 instantiation-depth accommodation as notify-venue-claim's
  // own wiring line — scoped to this one line only.
  return handleRequest(
    req,
    admin as unknown as NotifySubmissionAdminClient,
    sendEmail,
    Deno.env.get('NOTIFY_VENUE_SUBMISSION_WEBHOOK_SECRET'),
  );
});
