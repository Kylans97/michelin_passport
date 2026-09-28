-- Admin email notification on a new venue-about or venue-photo submission
-- (extends the pg_net -> Edge Function -> Resend chain built for restaurant
-- claims in 20260929120000_add_venue_claim_admin_email_notification.sql to
-- the two other manager-submitted content types).
--
-- ONE NEW EDGE FUNCTION, NOT AN EXTENSION OF notify-venue-claim, AND NOT
-- TWO SEPARATE NEW FUNCTIONS:
--   - The claims payload (role/business_email/phone/notes, plus a domain-
--     mismatch check against the claimant's account email) is about
--     verifying WHO gets to manage a venue. venue_about_submissions/
--     venue_photo_submissions are about WHAT an already-approved manager
--     submitted. Different question, different shape — folding this into
--     notify-venue-claim would make one function do two unrelated jobs,
--     the same reason claimConflictMessage() and the hardening migration
--     stayed restaurant-claim-scoped rather than growing extra branches.
--   - venue_about_submissions and venue_photo_submissions, by contrast,
--     share an identical core shape (id, user_id, venue_type, venue_id,
--     submitted_at) and differ only in their one content-specific column
--     (about_text vs storage_path/replaces_photo_id) — exactly the level
--     of sharing notify_venue_claim_change() (20260927120000) already
--     uses across all three claims_* tables via identical column names.
--     One shared trigger function + one shared Edge Function, branching
--     on submission_type, is the right grain: not over-consolidated
--     (folding claims in), not over-split (two near-duplicate functions
--     that would differ only in one field name).
--
-- Deliberately its own webhook secret (notify_venue_submission_webhook_
-- secret), not a reuse of notify_venue_claim_webhook_secret — same
-- least-privilege / blast-radius separation already applied to every
-- other secret in this project (see CLAUDE.md's SECURITY DEFINER note and
-- this project's four-times-independently-rediscovered anon-execute gap:
-- secrets and grants here are scoped per function on purpose, not shared
-- for convenience).
--
-- Same two independent best-effort guarantees as the claims trigger:
--   1. net.http_post() is asynchronous — queues and returns immediately,
--      so a slow/failing Resend send can never block the submission
--      INSERT.
--   2. The synchronous queuing step (vault lookup + net.http_post call)
--      is itself wrapped in BEGIN/EXCEPTION, so a missing secret, a vault
--      read error, or a malformed call is caught and logged as a WARNING
--      rather than aborting the transaction.
-- Failure visibility: WARNINGs land in Dashboard -> Logs -> Postgres
-- Logs; failures inside the Edge Function itself (a Resend error, a
-- lookup failure) are console.error there (Dashboard -> Edge Functions ->
-- notify-venue-submission -> Logs) — identical to notify-venue-claim.
--
-- AUTHENTICATION: same shape as notify-venue-claim. This function is
-- called only by these two triggers via pg_net, never by the Flutter app,
-- so it sets verify_jwt = false in config.toml and checks its own shared
-- secret (x-webhook-secret) against NOTIFY_VENUE_SUBMISSION_WEBHOOK_
-- SECRET, an Edge Function secret. The value is generated once and
-- reported out-of-band (chat), never as a literal in this file.

begin;

-- ============================================================
-- 1. The shared webhook secret, in vault.secrets — set OUT OF BAND, not
--    by this file (same reasoning as 20260929120000 §2: this is a
--    migration file, committed and kept in git history forever). This
--    block only warns if the secret is missing, so the gap is loud
--    rather than silent; the trigger's own exception handling covers
--    "secret not found" at runtime regardless.
-- ============================================================

do $$
begin
  if not exists (
    select 1 from vault.decrypted_secrets where name = 'notify_venue_submission_webhook_secret'
  ) then
    raise warning 'notify_venue_submission_webhook_secret is not set in vault.secrets — the '
      'venue_about_submissions/venue_photo_submissions admin-email triggers will run but skip '
      'sending (see their own exception handler) until it is created manually with the same '
      'value as the notify-venue-submission function''s NOTIFY_VENUE_SUBMISSION_WEBHOOK_SECRET '
      'secret. Never commit that value to this file.';
  end if;
end $$;

-- ============================================================
-- 2. Shared trigger function — attached to both tables below.
--    TG_TABLE_NAME discriminates which table fired it ('venue_about_
--    submissions' or 'venue_photo_submissions'); the Edge Function uses
--    that same string as submission_type to pick which content branch to
--    render, so no separate function or duplicated body is needed per
--    table. Sends the full new row as-is (to_jsonb(new)), same reasoning
--    as the claims trigger: no extra lookup of the row itself, exact
--    state at insert time.
-- ============================================================

create function public.notify_admin_of_pending_venue_submission()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_secret text;
begin
  if new.status = 'pending' then
    begin
      select decrypted_secret into v_secret
      from vault.decrypted_secrets
      where name = 'notify_venue_submission_webhook_secret';

      if v_secret is null then
        raise warning 'notify_admin_of_pending_venue_submission: webhook secret not found in '
          'vault — skipping admin email for % row %', TG_TABLE_NAME, new.id;
      else
        perform net.http_post(
          url := 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/notify-venue-submission',
          body := jsonb_build_object(
            'submission_type', TG_TABLE_NAME,
            'row', to_jsonb(new)
          ),
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-webhook-secret', v_secret
          ),
          timeout_milliseconds := 5000
        );
      end if;
    exception when others then
      -- Best-effort: this must never take the INSERT down with it. See
      -- this migration's own header for where this becomes visible.
      raise warning 'notify_admin_of_pending_venue_submission: failed to queue admin email for '
        '% row % — %', TG_TABLE_NAME, new.id, sqlerrm;
    end;
  end if;
  return new;
end;
$$;

revoke execute on function public.notify_admin_of_pending_venue_submission() from public, anon;

create trigger venue_about_submissions_notify_admin_on_insert
  after insert on public.venue_about_submissions
  for each row execute function public.notify_admin_of_pending_venue_submission();

create trigger venue_photo_submissions_notify_admin_on_insert
  after insert on public.venue_photo_submissions
  for each row execute function public.notify_admin_of_pending_venue_submission();

commit;
