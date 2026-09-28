// Notify Venue Claim — sends an admin-facing email the moment someone
// submits a restaurant claim, so a pending claim (which, since
// 20260928120000_harden_claims_restaurants_insert_rls.sql, now blocks
// every other user from claiming that same venue) never sits unseen.
//
// Called ONLY by the claims_restaurants insert trigger
// (notify_admin_of_pending_restaurant_claim(), added in
// 20260929120000_add_venue_claim_admin_email_notification.sql) via
// pg_net — never by the Flutter app, and there is no user JWT to verify
// in that calling context. So, unlike delete-account (verify_jwt = true,
// unchanged, because it IS called by the client with a real session):
// this function sets `verify_jwt = false` in config.toml and instead
// checks its own shared secret (the `x-webhook-secret` header, compared
// against NOTIFY_VENUE_CLAIM_WEBHOOK_SECRET) before doing anything else.
// That secret is duplicated in `vault.secrets` under the same name, which
// is the only place the trigger can read it from to send it. Anyone
// without it — including a caller with a perfectly valid anon/
// authenticated Supabase JWT — gets a 401 and nothing runs.
//
// Best-effort by construction: pg_net's net.http_post() is fire-and-
// forget from the trigger's perspective (it queues the request and
// returns immediately, outside whatever this function does), and the
// trigger itself wraps the whole call in its own exception handler — so
// nothing this function does, including a Resend outage or a thrown
// exception in here, can ever roll back the claim insert that triggered
// it. Failures are surfaced only via `console.error` (→ Supabase Edge
// Function logs) and this function's own HTTP status — nothing else
// reads either one automatically. See this repo's own PR/chat report for
// exactly how that surfaces to a human.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// Narrow, structural interface — only the two lookups this function
// actually performs, not the full Supabase SDK surface. Mirrors
// DeletionAdminClient's own approach (delete-account/index.ts): the real
// SupabaseClient satisfies this by structural typing, no cast needed;
// tests supply a small hand-rolled fake object literal instead.
export interface NotifyClaimAdminClient {
  from(table: string): {
    select(columns: string): {
      eq(
        column: string,
        value: string,
      ): {
        // PromiseLike, not Promise: the real SupabaseClient's
        // .maybeSingle() returns a PostgrestBuilder — thenable, but
        // missing catch/finally/Symbol.toStringTag, so it doesn't
        // structurally satisfy a strict Promise<T> type. Awaiting a
        // PromiseLike works identically; this is purely a type-checking
        // accommodation, not a behavior difference.
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

// The claims_restaurants row, sent verbatim as the trigger's own
// to_jsonb(new) — see the migration's own comment for why the full row
// is sent rather than just an id (avoids a second, redundant
// claims_restaurants lookup here, and is exactly the state at insert
// time with no race against a later update).
export interface ClaimPayload {
  id: string;
  user_id: string;
  restaurant_id: string;
  role: string;
  business_email: string;
  phone: string;
  notes: string | null;
  requested_at: string;
}

export interface EmailMessage {
  from: string;
  to: string;
  subject: string;
  html: string;
  text: string;
}

// A plain function, not a class/interface — this function's only
// external dependency besides Supabase, so there's nothing to name a
// bigger shape for. Deno.serve wires the real Resend call; tests inject
// one that just records what it was asked to send.
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

// A SQL Editor deep link, not a Table Editor one: Table Editor's
// per-row URL scheme keys on an internal numeric table id this function
// has no reliable way to resolve, while the SQL Editor's `content` query
// param (Supabase's own documented way to share a pre-filled query) only
// needs the table name and the row id — both of which this function
// already has. Opening it runs the query immediately.
function dashboardLink(claimId: string): string {
  const query = `select * from public.claims_restaurants where id = '${claimId}';`;
  return `https://supabase.com/dashboard/project/${DASHBOARD_PROJECT_REF}/sql/new?content=${
    encodeURIComponent(query)
  }`;
}

function emailDomain(email: string): string | null {
  const at = email.lastIndexOf('@');
  if (at === -1) return null;
  return email.slice(at + 1).toLowerCase();
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
/// hand-rolled fakes (no mocking framework), mirroring delete-account's
/// exact convention. `Deno.serve` below wires this to the real
/// service-role client and the real Resend call; this function never
/// constructs either itself.
export async function handleRequest(
  req: Request,
  admin: NotifyClaimAdminClient,
  sendEmail: SendEmail,
  webhookSecret: string | undefined,
): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  // Checked before anything else, including body parsing — a caller
  // without the right secret learns nothing, not even whether the body
  // shape was valid.
  const providedSecret = req.headers.get('x-webhook-secret');
  if (!webhookSecret || providedSecret !== webhookSecret) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  let claim: ClaimPayload;
  try {
    claim = await req.json();
  } catch (_err) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }
  if (
    !claim ||
    typeof claim.id !== 'string' ||
    typeof claim.user_id !== 'string' ||
    typeof claim.restaurant_id !== 'string' ||
    typeof claim.role !== 'string' ||
    typeof claim.business_email !== 'string' ||
    typeof claim.phone !== 'string' ||
    typeof claim.requested_at !== 'string'
  ) {
    return jsonResponse({ error: 'Missing required claim fields' }, 400);
  }

  // Venue and claimant lookups are independent of each other and of the
  // claim row itself (already fully known from the payload) — best-
  // effort each: a lookup failure degrades the email's content, it never
  // blocks sending it. The claim insert this email is ABOUT has already
  // committed by the time this function runs at all.
  const [venueResult, profileResult, userResult] = await Promise.all([
    admin.from('restaurants_full').select('name, restaurant_code').eq('id', claim.restaurant_id)
      .maybeSingle(),
    admin.from('profiles').select('display_name, username').eq('id', claim.user_id).maybeSingle(),
    admin.auth.admin.getUserById(claim.user_id),
  ]);

  if (venueResult.error) {
    console.error('notify-venue-claim: venue lookup failed', {
      claimId: claim.id,
      restaurantId: claim.restaurant_id,
      message: venueResult.error.message,
    });
  }
  if (profileResult.error) {
    console.error('notify-venue-claim: profile lookup failed', {
      claimId: claim.id,
      userId: claim.user_id,
      message: profileResult.error.message,
    });
  }
  if (userResult.error) {
    console.error('notify-venue-claim: account email lookup failed', {
      claimId: claim.id,
      userId: claim.user_id,
      message: userResult.error.message,
    });
  }

  const venueName = (venueResult.data?.name as string | undefined) ?? 'Unknown venue';
  const restaurantCode = (venueResult.data?.restaurant_code as string | undefined) ??
    'unknown code';
  const displayName = (profileResult.data?.display_name as string | undefined) ??
    (profileResult.data?.username as string | undefined) ?? 'Unknown claimant';
  const accountEmail = userResult.data.user?.email ?? null;

  const businessDomain = emailDomain(claim.business_email);
  const accountDomain = accountEmail ? emailDomain(accountEmail) : null;
  const domainMismatch = accountDomain !== null && businessDomain !== null &&
    businessDomain !== accountDomain;

  const submittedAt = formatAmsterdamTime(claim.requested_at);
  const link = dashboardLink(claim.id);

  const subject = `New venue claim: ${venueName} (${restaurantCode})`;

  const mismatchLineText = domainMismatch
    ? `\n⚠ Domain mismatch: business email domain "${businessDomain}" differs from the ` +
      `claimant's account email domain "${accountDomain}". Worth a closer look.\n`
    : '';
  const mismatchLineHtml = domainMismatch
    ? `<p style="color:#b45309;font-weight:600;">⚠ Domain mismatch: business email domain ` +
      `"${escapeHtml(businessDomain!)}" differs from the claimant's account email domain ` +
      `"${escapeHtml(accountDomain!)}". Worth a closer look.</p>`
    : '';

  const text = `A new claim was submitted for ${venueName} (${restaurantCode}).

Claimant: ${displayName}
Account email: ${accountEmail ?? 'unknown'}
Business email: ${claim.business_email}
Role: ${claim.role}
Phone: ${claim.phone}
Notes: ${claim.notes && claim.notes.trim().length > 0 ? claim.notes : '—'}
${mismatchLineText}
Submitted: ${submittedAt} (Europe/Amsterdam)

Review in the dashboard: ${link}`;

  const html = `
    <p>A new claim was submitted for <strong>${escapeHtml(venueName)}</strong> (${
    escapeHtml(restaurantCode)
  }).</p>
    <table cellpadding="4" cellspacing="0">
      <tr><td><strong>Claimant</strong></td><td>${escapeHtml(displayName)}</td></tr>
      <tr><td><strong>Account email</strong></td><td>${
    escapeHtml(accountEmail ?? 'unknown')
  }</td></tr>
      <tr><td><strong>Business email</strong></td><td>${
    escapeHtml(claim.business_email)
  }</td></tr>
      <tr><td><strong>Role</strong></td><td>${escapeHtml(claim.role)}</td></tr>
      <tr><td><strong>Phone</strong></td><td>${escapeHtml(claim.phone)}</td></tr>
      <tr><td><strong>Notes</strong></td><td>${
    claim.notes && claim.notes.trim().length > 0 ? escapeHtml(claim.notes) : '—'
  }</td></tr>
    </table>
    ${mismatchLineHtml}
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
    console.error('notify-venue-claim: email send failed', {
      claimId: claim.id,
      restaurantId: claim.restaurant_id,
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

  // The real SupabaseClient's .from(table) is generic over a Database
  // type param this file never declares, which makes TypeScript's
  // structural check against the deliberately narrow NotifyClaimAdminClient
  // interface exceed its instantiation-depth limit (TS2589) — a type-
  // checker limitation, not a real incompatibility: the real client
  // genuinely has every method this interface names, with the exact
  // shapes used here. This cast is scoped to this one production wiring
  // line only; handleRequest's own signature, and every test's hand-
  // rolled fake, stay fully structurally typed with no cast anywhere else.
  return handleRequest(
    req,
    admin as unknown as NotifyClaimAdminClient,
    sendEmail,
    Deno.env.get('NOTIFY_VENUE_CLAIM_WEBHOOK_SECRET'),
  );
});
