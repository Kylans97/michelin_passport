import 'restaurant.dart';

/// One provenance row from `public.private_chef_restaurant_history` (see
/// supabase/migrations/20260817120000_create_private_chefs_foundation.sql),
/// with its canonical restaurant already resolved — never built directly
/// from a raw Supabase row via a bare `fromJson`, since resolving
/// [restaurant] requires a second, batched query the model itself has no
/// business making (see PrivateChefRepository.getRestaurantHistory, which
/// mirrors EventsRepository.loadLinkedVenues' "N+1-free" pattern exactly).
///
/// Exactly one of [restaurant] / [restaurantNameText] is ever set — a
/// direct reflection of the database's own
/// `private_chef_restaurant_history_identity_xor` CHECK constraint, not a
/// convention this model invents independently.
///
/// Deliberately carries no star/Key field of its own. When [restaurant] is
/// present, its own `michelinStars` is the ONLY source of any recognition
/// shown beside this row — see PRIVATE_CHEFS.md §10/§15: recognition
/// belongs to the Restaurant, never to the chef or to this join row.
class PrivateChefRestaurantHistory {
  final String id;
  final String privateChefId;

  /// The canonical restaurant, when this row resolves to one already in
  /// the Mantelier catalogue. Null for text-only provenance.
  final Restaurant? restaurant;

  /// Populated only when [restaurant] is null — the chef's provenance at a
  /// restaurant not (yet, or ever) in the canonical catalogue. Never
  /// tappable, never shown with fabricated stars/city/links.
  final String? restaurantNameText;

  final String? role;
  final String? periodText;
  final int displayOrder;

  const PrivateChefRestaurantHistory({
    required this.id,
    required this.privateChefId,
    this.restaurant,
    this.restaurantNameText,
    this.role,
    this.periodText,
    this.displayOrder = 0,
  });

  /// True when this row resolves to a canonical Restaurant — the row is
  /// tappable (→ RestaurantDetailScreen) and its Restaurant's own
  /// recognition may be shown beside it. False means text-only: never
  /// tappable, never any recognition shown.
  bool get isCanonical => restaurant != null;

  /// The name to display, from whichever identity is actually present.
  String get displayName => restaurant?.name ?? restaurantNameText ?? '';

  /// Builds one history row from its raw table row plus an already-
  /// resolved [restaurant] (or null for text-only provenance) — the
  /// repository looks [restaurant] up in a single batched query across all
  /// of a chef's history rows before calling this, exactly mirroring
  /// EventsRepository.loadLinkedVenues.
  factory PrivateChefRestaurantHistory.fromRow(
    Map<String, dynamic> row, {
    Restaurant? restaurant,
  }) => PrivateChefRestaurantHistory(
    id: row['id'].toString(),
    privateChefId: row['private_chef_id'].toString(),
    restaurant: restaurant,
    restaurantNameText: restaurant == null
        ? row['restaurant_name_text'] as String?
        : null,
    role: row['role'] as String?,
    periodText: row['period_text'] as String?,
    displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
  );
}
