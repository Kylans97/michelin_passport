// Tests for the send-push Edge Function's testable core (handleRequest)
// and its APNs token signing. Hand-rolled fakes only, no mocking
// framework — same convention as notify-venue-claim/index.test.ts.

import { assert, assertEquals } from 'jsr:@std/assert@1';
import {
  type ApnsMessage,
  type ApnsResult,
  createApnsJwt,
  type DeviceRow,
  type EventContent,
  followedVenueEventCopy,
  formatEventDate,
  friendRequestCopy,
  handleRequest,
  type NotificationRow,
  type PreferenceRow,
  type PushStore,
} from './index.ts';

const SECRET = 'test-webhook-secret';
const NOW = new Date('2026-10-30T12:00:00Z');

function req(opts: { method?: string; body?: unknown; rawBody?: string; secret?: string | null } = {}) {
  const method = opts.method ?? 'POST';
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (opts.secret !== null) headers.set('x-webhook-secret', opts.secret ?? SECRET);
  return new Request('http://localhost/send-push', {
    method,
    headers,
    body: method === 'GET' ? undefined : opts.rawBody ?? JSON.stringify(opts.body ?? { notification_ids: ['n1'] }),
  });
}

class FakeStore implements PushStore {
  notifications: NotificationRow[] = [];
  preferences: PreferenceRow[] = [];
  devices: DeviceRow[] = [];
  requesterName: string | null = 'Anna';
  event: EventContent | null = { eventName: 'Four Hands Dinner', startDate: '2026-11-14', hostName: 'Hof van Cleve' };
  deleted: string[] = [];
  environmentChanges: Array<[string, string]> = [];
  eventLookups = 0;
  lookups = 0;

  loadNotifications(ids: string[]) {
    this.lookups++;
    return Promise.resolve(this.notifications.filter((n) => ids.includes(n.id)));
  }
  loadPreferences(userIds: string[]) {
    return Promise.resolve(this.preferences.filter((p) => userIds.includes(p.user_id)));
  }
  loadDevices(userIds: string[]) {
    return Promise.resolve(this.devices.filter((d) => userIds.includes(d.user_id)));
  }
  friendRequesterName(_id: string) {
    return Promise.resolve(this.requesterName);
  }
  eventContent(_id: string) {
    this.eventLookups++;
    return Promise.resolve(this.event);
  }
  deleteDevice(token: string) {
    this.deleted.push(token);
    return Promise.resolve();
  }
  setDeviceEnvironment(token: string, env: string) {
    this.environmentChanges.push([token, env]);
    return Promise.resolve();
  }
}

function recordingApns(respond: (m: ApnsMessage) => ApnsResult = () => ({ status: 200 })) {
  const sent: ApnsMessage[] = [];
  return {
    sent,
    send: (m: ApnsMessage) => {
      sent.push(m);
      return Promise.resolve(respond(m));
    },
  };
}

const FRIEND_REQUEST: NotificationRow = {
  id: 'n1',
  recipient_id: 'u1',
  type: 'friend_request_received',
  subject_id: 'f1',
};
const DEVICE: DeviceRow = { user_id: 'u1', token: 'aa'.repeat(32), apns_environment: 'production' };

Deno.test('a non-POST method is rejected', async () => {
  const res = await handleRequest(req({ method: 'GET' }), new FakeStore(), recordingApns().send, SECRET);
  assertEquals(res.status, 405);
});

Deno.test('a missing or wrong secret is rejected before any lookup', async () => {
  const store = new FakeStore();
  for (const secret of [null, 'wrong']) {
    const res = await handleRequest(req({ secret }), store, recordingApns().send, SECRET);
    assertEquals(res.status, 401);
  }
  assertEquals(store.lookups, 0);
});

Deno.test('an unconfigured secret rejects every request, never falls open', async () => {
  const res = await handleRequest(req(), new FakeStore(), recordingApns().send, undefined);
  assertEquals(res.status, 401);
});

Deno.test('invalid JSON and a malformed id list are rejected with 400', async () => {
  const store = new FakeStore();
  const bad = await handleRequest(req({ rawBody: '{' }), store, recordingApns().send, SECRET);
  assertEquals(bad.status, 400);
  const notArray = await handleRequest(req({ body: { notification_ids: 'n1' } }), store, recordingApns().send, SECRET);
  assertEquals(notArray.status, 400);
  const notStrings = await handleRequest(req({ body: { notification_ids: [1] } }), store, recordingApns().send, SECRET);
  assertEquals(notStrings.status, 400);
});

Deno.test('a friend request is pushed with the sender name and a deep-link payload', async () => {
  const store = new FakeStore();
  store.notifications = [FRIEND_REQUEST];
  store.devices = [DEVICE];
  const apns = recordingApns();
  const res = await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).sent, 1);
  assertEquals(apns.sent.length, 1);
  const payload = apns.sent[0].payload as Record<string, unknown>;
  assertEquals((payload.aps as { alert: unknown }).alert, { body: 'Anna sent you a friend request.' });
  assertEquals(payload.notification_id, 'n1');
  assertEquals(payload.type, 'friend_request_received');
  assertEquals(payload.subject_id, 'f1');
  assertEquals(apns.sent[0].environment, 'production');
});

Deno.test('a type that is not push-worthy is never sent', async () => {
  const store = new FakeStore();
  store.notifications = [{ ...FRIEND_REQUEST, type: 'venue_claim_approved' }];
  store.devices = [DEVICE];
  const apns = recordingApns();
  await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals(apns.sent.length, 0);
});

Deno.test('no preference row means the default, which is on', async () => {
  const store = new FakeStore();
  store.notifications = [FRIEND_REQUEST];
  store.devices = [DEVICE];
  const apns = recordingApns();
  await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals(apns.sent.length, 1);
});

Deno.test('a toggle turned off stops only its own type', async () => {
  const store = new FakeStore();
  store.notifications = [
    FRIEND_REQUEST,
    { id: 'n2', recipient_id: 'u1', type: 'followed_venue_event', subject_id: 'e1' },
  ];
  store.devices = [DEVICE];
  store.preferences = [{ user_id: 'u1', push_friend_requests: false, push_followed_venue_events: true }];
  const apns = recordingApns();
  await handleRequest(req({ body: { notification_ids: ['n1', 'n2'] } }), store, apns.send, SECRET, NOW);
  assertEquals(apns.sent.length, 1);
  assertEquals((apns.sent[0].payload as { type: string }).type, 'followed_venue_event');
});

Deno.test('a recipient with no devices is skipped without error', async () => {
  const store = new FakeStore();
  store.notifications = [FRIEND_REQUEST];
  const apns = recordingApns();
  const res = await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals(res.status, 200);
  assertEquals(apns.sent.length, 0);
});

Deno.test('a fan-out batch resolves the event once and pushes every device', async () => {
  const store = new FakeStore();
  store.notifications = ['u1', 'u2', 'u3'].map((u, i) => ({
    id: `n${i}`,
    recipient_id: u,
    type: 'followed_venue_event',
    subject_id: 'e1',
  }));
  store.devices = [
    { ...DEVICE, user_id: 'u1' },
    { user_id: 'u2', token: 'bb'.repeat(32), apns_environment: 'sandbox' },
    { user_id: 'u2', token: 'cc'.repeat(32), apns_environment: 'production' },
  ];
  const apns = recordingApns();
  await handleRequest(req({ body: { notification_ids: ['n0', 'n1', 'n2'] } }), store, apns.send, SECRET, NOW);
  assertEquals(store.eventLookups, 1);
  assertEquals(apns.sent.length, 3);
  assertEquals((apns.sent[0].payload as { aps: { alert: unknown } }).aps.alert, {
    title: 'Hof van Cleve',
    body: 'Four Hands Dinner · 14 November',
  });
});

Deno.test('an event that can no longer be found sends nothing', async () => {
  const store = new FakeStore();
  store.event = null;
  store.notifications = [{ id: 'n1', recipient_id: 'u1', type: 'followed_venue_event', subject_id: 'e1' }];
  store.devices = [DEVICE];
  const apns = recordingApns();
  await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals(apns.sent.length, 0);
});

Deno.test('an Unregistered token is deleted', async () => {
  const store = new FakeStore();
  store.notifications = [FRIEND_REQUEST];
  store.devices = [DEVICE];
  const apns = recordingApns(() => ({ status: 410, reason: 'Unregistered' }));
  const res = await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals((await res.json()).sent, 0);
  assertEquals(store.deleted, [DEVICE.token]);
});

Deno.test('a BadDeviceToken is retried on the other environment and corrected', async () => {
  const store = new FakeStore();
  store.notifications = [FRIEND_REQUEST];
  store.devices = [DEVICE];
  const apns = recordingApns((m) =>
    m.environment === 'production' ? { status: 400, reason: 'BadDeviceToken' } : { status: 200 }
  );
  const res = await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals((await res.json()).sent, 1);
  assertEquals(apns.sent.map((m) => m.environment), ['production', 'sandbox']);
  assertEquals(store.environmentChanges, [[DEVICE.token, 'sandbox']]);
  assertEquals(store.deleted, []);
});

Deno.test('a BadDeviceToken on both environments deletes the token', async () => {
  const store = new FakeStore();
  store.notifications = [FRIEND_REQUEST];
  store.devices = [DEVICE];
  const apns = recordingApns(() => ({ status: 400, reason: 'BadDeviceToken' }));
  await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals(store.deleted, [DEVICE.token]);
});

Deno.test('any other APNs error keeps the token', async () => {
  const store = new FakeStore();
  store.notifications = [FRIEND_REQUEST];
  store.devices = [DEVICE];
  const apns = recordingApns(() => ({ status: 429, reason: 'TooManyRequests' }));
  await handleRequest(req(), store, apns.send, SECRET, NOW);
  assertEquals(store.deleted, []);
});

Deno.test('copy: a missing name and a host-less event still read well', () => {
  assertEquals(friendRequestCopy(null).body, 'Someone sent you a friend request.');
  assertEquals(
    followedVenueEventCopy({ eventName: 'Gala', startDate: '2027-01-09', hostName: null }, NOW),
    { title: 'A new event', body: 'Gala · 9 January 2027' },
  );
});

Deno.test('event dates are the event\'s own local date, never shifted', () => {
  assertEquals(formatEventDate('2026-12-31', NOW), '31 December');
  assertEquals(formatEventDate('2027-01-01', NOW), '1 January 2027');
});

Deno.test('the APNs provider token is a verifiable ES256 JWT', async () => {
  const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
  let binary = '';
  for (const b of der) binary += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(binary)}\n-----END PRIVATE KEY-----`;

  const jwt = await createApnsJwt(pem, 'KEY123', 'TEAM456', 1_800_000_000);
  const [h, c, s] = jwt.split('.');
  const decode = (part: string) =>
    Uint8Array.from(atob(part.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - part.length % 4) % 4)), (ch) => ch.charCodeAt(0));
  assertEquals(JSON.parse(new TextDecoder().decode(decode(h))), { alg: 'ES256', kid: 'KEY123' });
  assertEquals(JSON.parse(new TextDecoder().decode(decode(c))), { iss: 'TEAM456', iat: 1_800_000_000 });
  const ok = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    pair.publicKey,
    decode(s),
    new TextEncoder().encode(`${h}.${c}`),
  );
  assert(ok);
});
