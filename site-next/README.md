# site-next

The public Mantelier site at mantelier.app. Astro, built to static HTML.
It replaced the old static `site/` once the app was on the App Store
(prepared 2026-11-21; it goes live when this is merged into `main`).

## Run and build

```
npm install
npm run dev        # http://localhost:4321
npm run build      # into dist/
```

## Deploy

Automatic: `.github/workflows/site-next.yml` builds from live Supabase
data every three hours (and on every push to this folder) and deploys
when the output changed: from `main` to the production branch, which is
mantelier.app; from any other branch to the `next` preview,
https://next.mantelier.pages.dev. So merging a change to this folder into
`main` publishes it. It needs the repository secret
`CLOUDFLARE_API_TOKEN` (Cloudflare → My Profile → API Tokens, a custom
token with Account · Cloudflare Pages · Edit); without it the workflow
only builds.

By hand, from a checkout whose HEAD equals `origin/main`:

```
npm run build
npx wrangler@3 pages deploy dist --project-name mantelier --branch main
```

Verify afterwards with curl: every changed page, and its images as
`image/*`.

`site/` is the old static site, kept only as a fallback. Deploying it
(`pages deploy site --branch main`) replaces this site until the next
scheduled run puts this one back.

## Static pages

`public/` carries the pages that came over from `site/` as they were, with
their own styling: `privacy`, `terms`, `support`, `hosts`, `journey`,
`venue-guide` and `lookbook` (with their screenshots), `auth/` (the email
links the app opens), `.well-known/` (Apple's app-site association; served
as JSON by `public/_headers`), `brand/`, and `_redirects`. Edit them here,
not in `site/`.

## Signing in

Members sign in with their Mantelier app account (email and password,
then the authenticator code where two-step sign-in is on) at
`/account/sign-in`. Everything signed-in runs in the browser with the
public anon key, under `/account` and in the wishlist / Interested / Going
buttons (`src/components/SaveControls.astro`); no page is ever built with
personal data, and RLS decides every read and write. No sign-up and no
password reset here: both stay in the app. Code: `src/lib/account/`.

To test against a local Supabase stack instead of production, put
`PUBLIC_AUTH_SUPABASE_URL` and `PUBLIC_AUTH_SUPABASE_ANON_KEY` (from
`supabase status`) in `.env.development`, which only `npm run dev` reads,
then create the local test members and copy a few events with
`scripts/local-sign-in-test.mjs` (it refuses any non-local URL);
`scripts/local-passport-test.mjs` then gives the first test member visits,
a stay, a confirmed event, wines and a photo for the Passport and globe;
`scripts/local-friends-test.mjs` adds friends, a waiting request and a
followed restaurant. The
catalogue pages still come from production; wishlist rows hold ids only,
so they match.

## Launch (done 2026-11-21)

The static pages moved into `public/`, the footer links became relative,
`HIDDEN` is false, `public/_headers` and `public/robots.txt` no longer
block indexing, `APP_STORE_URL` is set, and the workflow deploys `main`
to mantelier.app. To hide the site again, set `HIDDEN = true` and put the
noindex header and `Disallow: /` back.
