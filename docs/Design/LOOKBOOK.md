# Lookbook

`site/lookbook.html`, for showing venues how the app looks once it is filled.
Reachable by link only (`noindex`, no link from the site).

## How the screens are made

Real simulator screenshots, never redrawn, so the page cannot show something
the app does not do. Build against a local stack, load `scripts/seed_lookbook.py`,
override the status bar with `xcrun simctl status_bar`, capture with
`xcrun simctl io <device> screenshot`, and resize to 720 px wide JPEG in
`site/lookbook/`. The screens need re-capturing when the app's look changes.

## What is invented

Every venue, event, person, award and score. Names were searched on 2026-11-04
and no business with them turned up: Maison Aurelle, Noordtij, Atelier Verano,
Casa Lumera, Hotel Belmare, The Alderwick. The page says all this at the top
and in the footer. Never put a real venue's data on it without that venue's
agreement.

## Photos

Unsplash, under the Unsplash License; each page below was checked on 2026-11-04
to be a free photo, not Unsplash+. No identifiable people. The app loads them
from Unsplash for the local stack; the page only carries the screenshots.

| Used for | Photographer | unsplash.com/photos/ |
|---|---|---|
| Maison Aurelle | Tanja Tepavac | `jSH-7IjJVsQ` |
| Atelier Verano | Franco Debartolo | `-kFZHgP5OAg` |
| Casa Lumera | 𝒮 𝐴 ℛ 𝐴 ✿ | `z-lAPXXq6Co` |
| Noordtij | Igor Rand | `1-IeBcvLUQ4` |
| Hotel Belmare | Sue Winston | `2PF9cfoquRU` |
| The Alderwick | Vi Tran | `8Kd4Ig22QWM` |
| Four hands dinner, story | David Goldman | `UALNymlFeRo` |
| Game dinner | Piermario Eva | `DPLcHckDflk` |
| Interview | liuyun wu | `dhxtgSdwgyo` |
