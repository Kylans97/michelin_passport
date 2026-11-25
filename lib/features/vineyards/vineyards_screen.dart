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

/// Wine Estates — the collection of vineyards, the same masthead-over-ivory
/// shape as [JourneysScreen]. Only recognised estates, one section per list
/// (product owner, 2026-11-24 and 2026-11-25): The World's 50 Best
/// Vineyards in rank order, then each official classification in class
/// order. No search, sort or badge; every other estate is found through
/// search. With only the 50 Best, it looks exactly as it did.
class VineyardsScreen extends StatefulWidget {
  const VineyardsScreen({super.key});

  @override
  State<VineyardsScreen> createState() => _VineyardsScreenState();
}

class _VineyardsScreenState extends State<VineyardsScreen> {
  late final _repo = VineyardRepository(Supabase.instance.client);
  List<EstateCollectionSection>? _sections;
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
      final results = await Future.wait([
        _repo.getRecognised(),
        _repo.getRecognitions().catchError(
          (Object _) => const <VineyardRecognition>[],
        ),
      ]);
      final ranked = results[0] as List<Vineyard>;
      final recognitions = results[1] as List<VineyardRecognition>;
      final byId = {for (final v in ranked) v.id: v};
      final missing = {
        for (final r in recognitions)
          if (!byId.containsKey(r.vineyardId)) r.vineyardId,
      }.toList();
      if (missing.isNotEmpty) {
        for (final v in await _repo.loadByIds(missing)) {
          byId[v.id] = v;
        }
      }
      final sections = buildEstateCollection(
        ranked: ranked,
        recognitions: recognitions,
        byId: byId,
      );
      if (!mounted) return;
      setState(() {
        _sections = sections;
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

  /// With one list, its name ("The World's 50 Best Vineyards 2026.", from
  /// the data, so it never claims an edition the list doesn't hold); with
  /// several, what they have in common.
  String get _subtitle {
    final sections = _sections ?? const <EstateCollectionSection>[];
    if (sections.length > 1) return 'Recognised estates, list by list.';
    if (sections.length == 1) return '${sections.single.title}.';
    return "The World's 50 Best Vineyards.";
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
    final sections = _sections ?? const <EstateCollectionSection>[];
    if (sections.isEmpty) {
      return Center(
        child: Text(
          'Nothing here yet.',
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
      );
    }
    // One section keeps the single list it always was, with no heading.
    final showHeadings = sections.length > 1;
    final items = <Widget>[];
    for (final section in sections) {
      if (showHeadings) {
        items.add(
          Padding(
            padding: EdgeInsets.only(
              top: items.isEmpty ? 0 : CsSpacing.section,
              bottom: CsSpacing.base,
            ),
            child: Text(
              section.title,
              style: CsTypography.sectionTitle.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
          ),
        );
      }
      for (final entry in section.entries) {
        if (items.isNotEmpty &&
            !(showHeadings && entry == section.entries.first)) {
          items.add(const SizedBox(height: CsSpacing.base));
        }
        items.add(
          VineyardCard(
            vineyard: entry.vineyard,
            marker: entry.marker,
            note: entry.note,
            onTap: () => _open(entry.vineyard),
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      children: items,
    );
  }
}
