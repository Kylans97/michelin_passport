# Venue Photo Pipeline — Layer 3 (AI content review), deferred design

**Status: not built.** Layers 1 (client-side validation + EXIF strip)
and 2 (perceptual-hash duplicate detection) are live — see
`supabase/migrations/20260828130000_add_photo_duplicate_detection_and_
focus_point.sql` and `lib/data/services/venue_photo_pipeline.dart`.
Layer 3 — an Edge Function that sends a submitted photo to the
Anthropic API for a sorting judgment — is deliberately not built yet.

**Why deferred**: the product owner reviews every submitted photo by
hand for at least the first few months. Layer 3 only earns its keep
once that review queue gets too long to scan in one glance. This
document exists so that work can pick up from here later without
re-deriving the design from scratch.

**Explicitly not a decision flow.** The model sorts; it never
approves or rejects. Every submission stays `pending` until the
product owner reviews it, regardless of what the model says — Layer 3
only changes the ORDER a human sees submissions in, never their
status.

---

## What Layer 3 will do

After a photo submission is inserted (`venue_photo_submissions`,
status `pending`), a Supabase Edge Function is called with the
submission id. The function:

1. Fetches the object from the private `venue-photo-submissions`
   bucket using the service-role key (never the anon key — this bucket
   holds unreviewed content, matching this feature's own RLS design).
2. Sends the photo to the Anthropic API with the prompt below, forcing
   a structured (tool-call) JSON response.
3. Writes the result back onto the submission row.

## Trigger

Called by the client (`VenuePhotoSubmissionRepository`, fire-and-
forget) immediately after a successful insert, passing the new
submission's id. The function re-derives everything else (storage
path, venue context) from that row rather than trusting anything else
the client sends — the same "identity/authorization comes from the
server side, never a client-supplied parameter" posture the existing
`delete-account` function already uses.

## Schema this will need (NOT created yet)

Three columns on `venue_photo_submissions`, to be added in the same
migration that ships the Edge Function — deliberately not added
ahead of time, so the column set and the code that fills it land
together:

```sql
alter table public.venue_photo_submissions
  add column ai_category  text,
  add column ai_bucket    text
    check (ai_bucket in ('likely_good', 'questionable', 'likely_unsuitable')),
  add column ai_reasoning text;
```

`ai_category` is deliberately left as free text rather than a CHECK-
constrained enum at the database level in this sketch — the category
list below is expected to be refined once real submissions are seen
(matching the "log near-misses, not just failures" standard rather
than freezing a taxonomy before any real data exists against it). A
`check` constraint can be added once the category list has actually
been exercised.

## Response schema

Forced via a tool call, not freeform text-embedded JSON — the same
reliability reasoning behind every other structured-output boundary
in this codebase.

```json
{
  "category": "food | interior | dish_of_venue | chef_or_staff_portrait | identifiable_guests | marketing_material | logo | screenshot | stock_photo | other_unsuitable",
  "bucket": "likely_good | questionable | likely_unsuitable",
  "reasoning": "one or two sentences, in the voice of an editorial curator"
}
```

### Category list — revision history

The first draft of this prompt (proposed, not yet built) put "people"
under `other_unsuitable`. Corrected before any code was written: a
portrait of the chef is a normal, welcome submission for a gastronomy
guide — it has nothing to do with why a marketing flyer or a
screenshot doesn't belong. A photo with identifiable guests in it is
a **privacy** problem, categorically different from a **curation/fit**
problem — conflating the two under one "unsuitable" bucket would hide
the actual reason a human reviewer needs to know when deciding what
to do next (a guest photo needs a firm no regardless of how "nice" it
looks; a chef portrait might belong somewhere else in the app even if
not in this particular gallery slot). Split into two dedicated
categories instead of folding either into a generic catch-all:

- `chef_or_staff_portrait` — a normal submission, not a curation
  problem. Proposed default bucket: `questionable` — legitimate
  content, but this photo slot is scoped to food/interior/dish, so a
  human should decide whether it fits here or belongs elsewhere (e.g.
  a chef's own profile image) rather than the model silently
  presenting it as if it were a dish photo.
- `identifiable_guests` — a privacy issue, not a taste issue.
  Proposed default bucket: `likely_unsuitable`, with `reasoning`
  expected to explicitly say why ("contains identifiable guests —
  privacy, not a curation call") so a reviewer scanning buckets never
  mistakes this for "just doesn't look good enough."

## The prompt

**System:**

> You are sorting photo submissions for Mantelier, a curated
> gastronomy guide in the style of a private members' club —
> editorial, restrained, never database-UI. You classify; you never
> approve or reject. Every submission stays pending human review
> regardless of your answer — your only job is to help a human
> reviewer see the most promising submissions first.
>
> Classify the photo into exactly one `category`:
> - `food` — a genuine, unstaged photo of a dish or food item
> - `interior` — a genuine, unstaged photo of the venue's space
> - `dish_of_venue` — food styled/plated in a way that reads as this
>   venue's own kitchen output, not a generic stock shot
> - `chef_or_staff_portrait` — a portrait of a chef or staff member.
>   This is a normal, legitimate submission — not a curation problem,
>   just possibly the wrong slot for it.
> - `identifiable_guests` — one or more identifiable guests are the
>   subject or clearly visible in the photo. This is a PRIVACY
>   concern, not a quality or fit judgment — classify it here whenever
>   a real person's face is recognizable, regardless of how good the
>   photo otherwise is.
> - `marketing_material` — a designed graphic, poster, or flyer with
>   text/branding overlaid on or replacing the photo
> - `logo` — a brand mark or wordmark, not a photograph
> - `screenshot` — a captured screen (app, website, social media post,
>   review, menu PDF)
> - `stock_photo` — a generic, professionally-staged photo with no
>   specific connection to a real, particular kitchen or room
> - `other_unsuitable` — anything else that doesn't belong (receipts,
>   unrelated content, etc.) — do NOT use this category for people;
>   use `chef_or_staff_portrait` or `identifiable_guests` instead.
>
> Then judge `bucket` — not on technical quality alone. A sharp,
> well-lit photo can still be the wrong fit for a curated gastronomic
> guide (overly staged, generic stock-photo look, dominated by a logo
> or text, or simply not food/interior/dish content):
> - `likely_good` — clearly food, interior, or a venue's own dish;
>   looks like it belongs in this guide
> - `questionable` — plausibly fine but something gives you pause
>   (heavy filter/branding overlay, ambiguous subject, borderline
>   staged/stock look, or a chef/staff portrait that may belong
>   elsewhere)
> - `likely_unsuitable` — marketing material, logo, screenshot, stock
>   photo, identifiable guests, or otherwise doesn't belong
>
> Give a one- or two-sentence `reasoning` a human reviewer can scan
> quickly — state what you saw and why it lands where it does, not a
> generic description of the image. For `identifiable_guests`, always
> say so explicitly and note this is a privacy call, not a quality
> one.

**User:** *(image attached)* "Classify this photo submission."

## Model and secrets

A recent Claude model with vision (whichever is current when this is
actually built), called via the Anthropic API with a forced tool call
for the schema above. `ANTHROPIC_API_KEY` lives in the Edge Function's
own environment (`Deno.env.get('ANTHROPIC_API_KEY')`) — never in
pubspec, client code, or anywhere reachable from the Flutter app,
matching how `SUPABASE_SERVICE_ROLE_KEY` is already handled in
`supabase/functions/delete-account/index.ts`.

## Open questions for whoever picks this up

- Should `ai_category` become a CHECK-constrained enum once real
  category data exists, and if so, does the list above need
  revising first against what actually gets submitted?
- Does the review queue need a "sort by bucket" UI affordance, or is
  a plain `order by ai_bucket` query in the (not-yet-built) admin
  screen enough for the first version?
- `chef_or_staff_portrait`'s default `questionable` bucket is a
  judgment call, not a settled decision — revisit once real
  submissions show whether that's too lenient or too strict.
