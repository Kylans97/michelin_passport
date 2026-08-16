import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../core/widgets/key_row.dart';
import '../../data/repositories/award_history_repository.dart';
import '../../models/award_transition.dart';
import '../../models/hotel.dart';
import '../restaurants/widgets/michelin_award_timeline.dart';
import 'award_history/keys_history_view_model.dart';
import 'award_history/worlds_50_best_hotels_history_view_model.dart';
import 'widgets/worlds_50_best_hotels_history_section.dart';

/// The historical companion to Hotel Detail's current-recognition hero:
/// MICHELIN Key transitions over time and every World's 50 Best Hotels
/// ranked year. No Hall of Fame section — see
/// HotelWorlds50BestHistorySummary's class doc for why that's structurally
/// impossible here, not just omitted by convention. Mirrors
/// restaurants/award_history_screen.dart exactly in structure; reuses
/// MichelinAwardTimeline/detectAwardTransitions unchanged, only swapping
/// the badge (KeyRow) and label formatter (keysTransitionLabel).
///
/// UI Consistency Step 1B: same forest-green/ivory inversion as Restaurant
/// Award History. Gold is reserved for MICHELIN Keys alone — World's 50
/// Best is ivory.
class HotelAwardHistoryScreen extends StatefulWidget {
  final Hotel hotel;
  const HotelAwardHistoryScreen({super.key, required this.hotel});

  @override
  State<HotelAwardHistoryScreen> createState() =>
      _HotelAwardHistoryScreenState();
}

class _HotelAwardHistoryScreenState extends State<HotelAwardHistoryScreen> {
  late final _repo = AwardHistoryRepository(Supabase.instance.client);

  bool _loading = true;
  bool _loadError = false;
  List<AwardTransition> _keyTransitions = [];
  HotelWorlds50BestHistorySummary _worlds50Best =
      const HotelWorlds50BestHistorySummary(
        topFiftyYears: [],
        extendedYears: [],
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
      final keysFuture = _repo.loadMichelinHistory(
        entityType: 'hotel',
        entityId: widget.hotel.id,
      );
      final worlds50BestFuture = _repo.loadWorlds50BestHotelsHistory(
        widget.hotel.id,
      );
      final keyHistory = await keysFuture;
      final worlds50BestHistory = await worlds50BestFuture;
      if (!mounted) return;
      setState(() {
        _keyTransitions = detectAwardTransitions(keyHistory);
        _worlds50Best = HotelWorlds50BestHistorySummary.of(worlds50BestHistory);
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
    final hotel = widget.hotel;
    final hasKeys = _keyTransitions.isNotEmpty;
    final hasWorlds50Best =
        _worlds50Best.topFiftyYears.isNotEmpty ||
        _worlds50Best.extendedYears.isNotEmpty;
    final hasAnything = hasKeys || hasWorlds50Best;

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
                          hotel.name,
                          style: CsTypography.sectionTitle.copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${hotel.flagEmoji} ${hotel.cityName}, '
                          '${hotel.countryName}',
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
                            'A history of the honors this hotel has earned '
                            'over the years.',
                            style: CsTypography.body.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.xl),

                          if (!hasAnything)
                            const _EmptyHistoryState()
                          else ...[
                            if (hasKeys) ...[
                              Text(
                                'MICHELIN KEY HISTORY',
                                style: CsTypography.eyebrow.copyWith(
                                  color: AppColors.secondaryOnDark,
                                ),
                              ),
                              const SizedBox(height: CsSpacing.md),
                              MichelinAwardTimeline(
                                transitions: _keyTransitions,
                                badgeBuilder: (value) => KeyRow(count: value),
                                labelBuilder: keysTransitionLabel,
                              ),
                            ],
                            if (hasKeys && hasWorlds50Best)
                              const SizedBox(height: CsSpacing.xxl),
                            if (hasWorlds50Best) ...[
                              Text(
                                "WORLD'S 50 BEST",
                                style: CsTypography.eyebrow.copyWith(
                                  color: AppColors.secondaryOnDark,
                                ),
                              ),
                              const SizedBox(height: CsSpacing.md),
                              HotelWorlds50BestHistorySection(
                                summary: _worlds50Best,
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
            'Historical award data is not available for this hotel yet.',
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
