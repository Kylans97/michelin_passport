import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../journey_visuals.dart';

/// The cabins as a menu card: each named cabin type with its count on a
/// dotted leader, and the total beneath. Shown only when the cabins text
/// names its types with their counts ("Suites (16)"); any other cabins
/// text stays as the operator's own sentence (product owner, 2026-11-21:
/// the row of squares and circles "doen ook niet zoveel voor mij").
class JourneyCabinManifest extends StatelessWidget {
  final CabinLayout layout;

  /// The journey's name, set in italic above the list like a card's head.
  final String title;

  const JourneyCabinManifest({
    super.key,
    required this.layout,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final serif = CsTypography.editorialLead(
      size: 18,
    ).copyWith(fontStyle: FontStyle.normal, color: AppColors.textPrimary);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.lg,
        CsSpacing.lg,
        CsSpacing.lg,
        CsSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.subtleBorderLight),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: CsTypography.editorialLead(
              size: 15,
            ).copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.md),
          for (final group in layout.groups)
            _Line(
              label: Text(group.name ?? '', style: serif),
              count: '${group.count}',
              countStyle: serif.copyWith(color: AppColors.forestGreen),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CsSpacing.sm),
            child: Divider(height: 1, color: AppColors.subtleBorderLight),
          ),
          _Line(
            label: Text(
              'IN ALL',
              style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
            ),
            count: '${layout.total}',
            countStyle: serif.copyWith(color: AppColors.forestGreen),
            leader: false,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final Widget label;
  final String count;
  final TextStyle countStyle;
  final bool leader;

  const _Line({
    required this.label,
    required this.count,
    required this.countStyle,
    this.leader = true,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CsSpacing.xs),
    // The name takes its own width (wrapping only past most of the line),
    // the leader fills what is left, so every count sits flush right.
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.72),
            child: label,
          ),
          Expanded(
            child: leader
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
                    child: CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DottedLeader(),
                    ),
                  )
                : const SizedBox(),
          ),
          Text(count, style: countStyle),
        ],
      ),
    ),
  );
}

class _DottedLeader extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.secondaryOnDark;
    for (var x = 0.0; x < size.width; x += 5) {
      canvas.drawCircle(Offset(x + 1, size.height / 2), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLeader old) => false;
}
