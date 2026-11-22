// Apple Token — after a native Sign in with Apple, the app sends the
// one-time authorization code here; this exchanges it with Apple for a
// refresh token and keeps that in public.apple_sign_in_tokens
// (20261101650000), service_role only, so delete-account can revoke it.
//
// Identity comes only from the caller's own JWT (verify_jwt stays on, and
// getUser checks it again); the body carries nothing but the code. The app
// calls this best-effort: a failure here never blocks signing in.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { appleConfig, exchangeCode } from '../_shared/apple_sign_in.ts';

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!jwt) return json({ error: 'Missing Authorization header' }, 401);

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
  const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !user) return json({ error: 'Invalid or expired session' }, 401);

  let code: unknown;
  try {
    code = (await req.json())?.authorization_code;
  } catch (_) {
    return json({ error: 'Invalid JSON body' }, 400);
  }
  if (typeof code !== 'string' || code.length === 0) {
    return json({ error: 'authorization_code is required' }, 400);
  }

  const config = appleConfig((name) => Deno.env.get(name));
  if (!config) {
    console.error('apple-token: Apple key not configured');
    return json({ error: 'Not configured' }, 503);
  }
  const refreshToken = await exchangeCode(config, code);
  if (!refreshToken) return json({ error: 'Apple refused the code' }, 502);

  const { error } = await admin.from('apple_sign_in_tokens').upsert({
    user_id: user.id,
    refresh_token: refreshToken,
    updated_at: new Date().toISOString(),
  });
  if (error) {
    console.error('apple-token: could not store the token', { message: error.message });
    return json({ error: 'Could not store the token' }, 500);
  }
  return json({ stored: true }, 200);
});
