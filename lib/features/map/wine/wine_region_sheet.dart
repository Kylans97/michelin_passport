import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../models/wine_atlas.dart';

/// Tapping a region on the wine globe: what it is, its grapes and what
/// they become there, how a red from here feels, what to eat with it, and
/// the names a wine list uses for it ("Wine regions globe" canvas, screen
/// 2). Reference content only — written and reviewed by us, never gold.
Future<void> showWineRegionSheet(
  BuildContext context, {
  required WineAtlas atlas,
  required WineRegion region,
  int myWineCount = 0,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  builder: (sheetContext) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.62,
    minChildSize: 0.4,
    maxChildSize: 0.94,
    builder: (_, controller) => WineRegionDetail(
      atlas: atlas,
      region: region,
      myWineCount: myWineCount,
      scrollController: controller,
    ),
  ),
);

class WineRegionDetail extends StatelessWidget {
  final WineAtlas atlas;
  final WineRegion region;
  final int myWineCount;
  final ScrollController? scrollController;

  const WineRegionDetail({
    super.key,
    required this.atlas,
    required this.region,
    this.myWineCount = 0,
    this.scrollController,
  });

  void _openGrape(BuildContext context, Grape grape) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          GrapeScreen(atlas: atlas, grape: grape, fromRegion: region),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final grapes = atlas.grapesOf(region);
    final names = atlas.appellationsOf(region);
    final country = region.countryName ?? region.countryCode;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.hero,
      ),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.subtleBorderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: CsSpacing.lg),
        Text(
          'WINE REGION · ${country.toUpperCase()}',
          style: CsTypography.eyebrow.copyWith(color: AppColors.claret),
        ),
        const SizedBox(height: CsSpacing.xs),
        Text(
          region.name,
          style: CsTypography.screenTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: CsSpacing.sm),
        Text(
          region.summary,
          style: CsTypography.body.copyWith(color: AppColors.textPrimary),
        ),
        if (grapes.isNotEmpty) ...[
          const _SectionLabel('THE GRAPES'),
          // Names only (product owner, 2026-11-22): what the grape is here
          // leads its own screen, one tap away.
          for (final (grape, _) in grapes)
            _GrapeRow(grape: grape, onTap: () => _openGrape(context, grape)),
        ],
        if (region.hasRedProfile) ...[
          const _SectionLabel('A RED FROM HERE, IN THE GLASS'),
          TasteScale(
            label: 'Body',
            value: region.redBody!,
            word: bodyWord(region.redBody!),
          ),
          TasteScale(
            label: 'Acidity',
            value: region.redAcidity!,
            word: acidityWord(region.redAcidity!),
          ),
          TasteScale(
            label: 'Tannin',
            value: region.redTannin!,
            word: tanninWord(region.redTannin!),
          ),
        ],
        if ((region.pairing ?? '').isNotEmpty) ...[
          const SizedBox(height: CsSpacing.md),
          Text(
            'Goes with: ${region.pairing}',
            style: CsTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (names.isNotEmpty) ...[
          const _SectionLabel("ON A WINE LIST YOU'LL SEE"),
          _NameList(names: names),
        ],
        if ((region.labelNote ?? '').isNotEmpty) ...[
          const SizedBox(height: CsSpacing.md),
          Text(
            region.labelNote!,
            style: CsTypography.metadata.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (myWineCount > 0) ...[
          const SizedBox(height: CsSpacing.lg),
          Container(
            padding: const EdgeInsets.all(CsSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.claretTint,
              borderRadius: BorderRadius.circular(CsRadius.medium),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.wine_bar_outlined,
                  size: 18,
                  color: AppColors.claret,
                ),
                const SizedBox(width: CsSpacing.md),
                Expanded(
                  child: Text(
                    myWineCount == 1
                        ? '1 wine in your Cellar comes from here'
                        : '$myWineCount wines in your Cellar come from here',
                    style: CsTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A grape's own page: what you taste, how it feels, where it grows and
/// what that changes ("Wine regions globe" canvas, screen 4).
///
/// Opened from a region ([fromRegion]), it leads with what the grape is
/// there, in the region's own words, and lists that region first.
class GrapeScreen extends StatelessWidget {
  final WineAtlas atlas;
  final Grape grape;
  final WineRegion? fromRegion;

  const GrapeScreen({
    super.key,
    required this.atlas,
    required this.grape,
    this.fromRegion,
  });

  @override
  Widget build(BuildContext context) {
    // Only a region that lists this grape: a similar grape opened from
    // here may not grow there.
    final link = fromRegion == null ? null : atlas.linkOf(fromRegion!, grape);
    final from = link == null ? null : fromRegion;
    final regions = [
      ?from,
      for (final r in atlas.regionsOf(grape))
        if (r.id != from?.id) r,
    ];
    final similar = atlas.grape(grape.similarGrapeId);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ColoredBox(
            color: AppColors.deepGreen,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.base,
                  0,
                  CsSpacing.pageHorizontal,
                  CsSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EditorialBackButton(color: AppColors.ivory),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: CsSpacing.pageHorizontal - CsSpacing.base,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: CsSpacing.md),
                          Text(
                            'GRAPE · ${grape.colour.label.toUpperCase()}',
                            style: CsTypography.eyebrow.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.xs),
                          Text(
                            grape.name,
                            style: CsTypography.displayHero.copyWith(
                              color: AppColors.ivory,
                            ),
                          ),
                          if (grape.aliases.isNotEmpty) ...[
                            const SizedBox(height: CsSpacing.xs),
                            Text(
                              'Also: ${grape.aliases.join(', ')}',
                              style: CsTypography.metadata.copyWith(
                                color: AppColors.secondaryOnDark,
                              ),
                            ),
                          ],
                          const SizedBox(height: CsSpacing.sm),
                          Text(
                            grape.summary,
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              0,
              CsSpacing.pageHorizontal,
              CsSpacing.hero,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (from != null) _InRegion(region: from, link: link!),
                if (grape.tastes.isNotEmpty || grape.agedNote != null) ...[
                  const _SectionLabel('WHAT YOU TASTE'),
                  Wrap(
                    spacing: CsSpacing.sm,
                    runSpacing: CsSpacing.sm,
                    children: [
                      for (final taste in grape.tastes)
                        _TasteChip(taste, wine: true),
                      if (grape.agedNote != null)
                        _TasteChip('With age: ${grape.agedNote}', wine: false),
                    ],
                  ),
                ],
                if (grape.body != null) ...[
                  const SizedBox(height: CsSpacing.md),
                  TasteScale(
                    label: 'Body',
                    value: grape.body!,
                    word: bodyWord(grape.body!),
                  ),
                ],
                if (grape.acidity != null)
                  TasteScale(
                    label: 'Acidity',
                    value: grape.acidity!,
                    word: acidityWord(grape.acidity!),
                  ),
                if (grape.tannin != null)
                  TasteScale(
                    label: 'Tannin',
                    value: grape.tannin!,
                    word: tanninWord(grape.tannin!),
                  ),
                if (regions.isNotEmpty) ...[
                  const _SectionLabel('WHERE IT GROWS'),
                  _Card(
                    children: [
                      for (final region in regions)
                        _CardRow(
                          title: region.name,
                          trailing: region.id == from?.id
                              ? 'Where you came from'
                              : (region.countryName ?? region.countryCode),
                          onTap: () => showWineRegionSheet(
                            context,
                            atlas: atlas,
                            region: region,
                          ),
                        ),
                    ],
                  ),
                ],
                if (similar != null) ...[
                  const SizedBox(height: CsSpacing.lg),
                  InkWell(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GrapeScreen(
                          atlas: atlas,
                          grape: similar,
                          fromRegion: fromRegion,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(CsRadius.medium),
                    child: Container(
                      padding: const EdgeInsets.all(CsSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(CsRadius.medium),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: AppColors.forestGreen,
                          ),
                          const SizedBox(width: CsSpacing.md),
                          Expanded(
                            child: Text(
                              grape.similarNote == null
                                  ? 'Like this? Try ${similar.name}.'
                                  : 'Like this? Try ${similar.name}: '
                                        '${grape.similarNote}.',
                              style: CsTypography.body.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String bodyWord(int v) => v <= 2 ? 'light' : (v == 3 ? 'medium' : 'full');
String acidityWord(int v) => v <= 2 ? 'soft' : (v == 3 ? 'balanced' : 'fresh');
String tanninWord(int v) => v <= 2 ? 'soft' : (v == 3 ? 'medium' : 'firm');

/// Five short bars, [value] of them filled in claret, and a word.
class TasteScale extends StatelessWidget {
  final String label;
  final int value;
  final String word;

  const TasteScale({
    super.key,
    required this.label,
    required this.value,
    required this.word,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $word, $value of 5',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: CsSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: CsTypography.metadata.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          for (var i = 1; i <= 5; i++)
            Container(
              width: 26,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: i <= value ? AppColors.claret : AppColors.cardBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          const SizedBox(width: CsSpacing.sm),
          Text(
            word,
            style: CsTypography.metadata.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: CsSpacing.section,
      bottom: CsSpacing.md,
    ),
    child: Text(
      text,
      style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
    ),
  );
}

class _GrapeRow extends StatelessWidget {
  final Grape grape;
  final VoidCallback onTap;

  const _GrapeRow({required this.grape, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.sm),
    child: Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          padding: const EdgeInsets.all(CsSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: grape.colour == GrapeColour.red
                      ? AppColors.claret
                      : const Color(0xFFD9C27A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Text(
                  grape.name,
                  style: CsTypography.placeTitle.copyWith(
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// What the grape is in the region the member came from, in the region's
/// own words: [RegionGrape.lead] in serif, [RegionGrape.detail] below.
/// When the region says nothing, one quiet line instead, never made up.
class _InRegion extends StatelessWidget {
  final WineRegion region;
  final RegionGrape link;

  const _InRegion({required this.region, required this.link});

  @override
  Widget build(BuildContext context) {
    final lead = link.lead;
    final detail = link.detail;
    if (lead == null) {
      return Container(
        margin: const EdgeInsets.only(top: CsSpacing.lg),
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
        decoration: const BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: AppColors.cardBorder),
          ),
        ),
        child: Text(
          'Grown in ${region.name}.',
          style: CsTypography.metadata.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: CsSpacing.lg),
      padding: const EdgeInsets.all(CsSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.claretTint,
        borderRadius: BorderRadius.circular(CsRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IN ${region.name.toUpperCase()}',
            style: CsTypography.eyebrow.copyWith(color: AppColors.claret),
          ),
          const SizedBox(height: CsSpacing.sm),
          Text(
            lead,
            style: CsTypography.placeTitle.copyWith(
              fontSize: 19,
              color: AppColors.textPrimary,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: CsSpacing.sm),
            Text(
              detail,
              style: CsTypography.metadata.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NameList extends StatelessWidget {
  final List<WineAppellation> names;
  const _NameList({required this.names});

  @override
  Widget build(BuildContext context) => _Card(
    children: [
      for (final name in names)
        _CardRow(
          title: name.name,
          trailing: '${name.colourLabel} · ${name.note}',
        ),
    ],
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
          children[i],
        ],
      ],
    ),
  );
}

class _CardRow extends StatelessWidget {
  final String title;
  final String trailing;
  final VoidCallback? onTap;

  const _CardRow({required this.title, required this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CsSpacing.md,
        vertical: CsSpacing.md,
      ),
      // The note under the name, not beside it: right-aligned beside a
      // name it wrapped into a ragged column with a word hanging alone
      // ("red" under Chinon, seen in the simulator 2026-11-20).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: CsTypography.placeTitle.copyWith(
              fontSize: 15.5,
              color: AppColors.textPrimary,
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              trailing,
              style: CsTypography.metadata.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _TasteChip extends StatelessWidget {
  final String text;
  final bool wine;
  const _TasteChip(this.text, {required this.wine});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: wine ? AppColors.claretTint : AppColors.cardBorder,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: CsTypography.metadata.copyWith(
        color: wine ? AppColors.claret : AppColors.textPrimary,
      ),
    ),
  );
}
