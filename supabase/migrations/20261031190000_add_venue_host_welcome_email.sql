-- The host welcome email: when a claim goes from pending to approved, the
-- new host gets the same welcome the app shows them
-- (VenueHostWelcomeScreen) and mantelier.app/hosts carries.
--
-- Written 2026-11-02. Named after 20261031180000_add_pl_tr_2026_cities
-- (applied in production from claude/michelin-pl-tr-2026, not yet on main)
-- per CLAUDE.md's monotonic-sequence rule.
--
-- Same pattern and same secret as notify_admin_of_pending_venue_claim()
-- (20261007120000): a pg_net post to notify-venue-claim, which now also
-- handles `event: 'approved'`. No new vault secret and no new function to
-- deploy, only a redeploy of notify-venue-claim. Best-effort by
-- construction: its own exception handler means a missing secret or a
-- pg_net failure can never roll back the approval that fired it.
--
-- Fires on the status change itself, so every way a claim gets approved
-- (admin_approve_venue_claim in the app, approve_venue_claim from the
-- dashboard) sends it, and a later update of an approved claim does not
-- send it again. Deploy notify-venue-claim BEFORE applying this: until it
-- is deployed, the old function would treat the approved envelope as a
-- new claim and email the admins instead.

begin;

create function public.notify_host_of_approved_venue_claim()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  v_secret text;
begin
  if old.status = 'pending' and new.status = 'approved' then
    begin
      select decrypted_secret into v_secret
      from vault.decrypted_secrets
      where name = 'notify_venue_claim_webhook_secret';

      if v_secret is null then
        raise warning 'notify_host_of_approved_venue_claim: webhook secret not found '
          'in vault — skipping welcome email for % row %', TG_TABLE_NAME, new.id;
      else
        perform net.http_post(
          url := 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/notify-venue-claim',
          body := jsonb_build_object(
            'claim_type', TG_TABLE_NAME,
            'event', 'approved',
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
      raise warning 'notify_host_of_approved_venue_claim: failed to queue welcome email '
        'for % row % — %', TG_TABLE_NAME, new.id, sqlerrm;
    end;
  end if;
  return new;
end;
$$;

revoke execute on function public.notify_host_of_approved_venue_claim() from public, anon;

create trigger claims_restaurants_welcome_host_on_approval
  after update of status on public.claims_restaurants
  for each row execute function public.notify_host_of_approved_venue_claim();

create trigger claims_hotels_welcome_host_on_approval
  after update of status on public.claims_hotels
  for each row execute function public.notify_host_of_approved_venue_claim();

create trigger claims_private_chefs_welcome_host_on_approval
  after update of status on public.claims_private_chefs
  for each row execute function public.notify_host_of_approved_venue_claim();

commit;
