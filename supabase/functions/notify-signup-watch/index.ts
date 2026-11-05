// Notify Signup Watch — the weekly admin email about sign-ups that look
// automated. Called ONLY by public.send_signup_watch() through pg_cron and
// pg_net (20261101360000_add_signup_watch.sql), never by the Flutter app.
// No user JWT in that context, so `verify_jwt = false` in config.toml and
// its own shared secret instead, same shape as notify-content-report.
//
// The report holds counts and, at most, uncommon email domains: no address
// and no user id. Domains come from what people typed at sign-up, so they
// are escaped like any other outside input.

export interface SharedDomain {
  domain: string;
  accounts: number;
}

export interface SignupWatchReport {
  until: string;
  signups: number;
  unconfirmed: number;
  weekly_average_before: number;
  busiest_hour: number;
  total_accounts: number;
  shared_domains: SharedDomain[];
  alias_groups: number;
  flags: string[];
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

const FLAG_MEANINGS: Record<string, string> = {
  many_signups: 'Far more sign-ups than the weeks before.',
  burst: '10 or more sign-ups in one hour.',
  unconfirmed: 'Many accounts that never confirmed their address.',
  shared_domain: '3 or more accounts on one uncommon email domain.',
  aliases: '3 or more accounts that are one mailbox.',
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function isReport(value: unknown): value is SignupWatchReport {
  const r = value as SignupWatchReport | null;
  return !!r &&
    typeof r.signups === 'number' &&
    typeof r.unconfirmed === 'number' &&
    typeof r.weekly_average_before === 'number' &&
    typeof r.busiest_hour === 'number' &&
    typeof r.total_accounts === 'number' &&
    typeof r.alias_groups === 'number' &&
    Array.isArray(r.shared_domains) &&
    Array.isArray(r.flags);
}

/// Testable core, with injected dependencies like the other notify
/// functions. `Deno.serve` below wires it to the real Resend call.
export async function handleRequest(
  req: Request,
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

  let report: unknown;
  try {
    report = await req.json();
  } catch (_err) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }
  if (!isReport(report)) {
    return jsonResponse({ error: 'Missing report fields' }, 400);
  }

  const flagged = report.flags.length > 0;
  const subject = flagged
    ? `Signup watch: take a look (${report.signups} sign-ups this week)`
    : `Signup watch: nothing unusual (${report.signups} sign-ups this week)`;

  const numbers: [string, string][] = [
    ['Sign-ups in the last 7 days', String(report.signups)],
    ['Not confirmed', String(report.unconfirmed)],
    ['Weekly average, 4 weeks before', String(report.weekly_average_before)],
    ['Busiest hour', String(report.busiest_hour)],
    ['Groups of accounts on one mailbox', String(report.alias_groups)],
    ['All accounts', String(report.total_accounts)],
  ];
  const flagLines = report.flags.map((flag) => FLAG_MEANINGS[flag] ?? flag);
  const domainLines = report.shared_domains.map((d) => `${d.domain}: ${d.accounts}`);

  const text = [
    flagged ? 'Something in this week\'s sign-ups is worth a look.' : 'Nothing unusual this week.',
    ...(flagged ? ['', ...flagLines.map((line) => `- ${line}`)] : []),
    '',
    ...numbers.map(([label, value]) => `${label}: ${value}`),
    ...(domainLines.length > 0 ? ['', 'Uncommon domains:', ...domainLines] : []),
    '',
    'A flag means look, not that something is wrong: a launch sets them off too. Nothing has been blocked or changed.',
  ].join('\n');

  const html = `
    <p>${flagged ? 'Something in this week\'s sign-ups is worth a look.' : 'Nothing unusual this week.'}</p>
    ${flagged ? `<ul>${flagLines.map((line) => `<li>${escapeHtml(line)}</li>`).join('')}</ul>` : ''}
    <table cellpadding="4" cellspacing="0">
      ${numbers.map(([label, value]) => `<tr><td><strong>${label}</strong></td><td>${value}</td></tr>`).join('')}
    </table>
    ${
    domainLines.length > 0
      ? `<p><strong>Uncommon domains</strong></p><ul>${
        domainLines.map((line) => `<li>${escapeHtml(line)}</li>`).join('')
      }</ul>`
      : ''
  }
    <p>A flag means look, not that something is wrong: a launch sets them off too. Nothing has been blocked or changed.</p>
  `;

  const result = await sendEmail({ from: FROM_EMAIL, to: ADMIN_EMAIL, subject, html, text });
  if (!result.ok) {
    console.error('notify-signup-watch: email send failed', { message: result.error });
    return jsonResponse({ error: 'Email send failed' }, 502);
  }
  return jsonResponse({ success: true }, 200);
}

Deno.serve((req) => {
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
  return handleRequest(req, sendEmail, Deno.env.get('NOTIFY_SIGNUP_WATCH_WEBHOOK_SECRET'));
});
