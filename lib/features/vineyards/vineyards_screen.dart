import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/vineyard_repository.dart';
import '../../models/vineyard.dart';
import '../../models/vineyard_recognition.dart';
import 'vineyard_detail_screen.dart';
import 'widgets/vineyard_card.dart';

/// Wine Estates — one recognised list of estates, the same
/// masthead-over-ivory shape as [JourneysScreen]. Without a [scheme], The
/// World's 50 Best Vineyards in rank order (Guides, under The World's 50
/// Best); with one, that official classification in class order, the class
/// under each estate (Guides, Bordeaux Classifications; product owner,
/// 2026-11-25). No search, sort or badge; every other estate is found
/// through search.
class VineyardsScreen extends StatefulWidget {
  const VineyardsScreen({super.key, this.scheme});

  final RecognitionScheme? scheme;

  @override
  State<VineyardsScreen> createState() => _VineyardsScreenState();
}

class _VineyardsScreenState extends State<VineyardsScreen> {
  late final _repo = VineyardRepository(Supabase.instance.client);
  List<EstateCollectionEntry>? _entries;
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
      final scheme = widget.scheme;
      final List<EstateCollectionEntry> entries;
      if (scheme == null) {
        entries = [
          for (final v in await _repo.getRecognised())
            EstateCollectionEntry(
              vineyard: v,
              marker: '${v.worlds50BestRank ?? ''}',
            ),
        ];
      } else {
        final recognitions = await _repo.getRecognitions(scheme: scheme.code);
        final estates = await _repo.loadByIds([
          for (final r in recognitions) r.vineyardId,
        ]);
        entries = classifiedEstates(
          scheme: scheme.code,
          recognitions: recognitions,
          byId: {for (final v in estates) v.id: v},
        );
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  String get _title => widget.scheme?.label ?? 'Wine Estates';

  /// The classification's own line, or "The World's 50 Best Vineyards
  /// 2026." from the data, so it never claims an edition the list doesn't
  /// hold.
  String get _subtitle {
    final scheme = widget.scheme;
    if (scheme != null) return scheme.descriptor;
    final years = {
      for (final e in _entries ?? const <EstateCollectionEntry>[])
        ?e.vineyard.worlds50BestYear,
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
                        _title,
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
    final entries = _entries ?? const <EstateCollectionEntry>[];
    if (entries.isEmpty) {
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
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: CsSpacing.base),
      itemBuilder: (_, i) => VineyardCard(
        vineyard: entries[i].vineyard,
        marker: entries[i].marker,
        note: entries[i].note,
        onTap: () => _open(entries[i].vineyard),
      ),
    );
  }
}
