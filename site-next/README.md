# site-next

The new public Mantelier site, hidden until it replaces `site/` at
mantelier.app on the day the app launches. Astro, built to static HTML.

## Run and build

```
npm install
npm run dev        # http://localhost:4321
npm run build      # into dist/
```

## Deploy (hidden preview only)

Automatic: `.github/workflows/site-next.yml` builds from live Supabase
data every three hours (and on every push to this folder) and deploys to
the `next` preview when the output changed. It needs the repository
secret `CLOUDFLARE_API_TOKEN` (Cloudflare → My Profile → API Tokens, a
custom token with Account · Cloudflare Pages · Edit); without it the
workflow only builds. Schedules run only once the workflow is on `main`.

By hand:

```
npm run build
npx wrangler@3 pages deploy dist --project-name mantelier --branch next
```

This updates https://next.mantelier.pages.dev only. Never deploy this
folder with `--branch main`: that is mantelier.app, which still serves
`site/`.

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
a stay, a confirmed event, wines and a photo for the Passport and globe. The
catalogue pages still come from production; wishlist rows hold ids only,
so they match.

## Launch checklist

1. Move `privacy`, `terms`, `support`, `hosts`, `auth/` and
   `.well-known/` from `site/` into this site, and point the footer links
   back to relative paths.
2. Set `HIDDEN = false` in `src/config.ts`, remove the block in
   `public/_headers` and the `Disallow` in `public/robots.txt`.
3. Set `APP_STORE_URL` in `src/config.ts`.
4. Deploy with `--branch main`.
