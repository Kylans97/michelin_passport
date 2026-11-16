// What every page needs to know about the reader without loading
// supabase-js: is a session stored, and has it passed two-step sign-in?
// Read from the session supabase-js keeps in localStorage. Nothing here is
// trusted for access: the database (RLS) decides that on every request, and
// a stale or forged entry only changes which label the header shows.

/** Where supabase-js keeps the session (`storageKey` in client.ts). */
export const SESSION_KEY = 'mantelier-auth';
/** The member's display name, kept beside the session for the header. */
export const NAME_KEY = 'mantelier-account-name';

export type Peek = 'signed-out' | 'needs-two-step' | 'signed-in';

interface StoredSession {
  access_token?: string;
  user?: { factors?: { status?: string }[] };
}

function aalOf(jwt: string): string | null {
  try {
    const part = jwt.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(part)).aal ?? null;
  } catch {
    return null;
  }
}

/** As the app's sessionNeedsTwoStep: a verified authenticator and a token
 *  still at aal1 means the code step hasn't been passed. */
export function sessionNeedsTwoStep(session: StoredSession): boolean {
  const hasFactor = session.user?.factors?.some((f) => f.status === 'verified') ?? false;
  return hasFactor && aalOf(session.access_token ?? '') !== 'aal2';
}

export function peek(): Peek {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return 'signed-out';
    const session = JSON.parse(raw) as StoredSession;
    if (!session.access_token) return 'signed-out';
    return sessionNeedsTwoStep(session) ? 'needs-two-step' : 'signed-in';
  } catch {
    return 'signed-out';
  }
}

export function storedName(): string | null {
  try { return localStorage.getItem(NAME_KEY); } catch { return null; }
}

/** A same-site path to return to after signing in, never another host. */
export function safeNext(raw: string | null): string {
  return raw && raw.startsWith('/') && !raw.startsWith('//') && !raw.startsWith('/\\') ? raw : '/account';
}

export const signInHref = (next = location.pathname) => `/account/sign-in?next=${encodeURIComponent(next)}`;

/** The header's account link for a signed-in member: their name, and on a
 *  phone only its first letter in a circle, so the app button still fits. */
export function showMemberInHeader(name: string | null) {
  const link = document.querySelector<HTMLAnchorElement>('[data-account]');
  if (!link) return;
  const label = name ?? 'Account';
  link.href = '/account';
  link.setAttribute('aria-label', `${label}, your account`);
  link.classList.add('member');
  link.querySelector('[data-name]')!.textContent = label;
  link.querySelector('[data-initial]')!.textContent = [...label][0]?.toUpperCase() ?? 'A';
}
