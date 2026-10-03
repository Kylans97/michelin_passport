// Notify Content Report — sends an admin-facing email the moment someone
// reports a piece of content (a photo, a rating, a profile — see
// ReportContentType in lib/models/content_report.dart), so a report
// never sits unseen in a table nobody is otherwise notified to check.
// content_reports (20260913120000_add_content_reports_and_get_blocked_
// users.sql) has carried every friend-rating and private-chef-photo
// report since September with zero admin notification of any kind; this
// closes that for every content_type at once.
//
// Called ONLY by the content_reports insert trigger
// (notify_admin_of_pending_content_report(), added in
// 20261010120000_add_content_report_admin_email_notification.sql) via
// pg_net — never by the Flutter app, and there is no user JWT in that
// calling context. Same shape as notify-venue-claim: this function sets
// `verify_jwt = false` in config.toml and checks its own shared secret
// (the `x-webhook-secret` header, compared against
// NOTIFY_CONTENT_REPORT_WEBHOOK_SECRET) instead. That secret is
// duplicated in `vault.secrets` under the matching name
// (notify_content_report_webhook_secret), which is the only place the
// trigger can read it from to send it.
//
// Deliberately generic over content_type, matching content_reports' own
// shape: content_type = 'photo' alone doesn't say which of
// restaurant_photos/hotel_photos/private_chef_photos a report is about,
// and content_reports carries no venue-type hint at all — this function
// does not attempt that resolution. It reports exactly what the row
// holds (reporter identity, content_type, content_id, reason, details)
// plus a dashboard link to look the specific row up by id, the same
// "SQL Editor deep link" shape notify-venue-claim already uses.
//
// Best-effort by construction, same two independent ways as
// notify-venue-claim: pg_net's net.http_post() is fire-and-forget from
// the trigger's perspective, and the trigger itself wraps the whole call
// in its own exception handler — so nothing this function does,
// including a Resend outage or a thrown exception in here, can ever roll
// back the report insert that triggered it.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// Narrow, structural interface — only the one lookup this function
// actually performs (the reporter's identity), matching
// DeletionAdminClient/NotifyClaimAdminClient's own approach.
export interface NotifyContentReportAdminClient {
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

// The content_reports row, sent verbatim as the trigger's own
// to_jsonb(new) — same reasoning as ClaimPayload in notify-venue-claim:
// avoids a second, redundant lookup here, and is exactly the state at
// insert time with no race against a later update.
export interface ContentReportPayload {
  id: string;
  reporter_id: string;
  content_type: string;
  content_id: string;
  reason: string;
  details: string | null;
  created_at: string;
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

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Same "SQL Editor deep link, not Table Editor" reasoning as
// notify-venue-claim's own dashboardLink — content_reports is always the
// table name here (never attacker-controlled; there is only one table
// this function ever queries), so interpolating it directly carries the
// same (non-)risk the original hardcoded literal did there.
function dashboardLink(reportId: string): string {
  const query = `select * from public.content_reports where id = '${reportId}';`;
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

// content_type = 'photo' is the one genuinely ambiguous case: content_id
// alone doesn't say which of three photo tables a reported photo lives
// in (restaurant_photos/hotel_photos/private_chef_photos — ReportRating
// and ReportProfile each resolve unambiguously to one table, visits/
// profiles, so they need no equivalent resolution). Tries all three
// candidate tables in parallel (mirroring get_notifications()'s own
// three-way coalesce for claim_venue_*, just in TypeScript instead of
// SQL) and, on a match, resolves the owning venue's name too — so the
// email tells the admin "Flore" directly rather than leaving a second
// lookup to do by hand. No schema change: this is three reads against
// tables that already exist, same as the dashboard link it supplements.
interface PhotoContext {
  venueLabel: string;
  venueName: string;
  venueCode: string;
}

const PHOTO_TABLES: ReadonlyArray<{
  table: string;
  fkColumn: string;
  venueView: string;
  nameColumn: string;
  codeColumn: string;
  venueLabel: string;
}> = [
  {
    table: 'restaurant_photos',
    fkColumn: 'restaurant_id',
    venueView: 'restaurants_full',
    nameColumn: 'name',
    codeColumn: 'restaurant_code',
    venueLabel: 'restaurant',
  },
  {
    table: 'hotel_photos',
    fkColumn: 'hotel_id',
    venueView: 'hotels_full',
    nameColumn: 'name',
    codeColumn: 'hotel_code',
    venueLabel: 'hotel',
  },
  {
    table: 'private_chef_photos',
    fkColumn: 'private_chef_id',
    venueView: 'private_chefs_full',
    nameColumn: 'display_name',
    codeColumn: 'slug',
    venueLabel: 'private chef',
  },
];

async function resolvePhotoContext(
  admin: NotifyContentReportAdminClient,
  photoId: string,
): Promise<PhotoContext | null> {
  const photoLookups = await Promise.all(
    PHOTO_TABLES.map((candidate) =>
      admin.from(candidate.table).select(candidate.fkColumn).eq('id', photoId).maybeSingle()
    ),
  );

  for (let i = 0; i < PHOTO_TABLES.length; i++) {
    const candidate = PHOTO_TABLES[i];
    const venueId = photoLookups[i].data?.[candidate.fkColumn] as string | undefined;
    if (!venueId) continue;

    const venueResult = await admin.from(candidate.venueView)
      .select(`${candidate.nameColumn}, ${candidate.codeColumn}`).eq('id', venueId).maybeSingle();
    return {
      venueLabel: candidate.venueLabel,
      venueName: (venueResult.data?.[candidate.nameColumn] as string | undefined) ??
        'Unknown venue',
      venueCode: (venueResult.data?.[candidate.codeColumn] as string | undefined) ?? 'unknown',
    };
  }
  return null;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/// Testable core — accepts injected dependencies so tests can supply
/// hand-rolled fakes, mirroring every other notify-* function's own
/// convention. `Deno.serve` below wires this to the real service-role
/// client and the real Resend call.
export async function handleRequest(
  req: Request,
  admin: NotifyContentReportAdminClient,
  sendEmail: SendEmail,
  webhookSecret: string | undefined,
): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const providedSecret = req.headers.get('x-webhook-secret');
  if (!webhookSecret || providedSecret !== webhookSecret) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  let report: ContentReportPayload;
  try {
    report = await req.json();
  } catch (_err) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }
  if (
    !report ||
    typeof report.id !== 'string' ||
    typeof report.reporter_id !== 'string' ||
    typeof report.content_type !== 'string' ||
    typeof report.content_id !== 'string' ||
    typeof report.reason !== 'string' ||
    typeof report.created_at !== 'string'
  ) {
    return jsonResponse({ error: 'Missing required report fields' }, 400);
  }

  // Reporter identity lookup — best-effort, same as every other
  // notify-* function: a lookup failure degrades the email's content, it
  // never blocks sending it.
  const [profileResult, userResult] = await Promise.all([
    admin.from('profiles').select('display_name, username').eq('id', report.reporter_id)
      .maybeSingle(),
    admin.auth.admin.getUserById(report.reporter_id),
  ]);

  if (profileResult.error) {
    console.error('notify-content-report: profile lookup failed', {
      reportId: report.id,
      reporterId: report.reporter_id,
      message: profileResult.error.message,
    });
  }
  if (userResult.error) {
    console.error('notify-content-report: account email lookup failed', {
      reportId: report.id,
      reporterId: report.reporter_id,
      message: userResult.error.message,
    });
  }

  const reporterName = (profileResult.data?.display_name as string | undefined) ??
    (profileResult.data?.username as string | undefined) ?? 'Unknown reporter';
  const reporterEmail = userResult.data.user?.email ?? 'unknown';

  // Only 'photo' needs this — see resolvePhotoContext's own doc comment.
  const photoContext = report.content_type === 'photo'
    ? await resolvePhotoContext(admin, report.content_id)
    : null;
  const whatLine = photoContext
    ? `${photoContext.venueLabel}: ${photoContext.venueName} (${photoContext.venueCode})`
    : report.content_type === 'photo'
    ? 'Could not locate this photo in restaurant_photos/hotel_photos/private_chef_photos — it may already have been removed.'
    : null;

  const submittedAt = formatAmsterdamTime(report.created_at);
  const link = dashboardLink(report.id);
  const details = report.details && report.details.trim().length > 0 ? report.details : null;

  const subject = `New content report: ${report.content_type}`;

  const text = `A new ${report.content_type} report was submitted.

Reporter: ${reporterName}
Account email: ${reporterEmail}
Content type: ${report.content_type}
Content id: ${report.content_id}
${whatLine ? `What: ${whatLine}\n` : ''}Reason: ${report.reason}
Details: ${details ?? '—'}

Submitted: ${submittedAt} (Europe/Amsterdam)

Review in the dashboard: ${link}`;

  const whatLineHtml = whatLine
    ? `<tr><td><strong>What</strong></td><td>${escapeHtml(whatLine)}</td></tr>`
    : '';

  const html = `
    <p>A new <strong>${escapeHtml(report.content_type)}</strong> report was submitted.</p>
    <table cellpadding="4" cellspacing="0">
      <tr><td><strong>Reporter</strong></td><td>${escapeHtml(reporterName)}</td></tr>
      <tr><td><strong>Account email</strong></td><td>${escapeHtml(reporterEmail)}</td></tr>
      <tr><td><strong>Content type</strong></td><td>${escapeHtml(report.content_type)}</td></tr>
      <tr><td><strong>Content id</strong></td><td>${escapeHtml(report.content_id)}</td></tr>
      ${whatLineHtml}
      <tr><td><strong>Reason</strong></td><td>${escapeHtml(report.reason)}</td></tr>
      <tr><td><strong>Details</strong></td><td>${details ? escapeHtml(details) : '—'}</td></tr>
    </table>
    <p>Submitted: ${submittedAt} (Europe/Amsterdam)</p>
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
    console.error('notify-content-report: email send failed', {
      reportId: report.id,
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

  // Same TS2589 instantiation-depth workaround as every other notify-*
  // function's own production wiring line — see notify-venue-claim's own
  // comment for the full explanation.
  return handleRequest(
    req,
    admin as unknown as NotifyContentReportAdminClient,
    sendEmail,
    Deno.env.get('NOTIFY_CONTENT_REPORT_WEBHOOK_SECRET'),
  );
});
