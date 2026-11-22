import { assert, assertEquals } from 'jsr:@std/assert@1';
import {
  appleConfig,
  createClientSecret,
  exchangeCode,
  revokeRefreshToken,
} from './apple_sign_in.ts';

async function testKeyPem(): Promise<string> {
  const pair = await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
  let binary = '';
  for (const b of der) binary += String.fromCharCode(b);
  return `-----BEGIN PRIVATE KEY-----\n${btoa(binary)}\n-----END PRIVATE KEY-----`;
}

function decode(part: string): Record<string, unknown> {
  const b64 = part.replace(/-/g, '+').replace(/_/g, '/');
  return JSON.parse(atob(b64 + '='.repeat((4 - b64.length % 4) % 4)));
}

Deno.test('config falls back to the push key and the bundle ID', () => {
  const env: Record<string, string> = {
    APNS_KEY_P8: 'p8',
    APNS_KEY_ID: 'K1',
    APNS_TEAM_ID: 'T1',
  };
  assertEquals(appleConfig((n) => env[n]), {
    p8: 'p8',
    keyId: 'K1',
    teamId: 'T1',
    clientId: 'app.mantelier',
  });
  env.APPLE_SIGNIN_KEY_ID = 'K2';
  env.APPLE_SIGNIN_KEY_P8 = 'p8b';
  assertEquals(appleConfig((n) => env[n])?.keyId, 'K2');
  assertEquals(appleConfig(() => undefined), null);
});

Deno.test('client secret carries what Apple checks', async () => {
  const config = { p8: await testKeyPem(), keyId: 'KEY1', teamId: 'TEAM1', clientId: 'app.mantelier' };
  const jwt = await createClientSecret(config, 1000);
  const [header, claims, signature] = jwt.split('.');
  assertEquals(decode(header), { alg: 'ES256', kid: 'KEY1' });
  assertEquals(decode(claims), {
    iss: 'TEAM1',
    iat: 1000,
    exp: 1300,
    aud: 'https://appleid.apple.com',
    sub: 'app.mantelier',
  });
  assert(signature.length > 0);
});

Deno.test('exchange posts the code and returns the refresh token', async () => {
  const config = { p8: await testKeyPem(), keyId: 'K', teamId: 'T', clientId: 'app.mantelier' };
  let seen: { url: string; body: URLSearchParams } | null = null;
  const fakeFetch = (async (url: string, init: RequestInit) => {
    seen = { url, body: init.body as URLSearchParams };
    return new Response(JSON.stringify({ refresh_token: 'r1' }), { status: 200 });
  }) as unknown as typeof fetch;
  assertEquals(await exchangeCode(config, 'code1', fakeFetch, 1000), 'r1');
  assertEquals(seen!.url, 'https://appleid.apple.com/auth/token');
  assertEquals(seen!.body.get('code'), 'code1');
  assertEquals(seen!.body.get('grant_type'), 'authorization_code');
  assertEquals(seen!.body.get('client_id'), 'app.mantelier');
});

Deno.test('a refused code is null, not an exception', async () => {
  const config = { p8: await testKeyPem(), keyId: 'K', teamId: 'T', clientId: 'app.mantelier' };
  const fakeFetch = (async () =>
    new Response('{"error":"invalid_grant"}', { status: 400 })) as unknown as typeof fetch;
  assertEquals(await exchangeCode(config, 'old', fakeFetch, 1000), null);
});

Deno.test('revoke posts the refresh token', async () => {
  const config = { p8: await testKeyPem(), keyId: 'K', teamId: 'T', clientId: 'app.mantelier' };
  let body: URLSearchParams | null = null;
  const fakeFetch = (async (url: string, init: RequestInit) => {
    assertEquals(url, 'https://appleid.apple.com/auth/revoke');
    body = init.body as URLSearchParams;
    return new Response('', { status: 200 });
  }) as unknown as typeof fetch;
  assert(await revokeRefreshToken(config, 'r1', fakeFetch, 1000));
  assertEquals(body!.get('token'), 'r1');
  assertEquals(body!.get('token_type_hint'), 'refresh_token');
});
