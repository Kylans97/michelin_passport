begin;

-- ============================================================
-- Genericize the venue-claim admin-email notification across all three
-- claims tables, and close the one-pending-per-venue index gap that
-- left claims_hotels/claims_private_chefs without the protection
-- claims_restaurants already had.
--
-- Context: notify_admin_of_pending_restaurant_claim()
-- (20260929120000_add_venue_claim_admin_email_notification.sql) was
-- deliberately scoped to claims_restaurants only, with that migration's
-- own comment noting hotels/chefs weren't asked for yet. That gap
-- matters now — a private chef or hotel claim arrives today with no
-- admin email at all, and the next real tester is a private chef. This
-- closes it the same way notify_admin_of_pending_venue_submission()
-- (20261004120000_add_venue_submission_admin_email_notification.sql)
-- already solved the identical "one function, several tables" shape: a
-- TG_TABLE_NAME-discriminated envelope, not three near-duplicate
-- functions and three vault secrets.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Replace the restaurant-only trigger function with a generic one,
--    attached to all three claims tables.
-- ------------------------------------------------------------

drop trigger claims_restaurants_notify_admin_on_insert on public.claims_restaurants;
drop function public.notify_admin_of_pending_restaurant_claim();

create function public.notify_admin_of_pending_venue_claim()
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
        raise warning 'notify_admin_of_pending_venue_claim: webhook secret not found '
          'in vault — skipping admin email for % row %', TG_TABLE_NAME, new.id;
      else
        perform net.http_post(
          url := 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/notify-venue-claim',
          body := jsonb_build_object(
            'claim_type', TG_TABLE_NAME,
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
      raise warning 'notify_admin_of_pending_venue_claim: failed to queue admin email '
        'for % row % — %', TG_TABLE_NAME, new.id, sqlerrm;
    end;
  end if;
  return new;
end;
$$;

revoke execute on function public.notify_admin_of_pending_venue_claim() from public, anon;

create trigger claims_restaurants_notify_admin_on_insert
  after insert on public.claims_restaurants
  for each row execute function public.notify_admin_of_pending_venue_claim();

create trigger claims_hotels_notify_admin_on_insert
  after insert on public.claims_hotels
  for each row execute function public.notify_admin_of_pending_venue_claim();

create trigger claims_private_chefs_notify_admin_on_insert
  after insert on public.claims_private_chefs
  for each row execute function public.notify_admin_of_pending_venue_claim();

-- ------------------------------------------------------------
-- 2. Close the one-pending-per-venue index gap on hotels/chefs.
--
-- Confirmed via direct read-only query against production before
-- writing this (not assumed): zero hotel_id and zero private_chef_id
-- currently have more than one 'pending' row, so both indexes are safe
-- to add outright, exactly as claims_restaurants_one_pending_per_venue_uidx
-- (20260928120000_harden_claims_restaurants_insert_rls.sql) was. Same
-- behavior change as that index: a second person claiming the same
-- hotel/chef while one claim is already pending is now rejected with a
-- unique_violation, surfaced client-side the same way
-- VenueClaimRepository.submitClaim() already handles the restaurant case.
-- ------------------------------------------------------------

create unique index claims_hotels_one_pending_per_venue_uidx
  on public.claims_hotels (hotel_id)
  where status = 'pending';

create unique index claims_private_chefs_one_pending_per_venue_uidx
  on public.claims_private_chefs (private_chef_id)
  where status = 'pending';

commit;
