# New machine setup

For moving this project to a new laptop. Written because a `git clone` gets
you the code and nothing a human typed into a local file or a secret store
directly — those don't travel on their own, and one of them (the Resend key)
genuinely cannot be recovered if it's lost in the move.

---

## 1. What does not travel with a clone — capture these FIRST

Everything below is gitignored. A fresh clone will build nothing and run
nothing until these exist on the new machine. No secret value appears in this
document — only where each one comes from and where it has to end up.

| Path | What it is | Where the value comes from |
|---|---|---|
| `.env` (repo root) | `SUPABASE_URL`, `SUPABASE_ANON_KEY` — read by `flutter_dotenv` at app startup (`lib/main.dart`, `lib/core/supabase/supabase_config.dart`) | Supabase dashboard → the `michelin_passport` project (ref `wcmxugunvwsrulcpeyrc`) → Project Settings → API. Both are the **public** anon key and URL — not secret, just not committed. `.env.example` at repo root is the committed template; copy it to `.env` and fill in the two values. **The app will not build without this file** — it's also listed under `flutter: assets:` in `pubspec.yaml`, so its absence fails the build, not just the API calls. |
| `supabase/.temp/` | CLI link state (project ref, pooler URL, cached version pins) | Regenerated automatically by `supabase link` (§3) — nothing to manually copy here. |
| `.claude/` (repo root) | Claude Code's local project settings/permissions for this repo | Session-local. Either let Claude Code regenerate it fresh on the new machine, or copy `.claude/settings.json` across by hand if you want identical permission settings — `.claude/settings.local.json` is machine-specific and not worth carrying over. |

### The Resend API key — read this before you wipe the old machine

`RESEND_API_KEY` is read by two Edge Functions (`notify-venue-claim`,
`notify-venue-submission` — `Deno.env.get('RESEND_API_KEY')`). It is **not** in
`.env` or anywhere in this repo — it lives only in Supabase's project secret
store (set via `supabase secrets set`, consumed server-side at the platform
level). Resend does not let you read a key back out once it's issued; its
dashboard only shows a masked value. If this key is lost — the old machine is
gone and nobody wrote it down elsewhere — the only recovery is logging into
Resend and **rotating** it, then re-setting it on the Supabase project.

**Before moving machines, capture it safely** with:
```
supabase secrets list --linked
```
This lists the secret *names* currently set on the linked project, confirming
what needs to exist on the new machine's workflow — it does **not** print
values, by design, so this alone doesn't solve the problem. If you don't
already have the actual key value saved somewhere outside this repo (a
password manager, Resend's own original issuance email), the pragmatic move is
to treat the secret as already needing rotation: generate a new key in Resend,
`supabase secrets set RESEND_API_KEY=<new value> --linked`, and store the new
value somewhere that isn't a single laptop. Do this once, now, rather than
discovering it's gone after the old machine is wiped.

### The other three function secrets

Same situation, lower stakes (these are webhook shared secrets you control,
not a third-party key — losing one just means generating a new random value
and re-setting it, no external account involved):

- `PUBLISH_VENUE_PHOTO_WEBHOOK_SECRET` (`publish-venue-photo`)
- `NOTIFY_VENUE_CLAIM_WEBHOOK_SECRET` (`notify-venue-claim`)
- `NOTIFY_VENUE_SUBMISSION_WEBHOOK_SECRET` (`notify-venue-submission`)

`supabase secrets list --linked` confirms all four (including `RESEND_API_KEY`)
are set on the project; none of this depends on the old machine once confirmed
— they live in Supabase, not locally. `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`
are auto-injected by the platform into every Edge Function and need no manual
secret at all.

### iOS signing

Signing is **Automatic** (`CODE_SIGN_STYLE = Automatic`, team `QMF89BFNGF`,
`ios/Runner.xcodeproj/project.pbxproj`) — Xcode negotiates provisioning through
your Apple ID's membership in that team, not a checked-in profile. No
`.p12`/`.mobileprovision`/`ExportOptions.plist` file exists in this repo today.
On the new machine: sign into the same Apple Developer account in Xcode
(Settings → Accounts), open `ios/Runner.xcworkspace`, and let Xcode's automatic
signing resolve the team on first build. Nothing to copy for this specifically
— but note the gap while it's visible: **neither `.gitignore` nor
`ios/.gitignore` currently excludes `*.p12`/`*.mobileprovision`/
`ExportOptions.plist`.** If a manual export profile is ever added to this repo
in the future, add that exclusion first — today it's a non-issue only because
no such file exists yet.

---

## 2. Toolchain

Confirmed from this project's own config, not assumed:

- Dart SDK: `^3.12.1` (`pubspec.yaml`)
- Flutter: no version pin in the repo (no FVM, no `.fvmrc`) — install current
  stable. This machine runs Flutter 3.44.3 / Dart 3.12.2 as a reference point,
  not a requirement.
- Postgres: 17 (`supabase/config.toml`, `major_version = 17`) — only relevant
  if running a local Supabase stack; irrelevant to the linked production
  project, which is already on its own version.
- Supabase CLI: no version pin in the repo. This machine runs 2.111.0.
- Docker: required for `supabase start` (local dev stack) and for the
  schema-diff workaround (§5). This machine runs Docker 29.6.2.
- Xcode: required for iOS builds. This machine runs Xcode 26.6. CocoaPods
  1.17.0 is installed but this project currently has **no `ios/Podfile`** —
  confirm whether one gets generated on first `flutter build ios`/`pod
  install` before assuming CocoaPods is actually load-bearing here.

Install order that avoids backtracking: Flutter SDK → `flutter doctor` (fixes
most Xcode/Android toolchain gaps itself) → Docker Desktop → Supabase CLI.

---

## 3. Supabase CLI login and project link

```
supabase login
supabase link --project-ref wcmxugunvwsrulcpeyrc
```
`link` prompts interactively for the database password — have it ready (a
password manager entry, not memorized). This regenerates `supabase/.temp/`
locally; nothing from the old machine needs to be copied for this step.

**Immediately after linking, run the ledger check** — not as a formality, but
because a fresh clone plus a fresh CLI login is exactly the situation where a
local/remote mismatch would first surface, and it's cheap to catch here before
it's mixed up with unrelated new-machine noise:

```
supabase migration list --linked
```
Every row's `local` and `remote` columns should match. If they don't, stop and
report it rather than pushing anything — this is the exact check CLAUDE.md's
own cadence rule requires after any migration-touching session, and the first
run on a new machine is as good a time as any to prove the habit survived the
move.

---

## 4. The countries seed gap — this will bite immediately if you start a local stack

If you run `supabase start` (or `supabase db diff --linked`) on the new
machine, it will fail the same way it failed here: the shadow-database
bootstrap replays all 83 migrations from empty, and no migration in history
ever seeds `public.countries` — any migration carrying a real `country_code`
(`20260810160000_create_events.sql`, `20260812100000_...`,
`20260812150000_...`, and more) fails its foreign key, and the bootstrap never
completes. This is not new-machine-specific; it is a pre-existing gap in
migration history itself, confirmed by direct investigation, and it has
nothing to do with anything the move does differently.

**Parked, not fixed, as of this document**: a `countries` seed migration
(generated from the live table, not hand-typed — 55 rows, confirmed) has been
investigated and the CLI's exact behaviour on an out-of-order migration
timestamp confirmed (it refuses by default, needs `--include-all`), but the
seed migration has not been written, and will not be until it passes a full
84-file replay with `ON_ERROR_STOP=1` — proof that adding it doesn't just move
the failure somewhere else. See `CLAUDE.md`'s "Constraints on agent behaviour"
section for the current standing note on `supabase db diff --linked` being
blocked, and this project's own chat history around the schema-diff
investigation for the full trail.

Until that seed migration lands: `supabase db diff --linked` and a from-scratch
`supabase start` both fail on a fresh machine exactly as they do here. The
linked remote project itself is unaffected — this only blocks local-stack and
shadow-database workflows, not the app talking to production.

---

## 5. First commands to confirm the new machine works

In order, each should succeed before moving to the next:

```
flutter pub get
flutter analyze
flutter test
```
`flutter analyze` should report no issues; `flutter test` runs the full suite
(2000+ tests as of this writing) with no special flags.

Then a real build, to confirm signing and the toolchain end to end:
```
flutter run -d <device-id>          # physical device, debug
```
or, for a signing-free sanity check that doesn't need a connected device:
```
flutter build ios --no-codesign --simulator
```
Find a device id via `flutter devices`. A clean `flutter run` reaching the
app on-device (not just a successful build) is the actual confirmation —
`flutter build` alone doesn't exercise the signing/provisioning handshake the
same way.

If `flutter run` hangs on "Dart VM Service was not discovered" or times out on
"CONFIGURATION_BUILD_DIR" against a physical device, that's a stale
Xcode/lldb debug-session lock, not a project problem — quit Xcode, kill any
lingering `lldb`/`lldb-rpc-server` processes, and retry. Seen and resolved
this way during this project's own development, not hypothetical.
