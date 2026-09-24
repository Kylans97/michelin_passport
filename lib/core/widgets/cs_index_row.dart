import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// Lowercase Roman numeral for [n] (1-based) — "i.", "ii.", "iii." — the
/// magazine pass's own numbering style for [CsIndexRow]. Supports the
/// realistic range any list on this app needs (well under 100 items);
/// unbounded above that only in the sense it won't throw, not that the
/// result stays visually compact.
String toLowerRoman(int n) {
  const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const symbols = [
    'm', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i',
  ];
  var remaining = n;
  final buffer = StringBuffer();
  for (var i = 0; i < values.length; i++) {
    while (remaining >= values[i]) {
      buffer.write(symbols[i]);
      remaining -= values[i];
    }
  }
  return buffer.toString();
}

/// A single row in "The Index" — Explore's editorial list-of-lists:
/// `[34pt roman numeral | title + subtitle | arrow]`, a hairline beneath.
/// [index] is 1-based; this widget renders it as a lowercase Roman
/// numeral via [toLowerRoman].
class CsIndexRow extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final CsSurface surface;

  const CsIndexRow({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.surface = CsSurface.dark,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;
    final titleColor = onDark ? AppColors.textOnDark : AppColors.textPrimary;
    final subtitleColor = onDark
        ? AppColors.stone600OnGreen
        : AppColors.stone600OnPaper;
    final hairline = onDark
        ? AppColors.hairlineOnGreen
        : AppColors.hairlineOnPaper;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${toLowerRoman(index)}.',
                      style: CsTypography.editorialTitle(
                        size: 18,
                        italic: true,
                      ).copyWith(color: AppColors.gold600),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.editorialTitle(
                            size: 24,
                          ).copyWith(color: titleColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.editorialBody.copyWith(
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.gold600,
                    size: 18,
                  ),
                ],
              ),
            ),
            Container(height: 1, color: hairline),
          ],
        ),
      ),
    );
  }
}
