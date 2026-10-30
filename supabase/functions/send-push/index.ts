// Send Push — delivers push-worthy in-app notifications to the
// recipient's iPhones through APNs, directly (no Firebase).
//
// Called ONLY by notify_push_for_notifications(), the statement-level
// insert trigger on public.notifications
// (20261030130000_add_push_notifications.sql), via pg_net. Same shape as
// every notify-* function: no user JWT in that calling context, so
// `verify_jwt = false` in config.toml and the x-webhook-secret header is
// checked against SEND_PUSH_WEBHOOK_SECRET before anything else runs.
//
// The body carries only notification ids. Everything else — the type,
// the recipient, their preferences, their device tokens, the copy — is
// read here with service_role, so the in-app row stays the single record
// and nothing personal sits in pg_net's request table.
//
// Best-effort by construction: the trigger queues the call asynchronously
// and in its own exception block, so nothing here can roll back the
// notification insert. Failures surface as console.error in this
// function's logs (Dashboard -> Edge Functions -> send-push -> Logs).
//
// APNs: HTTP/2 to api.push.apple.com (or the sandbox host), token-based
// auth — an ES256 JWT signed with the .p8 key in APNS_KEY_P8, cached for
// 50 minutes (Apple accepts 20–60). A token APNs reports as gone
// (410 Unregistered) is deleted. A BadDeviceToken is first retried on the
// other environment, since the app's own sandbox/production report can be
// wrong for a build signed differently than expected; if that works the
// row's environment is corrected, otherwise the token is deleted.

import { createClient } from 'jsr:@supabase/supabase-js@2';

export type PushType = 'friend_request_received' | 'followed_venue_event';
export type ApnsEnvironment = 'sandbox' | 'production';

export interface NotificationRow {
  id: string;
  recipient_id: string;
  type: string;
  subject_id: string;
}

export interface PreferenceRow {
  user_id: string;
  push_friend_requests: boolean;
  push_followed_venue_events: boolean;
}

export interface DeviceRow {
  user_id: string;
  token: string;
  apns_environment: ApnsEnvironment;
}

export interface EventContent {
  eventName: string;
  startDate: string; // yyyy-mm-dd, the event's own local date
  hostName: string | null;
}

/// Every read and write this function makes, behind one narrow interface
/// so tests use a hand-rolled fake (same convention as the notify-*
/// functions' admin-client interfaces) rather than a query-builder mock.
export interface PushStore {
  loadNotifications(ids: string[]): Promise<NotificationRow[]>;
  loadPreferences(userIds: string[]): Promise<PreferenceRow[]>;
  loadDevices(userIds: string[]): Promise<DeviceRow[]>;
  friendRequesterName(friendshipId: string): Promise<string | null>;
  eventContent(eventId: string): Promise<EventContent | null>;
  deleteDevice(token: string): Promise<void>;
  setDeviceEnvironment(token: string, environment: ApnsEnvironment): Promise<void>;
}

export interface ApnsMessage {
  token: string;
  environment: ApnsEnvironment;
  payload: Record<string, unknown>;
  collapseId?: string;
}

export interface ApnsResult {
  status: number;
  reason?: string;
}

export type SendApns = (message: ApnsMessage) => Promise<ApnsResult>;

const PUSH_TYPES: ReadonlySet<string> = new Set(['friend_request_received', 'followed_venue_event']);

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function wantsPush(type: PushType, pref: PreferenceRow | undefined): boolean {
  // No row means the defaults, which are on.
  if (!pref) return true;
  return type === 'friend_request_received'
    ? pref.push_friend_requests
    : pref.push_followed_venue_events;
}

/// "14 November", or "14 November 2027" when the event is not this year.
/// The date is the event's own local date, rendered as is — never shifted
/// into anyone's timezone.
export function formatEventDate(isoDate: string, now: Date = new Date()): string {
  const [y, m, d] = isoDate.split('-').map(Number);
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const base = `${d} ${months[m - 1]}`;
  return y === now.getUTCFullYear() ? base : `${base} ${y}`;
}

export interface PushCopy {
  title?: string;
  body: string;
}

export function friendRequestCopy(name: string | null): PushCopy {
  return { body: `${name ?? 'Someone'} sent you a friend request.` };
}

export function followedVenueEventCopy(event: EventContent, now: Date = new Date()): PushCopy {
  return {
    title: event.hostName ?? 'A new event',
    body: `${event.eventName} · ${formatEventDate(event.startDate, now)}`,
  };
}

function buildPayload(n: NotificationRow, copy: PushCopy): Record<string, unknown> {
  const alert: Record<string, string> = { body: copy.body };
  if (copy.title) alert.title = copy.title;
  return {
    aps: { alert, sound: 'default', 'thread-id': n.type },
    notification_id: n.id,
    type: n.type,
    subject_id: n.subject_id,
  };
}

function otherEnvironment(env: ApnsEnvironment): ApnsEnvironment {
  return env === 'production' ? 'sandbox' : 'production';
}

async function deliver(
  store: PushStore,
  sendApns: SendApns,
  device: DeviceRow,
  payload: Record<string, unknown>,
  collapseId: string,
): Promise<boolean> {
  const first = await sendApns({
    token: device.token,
    environment: device.apns_environment,
    payload,
    collapseId,
  });
  if (first.status === 200) return true;

  if (first.status === 410 || first.reason === 'Unregistered') {
    await store.deleteDevice(device.token);
    return false;
  }

  if (first.reason === 'BadDeviceToken') {
    const env = otherEnvironment(device.apns_environment);
    const retry = await sendApns({ token: device.token, environment: env, payload, collapseId });
    if (retry.status === 200) {
      await store.setDeviceEnvironment(device.token, env);
      return true;
    }
    await store.deleteDevice(device.token);
    return false;
  }

  console.error('send-push: APNs rejected a push', {
    status: first.status,
    reason: first.reason,
    environment: device.apns_environment,
  });
  return false;
}

/// The testable core. `Deno.serve` below wires the real store and the
/// real APNs call.
export async function handleRequest(
  req: Request,
  store: PushStore,
  sendApns: SendApns,
  webhookSecret: string | undefined,
  now: Date = new Date(),
): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const providedSecret = req.headers.get('x-webhook-secret');
  if (!webhookSecret || providedSecret !== webhookSecret) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  let body: { notification_ids?: unknown };
  try {
    body = await req.json();
  } catch (_err) {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }
  const ids = body?.notification_ids;
  if (!Array.isArray(ids) || ids.some((id) => typeof id !== 'string')) {
    return jsonResponse({ error: 'notification_ids must be an array of strings' }, 400);
  }
  if (ids.length === 0) {
    return jsonResponse({ sent: 0 }, 200);
  }

  const notifications = (await store.loadNotifications(ids as string[]))
    .filter((n) => PUSH_TYPES.has(n.type));
  if (notifications.length === 0) {
    return jsonResponse({ sent: 0 }, 200);
  }

  const recipientIds = [...new Set(notifications.map((n) => n.recipient_id))];
  const [prefs, devices] = await Promise.all([
    store.loadPreferences(recipientIds),
    store.loadDevices(recipientIds),
  ]);
  const prefByUser = new Map(prefs.map((p) => [p.user_id, p]));
  const devicesByUser = new Map<string, DeviceRow[]>();
  for (const d of devices) {
    const list = devicesByUser.get(d.user_id) ?? [];
    list.push(d);
    devicesByUser.set(d.user_id, list);
  }

  // A fan-out batch is many notifications about one event: resolve each
  // subject's copy once, not once per recipient.
  const eventCache = new Map<string, EventContent | null>();

  let sent = 0;
  for (const n of notifications) {
    const type = n.type as PushType;
    if (!wantsPush(type, prefByUser.get(n.recipient_id))) continue;
    const targets = devicesByUser.get(n.recipient_id);
    if (!targets || targets.length === 0) continue;

    let copy: PushCopy;
    if (type === 'friend_request_received') {
      copy = friendRequestCopy(await store.friendRequesterName(n.subject_id));
    } else {
      if (!eventCache.has(n.subject_id)) {
        eventCache.set(n.subject_id, await store.eventContent(n.subject_id));
      }
      const event = eventCache.get(n.subject_id);
      if (!event) {
        console.error('send-push: event not found for notification', { notificationId: n.id });
        continue;
      }
      copy = followedVenueEventCopy(event, now);
    }

    const payload = buildPayload(n, copy);
    for (const device of targets) {
      try {
        if (await deliver(store, sendApns, device, payload, n.id)) sent++;
      } catch (err) {
        console.error('send-push: delivery failed', {
          notificationId: n.id,
          message: err instanceof Error ? err.message : String(err),
        });
      }
    }
  }

  return jsonResponse({ sent }, 200);
}

// ── APNs authentication ──────────────────────────────────────────────────

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

/// The provider token APNs expects: an ES256 JWT with the key id in the
/// header and the team id as issuer. WebCrypto's ECDSA signature is
/// already the raw r||s form JWS uses, so no DER conversion is needed.
export async function createApnsJwt(
  p8: string,
  keyId: string,
  teamId: string,
  issuedAt: number,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(p8),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const enc = new TextEncoder();
  const header = base64UrlEncode(enc.encode(JSON.stringify({ alg: 'ES256', kid: keyId })));
  const claims = base64UrlEncode(enc.encode(JSON.stringify({ iss: teamId, iat: issuedAt })));
  const signingInput = `${header}.${claims}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, enc.encode(signingInput)),
  );
  return `${signingInput}.${base64UrlEncode(signature)}`;
}

let cachedJwt: { value: string; issuedAt: number } | null = null;

async function providerToken(p8: string, keyId: string, teamId: string): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (!cachedJwt || nowSeconds - cachedJwt.issuedAt > 50 * 60) {
    cachedJwt = { value: await createApnsJwt(p8, keyId, teamId, nowSeconds), issuedAt: nowSeconds };
  }
  return cachedJwt.value;
}

// ── Production wiring ────────────────────────────────────────────────────

function supabaseStore(): PushStore {
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  const fail = (what: string, error: { message: string }) => {
    throw new Error(`${what}: ${error.message}`);
  };

  return {
    async loadNotifications(ids) {
      const { data, error } = await admin.from('notifications')
        .select('id, recipient_id, type, subject_id').in('id', ids);
      if (error) fail('notifications lookup', error);
      return (data ?? []) as NotificationRow[];
    },
    async loadPreferences(userIds) {
      const { data, error } = await admin.from('notification_preferences')
        .select('user_id, push_friend_requests, push_followed_venue_events').in('user_id', userIds);
      if (error) fail('preferences lookup', error);
      return (data ?? []) as PreferenceRow[];
    },
    async loadDevices(userIds) {
      const { data, error } = await admin.from('push_devices')
        .select('user_id, token, apns_environment').in('user_id', userIds);
      if (error) fail('devices lookup', error);
      return (data ?? []) as DeviceRow[];
    },
    async friendRequesterName(friendshipId) {
      const { data: f, error } = await admin.from('friendships')
        .select('requester_id').eq('id', friendshipId).maybeSingle();
      if (error || !f) return null;
      const { data: p } = await admin.from('profiles')
        .select('display_name, username').eq('id', f.requester_id).maybeSingle();
      return (p?.display_name as string | undefined) ?? (p?.username as string | undefined) ?? null;
    },
    async eventContent(eventId) {
      const { data: e, error } = await admin.from('events')
        .select('name, start_date').eq('id', eventId).maybeSingle();
      if (error || !e) return null;
      // The host's name, read from the link tables directly rather than
      // through event_host_venue(), whose execute is revoked from
      // everyone but its owner (20261018130000).
      const hosts: Array<[string, string, string]> = [
        ['event_restaurants', 'restaurants', 'name'],
        ['event_hotels', 'hotels', 'name'],
        ['event_chefs', 'private_chefs', 'display_name'],
      ];
      let hostName: string | null = null;
      for (const [linkTable, venueTable, nameColumn] of hosts) {
        const { data } = await admin.from(linkTable)
          .select(`${venueTable}(${nameColumn})`)
          .eq('event_id', eventId).eq('is_host', true).not('approved_at', 'is', null)
          .limit(1).maybeSingle();
        const venue = (data as Record<string, Record<string, string> | null> | null)?.[venueTable];
        if (venue?.[nameColumn]) {
          hostName = venue[nameColumn];
          break;
        }
      }
      return { eventName: e.name as string, startDate: e.start_date as string, hostName };
    },
    async deleteDevice(token) {
      const { error } = await admin.from('push_devices').delete().eq('token', token);
      if (error) console.error('send-push: could not delete a dead token', { message: error.message });
    },
    async setDeviceEnvironment(token, environment) {
      const { error } = await admin.from('push_devices')
        .update({ apns_environment: environment }).eq('token', token);
      if (error) console.error('send-push: could not correct a token environment', { message: error.message });
    },
  };
}

function apnsSender(): SendApns {
  const p8 = Deno.env.get('APNS_KEY_P8');
  const keyId = Deno.env.get('APNS_KEY_ID');
  const teamId = Deno.env.get('APNS_TEAM_ID');
  const topic = Deno.env.get('APNS_BUNDLE_ID');
  return async ({ token, environment, payload, collapseId }) => {
    if (!p8 || !keyId || !teamId || !topic) {
      return { status: 500, reason: 'APNs secrets are not configured' };
    }
    const host = environment === 'production'
      ? 'https://api.push.apple.com'
      : 'https://api.sandbox.push.apple.com';
    const headers: Record<string, string> = {
      authorization: `bearer ${await providerToken(p8, keyId, teamId)}`,
      'apns-topic': topic,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    };
    if (collapseId) headers['apns-collapse-id'] = collapseId;
    const res = await fetch(`${host}/3/device/${token}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });
    if (res.status === 200) {
      await res.body?.cancel();
      return { status: 200 };
    }
    let reason: string | undefined;
    try {
      reason = (await res.json()).reason;
    } catch (_err) {
      reason = undefined;
    }
    return { status: res.status, reason };
  };
}

Deno.serve((req) =>
  handleRequest(req, supabaseStore(), apnsSender(), Deno.env.get('SEND_PUSH_WEBHOOK_SECRET'))
);
