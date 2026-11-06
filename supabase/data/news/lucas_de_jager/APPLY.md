# Publishing Lucas de Jager's interview

Prepared 2026-11-06, applied the same day (see the app CHANGELOG). Each step stops on any error; nothing is
retried on CLI output alone (CLAUDE.md).

## Files

| File | What |
|---|---|
| `interview_as_given_20261106.md` | The text as the product owner gave it in chat. |
| `body_20261106.txt` | The same text in the app's body format: 46 paragraphs, "Q: " questions, "> " quotes, the introduction first. |
| `prepared_publish_lucas_interview.sql` | One transaction: the article, its four photos, the link to the chef, and the removal of the three placeholders. |

Photos are not in git. The five files to upload are in
`~/Downloads/lucas_interview_preview/upload/`, sent by the product owner
on 2026-11-06, no EXIF or location data in any of them:

| File | sha256 | Use |
|---|---|---|
| `portrait.jpg` | `88fba0bf…` | header and card, focus 0.5/0.25 |
| `dish-with-wine.jpg` | `62bf10e2…` | after paragraph 15 |
| `table.jpg` | `3725f6c2…` | after paragraph 23 |
| `at-work.jpg` | `d5cdb287…` | after paragraph 37 |
| `dish-with-sauce.jpg` | `05c38dd1…` | at the end (46), focus 0.5/0.4 |

The sixth photo sent (the same dish from above) is not used.

## Steps

1. **Migration.** From `claude/lucas-interview`:
   `echo y | supabase db push --linked`, which applies only
   `20261101380000_add_news_card_title.sql`. Then check it really is there
   (`select 1 from information_schema.columns where table_name =
   'news_articles' and column_name = 'card_title'`) and that
   `supabase migration list --linked` shows 151 rows in agreement.
2. **Photos.** For each of the five files:
   `supabase storage cp --experimental --linked --content-type image/jpeg
   <file> ss:///news-images/lucas-de-jager/<file>`.
   Then each public URL must answer 200 with `image/jpeg`.
3. **Article.** `supabase db query --linked -f
   prepared_publish_lucas_interview.sql`. It aborts unless step 1 and 2
   are done, the chef is the published Lucas de Jager and the
   placeholders are as expected.
4. **Check.** The News tab in the current App Store build shows "Why
   Mantelier" and the interview (with the full title, since that build
   doesn't read `card_title`), and no example articles.

## Tested

On a local stack with every migration through 20261101380000 and fixture
rows (2026-11-06): with four of the five photos it aborts; with all five
it publishes the article, its four photos and the chef link, removes the
three placeholders and their photos, and the stored body's md5 matches;
a second run aborts because the article exists. Not tested: the upload
itself, and the article in the App Store build against production.
