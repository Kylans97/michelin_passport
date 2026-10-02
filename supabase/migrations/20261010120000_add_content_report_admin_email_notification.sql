-- Admin email notification on a new content report — closes a gap the
-- Restaurant/Hotel photo-gallery Report action (this same change, Dart
-- side) would otherwise reopen: MODERATION_MANUAL_CHECKPOINTS.md #2
-- required the Report action to ship in the same change as the gallery,
-- but a Report action that reaches nobody is the same error as a gallery
-- shipping without one — the mechanism exists, the human end doesn't.
-- content_reports (20260913120000) has carried every friend-rating and
-- private-chef-photo report since September with zero admin notification
-- of any kind; this closes that for every content_type at once, not only
-- the one this task happens to add a UI for.
--
-- Same chain as notify_admin_of_pending_venue_claim: this trigger ->
-- pg_net (async HTTP) -> a new notify-content-report Edge Function ->
-- Resend. Its own webhook secret (notify_content_report_webhook_secret),
-- not a reused one — matches this project's own one-secret-per-function
-- convention (notify_venue_claim_webhook_secret,
-- notify_venue_submission_webhook_secret, publish_venue_photo_webhook_
-- secret each have their own). Must be set out of band before this does
-- anything (see this migration's own chat report for the exact command);
-- a missing secret degrades to a logged WARNING, same as every other
-- notify_admin_of_pending_* function, never a blocked insert.
--
-- Deliberately generic over content_type, matching content_reports' own
-- shape: there is no TG_TABLE_NAME branching to do (content_reports is a
-- single table), and the email itself does not attempt to resolve "which
-- restaurant/hotel/chef does this photo belong to" — content_type =
-- 'photo' alone doesn't say which of three photo tables, and
-- content_reports carries no venue-type hint at all. The email reports
-- exactly what the row holds (reporter identity, content_type,
-- content_id, reason, details) plus a dashboard link to look the
-- specific row up by id — the same "SQL Editor deep link" shape
-- notify-venue-claim already uses, generalized to content_reports.
--
-- BEST-EFFORT, same two independent ways as notify_admin_of_pending_
-- venue_claim: net.http_post() is itself async (queued, never blocking
-- this trigger's transaction), and the queuing call is wrapped in its
-- own BEGIN/EXCEPTION so even a synchronous failure (pg_net missing, a
-- vault read error) is a WARNING, never an aborted INSERT — a reporter
-- must never lose their report because the mail provider was down.

begin;

create function public.notify_admin_of_pending_content_report()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_secret text;
begin
  begin
    select decrypted_secret into v_secret
    from vault.decrypted_secrets
    where name = 'notify_content_report_webhook_secret';

    if v_secret is null then
      raise warning 'notify_admin_of_pending_content_report: webhook secret not found '
        'in vault — skipping admin email for report %', new.id;
    else
      perform net.http_post(
        url := 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/notify-content-report',
        body := to_jsonb(new),
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-webhook-secret', v_secret
        ),
        timeout_milliseconds := 5000
      );
    end if;
  exception when others then
    raise warning 'notify_admin_of_pending_content_report: failed to queue admin email '
      'for report % — %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

revoke execute on function public.notify_admin_of_pending_content_report() from public, anon;

create trigger content_reports_notify_admin_on_insert
  after insert on public.content_reports
  for each row execute function public.notify_admin_of_pending_content_report();

commit;
