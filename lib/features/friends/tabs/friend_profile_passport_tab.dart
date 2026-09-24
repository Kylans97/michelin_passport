import 'package:flutter/material.dart';
import '../../../core/theme/cs_spacing.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show openVisitDetail;
import '../widgets/friend_profile_stamp_page.dart';
import '../widgets/friend_profile_widgets.dart';

/// Tab 2: the read-only stamped passport page, then Stamps/Countries/
/// Avg. score. Wrapped in a plain [ListView] (not a fixed Column) so the
/// stats row always falls fully above the tab bar/bottom nav even when
/// there are several pages worth of stamps — the same reasoning every
/// other scrollable tab body in this screen already follows.
class FriendProfilePassportTab extends StatelessWidget {
  final FriendProfileLayoutData data;

  const FriendProfilePassportTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final avg = data.stats.avgScore;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.xxl,
      ),
      children: [
        FriendProfileStampPage(
          visits: data.visits,
          ownerName: data.friendName,
          onTapStamp: (fv) => openVisitDetail(context, fv),
        ),
        const SizedBox(height: CsSpacing.lg),
        FriendProfileStatsRow(
          stats: [
            FriendProfileStat(value: '${data.stats.stamps}', label: 'STAMPS'),
            FriendProfileStat(value: '${data.stats.countries}', label: 'COUNTRIES'),
            FriendProfileStat(
              value: avg == null ? '—' : avg.toStringAsFixed(1),
              label: 'AVG. SCORE',
            ),
          ],
        ),
      ],
    );
  }
}
