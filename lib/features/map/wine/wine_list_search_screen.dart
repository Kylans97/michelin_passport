import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_search_field.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../models/wine_atlas.dart';
import 'wine_region_sheet.dart';

/// "What's on the list?" — type a region, a name from the wine list or a
/// grape, and see what it is ("Wine regions globe" canvas, screen 3; the
/// product owner's own problem: "wine lists organised by region"). Pops
/// with the region to show on the globe when one is chosen; a grape opens
/// its own page.
class WineListSearchScreen extends StatefulWidget {
  final WineAtlas atlas;

  const WineListSearchScreen({super.key, required this.atlas});

  @override
  State<WineListSearchScreen> createState() => _WineListSearchScreenState();
}

class _WineListSearchScreenState extends State<WineListSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openGrape(Grape grape) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GrapeScreen(atlas: widget.atlas, grape: grape),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hits = widget.atlas.search(_query);
    final searching = _query.trim().length >= 2;
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            0,
            CsSpacing.pageHorizontal,
            CsSpacing.hero,
          ),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: EditorialBackButton(color: AppColors.ivory),
            ),
            const SizedBox(height: CsSpacing.sm),
            Text(
              "What's on the list?",
              style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
            ),
            const SizedBox(height: CsSpacing.base),
            CsSearchField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              hintText: 'A region, a name or a grape',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: CsSpacing.sm),
            Text(
              "Type it as it's written on the list.",
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.lg),
            if (searching && hits.isEmpty)
              Text(
                "Not in our wine regions yet. We're adding more.",
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            for (final hit in hits)
              Padding(
                padding: const EdgeInsets.only(bottom: CsSpacing.md),
                child: switch (hit) {
                  RegionHit(:final region) => _HitCard(
                    title: region.name,
                    place: region.countryName ?? region.countryCode,
                    lines: [
                      widget.atlas
                          .grapesOf(region)
                          .map((g) => g.$1.name)
                          .join(' · '),
                      region.summary,
                    ],
                    onTap: () => Navigator.pop(context, region),
                  ),
                  AppellationHit(:final appellation, :final region) => _HitCard(
                    title: appellation.name,
                    place: region.name,
                    lines: [
                      '${appellation.colourLabel[0].toUpperCase()}'
                          '${appellation.colourLabel.substring(1)} · '
                          '${appellation.note}',
                      'From ${region.name}: '
                          '${widget.atlas.grapesOf(region).map((g) => g.$1.name).join(', ')}',
                    ],
                    onTap: () => Navigator.pop(context, region),
                  ),
                  GrapeHit(:final grape) => _HitCard(
                    title: grape.name,
                    place: 'Grape · ${grape.colour.label.toLowerCase()}',
                    lines: [grape.tastes.join(', '), grape.summary],
                    onTap: () => _openGrape(grape),
                  ),
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HitCard extends StatelessWidget {
  final String title;
  final String place;
  final List<String> lines;
  final VoidCallback onTap;

  const _HitCard({
    required this.title,
    required this.place,
    required this.lines,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(CsRadius.large),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.large),
      child: Padding(
        padding: const EdgeInsets.all(CsSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: CsTypography.placeTitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  place,
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            for (final line in lines)
              if (line.trim().isNotEmpty) ...[
                const SizedBox(height: CsSpacing.xs),
                Text(
                  line,
                  style: CsTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
          ],
        ),
      ),
    ),
  );
}
