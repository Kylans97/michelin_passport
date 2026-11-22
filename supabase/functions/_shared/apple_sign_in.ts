// Sign in with Apple, server side: the client secret Apple's REST API
// wants, exchanging a one-time authorization code for a refresh token,
// and revoking that token. Used by apple-token (after a native sign-in)
// and delete-account (before deleting the user), which App Review
// requires for apps that offer Sign in with Apple.
//
// Configuration, as Edge Function secrets:
//   APPLE_SIGNIN_KEY_P8, APPLE_SIGNIN_KEY_ID  a key with Sign in with
//     Apple enabled; when unset, APNS_KEY_P8 / APNS_KEY_ID are used, which
//     works once Sign in with Apple is also enabled on the push key.
//   APPLE_TEAM_ID                            else APNS_TEAM_ID
//   APPLE_SIGNIN_CLIENT_ID                   else 'app.mantelier' (the
//     bundle ID, the audience of a native sign-in's tokens)

const APPLE = 'https://appleid.apple.com';

export interface AppleConfig {
  p8: string;
  keyId: string;
  teamId: string;
  clientId: string;
}

export function appleConfig(env: (name: string) => string | undefined): AppleConfig | null {
  const p8 = env('APPLE_SIGNIN_KEY_P8') ?? env('APNS_KEY_P8');
  const keyId = env('APPLE_SIGNIN_KEY_ID') ?? env('APNS_KEY_ID');
  const teamId = env('APPLE_TEAM_ID') ?? env('APNS_TEAM_ID');
  const clientId = env('APPLE_SIGNIN_CLIENT_ID') ?? 'app.mantelier';
  if (!p8 || !keyId || !teamId) return null;
  return { p8, keyId, teamId, clientId };
}

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

/// The client secret Apple's token and revoke endpoints take: an ES256
/// JWT, issuer the team, subject the client ID, audience Apple, valid for
/// five minutes (each call makes its own).
export async function createClientSecret(config: AppleConfig, issuedAt: number): Promise<string> {
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(config.p8),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const enc = new TextEncoder();
  const header = base64UrlEncode(enc.encode(JSON.stringify({ alg: 'ES256', kid: config.keyId })));
  const claims = base64UrlEncode(enc.encode(JSON.stringify({
    iss: config.teamId,
    iat: issuedAt,
    exp: issuedAt + 300,
    aud: APPLE,
    sub: config.clientId,
  })));
  const signingInput = `${header}.${claims}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, enc.encode(signingInput)),
  );
  return `${signingInput}.${base64UrlEncode(signature)}`;
}

type Fetch = typeof fetch;

/// The refresh token for a one-time authorization code, or null when Apple
/// refuses it (an expired or reused code).
export async function exchangeCode(
  config: AppleConfig,
  code: string,
  fetchImpl: Fetch = fetch,
  now = Math.floor(Date.now() / 1000),
): Promise<string | null> {
  const res = await fetchImpl(`${APPLE}/auth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: config.clientId,
      client_secret: await createClientSecret(config, now),
      code,
      grant_type: 'authorization_code',
    }),
  });
  if (!res.ok) {
    console.error('apple: token exchange refused', { status: res.status, body: await res.text() });
    return null;
  }
  const json = await res.json() as { refresh_token?: string };
  return json.refresh_token ?? null;
}

/// Revokes a refresh token. True when Apple accepted it.
export async function revokeRefreshToken(
  config: AppleConfig,
  refreshToken: string,
  fetchImpl: Fetch = fetch,
  now = Math.floor(Date.now() / 1000),
): Promise<boolean> {
  const res = await fetchImpl(`${APPLE}/auth/revoke`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: config.clientId,
      client_secret: await createClientSecret(config, now),
      token: refreshToken,
      token_type_hint: 'refresh_token',
    }),
  });
  if (!res.ok) {
    console.error('apple: revoke refused', { status: res.status, body: await res.text() });
  }
  return res.ok;
}
