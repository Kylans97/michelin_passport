import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/star_row.dart';
import '../../data/repositories/award_history_repository.dart';
import '../../models/award_transition.dart';
import '../../models/restaurant.dart';
import 'award_history/michelin_history_view_model.dart';
import 'award_history/worlds_50_best_history_view_model.dart';
import 'widgets/detail_section.dart';
import 'widgets/michelin_award_timeline.dart';
import 'widgets/worlds_50_best_history_section.dart';

/// The historical companion to Restaurant Detail's current-awards card:
/// Michelin star transitions over time, every World's 50 Best ranked year,
/// and Hall of Fame status. Restaurant Detail keeps showing *current*
/// state as it always has — nothing here ever substitutes for that, it's
/// reachable only via the "Award history" action.
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 1.5,
              ),
            )
          : _loadError
          ? _ErrorState(onRetry: _load)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${restaurant.flagEmoji} ${restaurant.cityName}, '
                    '${restaurant.countryName}',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!hasAnything)
                    const _EmptyHistoryState()
                  else ...[
                    if (hasMichelin) ...[
                      const SectionLabel('MICHELIN HISTORY'),
                      const SizedBox(height: 18),
                      MichelinAwardTimeline(
                        transitions: _michelinTransitions,
                        badgeBuilder: (value) => StarRow(count: value),
                        labelBuilder: michelinTransitionLabel,
                      ),
                    ],
                    if (hasMichelin && hasWorlds50Best)
                      const SizedBox(height: 32),
                    if (hasWorlds50Best) ...[
                      const SectionLabel("WORLD'S 50 BEST"),
                      const SizedBox(height: 14),
                      Worlds50BestHistorySection(summary: _worlds50Best),
                    ],
                    if (hasHallOfFame) ...[
                      if (hasMichelin || hasWorlds50Best)
                        const SizedBox(height: 28),
                      HallOfFameBadge(
                        inductionYear: _worlds50Best.hallOfFameYear,
                      ),
                    ],
                  ],
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
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.history_toggle_off_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Historical award data is not available for this restaurant '
            'yet.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
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
          color: AppColors.textSecondary,
          size: 40,
        ),
        const SizedBox(height: 16),
        Text(
          'Could not load award history',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: GoogleFonts.inter(color: AppColors.gold)),
        ),
      ],
    ),
  );
}
