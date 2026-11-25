// Sign-in on the site, with the app's own accounts and rules
// (lib/data/repositories/auth_repository.dart, two_step_repository.dart,
// lib/features/auth/). Browser only. The public anon key is the one the app
// already ships; RLS is what protects every row, so nothing here grants
// access the app wouldn't.
//
// No sign-up and no password reset here, by decision (2026-11-16): accounts
// are made in the app, and a reset link only works on the device that asked
// for it, so the site points to the app's own "Forgot password?".
//
// Since 2026-11-22 also Continue with Apple and Continue with email (a six
// digit code), the two ways the app now makes accounts, so those members
// can sign in here too. Still no sign-up: a code goes only to an address
// that already has an account (shouldCreateUser false), and an Apple
// account without a username (never set up in the app) is signed out
// again with a pointer to the app.
import { createClient, type Session, type SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE_ANON_KEY, SUPABASE_URL } from '../supabase';
import { NAME_KEY, SESSION_KEY, sessionNeedsTwoStep } from './peek';

// A local Supabase stack for testing replaces both, at dev time only:
// PUBLIC_AUTH_SUPABASE_URL / PUBLIC_AUTH_SUPABASE_ANON_KEY in site-next/.env.
const url = import.meta.env.PUBLIC_AUTH_SUPABASE_URL || SUPABASE_URL;
const key = import.meta.env.PUBLIC_AUTH_SUPABASE_ANON_KEY || SUPABASE_ANON_KEY;

let client: SupabaseClient | null = null;

export function supabase(): SupabaseClient {
  client ??= createClient(url, key, {
    // pkce: Apple's sign-in comes back with a ?code= this page exchanges
    // itself (completeAppleSignIn), never tokens in the address bar.
    auth: { storageKey: SESSION_KEY, persistSession: true, autoRefreshToken: true, detectSessionInUrl: false, flowType: 'pkce' },
  });
  return client;
}

/** The resent confirmation link lands where the app's does
 *  (AuthRepository.resentConfirmationRedirectUrl). */
const RESENT_CONFIRMATION_URL = 'https://mantelier.app/auth/confirmed';

export type SignInResult = 'signed-in' | 'needs-two-step' | 'unconfirmed';

export async function signIn(email: string, password: string): Promise<SignInResult> {
  const { data, error } = await supabase().auth.signInWithPassword({ email, password });
  if (error) {
    if (error.code === 'email_not_confirmed') return 'unconfirmed';
    throw new Error(error.code === 'invalid_credentials' ? 'That email and password don’t match an account.' : error.message);
  }
  return sessionNeedsTwoStep(data.session) ? 'needs-two-step' : 'signed-in';
}

/** Where Apple sends the member back to. It must be in the project's
 *  Authentication > URL Configuration > Redirect URLs. */
const APPLE_RETURN_URL = 'https://mantelier.app/account/sign-in';
const NEXT_KEY = 'mantelier-sign-in-next';

/** Leaves for Apple's sign-in page; [next] is kept for the way back. */
export async function startAppleSignIn(next: string): Promise<void> {
  try { sessionStorage.setItem(NEXT_KEY, next); } catch { /* back to the account page */ }
  const returnUrl = location.hostname === 'mantelier.app' ? APPLE_RETURN_URL : `${location.origin}/account/sign-in`;
  const { error } = await supabase().auth.signInWithOAuth({ provider: 'apple', options: { redirectTo: returnUrl } });
  if (error) throw new Error('Signing in with Apple didn’t work. Please try again.');
}

export type AppleReturn = { result: SignInResult | 'not-set-up'; next: string | null } | null;

/** On the way back from Apple: exchanges the ?code= for a session. Null
 *  when this page wasn't opened by Apple. An account never set up in the
 *  app (no username) is signed out again: accounts are made in the app. */
export async function completeAppleSignIn(): Promise<AppleReturn> {
  const params = new URLSearchParams(location.search);
  const code = params.get('code');
  const appleError = params.get('error_description') ?? params.get('error');
  if (!code && !appleError) return null;
  let next: string | null = null;
  try { next = sessionStorage.getItem(NEXT_KEY); sessionStorage.removeItem(NEXT_KEY); } catch { /* none kept */ }
  history.replaceState(null, '', location.pathname);
  if (!code) throw new Error('Signing in with Apple didn’t work. Please try again.');
  const { data, error } = await supabase().auth.exchangeCodeForSession(code);
  if (error || !data.session) throw new Error('Signing in with Apple didn’t work. Please try again.');
  const { data: profile } = await supabase()
    .from('profiles').select('username').eq('id', data.session.user.id).maybeSingle();
  if (!profile?.username) {
    await signOut();
    return { result: 'not-set-up', next };
  }
  return { result: sessionNeedsTwoStep(data.session) ? 'needs-two-step' : 'signed-in', next };
}

/** Sends a sign-in code, only to an address that has an account. Whether
 *  it has one is never said: the same answer either way, as in the app. */
export async function sendEmailCode(email: string): Promise<void> {
  const { error } = await supabase().auth.signInWithOtp({ email, options: { shouldCreateUser: false } });
  if (!error) return;
  // Supabase refuses an unknown address; say nothing different for it.
  if (error.code === 'otp_disabled' || /signups? not allowed/i.test(error.message)) return;
  if (error.status === 429 || error.code === 'over_email_send_rate_limit') {
    throw new Error('A code was sent a moment ago. Wait a minute, then ask for a new one.');
  }
  throw new Error(error.message);
}

export async function verifyEmailCode(email: string, code: string): Promise<SignInResult> {
  const { data, error } = await supabase().auth.verifyOtp({ email, token: code.replace(/[^0-9]/g, ''), type: 'email' });
  if (error || !data.session) {
    throw new Error('That code didn’t work. Check it, or send a new one; a code works for a limited time.');
  }
  return sessionNeedsTwoStep(data.session) ? 'needs-two-step' : 'signed-in';
}

export async function resendConfirmation(email: string): Promise<void> {
  const { error } = await supabase().auth.resend({
    type: 'signup',
    email,
    options: { emailRedirectTo: RESENT_CONFIRMATION_URL },
  });
  if (error) throw new Error(error.message);
}

/** The code step, as TwoStepRepository.verifySignIn: tries each linked
 *  authenticator, since the member doesn't know which one the code is from. */
export async function verifyTwoStep(code: string): Promise<void> {
  const digits = code.replace(/[^0-9]/g, '');
  const auth = supabase().auth;
  const { data, error } = await auth.mfa.listFactors();
  if (error) throw error;
  for (const f of data.totp) {
    const { error: verifyError } = await auth.mfa.challengeAndVerify({ factorId: f.id, code: digits });
    if (!verifyError) return;
  }
  throw new Error('That code didn’t match. Try the newest one.');
}

/** The current session once it is fully signed in (aal2 where the account
 *  has two-step on), else null. Refreshes an expired token first. */
export async function fullSession(): Promise<Session | null> {
  const { data } = await supabase().auth.getSession();
  const session = data.session;
  if (!session || sessionNeedsTwoStep(session)) return null;
  return session;
}

/** Signs out of the site only. supabase-js would otherwise end every
 *  session of the account, the phone's included. */
export async function signOut(): Promise<void> {
  await supabase().auth.signOut({ scope: 'local' });
  try { localStorage.removeItem(NAME_KEY); } catch { /* nothing kept */ }
}

/** Counts this sign-in for Studio's Website tab (20261101810000): one row,
 *  the member's id and the time, nothing else. Best effort and quick: a
 *  sign-in never waits long on it or fails because of it. */
export async function recordWebsiteSignIn(userId: string): Promise<void> {
  const insert = supabase().from('website_sign_ins').insert({ user_id: userId }).then(() => undefined, () => undefined);
  await Promise.race([insert, new Promise<void>((resolve) => setTimeout(resolve, 1500))]);
}

/** The member's name from their own profile, kept for the header. */
export async function loadName(userId: string): Promise<string | null> {
  const { data } = await supabase().from('profiles').select('display_name, username').eq('id', userId).maybeSingle();
  const name = (data?.display_name as string | null)?.trim() || (data?.username as string | null) || null;
  try {
    if (name) localStorage.setItem(NAME_KEY, name);
  } catch { /* the header falls back to "Account" */ }
  return name;
}

/** For a signed-in page: the full session, or off to sign in and back. */
export async function requireSession(): Promise<Session> {
  const session = await fullSession();
  if (!session) {
    location.replace(`/account/sign-in?next=${encodeURIComponent(location.pathname)}`);
    return new Promise(() => {}); // the page is leaving
  }
  return session;
}
