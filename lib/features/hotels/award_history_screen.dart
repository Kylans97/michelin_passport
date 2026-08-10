import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/detail_hero.dart' show HeroIconButton;
import '../../core/widgets/key_row.dart';
import '../../data/repositories/award_history_repository.dart';
import '../../models/award_transition.dart';
import '../../models/hotel.dart';
import '../restaurants/widgets/detail_section.dart';
import '../restaurants/widgets/michelin_award_timeline.dart';
import 'award_history/keys_history_view_model.dart';
import 'award_history/worlds_50_best_hotels_history_view_model.dart';
import 'widgets/worlds_50_best_hotels_history_section.dart';

/// The historical companion to Hotel Detail's current-awards card:
/// MICHELIN Key transitions over time and every World's 50 Best Hotels
/// ranked year. No Hall of Fame section — see
/// HotelWorlds50BestHistorySummary's class doc for why that's structurally
/// impossible here, not just omitted by convention. Mirrors
/// restaurants/award_history_screen.dart exactly in structure; reuses
/// MichelinAwardTimeline/detectAwardTransitions unchanged, only swapping
/// the badge (KeyRow) and label formatter (keysTransitionLabel).
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Compact dark-green editorial identity area — the venue name
          // lives here, not repeated in the ivory body below.
          DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.brandGreen),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: HeroIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.maybePop(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      hotel.name,
                      style: AppTypography.editorialHeading.copyWith(
                        color: AppColors.textOnDark,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${hotel.flagEmoji} ${hotel.cityName}, '
                      '${hotel.countryName}',
                      style: AppTypography.metadata.copyWith(
                        color: AppColors.textOnDark.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 1.5,
                    ),
                  )
                : _loadError
                ? _ErrorState(onRetry: _load)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A history of the honors this hotel has earned '
                          'over the years.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (!hasAnything)
                          const _EmptyHistoryState()
                        else ...[
                          if (hasKeys) ...[
                            const EditorialHeading('MICHELIN Key History'),
                            const SizedBox(height: 18),
                            MichelinAwardTimeline(
                              transitions: _keyTransitions,
                              badgeBuilder: (value) => KeyRow(count: value),
                              labelBuilder: keysTransitionLabel,
                            ),
                          ],
                          if (hasKeys && hasWorlds50Best)
                            const SizedBox(height: 36),
                          if (hasWorlds50Best) ...[
                            const EditorialHeading("World's 50 Best"),
                            const SizedBox(height: 14),
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
            'Historical award data is not available for this hotel yet.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
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
