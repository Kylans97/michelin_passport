import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/review_repository.dart';
import '../../models/review_item.dart';
import 'review_event_screen.dart';
import 'review_item_screen.dart';

/// Everything waiting for an admin, one tab per topic (claims, profiles,
/// photos, events, contact changes, reports — decided 2026-11-02, so no
/// topic disappears under a long list of another), each grouped by kind
/// and oldest first — reached from Profile's Review row, which only
/// admins see. Phase 1 of
/// docs/Architecture/VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md.
class ReviewQueueScreen extends StatefulWidget {
  final ReviewRepository? repository;
  const ReviewQueueScreen({super.key, this.repository});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  late final _repo =
      widget.repository ?? ReviewRepository(Supabase.instance.client);
  late Future<List<ReviewItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.loadQueue();
  }

  Future<void> _reload() async {
    final next = _repo.loadQueue();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _open(ReviewItem item) async {
    final decided = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => item.kind.isEvent
            ? ReviewEventScreen(item: item, repository: _repo)
            : ReviewItemScreen(item: item, repository: _repo),
      ),
    );
    if (decided == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReviewItem>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const <ReviewItem>[];
        final counts = {
          for (final t in ReviewTopic.values)
            t: items.where((i) => i.kind.topic == t).length,
        };
        return DefaultTabController(
          length: ReviewTopic.values.length,
          // Opens on the first topic with something waiting.
          initialIndex: ReviewTopic.values
              .indexWhere((t) => counts[t]! > 0)
              .clamp(0, ReviewTopic.values.length - 1),
          key: ValueKey(snap.hasData),
          child: Scaffold(
            backgroundColor: AppColors.warmWhite,
            appBar: AppBar(
              title: Text(
                'Review',
                style: CsTypography.placeTitle.copyWith(
                  color: AppColors.forestGreen,
                  fontSize: 20,
                ),
              ),
              backgroundColor: AppColors.warmWhite,
              surfaceTintColor: Colors.transparent,
              iconTheme: const IconThemeData(color: AppColors.forestGreen),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.forestGreen,
                unselectedLabelColor: AppColors.taupe,
                indicatorColor: AppColors.forestGreen,
                labelStyle: CsTypography.metadata.copyWith(fontSize: 14),
                tabs: [
                  for (final t in ReviewTopic.values)
                    Tab(
                      text: snap.hasData && counts[t]! > 0
                          ? '${t.label} · ${counts[t]}'
                          : t.label,
                    ),
                ],
              ),
            ),
            body: snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                      strokeWidth: 1.5,
                    ),
                  )
                : snap.hasError
                ? _refreshable(
                    _message(
                      'Could not load the review queue. Pull down to try again.',
                    ),
                  )
                : TabBarView(
                    children: [
                      for (final t in ReviewTopic.values)
                        _refreshable(_topicList(t, items)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _refreshable(Widget child) => RefreshIndicator(
    color: AppColors.forestGreen,
    onRefresh: _reload,
    child: child,
  );

  // One topic's items, grouped by kind, oldest first within each.
  Widget _topicList(ReviewTopic topic, List<ReviewItem> items) {
    final mine = items.where((i) => i.kind.topic == topic).toList();
    if (mine.isEmpty) {
      return _message('Nothing waiting under ${topic.label.toLowerCase()}.');
    }
    final kinds = ReviewKind.values.where((k) => k.topic == topic).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      children: [
        for (final kind in kinds)
          if (mine.any((i) => i.kind == kind)) ...[
            if (kinds.length > 1)
              Padding(
                padding: const EdgeInsets.only(
                  top: CsSpacing.md,
                  bottom: CsSpacing.sm,
                ),
                child: Text(
                  '${kind.heading} · ${mine.where((i) => i.kind == kind).length}',
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
              ),
            for (final item in mine.where((i) => i.kind == kind))
              _QueueRow(item: item, onTap: () => _open(item)),
          ],
      ],
    );
  }

  // Inside a ListView so pull-to-refresh still works on an empty list.
  Widget _message(String text) => ListView(
    padding: const EdgeInsets.all(CsSpacing.xl),
    children: [
      Text(text, style: CsTypography.body.copyWith(color: AppColors.taupe)),
    ],
  );
}

class _QueueRow extends StatelessWidget {
  final ReviewItem item;
  final VoidCallback onTap;
  const _QueueRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final where = [
      item.venueName,
      if (item.venueCity != null) item.venueCity!,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.rowTitle,
                    style: CsTypography.bodyMedium.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.kind.isEvent && item.hasVenue) where,
                      item.submitterLabel,
                      _ago(item.submittedAt),
                    ].join(' · '),
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.taupe),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inDays >= 1) return '${d.inDays}d ago';
    if (d.inHours >= 1) return '${d.inHours}h ago';
    return '${d.inMinutes.clamp(0, 59)}m ago';
  }
}
