# UI Consistency Audit

Read-only design-system audit, companion to `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md`. No screens were changed. Method: checked each screen for the legacy token set (`AppColors.background/card/surface/textPrimary/textSecondary`, `AppTypography`, direct `GoogleFonts.*` calls, standard Material `AppBar`) versus the current dark-editorial set (`AppColors.deepGreen/textOnDark/secondaryOnDark/subtleBorderDark/gold`, `CsTypography`, `CsSpacing`, `CsRadius`, `CsPrimaryButton`/`CsSecondaryButton`, `EditorialBackButton`).

---

## Classification

| # | Screen | File(s) | Class | Evidence |
|---|---|---|---|---|
| 1 | Login | `lib/features/auth/login_screen.dart` | **A** | `Scaffold(backgroundColor: AppColors.deepGreen)`, `CsSpacing.*` layout, `CsPrimaryButton` |
| 2 | Signup | `lib/features/auth/signup_screen.dart` | **A** | `Scaffold(backgroundColor: AppColors.deepGreen)`, `CsTypography.screenTitle`, `CsPrimaryButton` |
| 3 | Passport | `lib/features/passport/passport_screen.dart` | **A** | `AppColors.deepGreen`/`forestGreen` canvas, `CsTypography.screenTitle`, `CsSpacing.pageHorizontal` throughout |
| 4 | Add-visit sheet (review creation) | `lib/features/visits/widgets/add_visit_sheet.dart` | **C** | Zero `Cs*` tokens; `AppColors.card`/`textPrimary`/`textSecondary`/`surface`/`gold*` throughout |
| 5 | Restaurant Detail | `lib/features/restaurants/restaurant_detail_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.background)`, `AppTypography.metadata`/`.body`; zero `Cs*` tokens |
| 6 | Hotel Detail | `lib/features/hotels/hotel_detail_screen.dart` | **C** | Identical pattern to #5 |
| 7 | Explore | `lib/features/explore/explore_screen.dart` | **A** | `AppColors.deepGreen` canvas, `CsTypography.eyebrow`, `CsSpacing.pageHorizontal` throughout |
| 8 | Guides (landing + catalogue) | `lib/features/guides/guides_screen.dart`, `michelin_restaurant_guide_screen.dart` | **A** | `Scaffold(backgroundColor: AppColors.deepGreen)`, `CsTypography.screenTitle`/`.eyebrow`, `CsSpacing.section` |
| 9 | Rankings | `lib/features/rankings/rankings_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.background)`, `SliverAppBar` via `AppTypography.editorialHeading`; zero `Cs*` tokens |
| 10 | Wishlist | `lib/features/wishlist/wishlist_screen.dart` | **C** | `SliverAppBar(backgroundColor: AppColors.background)`, `AppColors.card`, direct `GoogleFonts.inter` calls |
| 11 | Trips (root + detail) | `lib/features/trips/planned_trips_screen.dart`, `trip_detail_screen.dart` | **A** | `Scaffold(backgroundColor: AppColors.deepGreen)` + `CsTypography`/`CsSpacing` throughout. One trivial legacy exception: `trip_detail_screen.dart`'s `_showSnack` snackbar helper still uses `AppColors.textPrimary`/`GoogleFonts.inter` directly |
| 12 | Profile | `lib/features/profile/profile_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.background)`, `AppColors.card`/`surface` throughout; zero `Cs*` tokens. **Also currently broken** — see below |
| 13 | Events | `lib/features/events/events_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.card)`, `SliverAppBar` via `AppTypography.editorialHeading`; zero `Cs*` tokens |
| 14 | Event Detail | `lib/features/events/event_detail_screen.dart` | **C** | `Scaffold(backgroundColor: AppColors.background)`, standard `AppBar`, `AppTypography.metadata`/`.body` |
| 15a | Country picker sheet | `lib/core/widgets/country_picker_sheet.dart` | **C** | `AppColors.card`/`divider`/`textPrimary`, direct `GoogleFonts.inter` calls |
| 15b | Date card | `lib/features/visits/widgets/date_card.dart` | **C** | `AppColors.surface`/`cardBorder`/`gold*`/`textPrimary`, direct `GoogleFonts.inter` calls |
| 15c | Save button | `lib/features/visits/widgets/save_button.dart` | **C** | `AppColors.gold` fill, direct `GoogleFonts.inter`; no `CsPrimaryButton` |

**No B (partially modernized) screens found** among the 15 sampled — the split is clean, not blended within a single screen (aside from Trips' one trivial snackbar exception).

## Overall pattern

The app divides cleanly along **when a feature was built**, not by feature importance. Everything from the recent "dark editorial" push — Auth (Login/Signup), Passport, Explore, Guides, and Trips — is fully on the current system (A). Everything that predates that push — Restaurant/Hotel Detail, Rankings, Wishlist, Profile, Events/Event Detail, the visit-review creation sheet, and the shared pickers/cards it depends on (country picker, date card, save button) — remains entirely on the original light-ivory system (C). This matches `app_colors.dart`'s own documentation of `deepGreen`/`textOnDark`/`secondaryOnDark`/`subtleBorderDark` as an additive foundation not yet adopted everywhere.

## A pre-existing functional bug found during this audit (not a design-system issue)

`lib/features/profile/profile_screen.dart` renders a "Friends" section (via `FriendshipRepository.searchUsers`/`getFriends`/`getPendingRequests`), a "Community Stats" tier-distribution section, and a tier badge — all backed by tables/views (`friendships`, `user_tiers`, `tier_stats`, `profiles.tier`) that were dropped by the `20260805141519_production_schema_v1.sql` migration and never recreated. A live read-only query against the linked production database during this audit confirmed none of `friendships`/`user_tiers`/`tier_stats`/`trophies`/`user_trophies` exist, and `profiles` has exactly `id, username, display_name, avatar_url, home_country_code, is_public, created_at` — no `tier` column. **These Profile screen sections will throw at runtime today**, independent of anything in this spike. See `FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md` §1 and §44 for how this intersects with the friendship work this spike recommends.

## Redesign priority (informational — not requested to implement)

If/when legacy screens are modernized, the natural order follows this spike's own MVP dependency chain, not alphabetical or arbitrary order:

1. **Profile** — already broken (above), and is the literal home of the friend-request UI this spike recommends building next. Fixing the schema gap and modernizing the visual system are best done in the same pass, since the Friends section needs to be rebuilt against a real schema either way.
2. **Add-visit sheet** — becomes the home of any future visibility control (§11 of the main document); worth modernizing when that ships, not before.
3. **Restaurant/Hotel Detail** — highest-traffic legacy screens (every Explore/Guides/Trips result routes here), but functionally correct today; a visual-only pass, not urgent.
4. **Rankings, Wishlist, Events/Event Detail** — lower urgency; no functional or privacy work in this spike touches them directly.
5. **Shared pickers/cards** (country picker, date card, save button) — used across several legacy screens; ride along with whichever screen above needs them modernized first rather than a standalone pass.

This is a sequencing observation for a future design task, not a commitment made by this spike.
