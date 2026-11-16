// Sign-in on the site, with the app's own accounts and rules
// (lib/data/repositories/auth_repository.dart, two_step_repository.dart,
// lib/features/auth/). Browser only. The public anon key is the one the app
// already ships; RLS is what protects every row, so nothing here grants
// access the app wouldn't.
//
// No sign-up and no password reset here, by decision (2026-11-16): accounts
// are made in the app, and a reset link only works on the device that asked
// for it, so the site points to the app's own "Forgot password?".
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
    auth: { storageKey: SESSION_KEY, persistSession: true, autoRefreshToken: true, detectSessionInUrl: false },
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
