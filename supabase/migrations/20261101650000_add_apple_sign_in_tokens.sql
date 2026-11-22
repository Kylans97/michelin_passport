-- Sign in with Apple: the Apple refresh token per account, kept only so
-- the account's Apple link can be revoked when the account is deleted.
-- App Review requires that (guideline 5.1.1(v)): an app offering Sign in
-- with Apple revokes the user's tokens through Apple's REST API on
-- account deletion. Asked for by the product owner on 2026-11-22 ("Can we
-- do extra login options? ... e-mail, apple login and phone number";
-- then "build sign in with Apple and the email code in the app, keeping
-- passwords"). Written 2026-11-22 on claude/sign-in-options; the number
-- is sort order: the next after 20261101640000, the highest on any
-- branch.
--
-- Applied to production 2026-11-22 on the product owner's go ahead ("apply
-- the migration"), after the privacy policy naming Sign in with Apple went
-- live on mantelier.app the same day.
--
-- The apple-token Edge Function writes a row after a native sign-in
-- (exchanging the one-time authorization code for a refresh token with
-- Apple); delete-account reads it and revokes it before deleting the
-- user. Nothing else reads it: no client policy and no client grant at
-- all, service_role only. The row cascades away with the account.
--
-- No function is created here, so there is no execute grant to revoke.

begin;

create table public.apple_sign_in_tokens (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  updated_at    timestamptz not null default now()
);

comment on table public.apple_sign_in_tokens is
  'Apple refresh token per account, only to revoke Sign in with Apple on account deletion. service_role only.';

alter table public.apple_sign_in_tokens enable row level security;

revoke all on public.apple_sign_in_tokens from public, anon, authenticated;

commit;
