import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../data/repositories/challenge_repository.dart';
import '../challenges_screen.dart';
import 'community_shared.dart';

/// Community → Friends: the running challenges in one line each (your
/// ring, the title, where you stand), and the way to the full overview and
/// the standings. Nothing at all on a server without challenges.
class ChallengesPreview extends StatefulWidget {
  final ChallengeRepository? repository;

  const ChallengesPreview({super.key, this.repository});

  @override
  State<ChallengesPreview> createState() => _ChallengesPreviewState();
}

class _ChallengesPreviewState extends State<ChallengesPreview> {
  // Null without a Supabase client (a widget test): nothing is shown.
  late final ChallengeRepository? _repo = widget.repository ?? _defaultRepo();

  static ChallengeRepository? _defaultRepo() {
    try {
      return ChallengeRepository(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }
  late final Future<List<(Challenge, RankingPlace?, int)>> _future = _load();

  Future<List<(Challenge, RankingPlace?, int)>> _load() async {
    final repo = _repo;
    if (repo == null) return const [];
    try {
      final list = await repo.challenges();
      final rankings = await Future.wait([
        for (final c in list)
          repo.ranking(c.id).catchError((_) => <RankingPlace>[]),
      ]);
      return [
        for (var i = 0; i < list.length; i++)
          (
            list[i],
            rankings[i].where((p) => p.isMe).firstOrNull,
            rankings[i].length,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  void _open({bool standings = false}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChallengesScreen(
        repository: widget.repository,
        scrollToStandings: standings,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<(Challenge, RankingPlace?, int)>>(
        future: _future,
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (snap.connectionState != ConnectionState.done || items.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: CsSpacing.section),
              CommunitySectionTitle('Challenges'),
              const SizedBox(height: CsSpacing.sm),
              for (final (challenge, me, people) in items)
                InkWell(
                  onTap: _open,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
                    child: Row(
                      children: [
                        ProgressRing(
                          progress: me?.value ?? 0,
                          target: me?.target ?? 1,
                          size: 44,
                        ),
                        const SizedBox(width: CsSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                challenge.title,
                                style: CsTypography.bodyMedium.copyWith(
                                  color: AppColors.ivory,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                me == null
                                    ? challenge.periodLabel
                                    : me.completed
                                    ? progressMeta(me)
                                    : people > 1
                                    ? '${ordinal(me.rank)} of $people · ${challenge.periodLabel}'
                                    : challenge.periodLabel,
                                style: CsTypography.metadata.copyWith(
                                  color: me?.completed == true
                                      ? AppColors.terracottaOnDark
                                      : AppColors.secondaryOnDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryOnDark,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: CsSpacing.xs),
              CommunityActionLink(
                label: 'Standings among friends',
                onTap: () => _open(standings: true),
              ),
            ],
          );
        },
      );
}
