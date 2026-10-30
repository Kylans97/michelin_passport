import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/photo_repository.dart';
import 'friend_profile_screen.dart' show FriendVenueVisit;
import 'widgets/friend_profile_verdict_row.dart';

/// "All →" from the Overview tab's "{NAME}'S VERDICTS" preview — the same
/// [FriendVerdictRow] widget, just every visit instead of the latest 3, so
/// the preview and the full list can never visually drift apart.
///
/// Covers beyond the preview's own ([coverPhotoByVisitId]) load as rows
/// are built, [coverChunkSize] visits per request — a friend with hundreds
/// of visits no longer costs hundreds of covers on opening their profile.
class FriendProfileAllVisitsScreen extends StatefulWidget {
  final String friendName;
  final List<FriendVenueVisit> visits;
  final Map<String, String> coverPhotoByVisitId;
  final void Function(BuildContext context, FriendVenueVisit visit) onTapVisit;

  /// Test seam; defaults to PhotoRepository.loadCoverPhotoUrlsForVisits.
  final Future<Map<String, String>> Function(List<String> visitIds)?
  loadCoverPhotos;

  static const coverChunkSize = 20;

  const FriendProfileAllVisitsScreen({
    super.key,
    required this.friendName,
    required this.visits,
    required this.coverPhotoByVisitId,
    required this.onTapVisit,
    this.loadCoverPhotos,
  });

  @override
  State<FriendProfileAllVisitsScreen> createState() =>
      _FriendProfileAllVisitsScreenState();
}

class _FriendProfileAllVisitsScreenState
    extends State<FriendProfileAllVisitsScreen> {
  late final _covers = {...widget.coverPhotoByVisitId};
  final _requestedChunks = <int>{};

  late final _load =
      widget.loadCoverPhotos ??
      PhotoRepository(Supabase.instance.client).loadCoverPhotoUrlsForVisits;

  // Called from itemBuilder, so only for rows the list actually builds.
  void _ensureCovers(int index) {
    final chunk = index ~/ FriendProfileAllVisitsScreen.coverChunkSize;
    if (!_requestedChunks.add(chunk)) return;
    final start = chunk * FriendProfileAllVisitsScreen.coverChunkSize;
    final ids = [
      for (final v
          in widget.visits
              .skip(start)
              .take(FriendProfileAllVisitsScreen.coverChunkSize))
        if (!_covers.containsKey(v.visit.id)) v.visit.id,
    ];
    if (ids.isEmpty) return;
    _load(ids).then(
      (urls) {
        if (mounted && urls.isNotEmpty) setState(() => _covers.addAll(urls));
      },
      onError: (Object _) {
        // A row without its cover falls back to its own tile, as before.
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
              "${widget.friendName.toUpperCase()}'S VERDICTS",
              style: CsTypography.editorialLabel().copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ).copyWith(bottom: CsSpacing.xxl),
              itemCount: widget.visits.length,
              itemBuilder: (context, i) {
                _ensureCovers(i);
                final visit = widget.visits[i];
                return FriendVerdictRow(
                  visit: visit,
                  photoUrl: _covers[visit.visit.id],
                  onTap: () => widget.onTapVisit(context, visit),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
