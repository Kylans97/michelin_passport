import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/challenge_repository.dart';
import 'widgets/community_shared.dart';

/// Challenges and standings among the member and their friends
/// (20261101870000): Mantelier's fixed challenges with each one's ranking,
/// then all-time standings for starred, World's 50 Best and Selection
/// restaurants. Everyone takes part; only visits shared with friends count.
class ChallengesScreen extends StatefulWidget {
  final ChallengeRepository? repository;

  /// Open on the standings instead of the challenges.
  final bool scrollToStandings;

  const ChallengesScreen({
    super.key,
    this.repository,
    this.scrollToStandings = false,
  });

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  late final ChallengeRepository _repo =
      widget.repository ?? ChallengeRepository(Supabase.instance.client);
  late final Future<List<(Challenge, List<RankingPlace>)>> _challenges =
      _loadChallenges();
  StandingKind _kind = StandingKind.stars;
  late Future<List<RankingPlace>> _standings = _repo.standings(_kind);
  final _standingsKey = GlobalKey();

  Future<List<(Challenge, List<RankingPlace>)>> _loadChallenges() async {
    final list = await _repo.challenges();
    final rankings = await Future.wait([
      for (final c in list) _repo.ranking(c.id).catchError((_) => <RankingPlace>[]),
    ]);
    return [for (var i = 0; i < list.length; i++) (list[i], rankings[i])];
  }

  @override
  void initState() {
    super.initState();
    if (widget.scrollToStandings) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _challenges;
        final ctx = _standingsKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
        }
      });
    }
  }

  void _selectKind(StandingKind kind) => setState(() {
    _kind = kind;
    _standings = _repo.standings(kind);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          0,
          CsSpacing.pageHorizontal,
          CsSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: EditorialBackButton(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            'Challenges',
            style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            'Set by Mantelier, the same for everyone. You and your friends '
            'take part; only visits you share with friends count.',
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.lg),
          FutureBuilder<List<(Challenge, List<RankingPlace>)>>(
            future: _challenges,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const _Loading();
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const CommunityEmptyNote(
                  message: 'New challenges will appear here.',
                );
              }
              return Column(
                children: [
                  for (final (challenge, places) in items)
                    _ChallengeCard(
                      challenge: challenge,
                      places: places,
                      onOpen: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChallengeRankingScreen(
                            challenge: challenge,
                            places: places,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: CsSpacing.section),
          CommunitySectionTitle('Standings', key: _standingsKey),
          const SizedBox(height: CsSpacing.xs),
          Text(
            'All time, among you and your friends.',
            style: CsTypography.metadata.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.md),
          _KindTabs(selected: _kind, onSelect: _selectKind),
          const SizedBox(height: CsSpacing.sm),
          FutureBuilder<List<RankingPlace>>(
            future: _standings,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const _Loading();
              }
              final places = snap.data ?? const [];
              if (places.length < 2) {
                return const CommunityEmptyNote(
                  message: 'Add friends to see where you stand.',
                );
              }
              return Column(
                children: [
                  for (final p in places)
                    PlaceRow(place: p, meta: '${p.value} ${_kind.unit}'),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// The full ranking of one challenge.
class ChallengeRankingScreen extends StatelessWidget {
  final Challenge challenge;
  final List<RankingPlace> places;

  const ChallengeRankingScreen({
    super.key,
    required this.challenge,
    required this.places,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          0,
          CsSpacing.pageHorizontal,
          CsSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: EditorialBackButton(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            challenge.periodLabel.toUpperCase(),
            style: CsTypography.editorialLabel().copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            challenge.title,
            style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            challenge.description,
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.lg),
          for (final p in places) PlaceRow(place: p, meta: progressMeta(p)),
        ],
      ),
    ),
  );
}

/// "2 of 3", or "Done on 13 November".
String progressMeta(RankingPlace p) {
  final done = p.completedOn;
  if (done != null) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    return 'Done on ${done.day} ${months[done.month - 1]}';
  }
  return '${p.value} of ${p.target ?? p.value}';
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final List<RankingPlace> places;
  final VoidCallback onOpen;

  const _ChallengeCard({
    required this.challenge,
    required this.places,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final me = places.where((p) => p.isMe).firstOrNull;
    final target = me?.target ?? places.firstOrNull?.target ?? 1;
    final progress = me?.value ?? 0;
    final status = me == null
        ? challenge.periodLabel
        : me.completed
        ? '${progressMeta(me)} · ${ordinal(me.rank)} of ${places.length}'
        : places.length > 1
        ? '${ordinal(me.rank)} of ${places.length} · ${challenge.periodLabel}'
        : challenge.periodLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: CsSpacing.lg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(CsSpacing.base),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.hairlineOnGreen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ProgressRing(progress: progress, target: target, size: 58),
                    const SizedBox(width: CsSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.title,
                            style: CsTypography.placeTitle.copyWith(
                              color: AppColors.ivory,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            challenge.description,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: CsTypography.metadata.copyWith(
                              color: me?.completed == true
                                  ? AppColors.terracottaOnDark
                                  : AppColors.secondaryOnDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (places.length > 1) ...[
                  const SizedBox(height: CsSpacing.sm),
                  for (final p in places.take(3))
                    PlaceRow(place: p, meta: progressMeta(p), compact: true),
                  if (places.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: CsSpacing.xs),
                      child: Text(
                        'Full ranking',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.ivory,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.ivory,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One person on a ranking: place, photo, name and their number. The
/// member's own row in light terracotta.
class PlaceRow extends StatelessWidget {
  final RankingPlace place;
  final String meta;
  final bool compact;

  const PlaceRow({
    super.key,
    required this.place,
    required this.meta,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = place.isMe ? AppColors.terracottaOnDark : AppColors.ivory;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : CsSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${place.rank}',
              style: CsTypography.placeTitle.copyWith(
                color: AppColors.secondaryOnDark,
                fontSize: compact ? 15 : 17,
              ),
            ),
          ),
          CommunityAvatarCircle(
            initials: initialsFor(place.isMe ? (place.displayName ?? 'You') : place.label),
            avatarUrl: place.avatarUrl,
            size: compact ? 28 : 40,
          ),
          const SizedBox(width: CsSpacing.md),
          Expanded(
            child: Text(
              place.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.bodyMedium.copyWith(color: nameColor),
            ),
          ),
          const SizedBox(width: CsSpacing.sm),
          Text(
            meta,
            style: CsTypography.metadata.copyWith(
              color: place.completed
                  ? AppColors.terracottaOnDark
                  : AppColors.secondaryOnDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin ring filling up to [progress] of [target], in light terracotta,
/// with "2/3" inside.
class ProgressRing extends StatelessWidget {
  final int progress;
  final int target;
  final double size;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.target,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _RingPainter(
        fraction: target <= 0 ? 0 : (progress / target).clamp(0, 1).toDouble(),
      ),
      child: Center(
        child: Text(
          '$progress/$target',
          style: CsTypography.metadata.copyWith(color: AppColors.ivory),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final double fraction;
  const _RingPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(3);
    canvas.drawArc(
      ring,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.hairlineOnGreen,
    );
    if (fraction > 0) {
      canvas.drawArc(
        ring,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = AppColors.terracottaOnDark,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

class _KindTabs extends StatelessWidget {
  final StandingKind selected;
  final ValueChanged<StandingKind> onSelect;

  const _KindTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CsSpacing.lg,
    runSpacing: CsSpacing.xs,
    children: [
      for (final kind in StandingKind.values)
        InkWell(
          onTap: () => onSelect(kind),
          child: Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: kind == selected
                      ? AppColors.terracottaOnDark
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              kind.label,
              style: CsTypography.bodyMedium.copyWith(
                color: kind == selected ? AppColors.ivory : AppColors.secondaryOnDark,
              ),
            ),
          ),
        ),
    ],
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(CsSpacing.xl),
    child: Center(
      child: CircularProgressIndicator(color: AppColors.ivory, strokeWidth: 1.5),
    ),
  );
}
