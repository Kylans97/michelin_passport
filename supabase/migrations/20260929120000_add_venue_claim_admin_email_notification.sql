-- Admin email notification on a new restaurant claim (Part 1 of the
-- venue-claim-hardening work — see the chat report from the research
-- round for the full investigation this is built on).
--
-- notify_venue_claim_change() (20260927120000) already notifies the
-- CLAIMANT in-app when their own claim is received/approved/rejected —
-- it never notifies the reviewer, and it's a plain notifications-table
-- insert, not email. This migration adds the genuinely missing half: an
-- email to claimedvenues@mantelier.app the moment a restaurant claim is
-- submitted, since the partial unique index added in
-- 20260928120000_harden_claims_restaurants_insert_rls.sql now means a
-- pending claim blocks every other user from claiming that same venue —
-- so a claim sitting unseen is a real problem, not just a delay.
--
-- A Postgres trigger can't send mail itself, so the chain is: this
-- trigger -> pg_net (async HTTP) -> the notify-venue-claim Edge Function
-- (supabase/functions/notify-venue-claim/index.ts) -> Resend. Deliberately
-- scoped to claims_restaurants only, matching every other restaurant-only
-- decision in this same body of work (the hardening migration, the
-- claimConflictMessage() split) — claims_hotels/claims_private_chefs
-- don't yet have the platform-wide one-pending-per-venue index that makes
-- an unseen claim urgent, so widening this to them was not asked for and
-- is not done here.
--
-- BEST-EFFORT, by construction in two independent ways:
--   1. net.http_post() is asynchronous — it queues the request in a
--      pg_net-managed table and returns immediately; the actual HTTP call
--      happens later, in a background worker, entirely outside this
--      trigger's transaction. A slow or failing Resend send can never
--      block or fail the INSERT that triggered it.
--   2. The queuing call itself (the vault lookup + net.http_post) is
--      wrapped in its own BEGIN/EXCEPTION block below, so even a failure
--      IN THAT SYNCHRONOUS STEP (pg_net missing, a vault read error, a
--      malformed call) is caught and logged as a WARNING rather than
--      propagating — an uncaught exception in an AFTER trigger would
--      abort the whole transaction, which would defeat the entire point
--      ("a claimant must never lose their submission because my mail
--      provider was down").
-- Where a failure becomes visible to a human: see this migration's own
-- chat report — Postgres WARNINGs land in Supabase's Postgres logs
-- (Dashboard -> Logs -> Postgres Logs), and any failure inside the Edge
-- Function itself (a Resend error, a lookup failure) is a console.error
-- there (Dashboard -> Edge Functions -> notify-venue-claim -> Logs).
--
-- AUTHENTICATION: this function is called ONLY by this trigger via
-- pg_net, never by the Flutter app — there is no user JWT in that
-- calling context, unlike delete-account (client-called, real session,
-- verify_jwt = true, unchanged). So notify-venue-claim sets
-- verify_jwt = false in config.toml and instead checks its own shared
-- secret (the x-webhook-secret header) against
-- NOTIFY_VENUE_CLAIM_WEBHOOK_SECRET, an Edge Function secret. The trigger
-- below needs the SAME value to send as that header, which is exactly
-- what vault.secrets is for — Supabase's own encrypted secret store on
-- the Postgres side, enabled on this project already (supabase_vault
-- extension) but never previously used. The value is generated once by
-- this migration and reported out-of-band (chat), never as a literal in
-- this file or any other committed file.

begin;

-- ============================================================
-- 1. pg_net — lets a Postgres trigger make an async outbound HTTP call.
--    Not previously enabled on this project (confirmed live before
--    writing this). extensions schema matches every other non-core
--    extension already installed here (pgcrypto, uuid-ossp).
-- ============================================================

create extension if not exists pg_net with schema extensions;

-- ============================================================
-- 2. The shared webhook secret, in vault.secrets — set OUT OF BAND, not
--    by this file. Its real value was created once via a direct
--    `select vault.create_secret('<value>', 'notify_venue_claim_webhook_
--    secret', '...')` call issued alongside applying this migration
--    (reported out of band — chat, not git), and NOT written here: this
--    is a migration file, which this project commits and keeps in git
--    history forever, and "Do not commit secrets to the repo" applies to
--    every secret this project has, this one included — the same
--    discipline RESEND_API_KEY and NOTIFY_VENUE_CLAIM_WEBHOOK_SECRET
--    (the Edge Function secrets, set via `supabase secrets set`, never
--    committed) already get.
--
--    This block is a guard, not the real setup step: it only warns if
--    the secret is missing (e.g. a fresh environment replaying this
--    migration from git alone) so the gap is loud rather than silent —
--    the trigger's own best-effort exception handling already covers
--    "secret not found" at runtime (see notify_admin_of_pending_
--    restaurant_claim() below), but a warning here, at migration time,
--    catches it before the first real claim ever gets silently unnoticed.
-- ============================================================

do $$
begin
  if not exists (
    select 1 from vault.decrypted_secrets where name = 'notify_venue_claim_webhook_secret'
  ) then
    raise warning 'notify_venue_claim_webhook_secret is not set in vault.secrets — the '
      'claims_restaurants admin-email trigger will run but skip sending (see its own '
      'exception handler) until it is created manually with the same value as the '
      'notify-venue-claim function''s NOTIFY_VENUE_CLAIM_WEBHOOK_SECRET secret. Never commit '
      'that value to this file.';
  end if;
end $$;

-- ============================================================
-- 3. Trigger function — fires only on INSERT with status = 'pending'
--    (the only way a row can be inserted at all, per
--    claims_restaurants_insert's own with_check since the hardening
--    migration, but checked explicitly anyway rather than assumed).
--    Sends the full new row as-is (to_jsonb(new)) rather than just an
--    id, so the Edge Function needs no extra claims_restaurants lookup
--    of its own and reflects exactly the state at insert time.
-- ============================================================

create function public.notify_admin_of_pending_restaurant_claim()
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
      where name = 'notify_venue_claim_webhook_secret';

      if v_secret is null then
        raise warning 'notify_admin_of_pending_restaurant_claim: webhook secret not found '
          'in vault — skipping admin email for claim %', new.id;
      else
        perform net.http_post(
          url := 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/notify-venue-claim',
          body := to_jsonb(new),
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
      raise warning 'notify_admin_of_pending_restaurant_claim: failed to queue admin email '
        'for claim % — %', new.id, sqlerrm;
    end;
  end if;
  return new;
end;
$$;

revoke execute on function public.notify_admin_of_pending_restaurant_claim() from public, anon;

create trigger claims_restaurants_notify_admin_on_insert
  after insert on public.claims_restaurants
  for each row execute function public.notify_admin_of_pending_restaurant_claim();

commit;
