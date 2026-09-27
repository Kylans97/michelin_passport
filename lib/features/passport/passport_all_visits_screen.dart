import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_editorial_glyphs.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../models/venue_entry.dart';
import 'models/passport_stamp_item.dart';
import 'passport_filter_type.dart';
import 'passport_stamp_source.dart';

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// Point 5's "volledige lijst van alle bezoeken" — every restaurant visit,
/// hotel stay, and confirmed event attendance the current user has,
/// flattened into one chronological (newest-first) list and filterable by
/// [PassportFilterType]. Reached from the booklet's back cover page (see
/// [PassportBackCoverPage] in widgets/passport_back_cover_page.dart), once
/// via "View all visits" (no filter) and once per filter shortcut.
///
/// Deliberately NOT capped to the booklet's own 5-year window (see
/// [buildPassportVolumes] in passport_booklet_data.dart) — "de volledige
/// lijst van alle bezoeken" reads as literally complete, a different scope
/// than what fits physically in the booklet (confirmed explicitly, not
/// assumed).
class PassportAllVisitsScreen extends StatefulWidget {
  final List<VenueEntry> entries;
  final List<EventAttendanceEntry> eventEntries;
  final PassportFilterType? initialFilter;
  final void Function(PassportStampItem item) onTapItem;

  const PassportAllVisitsScreen({
    super.key,
    required this.entries,
    required this.eventEntries,
    required this.initialFilter,
    required this.onTapItem,
  });

  @override
  State<PassportAllVisitsScreen> createState() => _PassportAllVisitsScreenState();
}

class _PassportAllVisitsScreenState extends State<PassportAllVisitsScreen> {
  late PassportFilterType? _filter = widget.initialFilter;

  List<PassportStampItem> get _items {
    final items = [
      ...buildRestaurantStampItems(widget.entries),
      ...buildHotelStampItems(widget.entries),
      ...buildEventStampItems(widget.eventEntries),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final filter = _filter;
    if (filter == null) return items;
    return items
        .where(
          (item) => switch (filter) {
            PassportFilterType.restaurants => item is RestaurantStampItem,
            PassportFilterType.hotels => item is HotelStampItem,
            PassportFilterType.events => item is EventStampItem,
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.base,
                CsSpacing.sm,
                CsSpacing.base,
                0,
              ),
              child: EditorialBackButton(color: AppColors.ivory),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.md,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: Text(
                'ALL VISITS',
                style: CsTypography.editorialLabel().copyWith(
                  color: AppColors.secondaryOnDark,
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
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in PassportFilterType.values)
                    CsFilterChip(
                      label: type.label,
                      selected: _filter == type,
                      onTap: () => setState(
                        () => _filter = _filter == type ? null : type,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No visits yet',
                        style: GoogleFonts.inter(
                          color: AppColors.secondaryOnDark,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CsSpacing.pageHorizontal,
                      ).copyWith(top: CsSpacing.md, bottom: CsSpacing.xxl),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _AllVisitsRow(
                        item: items[i],
                        onTap: () => widget.onTapItem(items[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row: type + date, venue name (with a stars/keys award for
/// restaurants/hotels), city/country. Mirrors [FriendVerdictRow]'s layout
/// (friends/widgets/friend_profile_verdict_row.dart) minus the photo
/// thumbnail and personal score — [PassportStampItem] carries neither
/// (the booklet's ink-stamp metaphor never surfaces a personal rating on
/// a stamp, only the award at the time of the visit).
class _AllVisitsRow extends StatelessWidget {
  final PassportStampItem item;
  final VoidCallback onTap;
  const _AllVisitsRow({required this.item, required this.onTap});

  String get _typeLabel => switch (item) {
    RestaurantStampItem() => 'RESTAURANT',
    HotelStampItem() => 'HOTEL',
    EventStampItem(:final entry) => entry.event.eventType.label.toUpperCase(),
  };

  @override
  Widget build(BuildContext context) {
    final date = item.date;
    final dateLabel = '${date.day} ${_months[date.month - 1]} ${date.year}';

    Widget? award;
    final current = item;
    if (current is RestaurantStampItem && (current.stars ?? 0) > 0) {
      award = CsEditorialStarRow(count: current.stars!, size: 13);
    } else if (current is HotelStampItem && (current.keys ?? 0) > 0) {
      award = CsEditorialKeyRow(count: current.keys!, size: 13);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: AppColors.hairlineOnGreen),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_typeLabel · $dateLabel',
                    style: CsTypography.editorialLabel().copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.venueName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.editorialTitle(size: 20).copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                      ),
                      if (award != null) ...[const SizedBox(width: 6), award],
                    ],
                  ),
                  if (item.cityName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    CsCountryLabel(
                      cityName: item.cityName,
                      countryCode: item.countryCode,
                      style: CsTypography.editorialBody.copyWith(
                        color: AppColors.secondaryOnDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
