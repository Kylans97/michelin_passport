import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../core/widgets/cs_invitation_card.dart';
import '../../../core/widgets/cs_ornament_divider.dart';
import '../../../models/passport_venue.dart';
import '../friend_profile_data.dart';
import '../friend_profile_dinner_invitation.dart';
import 'friend_profile_venue_picker_sheet.dart';

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// "Plan a dinner" (7d) — a modal sheet. [preselected] pre-fills the venue
/// (Together's "Plan" pill on a specific item); null means "nothing
/// chosen yet" (Together's own sticky primary button), which opens the
/// venue picker immediately before the rest of the sheet ever shows.
///
/// Returns the [DinnerInvitation] that was "sent" (see that class's own
/// doc — this is a stub, nothing is actually persisted anywhere yet) or
/// null if the flow was cancelled — the caller uses that to decide
/// whether to show the confirmation toast, matching "de sheet sluit, en
/// een toast" being two separate steps owned by two different widgets.
Future<DinnerInvitation?> showPlanDinnerSheet(
  BuildContext context, {
  required FriendProfileLayoutData data,
  required String viewerUserId,
  PassportVenue? preselected,
}) {
  return showModalBottomSheet<DinnerInvitation?>(
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
}

class FriendProfilePlanDinnerSheet extends StatefulWidget {
  final FriendProfileLayoutData data;
  final String viewerUserId;
  final PassportVenue? initialVenue;

  const FriendProfilePlanDinnerSheet({
    super.key,
    required this.data,
    required this.viewerUserId,
    required this.initialVenue,
  });

  @override
  State<FriendProfilePlanDinnerSheet> createState() =>
      _FriendProfilePlanDinnerSheetState();
}

class _FriendProfilePlanDinnerSheetState extends State<FriendProfilePlanDinnerSheet> {
  PassportVenue? _venue;
  final List<DateTime> _selectedDates = [];
  DinnerMealType _mealType = DinnerMealType.dinner;
  final _noteCtrl = TextEditingController();
  late final List<DateTime> _upcomingDates = List.generate(
    21,
    (i) => DateTime.now().add(Duration(days: i + 1)),
  );

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

  void _toggleDate(DateTime date) {
    setState(() {
      final existing = _selectedDates.indexWhere((d) => _isSameDay(d, date));
      if (existing != -1) {
        _selectedDates.removeAt(existing);
      } else if (_selectedDates.length < 3) {
        _selectedDates.add(date);
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _send() {
    final venue = _venue;
    if (venue == null || _selectedDates.isEmpty) return;
    final venueId = switch (venue) {
      RestaurantVenue(:final restaurant) => restaurant.id,
      HotelVenue(:final hotel) => hotel.id,
    };
    final invitation = DinnerInvitation(
      // Stub only — see DinnerInvitation's own doc. No real id space
      // exists yet, so this is a client-local placeholder, never sent
      // anywhere that would need it to be a real, collision-free id.
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      fromUserId: widget.viewerUserId,
      toUserId: widget.data.identity.id,
      venueId: venueId,
      venueIsHotel: venue is HotelVenue,
      proposedDates: List.of(_selectedDates)..sort(),
      mealType: _mealType,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    Navigator.pop(context, invitation);
  }

  @override
  Widget build(BuildContext context) {
    final venue = _venue;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
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
                          'NEW INVITATION',
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PROPOSE DATES',
                                style: CsTypography.editorialLabel().copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Pick up to 3',
                                style: CsTypography.editorialLabel().copyWith(
                                  color: AppColors.taupe,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: CsSpacing.sm),
                          SizedBox(
                            height: 70,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _upcomingDates.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final date = _upcomingDates[i];
                                final selected = _selectedDates.any((d) => _isSameDay(d, date));
                                return _DateTile(
                                  date: date,
                                  selected: selected,
                                  onTap: () => _toggleDate(date),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: CsSpacing.lg),
                          Row(
                            children: [
                              for (final meal in DinnerMealType.values) ...[
                                if (meal != DinnerMealType.values.first)
                                  const SizedBox(width: CsSpacing.sm),
                                _MealChip(
                                  label: meal.label,
                                  selected: _mealType == meal,
                                  onTap: () => setState(() => _mealType = meal),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: CsSpacing.lg),
                          Container(height: 1, color: AppColors.hairlineOnPaper),
                          TextField(
                            controller: _noteCtrl,
                            maxLines: 3,
                            style: CsTypography.editorialTitle(size: 16, italic: true).copyWith(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a note…',
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
                          const SizedBox(height: CsSpacing.xl),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _selectedDates.isEmpty ? null : _send,
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
                              child: const Text('Send invitation'),
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
            '$viewerLabel invites $friendName to dinner at',
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

class _DateTile extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  const _DateTile({required this.date, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.forestGreen : AppColors.card,
          borderRadius: BorderRadius.circular(4),
          border: selected ? null : Border.all(color: AppColors.hairlineOnPaper),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdays[date.weekday - 1],
              style: CsTypography.editorialLabel(size: 9).copyWith(
                color: selected ? AppColors.background : AppColors.taupe,
              ),
            ),
            Text(
              '${date.day}',
              style: CsTypography.editorialTitle(size: 26).copyWith(
                color: selected ? AppColors.background : AppColors.textPrimary,
              ),
            ),
            Text(
              _months[date.month - 1],
              style: CsTypography.editorialLabel(size: 9).copyWith(
                color: selected ? AppColors.background : AppColors.taupe,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MealChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MealChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.forestGreen : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: selected ? null : Border.all(color: AppColors.hairlineOnPaper),
        ),
        child: Text(
          label,
          style: CsTypography.editorialBody.copyWith(
            color: selected ? AppColors.textOnDark : AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}
