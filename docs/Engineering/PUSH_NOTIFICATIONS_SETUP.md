# Push notifications — setup and go-live

How push works is in the header of
`supabase/migrations/20261030130000_add_push_notifications.sql` and in
`supabase/functions/send-push/index.ts`. This page is only the steps that
can't live in git. Order matters: the migration's trigger skips pushes
until the vault secret exists, and the function refuses every call until
its secrets exist, so nothing goes out half-configured.

## 1. Apple Developer portal (by hand)

1. **Identifiers → `app.mantelier`** → enable **Push Notifications**. Save.
2. **Keys → +** → name it (e.g. "APNs"), tick **Apple Push Notifications
   service (APNs)**, Continue, Register. **Download the `.p8` once**:
   Apple never offers it again. Note the **Key ID** on that page and your
   **Team ID** (top right of the portal, or Membership details).
   One key serves sandbox and production, and every app on the team.
3. In Xcode, automatic signing picks up the new capability next build.
   The repo already carries `aps-environment` in
   `ios/Runner/RunnerProfile.entitlements` (`development`; an App Store or
   TestFlight export switches it to `production` itself).

No Firebase project is needed.

## 2. Supabase secrets (by hand, never committed)

Generate one webhook secret and use it in both places:

```bash
openssl rand -hex 32
```

Function secrets (the `.p8` contents go in as-is, newlines included):

```bash
supabase secrets set --project-ref wcmxugunvwsrulcpeyrc \
  APNS_KEY_ID=<key id> APNS_TEAM_ID=<team id> APNS_BUNDLE_ID=app.mantelier \
  SEND_PUSH_WEBHOOK_SECRET=<secret> APNS_KEY_P8="$(cat AuthKey_<key id>.p8)"
```

Vault, in the SQL editor:

```sql
select vault.create_secret('<secret>', 'send_push_webhook_secret',
  'x-webhook-secret for the send-push Edge Function');
```

## 3. Deploy and apply (each with the product owner's explicit yes)

1. `supabase functions deploy send-push --project-ref wcmxugunvwsrulcpeyrc`
2. `supabase db push --linked` (if it hangs after "Applying migration…",
   check production for `public.push_devices` before anything else — see
   CLAUDE.md).
3. `supabase migration list --linked`: local and remote agree.
4. Verify the revokes on production:
   `select has_function_privilege('anon', 'register_push_device(text,text,text)', 'EXECUTE');`
   and the same for the other five new functions: all `false`.

## 4. First real check

On a real iPhone, signed with the team that owns the key:

1. Run a build, follow a venue, tap **Turn on notifications**, allow.
   `push_devices` gets a row (`apns_environment = sandbox` for an Xcode
   build).
2. Have a second account send a friend request. Expect the banner.
3. Edge Function logs: one call, `{"sent":1}`. A `500 APNs secrets are not
   configured` means step 2 is missing; an error from `fetch` there is
   the HTTP/2 question in the CHANGELOG entry: the fallback is FCM.
