import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/vineyard_repository.dart';
import '../../models/vineyard.dart';
import 'vineyard_detail_screen.dart';
import 'widgets/vineyard_card.dart';

/// Wine Estates — the collection of vineyards, the same masthead-over-ivory
/// shape as [JourneysScreen]. Only recognised estates, The World's 50 Best
/// Vineyards in rank order, and nothing else: no search, sort or badge.
/// Every other estate is found through search (product owner, 2026-11-24).
class VineyardsScreen extends StatefulWidget {
  const VineyardsScreen({super.key});

  @override
  State<VineyardsScreen> createState() => _VineyardsScreenState();
}

class _VineyardsScreenState extends State<VineyardsScreen> {
  late final _repo = VineyardRepository(Supabase.instance.client);
  List<Vineyard>? _vineyards;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final vineyards = await _repo.getRecognised();
      if (!mounted) return;
      setState(() {
        _vineyards = vineyards;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _open(Vineyard vineyard) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VineyardDetailScreen(vineyardId: vineyard.id),
    ),
  );

  /// "The World's 50 Best Vineyards 2025", from the data itself, so the
  /// heading never claims an edition the list doesn't hold.
  String get _subtitle {
    final years = {
      for (final v in _vineyards ?? const <Vineyard>[])
        if (v.worlds50BestYear != null) v.worlds50BestYear!,
    };
    return years.length == 1
        ? "The World's 50 Best Vineyards ${years.single}."
        : "The World's 50 Best Vineyards.";
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: CsSpacing.base),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: EditorialBackButton(color: AppColors.ivory),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.xs,
                    CsSpacing.pageHorizontal,
                    CsSpacing.base,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wine Estates',
                        style: CsTypography.screenTitle.copyWith(
                          color: AppColors.ivory,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.xs),
                      Text(
                        _subtitle,
                        style: CsTypography.body.copyWith(
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
            child: ColoredBox(
              color: AppColors.ivory,
              child: SafeArea(top: false, child: _body()),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.forestGreen,
          strokeWidth: 1.5,
        ),
      );
    }
    if (_error) {
      return Center(
        child: TextButton(
          onPressed: _load,
          child: Text(
            'Could not load. Tap to try again.',
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ),
      );
    }
    final vineyards = _vineyards ?? const <Vineyard>[];
    if (vineyards.isEmpty) {
      return Center(
        child: Text(
          'Nothing here yet.',
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      itemCount: vineyards.length,
      separatorBuilder: (_, _) => const SizedBox(height: CsSpacing.base),
      itemBuilder: (_, i) => VineyardCard(
        vineyard: vineyards[i],
        onTap: () => _open(vineyards[i]),
      ),
    );
  }
}
