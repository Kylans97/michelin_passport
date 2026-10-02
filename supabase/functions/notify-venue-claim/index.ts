// Notify Venue Claim — sends an admin-facing email the moment someone
// submits a restaurant, hotel, or private-chef claim, so a pending claim
// (which, since 20260928120000_harden_claims_restaurants_insert_rls.sql
// for restaurants and 20261007120000_genericize_venue_claim_admin_email_
// and_pending_indexes.sql for hotels/chefs, now blocks every other user
// from claiming that same venue) never sits unseen.
//
// Called ONLY by the generic claims-table insert trigger
// (notify_admin_of_pending_venue_claim(), added in
// 20261007120000_genericize_venue_claim_admin_email_and_pending_indexes.sql,
// replacing the restaurant-only notify_admin_of_pending_restaurant_claim()
// from 20260929120000_add_venue_claim_admin_email_notification.sql) via
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
//
// ------------------------------------------------------------
// TEMPORARY dual-payload tolerance — remove once the trigger migration
// is confirmed applied and no old-shape call can still be in flight.
// ------------------------------------------------------------
// The trigger function changed, in the same deploy window as this file,
// from sending the raw restaurant row (`to_jsonb(new)`, no envelope) to
// sending `{claim_type, row}`. A migration and an Edge Function deploy
// are two separate actions with no way to guarantee which lands first,
// so this function accepts BOTH shapes — an un-enveloped body is treated
// as a legacy claims_restaurants payload — mirroring the same rule
// CLAUDE.md now states for a shipped build reading a column mid-rename:
// during the transition both shapes must stay correct, not merely
// present. Removal condition: once
// 20261007120000_genericize_venue_claim_admin_email_and_pending_indexes.sql
// is applied in production, the trigger can never again send the old
// flat shape, and the `'claim_type' in body` branch below (plus the
// LegacyClaimPayload type and its handling) can be deleted outright.

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

// The claims_* row, sent verbatim as the trigger's own to_jsonb(new) —
// see the migration's own comment for why the full row is sent rather
// than just an id (avoids a second, redundant claims table lookup here,
// and is exactly the state at insert time with no race against a later
// update). Only one of restaurant_id/hotel_id/private_chef_id is ever
// present on a given row — which one is determined by claim_type.
export interface ClaimRow {
  id: string;
  user_id: string;
  restaurant_id?: string;
  hotel_id?: string;
  private_chef_id?: string;
  role: string;
  business_email: string;
  phone: string;
  notes: string | null;
  requested_at: string;
}

// The current (post-genericization) trigger payload shape: TG_TABLE_NAME
// plus the row, exactly mirroring notify_admin_of_pending_venue_submission's
// own envelope (20261004120000_add_venue_submission_admin_email_notification.sql).
export interface ClaimEnvelope {
  claim_type: string;
  row: ClaimRow;
}

// The pre-genericization shape — a bare claims_restaurants row with no
// envelope at all. Accepted only for the dual-payload tolerance window
// described above.
export type LegacyClaimPayload = ClaimRow;

interface ClaimTypeConfig {
  readonly viewName: string;
  readonly subjectIdField: 'restaurant_id' | 'hotel_id' | 'private_chef_id';
  // Column names on the venue's own `_full` view — deliberately NOT
  // uniform across the three. Restaurants and hotels share `name` plus a
  // stable `*_code`; private chefs have neither — only `display_name`
  // and `slug` (confirmed against the actual private_chefs table before
  // writing this, not assumed from the restaurant/hotel pair). Forcing a
  // shared column shape here would mean inventing a code private chefs
  // don't have.
  readonly nameColumn: string;
  readonly codeColumn: string;
  readonly venueLabel: string;
}

const CLAIM_TYPES: Record<string, ClaimTypeConfig> = {
  claims_restaurants: {
    viewName: 'restaurants_full',
    subjectIdField: 'restaurant_id',
    nameColumn: 'name',
    codeColumn: 'restaurant_code',
    venueLabel: 'restaurant',
  },
  claims_hotels: {
    viewName: 'hotels_full',
    subjectIdField: 'hotel_id',
    nameColumn: 'name',
    codeColumn: 'hotel_code',
    venueLabel: 'hotel',
  },
  claims_private_chefs: {
    viewName: 'private_chefs_full',
    subjectIdField: 'private_chef_id',
    nameColumn: 'display_name',
    codeColumn: 'slug',
    venueLabel: 'private chef',
  },
};

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
//
// tableName is always one of CLAIM_TYPES' own keys by the time this is
// called (claim_type is validated against that allow-list before any
// lookup happens), never attacker-controlled free text, so interpolating
// it directly here carries the same (non-)risk as the original
// hardcoded 'claims_restaurants' literal did.
function dashboardLink(tableName: string, claimId: string): string {
  const query = `select * from public.${tableName} where id = '${claimId}';`;
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

  let body: unknown;
  try {
    body = await req.json();
  } catch (_err) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  // Dual-payload tolerance (see file header): an enveloped body carries
  // its own claim_type; a bare body is the legacy claims_restaurants
  // shape with no envelope at all.
  let claimType: string;
  let claim: ClaimRow;
  if (body && typeof body === 'object' && 'claim_type' in body && 'row' in body) {
    const envelope = body as ClaimEnvelope;
    claimType = envelope.claim_type;
    claim = envelope.row;
  } else {
    claimType = 'claims_restaurants';
    claim = body as LegacyClaimPayload;
  }

  const config = CLAIM_TYPES[claimType];
  if (!config) {
    return jsonResponse({ error: `Unknown claim_type: ${claimType}` }, 400);
  }

  const subjectId = claim?.[config.subjectIdField];

  if (
    !claim ||
    typeof claim.id !== 'string' ||
    typeof claim.user_id !== 'string' ||
    typeof subjectId !== 'string' ||
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
    admin.from(config.viewName).select(`${config.nameColumn}, ${config.codeColumn}`).eq(
      'id',
      subjectId,
    ).maybeSingle(),
    admin.from('profiles').select('display_name, username').eq('id', claim.user_id).maybeSingle(),
    admin.auth.admin.getUserById(claim.user_id),
  ]);

  if (venueResult.error) {
    console.error('notify-venue-claim: venue lookup failed', {
      claimId: claim.id,
      claimType,
      subjectId,
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

  const venueName = (venueResult.data?.[config.nameColumn] as string | undefined) ??
    'Unknown venue';
  const venueCode = (venueResult.data?.[config.codeColumn] as string | undefined) ??
    'unknown code';
  const displayName = (profileResult.data?.display_name as string | undefined) ??
    (profileResult.data?.username as string | undefined) ?? 'Unknown claimant';
  const accountEmail = userResult.data.user?.email ?? null;

  const businessDomain = emailDomain(claim.business_email);
  const accountDomain = accountEmail ? emailDomain(accountEmail) : null;
  const domainMismatch = accountDomain !== null && businessDomain !== null &&
    businessDomain !== accountDomain;

  const submittedAt = formatAmsterdamTime(claim.requested_at);
  const link = dashboardLink(claimType, claim.id);

  const subject = `New ${config.venueLabel} claim: ${venueName} (${venueCode})`;

  const mismatchLineText = domainMismatch
    ? `\n⚠ Domain mismatch: business email domain "${businessDomain}" differs from the ` +
      `claimant's account email domain "${accountDomain}". Worth a closer look.\n`
    : '';
  const mismatchLineHtml = domainMismatch
    ? `<p style="color:#b45309;font-weight:600;">⚠ Domain mismatch: business email domain ` +
      `"${escapeHtml(businessDomain!)}" differs from the claimant's account email domain ` +
      `"${escapeHtml(accountDomain!)}". Worth a closer look.</p>`
    : '';

  const text = `A new ${config.venueLabel} claim was submitted for ${venueName} (${venueCode}).

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
    <p>A new ${escapeHtml(config.venueLabel)} claim was submitted for <strong>${
    escapeHtml(venueName)
  }</strong> (${escapeHtml(venueCode)}).</p>
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
      claimType,
      subjectId,
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
