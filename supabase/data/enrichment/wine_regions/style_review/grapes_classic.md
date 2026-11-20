# Grape style texts — source check (gr_0001..gr_0017)

Checked 2026-11-20 against the seed file `supabase/data/enrichment/wine_regions/wine_regions_seed_v1.sql` (read-only).

## Method

- Two independent organisations per claim. Main references reached: Wine Folly (grape pages + deep dives = one org), Wine Spectator "Know your grapes", The Wine Society grape/region guides, Halliday Wine Companion variety pages, VIVC (official JKI variety catalogue, synonyms), Inter Beaujolais, Decanter China (Fongyee Walker study guide), Systembolaget (Swedish state retailer). Lower-tier sources used only where nothing better was reachable are named as such (Wine Traveler, Cellar Tours, MasterClass, VinePair, Wikipedia, individual wine reviews).
- Not reachable by the fetch tool (403/paywall/truncated): Wine-Searcher, Wine Enthusiast, Jancis Robinson, GuildSomm, Decanter grape pages, Falstaff, vinsdeloire.fr, champagne.fr. Decanter's Pinot Noir excerpt was seen only through a search snippet.
- Scale mapping (1–5): light / low = 1–2 (light-medium, medium-minus, medium-light = 2), medium = 3, medium-high / medium(+) / medium-full = 4, high / full = 4–5. A current value counts as supported when it falls inside what two sources say; otherwise it is moved to the value two sources share.
- Values unchanged where sources agree are marked supported; where two good sources disagree and the current value sits between them, it is kept and flagged.

## gr_0001 Pinot Noir

**aliases** — current: `{Spätburgunder, Pinot Nero}` → **supported** → proposed: `{Spätburgunder, Pinot Nero}`
  - https://www.winespectator.com/articles/pinot-noir-57812 — Pinot Nero (Italy), Spätburgunder (Germany), Blauburgunder (Austria): 'local names for the same grape'
  - https://winefolly.com/grapes/pinot-noir/ — synonyms Pinot Nero, Spätburgunder, Blauburgunder
  - https://www.vivc.de/index.php?r=passport%2Fview&id=9279 — official variety catalogue (JKI): Blauburgunder etc. in the 447-name synonym list

**summary** — current: `Thin-skinned and fussy, at its best where it's cool. Pale in the glass, but it carries a lot of scent.` → **supported** → proposed: `Thin-skinned and fussy, at its best where it's cool. Pale in the glass, but it carries a lot of scent.`
  - https://www.winespectator.com/articles/pinot-noir-57812 — thin skins, 'finicky', prefers cooler climates; lighter than Cabernet/Merlot; floral notes
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/pinot-noir-the-ultimate-grape-guide/ — 'thin skin', 'notoriously fickle', a 'cool-climate grape variety'; 'naturally delicate colour'
  - https://winefolly.com/grapes/pinot-noir/ — pale to medium colour; long, cool growing seasons
  - https://www.decanter.com/wine/grape-varieties/pinot-noir-red-52273/ — (via search excerpt) 'thin-skinned', 'notoriously temperamental'; 'one of the most sensuously fragrant red grapes'

**tastes** — current: `{Red cherry, Raspberry, Strawberry}` → **supported** → proposed: `{Red cherry, Raspberry, Strawberry}`
  - https://www.winespectator.com/articles/pinot-noir-57812 — young: cherries, strawberries, raspberries
  - https://winefolly.com/grapes/pinot-noir/ — cherry, raspberry
  - https://www.winecompanion.com.au/resources/varieties/pinot-noir — strawberry, cherry, raspberry

**aged_note** — current: `mushroom, forest floor` → **supported** → proposed: `mushroom, forest floor`
  - https://www.winespectator.com/articles/pinot-noir-57812 — with age a 'mushroomy, earthy note often described as forest floor'
  - https://winefolly.com/grapes/pinot-noir/ — aged Pinot: damp forest floor, mushroom, leather
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/pinot-noir-the-ultimate-grape-guide/ — 'herbal, forest floor aromas that come with a bit of age'

**body** — current: `2` → **supported** → proposed: `2`
  - https://winefolly.com/grapes/pinot-noir/ — light to medium body
  - https://www.winespectator.com/articles/pinot-noir-57812 — light- to medium-bodied
  - https://www.winecompanion.com.au/resources/varieties/pinot-noir — light- to medium-bodied

**acidity** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/pinot-noir/ — medium-high acidity
  - https://www.winespectator.com/articles/pinot-noir-57812 — moderate to high acidity
  - https://www.winecompanion.com.au/resources/varieties/pinot-noir — high acidity

**tannin** — current: `2` → **supported** → proposed: `2`
  - https://winefolly.com/grapes/pinot-noir/ — low tannin (thin skins)
  - https://www.winespectator.com/articles/pinot-noir-57812 — low levels of tannins
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/pinot-noir-the-ultimate-grape-guide/ — soft, silky tannins

**similar** — current: `gr_0014` "just as light, a little juicier" → **supported** → proposed: `gr_0014` "just as light, a little juicier"
  - https://winefolly.com/deep-dive/tasters-guide-to-gamay-wine/ — Gamay is light-bodied, 'similar in taste to Pinot Noir', 'a cousin of Pinot Noir'
  - https://www.thewinesociety.com/discover/explore/expertise/why-i-love-gamay/ — Beaujolais: 'light, juicy' bottles, low tannins, lively acidity
  - https://www.winespectator.com/articles/pinot-noir-57812 — Pinot is darker than Gamay

## gr_0002 Chardonnay

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/grapes/chardonnay/ — only alternative name given is Morillon (regional); empty list is not wrong
  - https://www.winespectator.com/articles/chardonnay-57804 — no synonyms listed

**summary** — current: `The chameleon: lean and steely in a cool climate, round and buttery when ripened in the sun and aged in oak.` → **adjusted** → proposed: `The chameleon: lean and steely in a cool climate, riper and fuller in warm ones; oak and winemaking can make it round and buttery.`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/chardonnay-the-ultimate-grape-guide/ — a chameleon; Chablis 'lean and steely'; warm regions riper, tropical; Meursault 'full-bodied, buttery' (oak)
  - https://www.winecompanion.com.au/resources/varieties/chardonnay — 'chameleon white wine'; rich buttery oaked style vs lean citrusy style
  - https://www.winespectator.com/articles/chardonnay-57804 — cool climate leaner; warm riper; butter comes from malolactic fermentation, lees stirring or oak, i.e. winemaking, not sun
  - https://winefolly.com/grapes/chardonnay/ — butter mainly from malolactic fermentation; oak adds vanilla/toast

**tastes** — current: `{Lemon, Green apple, Butter, with oak, Hazelnut}` → **supported** → proposed: `{Lemon, Green apple, Butter, with oak, Hazelnut}`
  - https://winefolly.com/grapes/chardonnay/ — lemon; unoaked green apple; butter with oaked/malolactic styles; hazelnut with bottle age
  - https://www.winespectator.com/articles/chardonnay-57804 — lemon, apple; butter from malolactic/lees/oak
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/chardonnay-the-ultimate-grape-guide/ — lemony zest; green-apple acidity (Chablis); butter (oaked Meursault); 'distinct hazelnut flavours' (Chassagne)

**aged_note** — current: `null` → **adjusted** → proposed: `honey, mushroom`
  - https://winefolly.com/grapes/chardonnay/ — with bottle age: hazelnut, toasted nuts, honey, mushroom
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/chardonnay-the-ultimate-grape-guide/ — with time 'slightly honeyed, stony aromas' and sometimes mushroomy flavours

**body** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/grapes/chardonnay/ — medium body (lighter unoaked, fuller oaked)
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/chardonnay-the-ultimate-grape-guide/ — light and lean (Chablis) to full and rich (Côte d'Or)

**acidity** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/grapes/chardonnay/ — medium overall; high unoaked, moderate oaked
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/chardonnay-the-ultimate-grape-guide/ — keeps acidity in cool sites, can lose it in hot ones

**tannin** — current: `null` → **supported** → proposed: `null`
  - https://winefolly.com/grapes/chardonnay/ — white; no tannin

**similar** — current: `gr_0012` "just as versatile, fresher" → **supported** → proposed: `gr_0012` "just as versatile, fresher"
  - https://winefolly.com/grapes/chenin-blanc/ — Chenin: 'Riesling's acidity meets Chardonnay's body and texture'; oaked Chenin a 'perfect substitute for Chardonnay'
  - https://www.winecompanion.com.au/resources/varieties/chenin-blanc — 'a wide spectrum of styles', 'high acidity'; oaked version 'can look similar to chardonnay'

## gr_0003 Cabernet Sauvignon

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/grapes/cabernet-sauvignon/ — no synonyms listed
  - https://www.winespectator.com/articles/cabernet-sauvignon-57803 — no synonyms listed

**summary** — current: `Small, thick-skinned berries that give dark colour, firm tannins and a long life.` → **adjusted** → proposed: `Thick-skinned, giving deep colour, firm tannins and a long life; it gives Bordeaux blends their backbone.`
  - https://www.winespectator.com/articles/cabernet-sauvignon-57803 — 'thick blue skins', 'plentiful tannins', 'particularly ageworthy' (decades) — berry size not mentioned
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/cabernet-sauvignon-the-ultimate-grape-guide/ — 'thick-skinned'; 'deep ruby red'; robust/firm tannins; Merlot guide: Cabernet 'gives Bordeaux blends backbone and sturdiness'
  - https://www.winecompanion.com.au/resources/varieties/cabernet-sauvignon — 'deep colour and firm structure'; often tannic young; among the most ageworthy varieties
  - https://www.decanterchina.com/en/columns/fongyee-walkers-wine-study-guide/how-to-distinguish-cabernet-sauvignon-and-syrah-shiraz-in-blind-tasting — Decanter China (Fongyee Walker): 'thick skinned'; berry size not discussed — 'small' found in no source checked, so dropped

**tastes** — current: `{Blackcurrant, Cedar, Graphite}` → **supported** → proposed: `{Blackcurrant, Cedar, Graphite}`
  - https://winefolly.com/grapes/cabernet-sauvignon/ — black currant, cedar, graphite
  - https://www.winecompanion.com.au/resources/varieties/cabernet-sauvignon — cedar, cassis, currant; Bordeaux styles graphite
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/cabernet-sauvignon-the-ultimate-grape-guide/ — blackcurrant, cassis, cedar

**aged_note** — current: `tobacco, leather` → **adjusted** → proposed: `tobacco`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/cabernet-sauvignon-the-ultimate-grape-guide/ — with age Haut-Médoc takes on tobacco and cedar; NZ tobacco; leather only for aged Argentine wines
  - https://www.winespectator.com/articles/cabernet-sauvignon-57803 — tobacco (from oak); leather not mentioned
  - https://www.winecompanion.com.au/resources/varieties/cabernet-sauvignon — tobacco in Bordeaux styles; no leather

**body** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/cabernet-sauvignon/ — full body
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/cabernet-sauvignon-the-ultimate-grape-guide/ — medium to full depending on region

**acidity** — current: `3` → **adjusted** → proposed: `4`
  - https://winefolly.com/grapes/cabernet-sauvignon/ — medium-high acidity
  - https://www.decanterchina.com/en/columns/fongyee-walkers-wine-study-guide/how-to-distinguish-cabernet-sauvignon-and-syrah-shiraz-in-blind-tasting — Cabernet acidity 'on the high side, refreshing and lively'

**tannin** — current: `5` → **supported** → proposed: `5`
  - https://winefolly.com/grapes/cabernet-sauvignon/ — medium-high tannin, 'high tannin content'
  - https://www.winespectator.com/articles/cabernet-sauvignon-57803 — plentiful tannins, tannic structure
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/cabernet-sauvignon-the-ultimate-grape-guide/ — robust, firm tannins

**similar** — current: `gr_0004` "softer and rounder" → **supported** → proposed: `gr_0004` "softer and rounder"
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/merlot-the-ultimate-grape-guide/ — Merlot's 'natural roundness'; thinner skin, less tannin than cabernet
  - https://www.winespectator.com/articles/merlot-57809 — 'softer wines with plush tannins' than Cabernet

## gr_0004 Merlot

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/grapes/merlot/ — only obscure regional names (Bordeleza Belcha, Petit Merle)
  - https://www.winespectator.com/articles/merlot-57809 — none listed

**summary** — current: `Softer than Cabernet, with plush fruit; the backbone of Bordeaux's right bank.` → **adjusted** → proposed: `Softer than Cabernet, with plush fruit; the leading grape of Bordeaux's right bank.`
  - https://www.winespectator.com/articles/merlot-57809 — 'softer wines with plush tannins and fruit'; 'dominant grape' in Pomerol and St-Emilion
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/merlot-the-ultimate-grape-guide/ — majority grape in most right-bank clarets; 'backbone' is the word this guide uses for Cabernet, not Merlot
  - https://www.winecompanion.com.au/resources/varieties/merlot — generally softer; supple qualities balance cabernet's structure

**tastes** — current: `{Plum, Black cherry, Chocolate}` → **adjusted** → proposed: `{Plum, Cherry, Chocolate}`
  - https://winefolly.com/grapes/merlot/ — cherry, plum, chocolate
  - https://www.winecompanion.com.au/resources/varieties/merlot — cherry, plum, raspberry ('dark cherry' only in pairing notes)
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/merlot-the-ultimate-grape-guide/ — plums, chocolate; black cherry not mentioned
  - https://www.winespectator.com/articles/merlot-57809 — plum; cherries in caption; black cherry not in text

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/merlot-the-ultimate-grape-guide/ — no description of aged character
  - https://www.winespectator.com/articles/merlot-57809 — no aged notes

**body** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/merlot/ — medium-full body
  - https://www.winecompanion.com.au/resources/varieties/merlot — medium to full

**acidity** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/grapes/merlot/ — medium acidity
  - https://www.winecompanion.com.au/resources/varieties/merlot — medium acidity

**tannin** — current: `3` → **adjusted** → proposed: `4`
  - https://winefolly.com/grapes/merlot/ — 'Medium-High Tannins' (taste-profile box)
  - https://www.winecompanion.com.au/resources/varieties/merlot — medium-high, often tempered by oak; still lower than Cabernet (5)

## gr_0005 Syrah

**aliases** — current: `{Shiraz}` → **supported** → proposed: `{Shiraz}`
  - https://winefolly.com/grapes/syrah/ — Shiraz in Australia
  - https://www.winespectator.com/articles/syrah-57816 — 'better-known there as Shiraz'
  - https://www.winecompanion.com.au/resources/varieties/shiraz — shiraz also called syrah

**summary** — current: `Dark and spicy: black pepper in the cool northern Rhône, riper and jammier as Shiraz in warm places.` → **replaced** → proposed: `Dark-fruited and spicy: leaner and more savoury in the northern Rhône, riper and bolder as Shiraz in warm places like Australia.`
  - https://www.winespectator.com/articles/syrah-57816 — Old World 'somewhat leaner, emphasizing a savory character'; hot climates 'riper, bolder fruit'; pepper listed generally, not tied to N. Rhône; 'jammy' not used
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/syrah-shiraz-the-ultimate-grape-guide/ — South Australia 'bold, dense and concentrated'; does not tie pepper to the N. Rhône (pepper cited for Barossa); 'jammy' not used
  - https://winefolly.com/grapes/syrah/ — French versions more acidity, earthy/herbaceous; Australian/US more fruit-driven
  - https://www.winecompanion.com.au/resources/varieties/shiraz — warm-climate full-bodied, rich, ripe; cooler styles medium-bodied and spicy

**tastes** — current: `{Blackberry, Black pepper, Olive}` → **supported** → proposed: `{Blackberry, Black pepper, Olive}`
  - https://www.winespectator.com/articles/syrah-57816 — blackberry, black pepper, olive
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/syrah-shiraz-the-ultimate-grape-guide/ — blackberry; 'peppery character'; 'black olive character'
  - https://www.winecompanion.com.au/resources/varieties/shiraz — blackberry and pepper

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/syrah-shiraz-the-ultimate-grape-guide/ — mature syrah 'gamey, truffle notes' — only one source, so not proposed
  - https://www.winespectator.com/articles/syrah-57816 — 'quite ageworthy', no aged aromas

**body** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/syrah/ — full body
  - https://www.winecompanion.com.au/resources/varieties/shiraz — warm full-bodied, cool medium-bodied

**acidity** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/grapes/syrah/ — medium acidity
  - https://www.decanterchina.com/en/columns/fongyee-walkers-wine-study-guide/how-to-distinguish-cabernet-sauvignon-and-syrah-shiraz-in-blind-tasting — Syrah acidity tends to be lower than Cabernet's

**tannin** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/syrah/ — medium-high tannin
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/syrah-shiraz-the-ultimate-grape-guide/ — Côte-Rôtie 'relatively tannic', Cornas 'often tannic in youth', Barossa 'dark and tannic'

## gr_0006 Grenache

**aliases** — current: `{Garnacha}` → **supported** → proposed: `{Garnacha}`
  - https://www.winespectator.com/articles/grenache-57807 — 'known as Garnacha in Spain and Cannonau in Italy'
  - https://www.winecompanion.com.au/resources/varieties/grenache — Spanish name garnacha
  - https://winefolly.com/grapes/grenache/ — Garnacha

**summary** — current: `Loves heat; gives ripe, warm reds with soft tannins, usually in a blend.` → **adjusted** → proposed: `Loves heat; gives ripe, full, high-alcohol reds, most often in a blend, as in the southern Rhône.`
  - https://www.winespectator.com/articles/grenache-57807 — 'thrives in warm climates'; 'relatively high-alcohol'; star of Southern Rhône blends; tannin not described
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/grenache-the-ultimate-grape-guide/ — hot, dry sites; 'full-bodied', naturally high alcohol; usually blended in the southern Rhône
  - https://www.winecompanion.com.au/resources/varieties/grenache — warmest, driest regions; key role in blends; 'balanced tannins' (not 'soft')
  - https://winefolly.com/grapes/grenache/ — medium tannin, over 15% ABV — 'soft tannins' supported by only one source (TWS 'sweet, rounded'), so dropped

**tastes** — current: `{Strawberry, Raspberry, Dried herbs}` → **supported** → proposed: `{Strawberry, Raspberry, Dried herbs}`
  - https://winefolly.com/grapes/grenache/ — stewed strawberry, dried herbs
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/grenache-the-ultimate-grape-guide/ — strawberry, raspberry, herbs
  - https://www.winespectator.com/articles/grenache-57807 — raspberry; dried-herb notes (bay leaf)
  - https://www.winecompanion.com.au/resources/varieties/grenache — raspberry; herbal notes (oregano, lavender)

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/grenache-the-ultimate-grape-guide/ — 'grows old very gracefully' but no aroma list
  - https://www.winespectator.com/articles/grenache-57807 — ageing not covered

**body** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/grenache/ — medium-full body
  - https://www.winecompanion.com.au/resources/varieties/grenache — medium to full
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/grenache-the-ultimate-grape-guide/ — full-bodied, round

**acidity** — current: `2` → **adjusted** → proposed: `3`
  - https://winefolly.com/grapes/grenache/ — medium acidity
  - https://www.winecompanion.com.au/resources/varieties/grenache — medium acidity
  - https://www.winespectator.com/articles/grenache-57807 — 'low to moderate acidity' (spans 2–3)

**tannin** — current: `2` → **adjusted** → proposed: `3`
  - https://winefolly.com/grapes/grenache/ — medium tannins
  - https://www.winecompanion.com.au/resources/varieties/grenache — 'balanced tannins'
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/grenache-the-ultimate-grape-guide/ — 'sweet, rounded tannins' in Côtes-du-Rhône but Rasteau 'tannic when young'

## gr_0007 Tempranillo

**aliases** — current: `{Tinto Fino, Tinta del País, Tinta Roriz}` → **supported** → proposed: `{Tinto Fino, Tinta del País, Tinta Roriz}`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/tempranillo-the-ultimate-grape-guide/ — Ribera del Duero: 'tinto fino or tinta del país'; Tinta Roriz in Douro/Dão
  - https://www.winecompanion.com.au/resources/varieties/tempranillo — tinta roriz, aragonéz, Tinta del Pais, Cencibel
  - https://winefolly.com/grapes/tempranillo/ — Tinta Roriz, Tinta del País, Tinta de Toro
  - https://www.vivc.de/index.php?r=passport%2Fview&id=12350 — official catalogue: Tinto Fino, Tinta del Pais, Tinta Roriz all listed synonyms of Tempranillo Tinto

**summary** — current: `Spain's great red grape: medium-bodied, and it takes well to oak.` → **adjusted** → proposed: `Spain's flagship red grape: medium- to full-bodied, with firm tannins, and it takes well to oak.`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/tempranillo-the-ultimate-grape-guide/ — 'Spain's flagship red grape'; oak-aged styles develop vanilla, spice
  - https://www.winecompanion.com.au/resources/varieties/tempranillo — 'Spain's most planted red wine grape'
  - https://www.winespectator.com/articles/tempranillo-57817 — 'medium- to full-bodied reds', moderate to high tannin and acidity; oak ageing common (American/French)
  - https://winefolly.com/grapes/tempranillo/ — medium-full body; top wines in oak at least 12 months

**tastes** — current: `{Cherry, Dried fig, Leather, Vanilla, with oak}` → **adjusted** → proposed: `{Cherry, Plum, Dried fig, Vanilla, with oak}`
  - https://winefolly.com/grapes/tempranillo/ — cherry, dried fig, cedar, tobacco
  - https://www.winecompanion.com.au/resources/varieties/tempranillo — young: cherry, plum, tomato, dried fig; mature: leather, tobacco, vanilla
  - https://www.winespectator.com/articles/tempranillo-57817 — cherry, plum; oak adds vanilla
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/tempranillo-the-ultimate-grape-guide/ — leather and vanilla develop with age/oak — leather moved to aged_note

**aged_note** — current: `null` → **adjusted** → proposed: `leather, spice`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/tempranillo-the-ultimate-grape-guide/ — with a few years in bottle: 'leathery, oaky (vanilla, spice)' aromas
  - https://www.winecompanion.com.au/resources/varieties/tempranillo — mature wines: cedar, leather, tobacco, clove
  - https://winefolly.com/grapes/tempranillo/ — at 20 years: dried fruit, nuts, spices

**body** — current: `3` → **adjusted** → proposed: `4`
  - https://winefolly.com/grapes/tempranillo/ — medium-full body
  - https://www.winespectator.com/articles/tempranillo-57817 — medium- to full-bodied

**acidity** — current: `3` → **adjusted** → proposed: `4`
  - https://winefolly.com/grapes/tempranillo/ — medium-high acidity
  - https://www.winespectator.com/articles/tempranillo-57817 — moderate to high acidity
  - https://www.winecompanion.com.au/resources/varieties/tempranillo — high acidity

**tannin** — current: `3` → **adjusted** → proposed: `4`
  - https://winefolly.com/grapes/tempranillo/ — medium-high tannins
  - https://www.winespectator.com/articles/tempranillo-57817 — moderate to high tannins
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/tempranillo-the-ultimate-grape-guide/ — 'thick-skinned', Toro 'huge structure'

**similar** — current: `gr_0010` "similar cherry fruit, brighter" → **supported** → proposed: `gr_0010` "similar cherry fruit, brighter"
  - https://www.winespectator.com/articles/sangiovese-57814 — Sangiovese: cherry; 'high acidity'
  - https://winefolly.com/grapes/sangiovese/ — cherry; medium-high acidity, high acidity per deep-dive — 'brighter' = higher acidity than Tempranillo's medium-high

## gr_0008 Riesling

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/grapes/riesling/ — no synonyms
  - https://www.winespectator.com/articles/riesling-57813 — no synonyms

**summary** — current: `Aromatic and high in acidity, at home on steep, cool slopes; from bone-dry to lusciously sweet.` → **adjusted** → proposed: `Aromatic and high in acidity, at home in cool climates; made in every style from bone-dry to lusciously sweet.`
  - https://www.winespectator.com/articles/riesling-57813 — 'deep aromatic character'; high acidity; 'does best in cool climates'; south-facing slopes, not 'steep'; 'bone-dry to sweet'
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/riesling-the-ultimate-grape-guide/ — 'some of the coolest climate wine regions'; 'lusciously sweet' to 'bone dry'; south-facing slopes, never 'steep'
  - https://winefolly.com/grapes/riesling/ — aromatic; high acidity; cool climates; bone-dry to very sweet
  - https://www.winecompanion.com.au/resources/varieties/riesling — 'high-acid variety'; 'prefers a cool environment'

**tastes** — current: `{Lime, Green apple, Peach}` → **supported** → proposed: `{Lime, Green apple, Peach}`
  - https://winefolly.com/grapes/riesling/ — lime, green apple
  - https://www.winecompanion.com.au/resources/varieties/riesling — lemon, lime, tart Granny Smith apples
  - https://www.winespectator.com/articles/riesling-57813 — peach; lime in caption
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/riesling-the-ultimate-grape-guide/ — lime, peach, apricot

**aged_note** — current: `petrol, honey` → **adjusted** → proposed: `petrol, toast`
  - https://www.winespectator.com/articles/riesling-57813 — aged versions 'develop hints of petrol aromas'; honey not mentioned
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/riesling-the-ultimate-grape-guide/ — 'pronounced petrolly aroma'; Australian riesling gains toasty character; honey tied to sweet wines, not to age
  - https://www.winecompanion.com.au/resources/varieties/riesling — mature: 'nutty, toasty and honeyed' (only source for honey with age)

**body** — current: `2` → **supported** → proposed: `2`
  - https://winefolly.com/grapes/riesling/ — light body
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/riesling-the-ultimate-grape-guide/ — lighter in northern Europe/NZ, fuller in Alsace/Australia

**acidity** — current: `5` → **supported** → proposed: `5`
  - https://winefolly.com/grapes/riesling/ — high
  - https://www.winecompanion.com.au/resources/varieties/riesling — high-acid variety
  - https://www.winespectator.com/articles/riesling-57813 — high acidity

**tannin** — current: `null` → **supported** → proposed: `null`
  - https://winefolly.com/grapes/riesling/ — white; no tannin

## gr_0009 Nebbiolo

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/deep-dive/guide-to-nebbiolo-wine — Spanna (Novara), Chiavennasca (Lombardy) are regional names; empty list is not wrong
  - https://www.winespectator.com/articles/nebbiolo-57810 — no synonyms

**summary** — current: `Pale and perfumed, but with high acidity and strong tannins; it needs time.` → **supported** → proposed: `Pale and perfumed, but with high acidity and strong tannins; it needs time.`
  - https://www.thewinesociety.com/discover/explore/expertise/a-simple-guide-to-barolo/ — 'light red in colour'; 'perfumed'; 'brisk, high acidity'; 'firmest... tannins'; may take bottle ageing
  - https://www.winespectator.com/articles/nebbiolo-57810 — 'high levels of acidity and tannins'; 'tight and austere in their youth'; floral (rose, violet)
  - https://www.winecompanion.com.au/resources/varieties/italian-reds — 'Light in colour, but big in flavour'; ideal structure for ageing
  - https://winefolly.com/deep-dive/guide-to-nebbiolo-wine — 'translucent (like Pinot!)'

**tastes** — current: `{Rose, Tar, Red cherry}` → **supported** → proposed: `{Rose, Tar, Red cherry}`
  - https://www.thewinesociety.com/discover/explore/expertise/a-simple-guide-to-barolo/ — classic 'tar and roses'
  - https://www.winespectator.com/articles/whats-the-difference-between-nebbiolo-barolo-and-barbaresco-45751 — 'tar, rose, licorice and truffle'
  - https://www.winespectator.com/articles/nebbiolo-57810 — cherry, rose
  - https://winefolly.com/grapes/nebbiolo/ — cherry, rose

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.winespectator.com/articles/nebbiolo-57810 — with age: dried fruit, game, mushroom, truffle — one source only, not proposed
  - https://www.thewinesociety.com/discover/explore/expertise/a-simple-guide-to-barolo/ — spice and tertiary flavours, unspecified

**body** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/grapes/nebbiolo/ — medium-full (4)
  - https://www.thewinesociety.com/discover/explore/expertise/a-simple-guide-to-barolo/ — 'can make it feel medium to light-bodied' (2–3) — sources split, 3 kept as the midpoint; flag for editor

**acidity** — current: `5` → **supported** → proposed: `5`
  - https://www.winespectator.com/articles/nebbiolo-57810 — high acidity
  - https://www.thewinesociety.com/discover/explore/expertise/a-simple-guide-to-barolo/ — 'brisk, high acidity'
  - https://winefolly.com/deep-dive/guide-to-nebbiolo-wine — high acidity

**tannin** — current: `5` → **supported** → proposed: `5`
  - https://winefolly.com/grapes/nebbiolo/ — high tannins
  - https://www.thewinesociety.com/discover/explore/expertise/a-simple-guide-to-barolo/ — 'some of the wine world's firmest... tannins'
  - https://www.winespectator.com/articles/nebbiolo-57810 — high tannins

**similar** — current: `gr_0001` "also pale and perfumed, much softer" → **supported** → proposed: `gr_0001` "also pale and perfumed, much softer"
  - https://www.thewinesociety.com/discover/explore/expertise/a-simple-guide-to-barolo/ — Barolo 'can resemble pinot noir in the glass'
  - https://winefolly.com/deep-dive/guide-to-nebbiolo-wine — 'translucent (like Pinot!)'
  - https://www.winespectator.com/articles/pinot-noir-57812 — Pinot: low tannins

## gr_0010 Sangiovese

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/deep-dive/guide-to-sangiovese-wine/ — Prugnolo Gentile, Sangiovese Grosso, Nielluccio, Morellino listed (some are wine names); empty list is not wrong
  - https://www.winespectator.com/articles/sangiovese-57814 — none

**summary** — current: `Italy's most planted red: bright, savoury and fresh, made for food.` → **adjusted** → proposed: `Italy's most planted red, at the heart of Tuscany's wines: cherry-fruited and savoury, with high acidity and firm tannins.`
  - https://www.winespectator.com/articles/sangiovese-57814 — 'most widely planted grape variety in the country'; savory; high acidity; tannic
  - https://winefolly.com/grapes/sangiovese/ — 'Italy's most planted wine variety', 'pride of Chianti'; medium-high acidity and tannin
  - https://www.winecompanion.com.au/resources/varieties/italian-reds — 'most planted in Italy'; 'high acid', 'high tannin', savoury
  - https://vinepair.com/articles/complete-sangiovese-wine-guide/ — 'king' of Tuscan wine; 'made for food' found in no two sources, so dropped

**tastes** — current: `{Sour cherry, Tomato leaf, Dried herbs}` → **adjusted** → proposed: `{Sour cherry, Tomato, Herbs}`
  - https://vinepair.com/articles/complete-sangiovese-wine-guide/ — 'particularly sour cherry'; tomato; fennel, rosemary, thyme
  - https://winefolly.com/deep-dive/guide-to-sangiovese-wine/ — tart cherry; tomato; oregano, thyme — neither names 'tomato leaf' or 'dried' herbs
  - https://www.winespectator.com/articles/sangiovese-57814 — cherry, earth

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://winefolly.com/deep-dive/guide-to-sangiovese-wine/ — ages toward dried cherries, figs, roses — one org only
  - https://www.winespectator.com/articles/sangiovese-57814 — 'long-lived', no aromas

**body** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/deep-dive/guide-to-sangiovese-wine/ — 'medium weighted body' (grapes page says medium-full)
  - https://www.winecompanion.com.au/resources/varieties/italian-reds — medium- to full-bodied

**acidity** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/sangiovese/ — medium-high acidity
  - https://www.winespectator.com/articles/sangiovese-57814 — high acidity
  - https://www.winecompanion.com.au/resources/varieties/italian-reds — high acid

**tannin** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/sangiovese/ — medium-high tannins
  - https://www.winespectator.com/articles/sangiovese-57814 — tannic
  - https://www.winecompanion.com.au/resources/varieties/italian-reds — high tannin

## gr_0011 Sauvignon Blanc

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://www.winespectator.com/articles/sauvignon-blanc-57815 — 'Fumé Blanc' was a Mondavi label term, not a synonym
  - https://winefolly.com/grapes/sauvignon-blanc/ — no synonyms

**summary** — current: `Crisp and green, with high acidity: flinty in the Loire, tropical in New Zealand.` → **adjusted** → proposed: `Crisp, green and high in acidity: flinty and mineral in the Loire, pungently fruity in New Zealand.`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/sauvignon-blanc-the-ultimate-grape-guide/ — 'racing acidity'; 'green nettle'; Loire gun-flint; Marlborough 'pungently aromatic', tropical
  - https://winefolly.com/grapes/sauvignon-blanc/ — 'green' herbal flavours, racy acidity; Loire flint and smoke; Marlborough 'more citrus-focused than big and tropical' — so 'tropical' is contested
  - https://www.thewinesociety.com/discover/explore/regional-guides/loire-wine-guide/ — 'refined, flinty sauvignon blanc'
  - https://www.winespectator.com/articles/sauvignon-blanc-57815 — NZ zingy, citrus and herbal; tropical only for California

**tastes** — current: `{Gooseberry, Grapefruit, Cut grass}` → **adjusted** → proposed: `{Gooseberry, Passion fruit, Cut grass}`
  - https://winefolly.com/grapes/sauvignon-blanc/ — gooseberry, grapefruit, passion fruit; Loire grassy
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/sauvignon-blanc-the-ultimate-grape-guide/ — gooseberry; 'fresh-cut grass'; passionfruit (NZ); grapefruit not mentioned
  - https://www.winespectator.com/articles/sauvignon-blanc-57815 — gooseberries; no grapefruit
  - https://www.thewinesociety.com/discover/explore/regional-guides/loire-wine-guide/ — 'fresh, grassy'

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/sauvignon-blanc-the-ultimate-grape-guide/ — Loire best young
  - https://winefolly.com/grapes/sauvignon-blanc/ — cellar 3–5 years

**body** — current: `2` → **supported** → proposed: `2`
  - https://winefolly.com/grapes/sauvignon-blanc/ — medium-light
  - https://www.winespectator.com/articles/sauvignon-blanc-57815 — Loire/NZ light styles

**acidity** — current: `5` → **supported** → proposed: `5`
  - https://winefolly.com/grapes/sauvignon-blanc/ — high
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/sauvignon-blanc-the-ultimate-grape-guide/ — 'racing acidity'

**tannin** — current: `null` → **supported** → proposed: `null`
  - https://winefolly.com/grapes/sauvignon-blanc/ — no tannins

**similar** — current: `gr_0008` "even more aromatic" → **adjusted** → proposed: `gr_0008` "just as crisp, from bone-dry to sweet"
  - https://winefolly.com/grapes/riesling/ — Riesling: high acidity, bone-dry to very sweet
  - https://www.winespectator.com/articles/riesling-57813 — high acidity; 'bone-dry to sweet' — no source compares the two grapes' aromatic intensity, so 'even more aromatic' is unsupported

## gr_0012 Chenin Blanc

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/grapes/chenin-blanc/ — Steen, Pineau (regional)
  - https://www.winespectator.com/articles/chenin-blanc-57805 — Steen in South Africa — could be added, not required

**summary** — current: `Versatile: dry, off-dry, sweet or sparkling, always with fresh acidity.` → **supported** → proposed: `Versatile: dry, off-dry, sweet or sparkling, always with fresh acidity.`
  - https://winefolly.com/grapes/chenin-blanc/ — dry, off-dry, sweet, sparkling; 'high levels of zingy acidity no matter the style'
  - https://www.winecompanion.com.au/resources/varieties/chenin-blanc — 'wide spectrum of styles' incl. sparkling; 'high acidity'
  - https://www.winespectator.com/articles/chenin-blanc-57805 — 'range of styles and sweetness levels'; high acidity

**tastes** — current: `{Quince, Apple, Honey}` → **adjusted** → proposed: `{Yellow apple, Pear, Honey}`
  - https://winefolly.com/grapes/chenin-blanc/ — quince, yellow apple, pear, honey
  - https://www.winespectator.com/articles/chenin-blanc-57805 — yellow apple, pear; quince not mentioned
  - https://www.winecompanion.com.au/resources/varieties/chenin-blanc — honeyed note; no quince

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.thewinesociety.com/discover/explore/regional-guides/loire-wine-guide/ — 'greater finesse and complexity with age', no aromas
  - https://winefolly.com/grapes/chenin-blanc/ — ages for decades, aromas not specified

**body** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/grapes/chenin-blanc/ — medium-light (2)
  - https://www.winecompanion.com.au/resources/varieties/chenin-blanc — 'crisp and dry' to 'richer, fuller-bodied' — range; kept at 3, weakly supported

**acidity** — current: `5` → **supported** → proposed: `5`
  - https://winefolly.com/grapes/chenin-blanc/ — high
  - https://www.winecompanion.com.au/resources/varieties/chenin-blanc — high acidity

**tannin** — current: `null` → **supported** → proposed: `null`
  - https://winefolly.com/grapes/chenin-blanc/ — no tannins

## gr_0013 Cabernet Franc

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/grapes/cabernet-franc/ — Breton, Bouchet (regional)
  - https://www.thewinesociety.com/discover/explore/regional-guides/loire-wine-guide/ — none

**summary** — current: `Lighter than Cabernet Sauvignon, fragrant, sometimes a little leafy.` → **supported** → proposed: `Lighter than Cabernet Sauvignon, fragrant, sometimes a little leafy.`
  - https://winefolly.com/grapes/cabernet-franc/ — tannins 'not as high as those of Cabernet Sauvignon'; more floral; bell pepper (methoxypyrazines)
  - https://www.thewinesociety.com/discover/explore/regional-guides/loire-wine-guide/ — 'lovely fragrance and freshness', 'gentle tannin', 'moderate alcohol'
  - https://www.masterclass.com/articles/learn-about-cabernet-franc-grapes-wine-region-and-tasting-notes — lighter-bodied, less tannic than Cabernet Sauvignon; bell pepper, herbs (lower-tier source)

**tastes** — current: `{Raspberry, Bell pepper, Violet}` → **supported** → proposed: `{Raspberry, Bell pepper, Violet}`
  - https://winefolly.com/grapes/cabernet-franc/ — raspberry, bell pepper
  - https://www.masterclass.com/articles/learn-about-cabernet-franc-grapes-wine-region-and-tasting-notes — bell pepper, roasted red pepper
  - https://www.thewinesociety.com/product/the-societys-chinon-2022/ — Chinon: 'violet-scented fruit' (wine note, not a grape profile)
  - https://www.winespectator.com/wine/wine-detail/id/1332416/name/jean-maurice-raffault-chinon-les-galuches-2023/guest — Chinon: violet, black raspberry (wine review)

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://winefolly.com/grapes/cabernet-franc/ — 'very savory with age' — too vague to propose

**body** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/grapes/cabernet-franc/ — medium
  - https://www.thewinesociety.com/discover/explore/regional-guides/loire-wine-guide/ — moderate alcohol, gentle structure

**acidity** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/cabernet-franc/ — high acidity
  - https://www.masterclass.com/articles/learn-about-cabernet-franc-grapes-wine-region-and-tasting-notes — Loire examples lean and high in acid

**tannin** — current: `3` → **supported** → proposed: `3`
  - https://winefolly.com/grapes/cabernet-franc/ — medium-high (4)
  - https://www.thewinesociety.com/discover/explore/regional-guides/loire-wine-guide/ — 'gentle tannin' (2) — split; 3 kept as midpoint

## gr_0014 Gamay

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://winefolly.com/grapes/gamay/ — no synonyms

**summary** — current: `Light, juicy and low in tannin: the grape of Beaujolais.` → **supported** → proposed: `Light, juicy and low in tannin: the grape of Beaujolais.`
  - https://www.thewinesociety.com/discover/explore/expertise/why-i-love-gamay/ — 'light, juicy bistro bottles', 'low tannins'; Beaujolais its 'spiritual home'
  - https://winefolly.com/deep-dive/tasters-guide-to-gamay-wine/ — 'light-bodied', 'low tannin'
  - https://winefolly.com/grapes/gamay/ — 'the main variety planted in Beaujolais'

**tastes** — current: `{Red cherry, Raspberry, Violet}` → **supported** → proposed: `{Red cherry, Raspberry, Violet}`
  - https://winefolly.com/deep-dive/tasters-guide-to-gamay-wine/ — cherry, raspberry, 'fresh cut violets'
  - https://www.thewinesociety.com/discover/explore/expertise/why-i-love-gamay/ — cherries, raspberries, cranberries
  - https://www.beaujolais.com/en/taste/tasting-advice/vintages/ — Inter Beaujolais vintage notes: cherry, raspberry, violet, peony

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.thewinesociety.com/discover/explore/expertise/why-i-love-gamay/ — crus 'age-worthy', no aromas

**body** — current: `2` → **supported** → proposed: `2`
  - https://winefolly.com/grapes/gamay/ — medium-light
  - https://winefolly.com/deep-dive/tasters-guide-to-gamay-wine/ — light-bodied
  - https://www.thewinesociety.com/discover/explore/expertise/why-i-love-gamay/ — light, juicy

**acidity** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/gamay/ — medium-high
  - https://www.thewinesociety.com/discover/explore/expertise/why-i-love-gamay/ — 'lively acidity'

**tannin** — current: `1` → **supported** → proposed: `1`
  - https://winefolly.com/deep-dive/tasters-guide-to-gamay-wine/ — low tannin
  - https://www.thewinesociety.com/discover/explore/expertise/why-i-love-gamay/ — low tannins

## gr_0015 Touriga Nacional

**aliases** — current: `{}` → **supported** → proposed: `{}`
  - https://www.winecompanion.com.au/resources/varieties/touriga-nacional — 'touriga' shortening only
  - https://winefolly.com/grapes/touriga-nacional/ — none

**summary** — current: `Portugal's leading grape: dark, floral and structured, the heart of port and of dry Douro reds.` → **adjusted** → proposed: `Portugal's best-known red grape: dark, floral and firmly structured, a key grape in port and in dry Douro reds.`
  - https://www.winecompanion.com.au/resources/varieties/touriga-nacional — 'Portugal's best-known red grape variety'; 'most famous variety used for port'; deep colour; violets; high tannins
  - https://www.systembolaget.se/vin/druvans-varld/druvsorter/touriga-nacional/ — Swedish state retailer: 'Portugal's most famous grape variety'; important port component; Douro
  - https://winefolly.com/deep-dive/exploring-touriga-nacional-wine/ — 'primary blending grape' in port; dry reds; 'bold tannin'; Wine Folly grapes page calls it only 'increasingly important' — 'leading'/'heart' not supported

**tastes** — current: `{Blackberry, Violet, Bergamot}` → **supported** → proposed: `{Blackberry, Violet, Bergamot}`
  - https://winefolly.com/deep-dive/exploring-touriga-nacional-wine/ — blackberry; 'violet, bergamot and Earl Grey tea'
  - https://www.systembolaget.se/vin/druvans-varld/druvsorter/touriga-nacional/ — blackberry; violet, mint or bergamot
  - https://www.winecompanion.com.au/resources/varieties/touriga-nacional — violets, Earl Grey (bergamot-scented) tea, blackberry

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://winefolly.com/deep-dive/exploring-touriga-nacional-wine/ — tannins soften; oak adds vanilla — not grape aromas

**body** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/touriga-nacional/ — full body
  - https://www.winecompanion.com.au/resources/varieties/touriga-nacional — full-bodied

**acidity** — current: `3` → **adjusted** → proposed: `4`
  - https://winefolly.com/grapes/touriga-nacional/ — medium-high acidity
  - https://www.winecompanion.com.au/resources/varieties/touriga-nacional — 'a great fresh acidity'

**tannin** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/touriga-nacional/ — high tannins
  - https://www.winecompanion.com.au/resources/varieties/touriga-nacional — 'high tannins'

## gr_0016 Meunier

**aliases** — current: `{Pinot Meunier}` → **supported** → proposed: `{Pinot Meunier}`
  - https://winefolly.com/grapes/pinot-meunier/ — page titled Pinot Meunier
  - https://www.winetraveler.com/grape/pinot-meunier/ — Pinot Meunier
  - https://en.wikipedia.org/wiki/Pinot_Meunier — also Schwarzriesling, Müllerrebe in Germany (could be added)

**summary** — current: `A cousin of Pinot Noir grown mostly in Champagne, where it adds fruit and roundness.` → **adjusted** → proposed: `A mutation of Pinot Noir, best known in Champagne, where it adds fruit and roundness to the blend.`
  - https://www.winetraveler.com/grape/pinot-meunier/ — 'a mutation of Pinot Noir'; adds fruit, softness and early approachability; ~40% of Champagne plantings
  - https://www.winecompanion.com.au/resources/varieties/pinot-noir — pinot meunier is a mutation within the Pinot family, confirmed by DNA (1993)
  - https://en.wikipedia.org/wiki/Pinot_Meunier — chimeric mutation of Pinot; about one-third of Champagne (cites NYT/Oxford Companion); also grown in Germany
  - https://www.cellartours.com/blog/france/the-third-variety-pinot-meunier — adds 'ripe fruit' to NV blends; over one-third of Champagne — 'grown mostly in Champagne' (share of world plantings) not stated by any source, 'cousin' understates a mutation

**tastes** — current: `{Red apple, Red berries}` → **replaced** → proposed: `{Cherry, Red berries, Mushroom}`
  - https://winefolly.com/grapes/pinot-meunier/ — tart cherry, pomegranate, mushroom, rose
  - https://www.winetraveler.com/grape/pinot-meunier/ — cherry, raspberry, strawberry; 'earthy, mushroomy notes'
  - https://www.cellartours.com/blog/france/the-third-variety-pinot-meunier — red berries — 'red apple' found only in a sparkling producer note, not in any grape profile

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.cellartours.com/blog/france/the-third-variety-pinot-meunier — matures faster than Pinot Noir
  - https://en.wikipedia.org/wiki/Pinot_Meunier — less ageing potential (Oxford Companion)

**body** — current: `2` → **supported** → proposed: `2`
  - https://winefolly.com/grapes/pinot-meunier/ — medium-light
  - https://www.winetraveler.com/grape/pinot-meunier/ — still versions 'light-bodied'

**acidity** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/grapes/pinot-meunier/ — medium-high
  - https://www.winetraveler.com/grape/pinot-meunier/ — high-acid

**tannin** — current: `1` → **supported** → proposed: `1`
  - https://winefolly.com/grapes/pinot-meunier/ — low tannins
  - https://www.winetraveler.com/grape/pinot-meunier/ — low tannin

## gr_0017 Mourvèdre

**aliases** — current: `{Monastrell, Mataro}` → **supported** → proposed: `{Monastrell, Mataro}`
  - https://winefolly.com/deep-dive/mourvedre-wine/ — Monastrell, Mataró
  - https://www.winecompanion.com.au/resources/varieties/mourvedre — 'mataro and monastrell'

**summary** — current: `Dark and meaty, it needs heat; it gives structure to southern Rhône blends.` → **supported** → proposed: `Dark and meaty, it needs heat; it gives structure to southern Rhône blends.`
  - https://winefolly.com/deep-dive/mourvedre-wine/ — 'meaty and full-bodied'; 'thick-skinned', ripens very late, warm climates; Rhône blending grape (Châteauneuf)
  - https://www.winecompanion.com.au/resources/varieties/mourvedre — 'robust structure'; late-ripening, needs sunshine; major component in Châteauneuf-du-Pape and Gigondas

**tastes** — current: `{Blackberry, Game, Black pepper}` → **supported** → proposed: `{Blackberry, Game, Black pepper}`
  - https://winefolly.com/deep-dive/mourvedre-wine/ — blackberry, black pepper, meat; Bandol/Jumilla 'very gamey'
  - https://www.winecompanion.com.au/resources/varieties/mourvedre — blackberry; black pepper; 'meaty'

**aged_note** — current: `null` → **supported** → proposed: `null`
  - https://www.winecompanion.com.au/resources/varieties/mourvedre — chocolate and leather can develop with age — one source only

**body** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/deep-dive/mourvedre-wine/ — full-bodied
  - https://www.winecompanion.com.au/resources/varieties/mourvedre — robust structure

**acidity** — current: `3` → **adjusted** → proposed: `4`
  - https://winefolly.com/deep-dive/mourvedre-wine/ — 'Medium (+)' acidity
  - https://www.winecompanion.com.au/resources/varieties/mourvedre — 'excellent acid structure'

**tannin** — current: `4` → **supported** → proposed: `4`
  - https://winefolly.com/deep-dive/mourvedre-wine/ — high tannin
  - https://www.winecompanion.com.au/resources/varieties/mourvedre — 'high tannin'

## Totals

- Fields checked: 125 (7 per grape × 17 + 6 similar links).
- Fields with a proposed change: 31 (= rows in grapes_classic.json).

## Weakly sourced (kept, flag for editor)

- Cabernet Franc tastes (raspberry / bell pepper / violet): Wine Folly plus MasterClass and individual Chinon wine notes (Wine Society, Wine Spectator); no second grape-profile source reachable.
- Cabernet Franc tannin 3 and Nebbiolo body 3: two good sources disagree (one above, one below); kept as midpoint.
- Chenin Blanc body 3: Wine Folly says medium-light (2); Halliday gives a crisp-to-full range. Kept, weak.
- Meunier: best available sources are Wine Folly, Wine Traveler, Cellar Tours, Wikipedia (citing Oxford Companion) and Halliday's Pinot Noir page; Comité Champagne and Decanter pages were unreachable.

## Optional additions (not proposed in JSON)

- Possible synonyms: Grenache → Cannonau (only Wine Spectator checked, needs a second source); Meunier → Schwarzriesling, Müllerrebe (Wikipedia, Wine With Seth); Chenin Blanc → Steen (Wine Folly, Wine Spectator).
- Nebbiolo aged_note (dried fruit, mushroom, truffle) and Syrah aged_note (game, truffle) each had only one source.
