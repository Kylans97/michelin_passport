# Grape tastes and summaries: fixes for the 41 audit flags

Checked 2026-11-22 against grapes_base.csv. Proposals only; nothing written to the database.

## Method

- Follows grapes_classic.md: two independent organisations per claim, URL plus what each says. Two pages of one organisation count once.
- Lower tier sources (Wikipedia, Viniou, VinoVoss, merchants, single wine notes, blogs) used only where nothing better was reachable and labelled [lower tier].
- [seen in search only] means the page refused the fetch (403, paywall, truncation) and its wording was read in search results. Counted, but marked so the editor can confirm in a browser.
- Refused fetches throughout: austrianwine.com, Jancis Robinson, Wine-Searcher, Wine Enthusiast, most Decanter article bodies, winesofhungary.hu (redirects to a 404).
- held back = fewer than two tastes (or no claim) reached two sources; the field stays as it is.

## gr_0168 Areni

**tastes**: current: `["Cherry", "Plum", "Black pepper and spice"]` → **proposed** → proposed: `["Cherry", "Spice"]`
  - https://mag.sommtv.com/2023/10/areni-grape-variety/ (SOMM TV Magazine [lower tier]): red and black fruit, hints of cassis and spices; cherry, raspberry, mulberry
  - https://www.viniou.com/grape-varieties/889_areni-noir (Viniou [lower tier]): red cherry, pomegranate; hints of black pepper; spice and herbs
  - https://wineanorak.com/2021/11/22/armenian-wine-a-brief-study/ (wineanorak (Jamie Goode), single wines [lower tier]): cherry and plum fruit, a spicy finish
  - Note: "Black pepper and spice" simplified to Spice. Plum dropped (one source). Black pepper held back: Viniou plus one single wine note on Vinography. No top tier source reachable (Wine Folly 404, Wine-Searcher 403).

## gr_0002 Chardonnay

**tastes**: current: `["Lemon", "Green apple", "Butter, with oak", "Hazelnut"]` → **proposed** → proposed: `["Lemon", "Green apple", "Butter", "Hazelnut"]`
  - https://winefolly.com/grapes/chardonnay/ (Wine Folly): butter comes mainly from diacetyl made during malolactic fermentation; oak gives vanilla, cream and clove
  - https://www.internationalwinechallenge.com/iwc-insight/production/butter-bombs-are-back-in-demand.html (International Wine Challenge): buttery notes come from malolactic fermentation; oak adds butterscotch and brown sugar
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/chardonnay-the-ultimate-grape-guide/ (The Wine Society): oak, malolactic and lees stirring each add layers; butter in oaked Meursault; oak adds vanilla, toast or toffee
  - Note: The suggested "Butter from oak" would be wrong: both sources put butter down to malolactic fermentation, not oak. Plain "Butter" keeps the chip accurate (it is a winemaking note in oaked, malolactic styles; the summary already says winemaking can make it buttery). Other tastes unchanged, sourced in grapes_classic.md.

## gr_0032 Semillon

**summary**: current: `A white grape that once covered most of the Cape's vineyards. It gives fuller bodied wines, and in South Africa it is closely tied to Franschhoek.` → **proposed** → proposed: `A white grape that gives fuller bodied wines with a waxy texture and lemon notes, often blended with Sauvignon Blanc. It is the main grape of sweet Sauternes, and in the Hunter Valley it makes light, dry wines that age for decades.`
  - https://winefolly.com/grapes/semillon/ (Wine Folly): medium to fuller body, silky to oily texture; lemon and beeswax; paired with Sauvignon Blanc in white Bordeaux; botrytis gives Sauternes; Hunter Valley wines lean, dry, early picked, long ageing
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/semillon-the-ultimate-grape-guide (The Wine Society): "Waxy", "Lemon"; its fatness and body complement Sauvignon; about 80% of Sauternes; Hunter Valley makes the longest lived dry Semillons
  - https://winecompanion.com.au/articles/wine-lists/semillon-variety-spotlight (Halliday Wine Companion): light to medium bodied Hunter Semillon, lemon citrus young, able to age for decades
  - Note: Removed (South Africa specific, move to the Franschhoek region note): "A white grape that once covered most of the Cape's vineyards." and "in South Africa it is closely tied to Franschhoek." Neither was verified in this pass (Wine Folly alone says it was once the most planted grape there; nothing found for Franschhoek), so verify with WOSA before the region note uses them. "Low acidity" deliberately left out: sources disagree.

**tastes**: current: `["Beeswax", "Lemon", "Peach"]` → **held back** → proposed: `unchanged`
  - https://winefolly.com/grapes/semillon/ (Wine Folly): lemon, beeswax, peach among primary flavours
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/semillon-the-ultimate-grape-guide (The Wine Society): waxy, lanolin, lemon (no peach)
  - https://www.firstleaf.com/a/wine-directory/varietals/semillon (Firstleaf [lower tier] [seen in search only, page did not load]): peach in warm climate styles
  - Note: Not flagged, checked on the way. Lemon and Beeswax have two sources; Peach has only Wine Folly plus a lower tier merchant. Left unchanged; editor may drop Peach.

## gr_0178 Bonarda

**tastes**: current: `["Spice"]` → **proposed** → proposed: `["Cherry", "Plum", "Spice"]`
  - https://winefolly.com/grapes/bonarda/ (Wine Folly): plum sauce, cherry, cardamom, fig paste, graphite
  - https://southamericawineguide.com/a-guide-to-bonarda/ (South America Wine Guide [lower tier]): cherries, plums, cloves
  - Note: Spice kept as the umbrella for cardamom (Wine Folly) and cloves; neither uses the word. Strict option: ["Cherry", "Plum"].

## gr_0049 Pinot Blanc

**summary**: current: `A white grape called Weissburgunder in Austria. It gives dry wines with citrus and stone fruit notes and a mineral edge, usually made to drink young.` → **proposed** → proposed: `A white grape called Weissburgunder in Germany and Austria and Pinot Bianco in Italy. It gives light, fresh dry wines with gentle pear, peach and lemon notes, and is also used for sparkling wine such as Crémant d'Alsace.`
  - https://winefolly.com/grapes/pinot-blanc/ (Wine Folly): light body, medium acidity; pear, peach, almond, lemon zest; grown mainly in Germany and northern Italy
  - https://www.falstaff.com/en/grape-varieties/weissburgunder (Falstaff): synonyms Pinot Bianco and Weissburgunder; Italian wines fresh and fruity; an important part of Crémant d'Alsace
  - https://www.yahoo.com/now/meet-pinot-blanc-star-alsace-224625793.html (Food & Wine (syndicated on Yahoo)): Pinot Bianco in Italy, Weissburgunder in Austria; peach, lemon, pears and apples; still or sparkling
  - Note: Removed (Austria specific framing): "A white grape called Weissburgunder in Austria." kept as part of a general naming clause, so nothing needs to move. Also dropped "usually made to drink young": Falstaff and Food & Wine both say some versions age well. "Mineral edge" dropped with the Mineral taste (one source).

**tastes**: current: `["Lemon zest", "Peach", "Mineral"]` → **proposed** → proposed: `["Pear", "Peach", "Lemon zest"]`
  - https://winefolly.com/grapes/pinot-blanc/ (Wine Folly): pear, peach, lemon zest, almond, crushed gravel
  - https://www.yahoo.com/now/meet-pinot-blanc-star-alsace-224625793.html (Food & Wine (syndicated on Yahoo)): peach, nectarine, lemon, pears and apples
  - Note: Mineral dropped: only Wine Folly ("crushed gravel") plus single producer notes. Pear added (two sources).

## gr_0050 Muscat Blanc à Petits Grains

**summary**: current: `A highly aromatic white grape of the Muscat family. In Austria it is called Gelber Muskateller or simply Muskateller.` → **proposed** → proposed: `A highly aromatic white grape of the Muscat family, whose wines keep the scent of fresh grapes. It is made in many styles, from dry to sweet, still or sparkling, and as fortified wine.`
  - https://winefolly.com/grapes/muscat-blanc/ (Wine Folly): available in many styles, from dry to sweet, still, sparkling and fortified
  - https://guildsomm.com/public_content/features/articles/b/bryce-wiatrak/posts/introduction-to-muscat (GuildSomm): the most distinguished Muscat; dry in Alsace, dry and sweet in Austria, fortified on Samos and in Rivesaltes; sparkling to botrytised
  - https://www.thewinesociety.com/discover/explore/the-road-less-travelled/muscat-diverse-fragrant-wine (The Wine Society): the aroma and taste of fresh grapes persists from grape to young wine; dry Muscat d'Alsace; often fortified
  - Note: Removed (Austria specific, move to the Südsteiermark region note): "In Austria it is called Gelber Muskateller or simply Muskateller." That synonym rests on GuildSomm plus the alias list; austrianwine.com refused fetches. "Fresh grapes" scent: The Wine Society plus lower tier Enotria&Coe only.

**tastes**: current: `[]` → **proposed** → proposed: `["Grapes", "Orange blossom"]`
  - https://www.thewinesociety.com/discover/explore/the-road-less-travelled/muscat-diverse-fragrant-wine (The Wine Society): fresh grape aroma persists into the wine
  - https://winefolly.com/grapes/muscat-blanc/ (Wine Folly): orange blossom among primary flavours
  - https://www.enotria.com/wine/grapes/muscat-blanc-a-petits-grains/ (Enotria&Coe [lower tier] [seen in search only, page did not load]): fresh grapes, orange blossom
  - Note: Weak: each taste has one top source plus one lower tier merchant. Peach held back (Wine Society says it of Muscat in general; GuildSomm only in one Alsace wine). If lower tier support is not acceptable, hold the whole field back.

## gr_0132 St. Laurent

**tastes**: current: `["Blackberry"]` → **proposed** → proposed: `["Cherry", "Blackcurrant"]`
  - https://www.vinarskecentrum.cz/storage/files/odrudy-vune-brozura-AJ-2021-web.pdf (Czech National Wine Centre grape brochure): sour cherry, plum jam and sometimes blackcurrant
  - https://www.winesofgermany.com/our-wine/grape-varieties/grape-variety/95/st-laurent (Wines of Germany (DWI)): wild cherry, elderberry, cassis, dark chocolate
  - https://winefolly.com/grapes/st-laurent/ (Wine Folly): raspberry, blackberry, tobacco, baking spice; yields cherry flavoured wines
  - https://www.austrianwine.com/our-wine/grape-varieties/red-wine/st-laurent (Austrian Wine [seen in search only, page did not load]): morello cherry, berries, plums
  - Note: Blackberry dropped: Wine Folly only. Sour cherry and Plum would also qualify if Austrian Wine (refused every fetch, seen in search text) is confirmed in a browser: then ["Sour cherry", "Plum", "Blackcurrant"].

## gr_0095 Portugieser

**summary**: current: `A red grape once called Kékoportó in Hungary, where Villány is its stronghold. It gives light, fruity reds with soft tannins, mostly drunk young, and is the base of Redy.` → **proposed** → proposed: `A red grape traced to north east Slovenia and grown mainly in Germany, Austria and Hungary. It gives light, fruity reds with soft tannins, mostly drunk young.`
  - https://www.winesofgermany.com/our-wine/grape-varieties/grape-variety/91/portugieser (Wines of Germany (DWI)): origin traced to north east Slovenia; Austria and Hungary the other main countries; light ruby, moderate tannin, berry flavours
  - https://www.vinarskecentrum.cz/storage/files/odrudy-vune-brozura-AJ-2021-web.pdf (Czech National Wine Centre grape brochure): origin Slovenia (Lower Styria); pale ruby, lower acidity and tannin; used for young St Martin's wines
  - https://www.meininger.de/wein/rebsorten/Portugieser (Meininger [seen in search only, page did not load]): from north east Slovenia; fruity, light, young and accessible
  - Note: Removed (Hungary specific, move to the Villány region note): "once called Kékoportó in Hungary", "where Villány is its stronghold", "is the base of Redy". None verified on an official page here (winesofhungary.hu redirects to a 404); secondary sources say Kékoportó was renamed in 2004 and RedY needs at least 51% Portugieser. "Pale ruby" left out because a Hungarian source describes deeper colour in Villány.

**tastes**: current: `["Red berries", "Spice", "Floral"]` → **proposed** → proposed: `["Cherry", "Raspberry", "Violet"]`
  - https://www.winesofgermany.com/our-wine/grape-varieties/grape-variety/91/portugieser (Wines of Germany (DWI)): redcurrant, raspberry, strawberry, sometimes sour cherry or pepper
  - https://www.vinarskecentrum.cz/storage/files/odrudy-vune-brozura-AJ-2021-web.pdf (Czech National Wine Centre grape brochure): sometimes floral; violets, peony, cut hay, cherries, cassis
  - https://www.austrianwine.com/our-wine/wine-styles/6-red-wines-classic-elegant (Austrian Wine [seen in search only, page did not load]): delicate raspberry notes; Thermenregion reds with a violet aroma
  - Note: Red berries replaced by named fruit; Spice dropped (one source). Raspberry and Violet depend on Austrian Wine text seen only in search; with fetched pages alone only Cherry qualifies, so confirm austrianwine.com in a browser or hold back.

## gr_0157 Ranna Melnishka Loza

**tastes**: current: `[]` → **proposed** → proposed: `["Cherry", "Spice"]`
  - https://vinovoss.com/grapes/ranna-melnishka (VinoVoss [lower tier]): red and black fruit, spice, tobacco; sour cherries
  - https://www.viniou.com/grape-varieties/1145_melnik-55 (Viniou [lower tier]): ripe cherries, wild strawberries; tobacco, black pepper, sweet spice
  - https://www.thewinesociety.com/product/melnik-55-villa-melnik-2023-en.aspx (The Wine Society, single wine [lower tier]): brambles and spice
  - Note: Weak: lower tier only. Tobacco left for an aged note.

## gr_0007 Tempranillo

**tastes**: current: `["Cherry", "Plum", "Dried fig", "Vanilla, with oak"]` → **proposed** → proposed: `["Cherry", "Plum", "Dried fig", "Vanilla from oak"]`
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/tempranillo-the-ultimate-grape-guide/ (The Wine Society): with age Tempranillo develops leathery, oaky (vanilla, spice) aromas
  - https://winefolly.com/grapes/chardonnay/ (Wine Folly): oak adds vanilla (vanillin); its Tempranillo page says top wines spend 12 months or more in oak
  - https://www.decanter.com/learn/wine-terminology/are-notes-of-vanilla-a-sign-of-american-oak-ask-decanter-294135 (Decanter [seen in search only, page did not load]): vanillin is an aldehyde from oak, stronger in American oak
  - Note: Only the form changes: "Vanilla, with oak" becomes "Vanilla from oak", same meaning, one chip.

## gr_0186 L'Acadie Blanc

**tastes**: current: `["Floral"]` → **proposed** → proposed: `["Floral", "Apple"]`
  - https://vinovoss.com/grapes/l-acadie-blanc (VinoVoss [lower tier]): honey and floral aromas
  - https://www.viniou.com/grape-varieties/768_l-acadie-blanc (Viniou [lower tier]): lemon, grapefruit, green apple, light floral
  - https://devoniancoast.ca/grapes.html (Devonian Coast Wineries (Nova Scotia producer group) [lower tier]): orchard fruit, apple and pear
  - Note: Weak: lower tier only; Wines of Nova Scotia gives no varietal profile. Honey held back (VinoVoss wording seems derived from Wikipedia).

## gr_0046 Gamaret

**tastes**: current: `["Spice"]` → **proposed** → proposed: `["Spice", "Black fruit"]`
  - https://swisswine.com/en/grapes/gamaret-en (Swiss Wine Promotion): spicy aromas, powerful tannins
  - https://swisswinevalais.ch/en/discover/grape-varieties/gamaret/ (Interprofession Vigne et Vin du Valais): aromas of black fruit and spices; slightly spicy tannins
  - https://www.ge.ch/commander-du-vin-republique (Domaine de l'État de Genève (producer copy)): arômes de fruits noirs et d'épices
  - Note: Spice kept (three sources). Black fruit: Valais body plus Geneva state estate (producer copy).

## gr_0045 Humagne Rouge

**tastes**: current: `["Violet"]` → **held back** → proposed: `unchanged`
  - https://swisswine.com/en/grapes/humagne-rouge-en (Swiss Wine Promotion): violet, dried vine leaf, elderberry, smoke
  - https://swisswinevalais.ch/en/discover/grape-varieties/humagne-rouge/ (Interprofession Vigne et Vin du Valais): violet or gentian; wild fruits, undergrowth, bark
  - Note: Violet confirmed by two bodies, so the current value is right. No second taste shared by two sources, so no list of two to four can be proposed. Left as is.

## gr_0082 Muscat of Alexandria

**summary**: current: `Known in Portugal as Moscatel de Setúbal, this Muscat gives aromatic, floral wines, most famously the sweet fortified wines of Setúbal.` → **proposed** → proposed: `An aromatic Muscat grape, called Moscatel in Portugal and Spain, with floral and orange notes. It is used mostly for sweet and fortified wines such as Moscatel de Setúbal, and is also made into dry, aromatic whites.`
  - https://winesofportugal.com/en/portuguese-wines/grape-varieties/moscatel-de-setubal (Wines of Portugal): called Muscat of Alexandria outside Portugal; light dry or off dry wines, but sweet fortified wines more common, Moscatel de Setúbal best known; orange zest, honey, orange blossom
  - https://guildsomm.com/public_content/features/articles/b/bryce-wiatrak/posts/introduction-to-muscat (GuildSomm): the dominant Muscat in Spain and Portugal; best in dried grape or fortified wines (Setúbal, Moscatel Sherry, Pantelleria)
  - https://winefolly.com/grapes/muscat-of-alexandria/ (Wine Folly): used primarily for dessert wines
  - https://vinovoss.com/grapes/moscatel-de-alejandria (VinoVoss [lower tier]): Chile makes dry, aromatic, light bodied whites from it
  - Note: Removed (Portugal specific, move to the Setúbal region note): "Known in Portugal as Moscatel de Setúbal". The dry whites clause rests on Wines of Portugal plus lower tier VinoVoss for Chile.

**tastes**: current: `["Lychee", "Orange", "Honey", "Flowers"]` → **proposed** → proposed: `["Lychee", "Orange", "Honey", "Floral"]`
  - https://winefolly.com/grapes/muscat-of-alexandria/ (Wine Folly): mandarin orange, honey, lychee, peach skin, white flowers
  - https://winesofportugal.com/en/portuguese-wines/grape-varieties/moscatel-de-setubal (Wines of Portugal): lychees, lemons, lime flowers; Setúbal: orange zest, honey, orange blossom, acacia
  - Note: Audit flag was right, no fault: all four have two sources. Only change: "Flowers" is not in the app vocabulary, renamed "Floral". Optional; leave as is if not wanted.

## gr_0041 Gewürztraminer

**summary**: current: `A highly aromatic white grape, called Traminac in Croatia. Known for lychee and rose, it makes rich, round wines with soft acidity, from dry to sweet.` → **proposed** → proposed: `A highly aromatic white grape known for lychee and rose. It makes rich, round wines with soft acidity, from dry to sweet, and Alsace is its best known home.`
  - https://winefolly.com/grapes/gewurztraminer/ (Wine Folly): medium to full body, moderate to low acidity, dry to sweet; Alsace its adopted homeland with over a quarter of plantings; lychee, rose
  - https://www.thewinesociety.com/discover/wine-basics/grape-varieties/gewurztraminer-the-ultimate-grape-guide (The Wine Society): "rich, round wines"; for drinkers who prefer whites without strong acidity; Alsace dry to sweet, its spiritual home
  - Note: Removed (Croatia specific, move to the Hrvatsko Podunavlje region note): "called Traminac in Croatia". Not verified in this pass; check VIVC before the region note uses it. Tastes (Lychee, Rose, Ginger, Grapefruit) checked and supported by both sources; unchanged.

## gr_0109 Marselan

**tastes**: current: `["Dark berries"]` → **proposed** → proposed: `["Red fruit", "Black fruit", "Floral"]`
  - https://vins-rhone.com/en/marselan-grape-variety (Inter Rhône): notes of ripe red and black fruits
  - https://www.decanter.com/?p=305630 (Decanter [seen in search only, page did not load]): citing a 2018 China National Food Industry Association study: red and black fruit, floral with herbal spices
  - https://pmc.ncbi.nlm.nih.gov/articles/PMC10000944/ (Foods (2023), peer reviewed study): young Chinese Marselan has a distinct floral note from terpenoids
  - Note: Dark berries dropped: only one Decanter article says it. Decanter support came from search text only, so Red fruit and Black fruit rest on Inter Rhône plus that snippet.

## gr_0166 Mavro

**tastes**: current: `["Red fruit"]` → **held back** → proposed: `unchanged`
  - https://www.viniou.com/grape-varieties/1115_mavro (Viniou [lower tier]): blackberries, plums, cherries
  - https://www.exoticwinetravel.com/?p=4893 (Exotic Wine Travel [lower tier]): Mavro rosé: strawberry, cherry
  - Note: Only Cherry repeats (one taste, lower tier). No source found saying "red fruit" twice either. Left as is.

## gr_0155 Muškát moravský

**tastes**: current: `["Muscat"]` → **held back** → proposed: `unchanged`
  - https://www.vinarskecentrum.cz/storage/files/odrudy-vune-brozura-AJ-2021-web.pdf (Czech National Wine Centre grape brochure): highly muscaty nose; tangerines and oranges
  - https://www.vinazmoravyvinazcech.cz/en/encyclopedia/how-to-know-our-wines/divided-by-variety/for-wine-production/white-wine-varieties/4581636-moravian-muscat (Wines of Moravia and Bohemia (Wine Fund)): page title only: fragrant white variety full of flowers
  - https://www.rohlik.cz/en-CZ/1327393-chateau-bzenec-moravian-muscat (Rohlik retailer [lower tier] [seen in search only, page did not load]): exotic fruit, citrus, flowers
  - Note: Audit flag correct: "Muscat" is a grape family, not a taste. But no taste has two organisations (Tangerine only the National Wine Centre). Left as is pending a second source; candidate ["Tangerine", "Citrus", "Floral"].

## gr_0129 Parellada

**tastes**: current: `[]` → **proposed** → proposed: `["Citrus", "White flowers"]`
  - https://winefolly.com/deep-dive/what-is-cava/ (Wine Folly): Parellada: delicate citrusy and white flower notes
  - https://www.wineenthusiast.com/basics/grapes-101/cava-wine-region-grapes/ (Wine Enthusiast [seen in search only, page did not load]): Parellada adds citrus pith and dried herbs
  - https://www.decanter.com/reviews/catalonia/pares-balta-honeymoon-2015/ (Decanter single wine review [lower tier] [seen in search only, page did not load]): white flowers and ripe peachy fruit (Parellada based wine)
  - Note: Weak: second sources seen only in search text. DO Cava and Guía Peñín give no aroma words. Editor may propose Citrus alone, which would then need holding back under the two to four rule.

## gr_0140 Mauzac

**tastes**: current: `["Apple"]` → **proposed** → proposed: `["Apple", "Pear"]`
  - https://www.vins-gaillac.com/notre-vignoble/nos-cepages-millenaires/ (Vins de Gaillac): arômes de pomme mûre et de poire
  - https://www.bbr.com/grape-mz-mauzac (Berry Bros & Rudd): apple peel flavours like cider, cut grass
  - https://www.bkwine.com/features/wine-regions/unique-wines-and-grapes-sud-ouest/ (BKWine): aromatic grape with hints of apples
  - https://www.hachette-vins.com/tout-sur-le-vin/appellations-vins/292/gaillac (Guide Hachette): apple and pear scents typical of Mauzac (in a méthode ancestrale note)
  - Note: Apple kept (three organisations). Pear: Vins de Gaillac plus Hachette.

## gr_0139 Duras

**tastes**: current: `["Pepper"]` → **held back** → proposed: `unchanged`
  - https://www.vins-gaillac.com/notre-vignoble/nos-cepages-millenaires/ (Vins de Gaillac): arômes épicés et poivrés
  - https://oeno-one.eu/article/view/46 (OENO One (IFV Sud Ouest, AWRI)): rotundone, the peppery compound, found in Duras wines
  - Note: Pepper confirmed by two sources, so the current value is right. Spice has only Vins de Gaillac. Left as is.

## gr_0138 Fer Servadou

**tastes**: current: `["Dark berries"]` → **proposed** → proposed: `["Blackcurrant", "Raspberry"]`
  - https://www.vins-gaillac.com/notre-vignoble/nos-cepages-millenaires/ (Vins de Gaillac): Braucol évoquant le cassis et la framboise
  - https://hachette-vins.com/tout-sur-le-vin/appellations-vins/301/marcillac (Guide Hachette (Marcillac, at least 80% Fer Servadou)): framboise, cassis, myrtille, subtle spice
  - Note: Dark berries dropped: no source uses it. Hachette describes the appellation, which is almost entirely this grape.

## gr_0084 Poulsard

**tastes**: current: `["Red berries"]` → **proposed** → proposed: `["Red fruit", "Earthy"]`
  - https://www.jura-vins.com/les-rouges.htm (Comité Interprofessionnel des Vins du Jura): fruits rouges et noirs sauvages; spicy undergrowth accents
  - https://www.winespectator.com/articles/jurassic-park-16141 (Wine Spectator): Poulsards tasted were gamy and earthy
  - https://www.idealwine.net/?p=87615 (iDealwine [lower tier]): small red fruits; sometimes smoke, leather, undergrowth
  - Note: Red berries reworded to Red fruit (the Jura body says fruits rouges; berries only at iDealwine). Earthy: Jura body undergrowth plus Wine Spectator, whose remark was critical, so the editor may prefer to drop it; then the field drops to one taste and should be held back.

## gr_0091 Grenache Blanc

**tastes**: current: `["Plum"]` → **proposed** → proposed: `["Pear", "Citrus", "Herbs"]`
  - https://winefolly.com/grapes/grenache-blanc/ (Wine Folly): green plum, pear, lemon zest, honeysuckle; deep dive: pear forward, lime zest, herbal and saline finish
  - https://spanishwinelover.com/terra-alta-charting-new-roads-for-garnacha (Spanish Wine Lover [lower tier] [seen in search only, page did not load]): young wines show pear and Mediterranean herbs
  - https://iwsc.net/results/detail/128445/lo-noi-del-saxo-2021 (IWSC single wine [lower tier] [seen in search only, page did not load]): herbs, citrus, apple, pear
  - https://www.foodswinesfromspain.com/en/wine/articles/2018/march/garnacha-blanca-wines (Foods & Wines from Spain (ICEX), single wine [lower tier] [seen in search only, page did not load]): pear, grapefruit, white flowers, citrus
  - Note: Plum is wrong for this white; it is likely a truncation of Wine Folly's "green plum". Weak: every taste has Wine Folly plus lower tier only. Also: Wine Folly says medium to medium low acidity, while the summary says "low in acidity".

## gr_0164 Mandilaria

**tastes**: current: `["Leather"]` → **proposed** → proposed: `["Plum", "Liquorice", "Leather"]`
  - https://www.winesofcrete.gr/en/?p=1845 (Wines of Crete): plums, figs, raspberries, leather, liquorice
  - https://www.viniou.com/grape-varieties/671_mandilaria (Viniou [lower tier]): dark cherry, black plum, liquorice; leather when oak aged
  - https://cavaoinos.com/varieties/mandilaria/ (Cava Oinos [lower tier]): ripe fruit, fleshy aromas such as leather
  - Note: Leather has two sources as a varietal aroma; Viniou ties it to oak, so the editor may move it to aged_note.

## gr_0161 Negoska

**tastes**: current: `["Chocolate"]` → **proposed** → proposed: `["Chocolate", "Cherry", "Blackberry"]`
  - https://winesofgreece.org/?p=3708 (Wines of Greece): dark and fruity; a rounded, chocolaty flavour in Goumenissa blends
  - https://www.greekboston.com/?p=77939 (GreekBoston [lower tier]): tastes of chocolate and fruit
  - https://www.viniou.com/grape-varieties/655_negoska (Viniou [lower tier]): cherry, plum, blackberry
  - https://vinovoss.com/grapes/negoska (VinoVoss [lower tier]): blackberry, black cherry, spice
  - Note: Chocolate kept. Cherry and Blackberry rest on lower tier only.

## gr_0160 Mavrodaphne

**tastes**: current: `["Dried fruit"]` → **proposed** → proposed: `["Dried fruit", "Raisin", "Fig"]`
  - https://winesofgreece.org/varieties/mavrodaphne/ (Wines of Greece): dried prunes and currants; aged Mavrodaphne of Patras: dried fruit, flowers, nuts
  - https://decanter.com/wine-reviews/greece/peloponnese/nyx-mavrodaphne-of-patras-peloponnese-greece-67420 (Decanter single wine review [lower tier]): spiced dried fruit, sweet fig and raisin
  - https://en.wikipedia.org/wiki/Mavrodafni (Wikipedia [lower tier]): raisins, plums, fig, caramel, chocolate
  - Note: These describe the sweet fortified wine; dry Mavrodaphne reads differently. Raisin and Fig rest on lower tier sources (Wines of Greece "currants" leans toward Raisin).

## gr_0122 Lambrusco Grasparossa

**tastes**: current: `["Black cherry"]` → **held back** → proposed: `unchanged`
  - https://lambrusco.net/vitigni/grasparossa/ (Consorzio Tutela Lambrusco): mora, amarena, mirtillo rosso, viola, fresh almond
  - https://winefolly.com/tutorial/lambrusco-wines-worth-drinking/ (Wine Folly): black currant and blueberries
  - http://www.diffordsguide.com/encyclopedia/483/bws/lambrusco (Difford's Guide): ripe dark berries, plums
  - Note: No taste is named by two organisations under the strict rule; Black cherry appears only in lower tier pages (the Consorzio says amarena, sour cherry). Left as is.

## gr_0121 Lambrusco di Sorbara

**tastes**: current: `["Violet"]` → **proposed** → proposed: `["Violet", "Red fruit", "Cherry"]`
  - https://lambrusco.net/denominazioni-2/ (Consorzio Tutela Lambrusco): sentori di viola e frutti rossi; grape page: viola, rosa, mirtillo, ciliegia
  - https://www.enotecaemiliaromagna.it/en/wine-tourism/wine-territories/lambrusco-di-sorbara/ (Enoteca Regionale Emilia Romagna): intense aroma of violet and red fruits
  - https://winefolly.com/tutorial/lambrusco-wines-worth-drinking/ (Wine Folly): orange blossom, mandarin, cherries, violets, watermelon
  - Note: Violet kept (three organisations). Red fruit: Consorzio plus Enoteca. Cherry: Consorzio plus Wine Folly.

## gr_0185 Delaware

**tastes**: current: `[]` → **held back** → proposed: `unchanged`
  - https://www.viniou.co.uk/grape-varieties/241_delaware (Viniou [lower tier]): strawberry, redcurrant, raspberry, muscat florality, melon
  - https://wineanorak.com/?p=20216 (wineanorak, single Osaka wines [lower tier]): melon, pear, table grape
  - Note: Only Melon repeats (one taste, lower tier). Left empty.

## gr_0100 Elbling

**tastes**: current: `["Apple", "Tart", "Neutral"]` → **proposed** → proposed: `["Green apple", "Citrus"]`
  - https://aop.public.lu/en/cepages.html (Vins et Crémants Luxembourg (AOP Moselle Luxembourgeoise)): citrus fruit, gooseberry, green apple, pomegranate
  - https://www.fondazioneslowfood.com/en/ark-of-taste-slow-food/elbling/ (Slow Food Foundation (Ark of Taste)): citrus fruits, melon, gooseberry, green apple, pomegranate
  - https://www.winesofgermany.com/our-wine/grape-varieties/grape-variety/99/elbling (Wines of Germany (DWI)): delicate fragrance reminiscent of apple
  - https://www.falstaff.com/en/grape-varieties/elbling (Falstaff): relatively neutral, racy, striking acidity
  - Note: Tart and Neutral dropped: they describe structure (Falstaff supports both) and already sit in the summary. Slow Food's list closely follows the Luxembourg text, so independence is not certain. Separately, the summary has a hyphen ("apple-like").

## gr_0152 Băbească Neagră

**tastes**: current: `[]` → **proposed** → proposed: `["Red fruit", "Floral"]`
  - https://www.crameromania.ro/en/grape-varieties/babeasca-neagra-367.html (ReVino Romania): red fruit (sour cherries, prunes), floral tones (violets, peonies, iris)
  - https://wineofmoldova.com/en/local-grape-varieties/ (Wine of Moldova (ONVV), as Rară Neagră): rosehip flower, red currant, wild blackberries; elsewhere red berries
  - https://www.wine-searcher.com/grape-719-babeasca-neagra (Wine-Searcher [seen in search only, page did not load]): Rară Neagră is a synonym; light, fruity, high acid
  - Note: Synonym confirmed, so the Moldovan Rară Neagră pages apply.

## gr_0026 Pinotin

**tastes**: current: `["Dark berries"]` → **held back** → proposed: `unchanged`
  - https://www.falstaff.com/en/wines/weinbau-dr-wobar-pinotin-trocken (Falstaff single wine reviews [lower tier]): blackberry, elderberry, dark berries
  - https://www.viniou.com/grape-varieties/1034_pinotin (Viniou [lower tier]): raspberry, cherry, herbal, violet
  - Note: No editorial or official source names the fruit, and the two lower tier sources contradict each other. Left as is. Separately, the summary has a hyphen ("disease-resistant").

## gr_0080 Verdelho

**summary**: current: `A white grape best known on Madeira for a medium-dry style, richer than Sercial but still high in acid; in Australia it makes dry, aromatic whites.` → **proposed** → proposed: `A white grape best known on Madeira, where it gives a tangy, medium dry fortified wine with high acidity. In Australia it also makes dry, aromatic white wines.`
  - https://winesofportugal.com/en/portuguese-wines/grape-varieties/verdelho (Wines of Portugal): Madeira and Azores; traditionally the tangy, off dry style of Madeira; high acidity; rich, aromatic dry whites in Australia
  - https://winefolly.com/grapes/verdelho/ (Wine Folly): one of the four key Madeira grapes; quality wines from select Australian producers; medium to high acidity
  - Note: Rewrite removes a hyphen ("medium-dry") and a semicolon. "Richer than Sercial" dropped (no source found). Nothing country specific needs to move. A dry Azores clause was left out: only producer and retailer pages support it.

**tastes**: current: `["Caramel", "Nuts", "Spice"]` → **held back** → proposed: `unchanged`
  - https://winefolly.com/grapes/verdelho/ (Wine Folly): pineapple and Brazil nut among primary flavours
  - https://www.wine.com/product/azores-wine-company-verdelho-o-original-2018/542815 (wine.com, Azores Wine Company notes [lower tier]): passionfruit, pineapple, sea spray
  - https://www.jancisrobinson.com/learn/grape-varieties/white/verdelho (Jancis Robinson [seen in search only, page did not load]): lemony Australian table wine
  - Note: Audit flag correct: Caramel and Nuts describe aged Madeira and belong in the aged note. But no replacement list reaches two tastes with two sources each (Pineapple: Wine Folly plus lower tier; Citrus: no fetched top source). Left as is; editor may move Caramel and Nuts to aged_note once sourced.

## gr_0081 Tinta Negra

**tastes**: current: `[]` → **held back** → proposed: `unchanged`
  - https://www.winesofportugal.com/en/portuguese-wines/grape-varieties/tinta-negra (Wines of Portugal): unfortified it gives rather neutral rosés or pale reds; no tastes
  - https://www.viniou.com/grape-varieties/302_tinta-negra (Viniou [lower tier]): red berries, fig, date, caramel; mostly describes aged Madeira
  - Note: No second source attributes tastes to the grape itself rather than aged Madeira. Left empty.

## gr_0150 Grasă de Cotnari

**tastes**: current: `[]` → **held back** → proposed: `unchanged`
  - https://www.falstaff.com/en/grape-varieties/grasa (Falstaff): mainly sweet, intense body; no aromas named
  - https://en.wikipedia.org/wiki/Gras%C4%83_de_Cotnari (Wikipedia [lower tier]): apricot, walnut, almond
  - https://www.nataliemaclean.com/wine-reviews/cotnari-grasa-de-cotnari-2017/315234 (Natalie MacLean community review [lower tier]): honey, toasted almond, ripe apricot
  - Note: Only lower tier pages name aromas, and they describe botrytised sweet wine rather than the grape. Left empty; candidate ["Apricot", "Almond"].

## gr_0151 Frâncușă

**tastes**: current: `[]` → **held back** → proposed: `unchanged`
  - https://revino.ro/en/francusa-grape-varieties-a314.html (ReVino Romania): floral notes, fruitiness, freshness
  - https://www.cotnari.ro/?p=5384 (Cotnari producer [lower tier]): floral touch
  - Note: Only Floral repeats, which is one taste. Left empty.

## gr_0149 Fetească Regală

**tastes**: current: `["Floral"]` → **proposed** → proposed: `["Floral", "Citrus", "Pear"]`
  - https://wineofmoldova.com/en/local-grape-varieties/ (Wine of Moldova (ONVV)): floral and grapefruit aroma with fresh pear and citrus nuances
  - https://www.crameromania.ro/en/grape-varieties/feteasca-regala-romanian-grape-varieties-299.html (ReVino Romania): flowers such as rose and wildflowers
  - https://wine-intelligence.com/blogs/wines-grapes-cru-ried-wine-brand-grape/feteasca-regala-white-wine (Wine-Intelligence [lower tier]): floral, apple, pear, citrus
  - Note: Floral kept (Wine of Moldova plus ReVino). Citrus and Pear: Wine of Moldova plus lower tier only. Strict option: keep ["Floral"] and hold back. Note winesofromania.com is a private blog, not an official body.

## gr_0153 Muscat Ottonel

**tastes**: current: `[]` → **held back** → proposed: `unchanged`
  - https://www.austrianwine.com/our-wine/grape-varieties/white-wine/muskat-ottonel (Austrian Wine [seen in search only, page did not load]): delicate muscat flavour; intensive, grapey, mild
  - https://www.jancisrobinson.com/learn/grape-varieties/white/muscat (Jancis Robinson [seen in search only, page did not load]): palest Muscat, less grapey than the others
  - https://www.vins-ribeauville.com/en/muscat-alsace/ (Ribeauvillé cooperative [lower tier]): rose, jasmine, orange blossom
  - Note: Top sources seen only in search text and pointing different ways; floral notes only in lower tier pages. Left empty.

## gr_0176 Papazkarası

**tastes**: current: `[]` → **proposed** → proposed: `["Red fruit", "Spice"]`
  - https://goturkiye.com/vineyards/indigenous-grape-varieties (Go Türkiye (Turkish government tourism portal)): plum, cherry and spices
  - https://thequirkycork.com/get-to-know-the-grape-papazkarasi/ (The Quirky Cork [lower tier]): red and black fruits, olives, purple flowers, pepper, spice
  - https://en.wikipedia.org/wiki/Papazkaras%C4%B1 (Wikipedia [lower tier]): red fruit, floral notes, spice
  - Note: Spice: three sources. Red fruit: lower tier only (Go Türkiye names cherry and plum).

## gr_0177 Kınalı Yapıncak

**tastes**: current: `["Pear"]` → **proposed** → proposed: `["Pear", "Apple", "Quince"]`
  - https://goturkiye.com/vineyards/indigenous-grape-varieties (Go Türkiye (Turkish government tourism portal)): Yapıncak: apple, pear and quince
  - https://thequirkycork.com/?p=15692 (The Quirky Cork [lower tier]): apple, pear, quince, citrus; Yapıncak also known as Kınalı Yapıncak
  - Note: Identity caveat: Go Türkiye says "Yapıncak", and the link to Kınalı Yapıncak rests on The Quirky Cork only. Check VIVC before applying.

## Totals

- Grapes with at least one proposal: 30
- Grapes fully held back: 11: Delaware, Duras, Frâncușă, Grasă de Cotnari, Humagne Rouge, Lambrusco Grasparossa, Mavro, Muscat Ottonel, Muškát moravský, Pinotin, Tinta Negra
