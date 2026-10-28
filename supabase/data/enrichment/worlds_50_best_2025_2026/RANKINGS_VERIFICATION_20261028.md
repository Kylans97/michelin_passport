# World's 50 Best — production rankings verification (2026-10-28)

Production rows (exported by the user from the Supabase SQL editor) compared rank-by-rank
against the official lists. Matching on the exact property + city, never on brand name.

| List | Prod rows | Matches official | Wrong | Official source |
|---|---|---|---|---|
| Restaurants 2025, 1-50 + Hall of Fame | 50 + 1 | 50 / 50, HoF correct (Disfrutar) | 0 | the50.com/restaurants/best-in-the-world/list/1-50 (rendered 2026-10-28) |
| Restaurants 2025, 51-100 | 23 | 23 / 23 | 0 | the50.com/restaurants/best-in-the-world/list/51-100 |
| Hotels 2025, 1-50 | 48 | 48 / 48 | 0 | theworlds50best.com/stories/News/the-worlds-50-best-hotels-2025-the-list.html |
| Hotels 2025, 51-100 | 48 | 48 / 48 | 0 | mma.prnewswire.com/media/2794912/50_Best.pdf (official 51-100 release, 14 Oct 2025) |
| Hotels 2026, 1-50 | 47 | 47 / 47 | 0 | the50.com/hotels/best-in-the-world/list/1-50 |
| Hotels 2026, 51-100 | 34 | 34 / 34 | 0 | the50.com/hotels/best-in-the-world/list/51-100 |

Name-spelling differences only (same property, same city): Raffles Singapore (hotel_186),
Bulgari Tokyo (hotel_647), Hotel Sacher Vienna (hotel_30).

## Ranked but not in production

Restaurants 2025 (27): 51 Alcalde, 54 El Chato, 55 La Colombe, 57 Onjium, 59 Nobelhart & Schmutzig,
61 Nuema, 64 Fu He Hui, 66 Saint Peter, 67 Arca, 68 Masque, 70 Tuju, 74 Mountain, 75 Mil, 76 Leo,
77 Le Doyenné, 81 Oteque, 82 Fyn, 83 A Casa do Porco, 85 Txispa, 86 The Clove Club,
88 Salsify at the Roundhouse, 89 Huniik, 93 Burnt Ends, 94 Meet the Bund, 95 Evvai, 97 Labyrinth,
99 Amisfield Restaurant.

Hotels 2025 (4, held back deliberately, see catalogue_expansion/phase11_geocoding_report.md):
39 One&Only Mandarina, 40 Singita Kruger, 91 Suján Jawai, 92 Soneva Secret.

Hotels 2026 (19): 23 One&Only Mandarina, 31 The Peninsula Istanbul, 50 San Domenico Palace,
53 Park Hyatt Tokyo, 56 Rosewood London, 62 Castiglion del Bosco, 63 Sofitel Legend Casco Viejo,
66 Orient Express La Minerva, 68 Forestis Dolomites, 72 Ritz Paris, 73 Palace Hotel Tokyo,
80 Carlton Cannes, 81 Capella Hanoi, 89 Waldorf Astoria Osaka, 90 Mandarin Oriental Shenzhen,
91 Villa Treville, 96 Wynn Palace, 98 The Oberoi Udaivilas, 99 The Peninsula Shanghai.

Not checked: years before 2025 (out of agreed scope).
