import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_properties.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/analytics/supabase_analytics_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../core/widgets/cs_invitation_card.dart';
import '../../../core/widgets/cs_ornament_divider.dart';
import '../../../data/repositories/venue_invite_repository.dart';
import '../../../models/passport_venue.dart';
import '../friend_profile_data.dart';
import 'friend_profile_venue_picker_sheet.dart';

/// "Suggest going together" — a modal sheet. [preselected] pre-fills the
/// venue (Together's per-item "Plan" pill); null means "nothing chosen
/// yet" (Together's own sticky primary button), which opens the venue
/// picker immediately before the rest of the sheet ever shows.
///
/// Deliberately narrow: one venue (already on the viewer's wishlist) plus
/// an optional short note — no dates, no meal type. This is a signal
/// ("this is on my list too, shall we go together?"), not a scheduling
/// tool; if the recipient accepts, the two of them arrange the actual
/// visit themselves outside this flow (see `send_venue_invite`/
/// `accept_venue_invite`'s own migration comments —
/// supabase/migrations/20260925140000_add_venue_invites.sql).
///
/// Returns `true` once the invite has actually been sent (a real
/// `venue_invites` row, not a client-local stub — see
/// EDITORIAL_REDESIGN_TRACKING.md for the "From your events"-style
/// correction this replaces), `false`/null if the flow was cancelled.
Future<bool> showPlanDinnerSheet(
  BuildContext context, {
  required FriendProfileLayoutData data,
  required String viewerUserId,
  PassportVenue? preselected,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => FriendProfilePlanDinnerSheet(
      data: data,
      viewerUserId: viewerUserId,
      initialVenue: preselected,
    ),
  );
  return sent ?? false;
}

class FriendProfilePlanDinnerSheet extends StatefulWidget {
  final FriendProfileLayoutData data;
  final String viewerUserId;
  final PassportVenue? initialVenue;

  // Optional DI seam, matching NewsArticleDetailScreen's established
  // convention — defaults to the real repository/service so a test can
  // supply fakes without needing a live Supabase session.
  final VenueInviteRepository? repo;
  final AnalyticsService? analytics;

  const FriendProfilePlanDinnerSheet({
    super.key,
    required this.data,
    required this.viewerUserId,
    required this.initialVenue,
    this.repo,
    this.analytics,
  });

  @override
  State<FriendProfilePlanDinnerSheet> createState() =>
      _FriendProfilePlanDinnerSheetState();
}

class _FriendProfilePlanDinnerSheetState extends State<FriendProfilePlanDinnerSheet> {
  late final VenueInviteRepository _repo =
      widget.repo ?? VenueInviteRepository(Supabase.instance.client);
  late final AnalyticsService _analytics =
      widget.analytics ?? SupabaseAnalyticsService(Supabase.instance.client);

  PassportVenue? _venue;
  final _noteCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _venue = widget.initialVenue;
    if (_venue == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _changePlace(autoCloseIfCancelled: true));
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePlace({bool autoCloseIfCancelled = false}) async {
    final picked = await showVenuePickerSheet(
      context,
      sharedWishlist: widget.data.sharedWishlistVenues,
      myWishlist: widget.data.myWishlist,
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _venue = picked);
    } else if (autoCloseIfCancelled && _venue == null) {
      Navigator.pop(context);
    }
  }

  Future<void> _send() async {
    final venue = _venue;
    if (venue == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final entityType = venue is HotelVenue
        ? AnalyticsEntityType.hotel
        : AnalyticsEntityType.restaurant;
    final entityId = switch (venue) {
      RestaurantVenue(:final restaurant) => restaurant.id,
      HotelVenue(:final hotel) => hotel.id,
    };

    try {
      final inviteId = await _repo.sendInvite(
        toUserId: widget.data.identity.id,
        venue: venue,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      _analytics.track(
        AnalyticsEvent.venueInviteSent,
        AnalyticsProperties(
          inviteId: inviteId,
          entityType: entityType,
          entityId: entityId,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not send. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = _venue;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairlineOnPaper,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.md,
                  CsSpacing.pageHorizontal,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: CsTypography.editorialBody.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'GO TOGETHER',
                          style: CsTypography.editorialLabel().copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
              Expanded(
                child: venue == null
                    ? const SizedBox.shrink()
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          CsSpacing.pageHorizontal,
                          CsSpacing.lg,
                          CsSpacing.pageHorizontal,
                          CsSpacing.xxl,
                        ),
                        children: [
                          Center(
                            child: _InvitationPreview(
                              viewerLabel: widget.data.myIdentity?.label ?? 'You',
                              friendName: widget.data.friendName,
                              venue: venue,
                              onChangePlace: () => _changePlace(),
                            ),
                          ),
                          const SizedBox(height: CsSpacing.xl),
                          Container(height: 1, color: AppColors.hairlineOnPaper),
                          TextField(
                            controller: _noteCtrl,
                            maxLines: 3,
                            style: CsTypography.editorialTitle(size: 16, italic: true).copyWith(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a note… (optional)',
                              hintStyle: CsTypography.editorialTitle(
                                size: 16,
                                italic: true,
                              ).copyWith(color: AppColors.taupe),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: CsSpacing.md,
                              ),
                            ),
                          ),
                          Container(height: 1, color: AppColors.hairlineOnPaper),
                          if (_error != null) ...[
                            const SizedBox(height: CsSpacing.md),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: CsTypography.body.copyWith(color: AppColors.error),
                            ),
                          ],
                          const SizedBox(height: CsSpacing.xl),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _sending ? null : _send,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.forestGreen,
                                foregroundColor: AppColors.textOnDark,
                                disabledBackgroundColor:
                                    AppColors.forestGreen.withValues(alpha: 0.4),
                                shape: const StadiumBorder(),
                                textStyle: CsTypography.editorialBody.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textOnDark,
                                      ),
                                    )
                                  : const Text('Send'),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationPreview extends StatelessWidget {
  final String viewerLabel;
  final String friendName;
  final PassportVenue venue;
  final VoidCallback onChangePlace;

  const _InvitationPreview({
    required this.viewerLabel,
    required this.friendName,
    required this.venue,
    required this.onChangePlace,
  });

  @override
  Widget build(BuildContext context) {
    final (cityName, awardText) = switch (venue) {
      RestaurantVenue(:final restaurant) => (
        restaurant.cityName,
        restaurant.hasMichelinStar ? '★' * restaurant.michelinStars! : null,
      ),
      HotelVenue(:final hotel) => (
        hotel.cityName,
        null, // Keys render as the glyph row below, not inline text.
      ),
    };

    return CsInvitationCard(
      maxWidth: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$viewerLabel wants to go with $friendName to',
            textAlign: TextAlign.center,
            style: CsTypography.editorialLead().copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: 12),
          Text(
            venue.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.editorialTitle(size: 38).copyWith(
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: CsCountryLabel(
                  cityName: cityName,
                  countryCode: venue.countryCode,
                  style: CsTypography.editorialBody.copyWith(color: AppColors.taupe),
                ),
              ),
              if (awardText != null) ...[
                const SizedBox(width: 6),
                Text(
                  '· $awardText',
                  style: CsTypography.editorialBody.copyWith(color: AppColors.gold600),
                ),
              ],
              if (venue is HotelVenue && (venue as HotelVenue).hotel.hasMichelinKeys) ...[
                const SizedBox(width: 6),
                CsEditorialKeyRow(count: (venue as HotelVenue).hotel.michelinKeys!, size: 12),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const CsOrnamentDivider(),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onChangePlace,
            child: Text(
              'Change place',
              style: CsTypography.editorialLabel().copyWith(color: AppColors.forestGreen),
            ),
          ),
        ],
      ),
    );
  }
}
