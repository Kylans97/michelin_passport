import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/review_repository.dart';
import '../../models/review_item.dart';
import 'review_event_screen.dart';
import 'review_item_screen.dart';

/// Everything waiting for an admin, under a heading per topic (claims,
/// profiles, photos, events, contact changes, reports) with its count, and
/// one filter to show a single topic — so no topic disappears under a long
/// list of another (2026-11-02; a tab per topic didn't fit on a phone).
/// Grouped by kind within a topic, oldest first — reached from Profile's Review row, which only
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

  // Null shows every topic.
  ReviewTopic? _topic;

  Future<void> _pickTopic(Map<ReviewTopic, int> counts, int total) async {
    final picked = await showModalBottomSheet<_TopicPick>(
      context: context,
      // Seven rows are taller than the default sheet on a phone: let it
      // grow with its content, and scroll beyond that.
      isScrollControlled: true,
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: CsSpacing.sm),
            for (final option in [null, ...ReviewTopic.values])
              Builder(
                builder: (context) {
                  final n = option == null ? total : counts[option]!;
                  final waiting = n > 0;
                  return ListTile(
                    // A green dot where something is waiting, so open
                    // topics stand out before one is picked.
                    leading: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: waiting
                            ? AppColors.forestGreen
                            : Colors.transparent,
                        border: waiting
                            ? null
                            : Border.all(color: AppColors.subtleBorderLight),
                      ),
                    ),
                    minLeadingWidth: 8,
                    title: Text(
                      option?.label ?? 'All topics',
                      style: CsTypography.body.copyWith(
                        color: waiting
                            ? AppColors.forestGreen
                            : AppColors.taupe,
                      ),
                    ),
                    subtitle: Text(
                      waiting ? '$n waiting' : 'Nothing waiting',
                      style: CsTypography.metadata.copyWith(
                        color: waiting
                            ? AppColors.forestGreen
                            : AppColors.taupe,
                        fontWeight: waiting ? FontWeight.w600 : null,
                      ),
                    ),
                    trailing: option == _topic
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.forestGreen,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(_TopicPick(option)),
                  );
                },
              ),
            const SizedBox(height: CsSpacing.sm),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _topic = picked.topic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: FutureBuilder<List<ReviewItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            );
          }
          if (snap.hasError) {
            return _refreshable(
              _message(
                'Could not load the review queue. Pull down to try again.',
              ),
            );
          }
          final items = snap.data ?? const <ReviewItem>[];
          final counts = {
            for (final t in ReviewTopic.values)
              t: items.where((i) => i.kind.topic == t).length,
          };
          final shown = _topic == null ? items.length : counts[_topic]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.sm,
                  CsSpacing.pageHorizontal,
                  0,
                ),
                child: _TopicFilter(
                  label: '${_topic?.label ?? 'All topics'} · $shown',
                  onTap: () => _pickTopic(counts, items.length),
                ),
              ),
              Expanded(child: _refreshable(_list(items))),
            ],
          );
        },
      ),
    );
  }

  Widget _refreshable(Widget child) => RefreshIndicator(
    color: AppColors.forestGreen,
    onRefresh: _reload,
    child: child,
  );

  // All topics, or the one picked: a heading per topic with its count,
  // and within a topic of several kinds a subheading per kind. Oldest
  // first within each.
  Widget _list(List<ReviewItem> items) {
    final topics = _topic == null ? ReviewTopic.values : [_topic!];
    final mine = items.where((i) => topics.contains(i.kind.topic)).toList();
    if (mine.isEmpty) {
      return _message(
        _topic == null
            ? 'Nothing waiting for review.'
            : 'Nothing waiting under ${_topic!.label.toLowerCase()}.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.sm,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      children: [
        for (final topic in topics)
          if (mine.any((i) => i.kind.topic == topic)) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: CsSpacing.lg,
                bottom: CsSpacing.xs,
              ),
              child: Text(
                '${topic.label.toUpperCase()} · '
                '${mine.where((i) => i.kind.topic == topic).length}',
                style: CsTypography.eyebrow.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
            ),
            for (final kind in ReviewKind.values.where((k) => k.topic == topic))
              if (mine.any((i) => i.kind == kind)) ...[
                if (ReviewKind.values.where((k) => k.topic == topic).length > 1)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: CsSpacing.sm,
                      bottom: CsSpacing.xs,
                    ),
                    child: Text(
                      '${kind.heading} · ${mine.where((i) => i.kind == kind).length}',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                  ),
                for (final item in mine.where((i) => i.kind == kind))
                  _QueueRow(item: item, onTap: () => _open(item)),
              ],
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

// Wraps the picked topic so "All topics" (null) can be told apart from
// dismissing the sheet.
class _TopicPick {
  final ReviewTopic? topic;
  const _TopicPick(this.topic);
}

/// The one compact "All topics · 12 ▾" control in place of a tab per
/// topic, which didn't fit on a phone (2026-11-02).
class _TopicFilter extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TopicFilter({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: CsTypography.metadata.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}
