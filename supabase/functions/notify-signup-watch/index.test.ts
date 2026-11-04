// Tests for the notify-signup-watch Edge Function's testable core
// (handleRequest). Hand-rolled fakes only, same as the other notify
// functions.

import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { type EmailMessage, handleRequest, type SendEmail } from './index.ts';

const SECRET = 'test-webhook-secret';

const QUIET = {
  until: '2026-11-09T07:00:00Z',
  signups: 3,
  unconfirmed: 0,
  weekly_average_before: 2.5,
  busiest_hour: 1,
  total_accounts: 28,
  shared_domains: [],
  alias_groups: 0,
  flags: [],
};

function req(body: unknown, secret: string | null = SECRET, method = 'POST'): Request {
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (secret !== null) headers.set('x-webhook-secret', secret);
  return new Request('http://localhost/notify-signup-watch', {
    method,
    headers,
    body: method === 'POST' ? JSON.stringify(body) : undefined,
  });
}

function recorder(ok = true): { sent: EmailMessage[]; send: SendEmail } {
  const sent: EmailMessage[] = [];
  return {
    sent,
    send: (message) => {
      sent.push(message);
      return Promise.resolve(ok ? { ok: true } : { ok: false, error: 'down' });
    },
  };
}

Deno.test('a quiet week still sends, and says so', async () => {
  const mail = recorder();
  const res = await handleRequest(req(QUIET), mail.send, SECRET);
  assertEquals(res.status, 200);
  assertEquals(mail.sent.length, 1);
  assertStringIncludes(mail.sent[0].subject, 'nothing unusual');
  assertStringIncludes(mail.sent[0].text, 'Sign-ups in the last 7 days: 3');
});

Deno.test('flags are spelled out and domains listed', async () => {
  const mail = recorder();
  await handleRequest(
    req({
      ...QUIET,
      signups: 40,
      flags: ['many_signups', 'shared_domain'],
      shared_domains: [{ domain: 'tempmail.test', accounts: 30 }],
    }),
    mail.send,
    SECRET,
  );
  const { subject, text, html } = mail.sent[0];
  assertStringIncludes(subject, 'take a look');
  assertStringIncludes(text, 'Far more sign-ups');
  assertStringIncludes(text, 'tempmail.test: 30');
  assertStringIncludes(html, 'tempmail.test: 30');
});

Deno.test('a domain is outside input and is escaped in the html', async () => {
  const mail = recorder();
  await handleRequest(
    req({
      ...QUIET,
      flags: ['shared_domain'],
      shared_domains: [{ domain: '<img src=x>.test', accounts: 3 }],
    }),
    mail.send,
    SECRET,
  );
  assert(!mail.sent[0].html.includes('<img'));
  assertStringIncludes(mail.sent[0].html, '&lt;img src=x&gt;.test');
});

Deno.test('a wrong or missing secret sends nothing', async () => {
  for (const secret of ['wrong', null]) {
    const mail = recorder();
    const res = await handleRequest(req(QUIET, secret), mail.send, SECRET);
    assertEquals(res.status, 401);
    assertEquals(mail.sent.length, 0);
  }
  const mail = recorder();
  const res = await handleRequest(req(QUIET), mail.send, undefined);
  assertEquals(res.status, 401);
  assertEquals(mail.sent.length, 0);
});

Deno.test('anything but a POST with a whole report is refused', async () => {
  const mail = recorder();
  assertEquals((await handleRequest(req(null, SECRET, 'GET'), mail.send, SECRET)).status, 405);
  assertEquals((await handleRequest(req({ signups: 3 }), mail.send, SECRET)).status, 400);
  assertEquals(mail.sent.length, 0);
});

Deno.test('a failed send is a 502', async () => {
  const res = await handleRequest(req(QUIET), recorder(false).send, SECRET);
  assertEquals(res.status, 502);
});
