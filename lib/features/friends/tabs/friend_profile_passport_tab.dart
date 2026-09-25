import 'package:flutter/material.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../models/passport_venue.dart';
import '../../passport/models/passport_stamp_item.dart';
import '../../passport/passport_booklet_data.dart';
import '../../passport/widgets/passport_booklet_view.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show FriendVenueVisit, openVisitDetail;

/// Tab 2: the friend's own Passport booklet — the exact same
/// cover→data-page→stamp-pages UI the current user's own Passport tab
/// uses ([PassportBookletView]), reused wholesale rather than rebuilt,
/// showing the FRIEND's data, read-only. Three differences from "your
/// own" booklet, all explicit asks, not incidental:
///   1. The data page shows the FRIEND's own name/member number/counts/
///      countries — [PassportBookletView] is generic over whose data it's
///      given, so this is just which values get passed in.
///   2. `includeNextStampSlot: false` — no "Add your next stamp" empty
///      slot anywhere; this isn't the viewer's passport to add to.
///   3. Tapping a stamp opens the EXISTING VisitDetailScreen/
///      StayDetailScreen for that specific visit (via [openVisitDetail],
///      already ownership-gated — see that function's own doc comment),
///      not the venue's own detail screen the way the current user's own
///      booklet does it (see `PassportCollectionBody._onTapStamp`) — the
///      current-user booklet has no per-visit screen it makes sense to
///      jump to (they're all "your own"), a friend's booklet is
///      specifically about that ONE recorded visit.
///
/// Privacy, checked before writing this (not assumed): the underlying
/// data load (`VisitedRepository.loadPassportVenues(widget.userId)` in
/// friend_profile_screen.dart, unchanged by this tab) already relies
/// entirely on `visits_read` RLS, which returns a friend's
/// `visibility = 'friends'` rows and NEVER their `private` ones,
/// friendship or not — nothing additional to filter here. Events are
/// deliberately excluded (`eventEntries: const []`) — the pre-existing,
/// deliberate "restaurants/hotels only" scope this screen already had
/// (see the now-deleted FriendProfileStampPage's own doc comment) is kept
/// as-is, not silently expanded. The friend's member number now shows for
/// real (20260925130000_add_member_number_to_profile_identity.sql
/// extended get_profile_identity() for exactly this) rather than the
/// placeholder/dash Round 1 of the current-user booklet briefly used.
class FriendProfilePassportTab extends StatelessWidget {
  final FriendProfileLayoutData data;

  const FriendProfilePassportTab({super.key, required this.data});

  void _onTapStamp(BuildContext context, PassportStampItem item) {
    final fv = switch (item) {
      RestaurantStampItem(:final restaurant, :final visit) => FriendVenueVisit(
        RestaurantVenue(restaurant),
        visit,
      ),
      HotelStampItem(:final hotel, :final visit) => FriendVenueVisit(
        HotelVenue(hotel),
        visit,
      ),
      EventStampItem() => null, // never reached — no event stamps in this booklet
    };
    if (fv != null) openVisitDetail(context, fv);
  }

  @override
  Widget build(BuildContext context) {
    final volumes = buildPassportVolumes(
      entries: data.visitedEntries,
      eventEntries: const [],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.xxl,
      ),
      child: Center(
        child: PassportBookletView(
          volumes: volumes,
          holderName: data.friendName,
          avatarUrl: data.identity.avatarUrl,
          memberNumber: data.identity.memberNumber,
          countryNameByCode: data.countryNameByCode,
          includeNextStampSlot: false,
          onTapStamp: (item) => _onTapStamp(context, item),
        ),
      ),
    );
  }
}
