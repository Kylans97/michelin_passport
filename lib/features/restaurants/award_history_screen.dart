import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../core/widgets/star_row.dart';
import '../../data/repositories/award_history_repository.dart';
import '../../models/award_transition.dart';
import '../../models/restaurant.dart';
import 'award_history/michelin_history_view_model.dart';
import 'award_history/worlds_50_best_history_view_model.dart';
import 'widgets/michelin_award_timeline.dart';
import 'widgets/worlds_50_best_history_section.dart';

/// The historical companion to Restaurant Detail's current-recognition
/// hero: Michelin star transitions over time, every World's 50 Best ranked
/// year, and Hall of Fame status. Restaurant Detail keeps showing *current*
/// state as it always has — nothing here ever substitutes for that, it's
/// reachable only via the "Award history" action.
///
/// UI Consistency Step 1B (physical-device polish): a deliberate color
/// inversion from Restaurant Detail's ivory canvas — this screen is a full
/// forest-green "archive / record book" canvas with ivory content, so
/// moving between the two reads as a deliberate transition into a distinct
/// experience. Even here, gold is reserved for Michelin stars alone —
/// World's 50 Best and Hall of Fame are ivory, never gold.
class AwardHistoryScreen extends StatefulWidget {
  final Restaurant restaurant;
  const AwardHistoryScreen({super.key, required this.restaurant});

  @override
  State<AwardHistoryScreen> createState() => _AwardHistoryScreenState();
}

class _AwardHistoryScreenState extends State<AwardHistoryScreen> {
  late final _repo = AwardHistoryRepository(Supabase.instance.client);

  bool _loading = true;
  bool _loadError = false;
  List<AwardTransition> _michelinTransitions = [];
  Worlds50BestHistorySummary _worlds50Best = const Worlds50BestHistorySummary(
    topFiftyYears: [],
    extendedYears: [],
    hallOfFameYear: null,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final michelinFuture = _repo.loadMichelinHistory(
        entityType: 'restaurant',
        entityId: widget.restaurant.id,
      );
      final worlds50BestFuture = _repo.loadWorlds50BestHistory(
        widget.restaurant.id,
      );
      final michelinHistory = await michelinFuture;
      final worlds50BestHistory = await worlds50BestFuture;
      if (!mounted) return;
      setState(() {
        _michelinTransitions = detectAwardTransitions(michelinHistory);
        _worlds50Best = Worlds50BestHistorySummary.of(worlds50BestHistory);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final hasHallOfFame = _worlds50Best.hallOfFameYear != null;
    final hasMichelin = _michelinTransitions.isNotEmpty;
    final hasWorlds50Best =
        _worlds50Best.topFiftyYears.isNotEmpty ||
        _worlds50Best.extendedYears.isNotEmpty;
    final hasAnything = hasMichelin || hasWorlds50Best || hasHallOfFame;

    return Scaffold(
      backgroundColor: AppColors.forestGreen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.sm,
                CsSpacing.sm,
                CsSpacing.pageHorizontal,
                CsSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: EditorialBackButton(),
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CsSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: CsTypography.sectionTitle.copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${restaurant.flagEmoji} ${restaurant.cityName}, '
                          '${restaurant.countryName}',
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.textOnDark,
                        strokeWidth: 1.5,
                      ),
                    )
                  : _loadError
                  ? _ErrorState(onRetry: _load)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        CsSpacing.pageHorizontal,
                        CsSpacing.md,
                        CsSpacing.pageHorizontal,
                        CsSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A history of the honors this restaurant has '
                            'earned over the years.',
                            style: CsTypography.body.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.xl),

                          if (!hasAnything)
                            const _EmptyHistoryState()
                          else ...[
                            if (hasMichelin) ...[
                              Text(
                                'MICHELIN HISTORY',
                                style: CsTypography.eyebrow.copyWith(
                                  color: AppColors.secondaryOnDark,
                                ),
                              ),
                              const SizedBox(height: CsSpacing.md),
                              MichelinAwardTimeline(
                                transitions: _michelinTransitions,
                                badgeBuilder: (value) => StarRow(count: value),
                                labelBuilder: michelinTransitionLabel,
                              ),
                            ],
                            if (hasMichelin && hasWorlds50Best)
                              const SizedBox(height: CsSpacing.xxl),
                            if (hasWorlds50Best) ...[
                              Text(
                                "WORLD'S 50 BEST",
                                style: CsTypography.eyebrow.copyWith(
                                  color: AppColors.secondaryOnDark,
                                ),
                              ),
                              const SizedBox(height: CsSpacing.md),
                              Worlds50BestHistorySection(
                                summary: _worlds50Best,
                              ),
                            ],
                            if (hasHallOfFame) ...[
                              if (hasMichelin || hasWorlds50Best)
                                const SizedBox(height: CsSpacing.xl),
                              HallOfFameBadge(
                                inductionYear: _worlds50Best.hallOfFameYear,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.history_toggle_off_rounded,
          color: AppColors.secondaryOnDark,
          size: 20,
        ),
        const SizedBox(width: CsSpacing.md),
        Expanded(
          child: Text(
            'Historical award data is not available for this restaurant '
            'yet.',
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.secondaryOnDark,
          size: 40,
        ),
        const SizedBox(height: CsSpacing.base),
        Text(
          'Could not load award history',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.md),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: CsTypography.bodyMedium.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
        ),
      ],
    ),
  );
}
