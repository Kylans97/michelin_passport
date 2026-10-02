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

## 4. The countries seed gap — fixed in migration history, not yet proven by replay

The gap itself: no migration in the first 83 ever seeded `public.countries` —
it was populated by hand outside migration history at some point after the
schema was first applied. Any from-scratch replay (a shadow database, a
preview branch, disaster recovery into an empty project) hit this immediately,
failing at the first insert carrying a real `country_code`.

**Fixed and applied**: `supabase/migrations/20260805141520_seed_countries.sql`
is now committed and applied to production — 55 rows generated from the live
table (not hand-typed), `on conflict (country_code) do nothing`, validated in a
rollback transaction first (0 rows would insert — a true no-op against data
that already exists) before being applied for real with `--include-all`
(required: its timestamp precedes migrations already on remote, so plain
`db push` wouldn't see it as pending). The remote ledger confirms 84/84, no
local-only file.

**Still outstanding, and this is the part a new machine should actually run**:
an end-to-end proof that a database built from *only* these 84 files, with
nothing seeded by hand, comes up clean. The rollback validation above proves
the migration is safe against a database that already has the data — it does
not prove a database that doesn't yet exist can be built from the files alone.
That proof needs a disposable Postgres replay with `ON_ERROR_STOP=1`
(errors fatal, nothing tolerated), and it has not run since the fix landed —
Docker has been down on the machine that did this work since **2026-10-01**
and never recovered before this document was last updated.

**Run this on the new machine, once Docker is confirmed working, and be
specific about what each outcome means:**
- Replaying the **83** pre-fix files alone should fail at
  `20260810160000_create_events.sql`, **line 172** — the `'t Preuvenemint`
  insert, `country_code = 'NL'`, against an empty `countries` table. If it
  fails somewhere else instead, that's not this gap — don't assume it's the
  same problem.
- Replaying all **84** files (including the seed) should complete with zero
  errors. If something *else* fails once `countries` exists, that's a second,
  different gap — name it, don't work around it silently.

Being specific about the expected failure point matters here: without it,
whoever runs this later has no way to tell "the known problem, still present"
apart from "a new problem that looks similar."

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

---

## 6. Releasing to TestFlight via Transporter

Ten uploads have gone out this way before this document existed — the
procedure lived entirely in one person's head. **Recorded here from the
first run actually walked through while writing this section** (2026-10-08,
version 1.1.0 build 12, Xcode 26.6, Flutter 3.44.3), not from memory
afterward: exit code 0, real timings, real file sizes, below.

### Prerequisite — signing must already resolve

Covered in §1's "iOS signing" above: automatic signing
(`CODE_SIGN_STYLE = Automatic`), team `QMF89BFNGF`, needs the right Apple ID
signed into Xcode (Settings → Accounts) and nothing else — no checked-in
`.p12`/`.mobileprovision`/`ExportOptions.plist` exists or is needed. Confirmed
again on this run: the build resolved signing with no prompt, no manual step.

### The command

From the repo root, after bumping `version:` in `pubspec.yaml` (the one and
only place the build/version numbers live — `flutter build ipa` reads
`CFBundleShortVersionString`/`CFBundleVersion` from it directly, no separate
Xcode project edit):

```
flutter build ipa
```

That's the whole command — no flags needed. Two things worth knowing about
why no flags are required:

- **Export method defaults to `app-store`**, which is exactly what an
  App Store Connect/TestFlight upload needs. `flutter build ipa --help`
  also offers `ad-hoc`/`development` via `--export-method`, irrelevant here.
- **`flutter build ipa` auto-generates its own `ExportOptions.plist`**
  (written to `build/ios/ipa/ExportOptions.plist`, confirmed by reading it
  after this run: `method: app-store-connect`, `signingStyle: automatic`,
  `teamID: QMF89BFNGF`) — this is a **build artifact**, not something to
  hand-author or commit. `build/` is already outside version control
  (`git status` shows nothing under it after a build), so this file and
  the whole archive/IPA never touch git.

### What it did, this run

```
Archiving app.mantelier...
Automatically signing iOS for device deployment using specified development team in Xcode project: QMF89BFNGF
Running Xcode build...
Xcode archive done.                                         57,4s
✓ Built build/ios/archive/Runner.xcarchive (185.9MB)

[✓] App Settings Validation
    • Version Number: 1.1.0
    • Build Number: 12
    • Display Name: Mantelier
    • Deployment Target: 13.0
    • Bundle Identifier: app.mantelier

Building App Store IPA...                                          31,2s
✓ Built IPA to build/ios/ipa (24.0MB)
```

Confirmed valid afterward (`unzip -l`, not just trusting the success
message): a well-formed zip with the expected `Payload/Runner.app/`
structure inside.

### Where the file Transporter wants actually is

**`build/ios/ipa/Mantelier.ipa`** — named after the app's Display Name
("Mantelier"), *not* `Runner.ipa`. Open the Transporter app and drag this
exact file in (Flutter's own success message states the same path/pattern:
`build/ios/ipa/*.ipa`). The sibling files in that directory
(`ExportOptions.plist`, `DistributionSummary.plist`, `Packaging.log`) are
build metadata, not needed by Transporter.

The non-interactive alternative Flutter also prints —
`xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey ... --apiIssuer ...`
— was not exercised this run (Transporter is the established path here);
noted in case a future scripted/CI upload ever needs it.

### Disk cost — the real worry going in, smaller than feared

This machine was at **16.0 GB free of 245 GB (93% full)** immediately
before this run (`df -H /` / `diskutil info /`, the Data volume figure —
the plain `df -h /` system-volume number reads misleadingly low on APFS
and should not be trusted alone). After archive + IPA export: **15 GB
free** — roughly **1 GB** consumed total, not the feared double-digit-GB
archive. Breakdown: the `.xcarchive` itself is 178 MB on disk, the IPA
23 MB, the rest is incremental `DerivedData` growth
(`~/Library/Developer/Xcode/DerivedData`, largest component
`ModuleCache.noindex` at 139 MB plus a `Runner-*` build folder at 351 MB —
already-cached toolchain output, not re-downloaded per build). A full
clean build from an empty DerivedData would cost more than this
incremental one did; that cost has not been separately measured.

### Nothing surprised this run beyond the above

No signing prompt, no missing-Podfile issue (confirmed: this project still
has no `ios/Podfile` and the build didn't need one), no space failure. If a
future run **does** fail for space, the standing instruction is: stop,
report exactly what got left behind (a partial `.xcarchive`, a partial
`build/ios/ipa`), and do not clear space or retry in the same session —
decide that deliberately, separately, not as a reflex.
