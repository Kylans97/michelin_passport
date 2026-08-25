import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../models/event.dart';
import '../../events/event_date_format.dart';
import '../../events/event_detail_screen.dart';
import '../../passport/widgets/passport_card_chrome.dart';

/// EVENT WISHLIST V1 — a saved Event, in the same ivory [CsPlaceCard]
/// family as [WishlistRestaurantCard]/[WishlistHotelCard]
/// (`wishlist_venue_cards.dart`) — same image slot, same serif title, same
/// bookmark chrome. Deliberately a separate widget rather than a case
/// added to those: an Event is a different canonical entity (no Michelin
/// stars/Keys, a date range instead), and [CsPlaceCard]'s [awardRow] slot
/// is repurposed here for that date range rather than [StarRow]/[KeyRow].
///
/// [onRemove] always means "remove from wishlist" — [PassportCardBookmark]
/// renders filled/remove-only, matching the restaurant/hotel cards' own
/// convention (every card in this list is, by definition, already
/// wishlisted). Tapping the card opens the canonical [EventDetailScreen] —
/// there is no separate Wishlist Event Detail screen.
class EventWishlistCard extends StatelessWidget {
  final Event event;
  final VoidCallback onRemove;

  const EventWishlistCard({
    super.key,
    required this.event,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final location = [
      if (event.city != null && event.city!.isNotEmpty) event.city,
      event.countryCode,
    ].join(', ');

    return CsPlaceCard(
      image: _EventCardImage(imageUrl: event.imageUrl),
      title: event.name,
      subtitle: location,
      awardRow: Text(
        formatEventDateRange(event),
        style: CsTypography.metadata.copyWith(
          color: AppColors.taupe,
          fontWeight: FontWeight.w600,
        ),
      ),
      bookmark: PassportCardBookmark(isWishlisted: true, onTap: onRemove),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
      ),
    );
  }
}

/// The card's image slot — a real photo when [imageUrl] is set and loads
/// successfully, otherwise the branded [CsImagePlaceholder] — mirrors
/// `EventCard`'s/`CommunityEventsPreview`'s own identical, independently
/// duplicated "event thumbnail" pattern (see either's own doc comment for
/// why each keeps its own small copy rather than sharing one).
class _EventCardImage extends StatelessWidget {
  final String? imageUrl;
  const _EventCardImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(CsRadius.medium));
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const CsImagePlaceholder(borderRadius: radius);
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const CsImagePlaceholder(borderRadius: radius),
      ),
    );
  }
}
