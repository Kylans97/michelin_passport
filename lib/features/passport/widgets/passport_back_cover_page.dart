import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_masthead_logo.dart';
import '../passport_filter_type.dart';

/// The booklet's final page, right after the last stamp page — a way out
/// of the ink-stamp metaphor into a flat, searchable list of every visit:
/// a link to the complete list, a shortcut per [PassportFilterType], and
/// the closing editorial line. Only the current user's own booklet
/// includes this (see [PassportOpenBookPager.includeBackCoverPage] in
/// passport_open_book_pager.dart) — a friend's read-only booklet has no
/// equivalent screen to link to.
class PassportBackCoverPage extends StatelessWidget {
  final VoidCallback onViewAll;
  final ValueChanged<PassportFilterType> onFilterTap;
  final Size size;

  const PassportBackCoverPage({
    super.key,
    required this.onViewAll,
    required this.onFilterTap,
    this.size = const Size(320, 480),
  });

  static const _cornerLeft = 4.0;
  static const _cornerRight = 14.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_cornerLeft),
          bottomLeft: Radius.circular(_cornerLeft),
          topRight: Radius.circular(_cornerRight),
          bottomRight: Radius.circular(_cornerRight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_cornerLeft),
          bottomLeft: Radius.circular(_cornerLeft),
          topRight: Radius.circular(_cornerRight),
          bottomRight: Radius.circular(_cornerRight),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  CsMastheadLogo(size: 22, tint: AppColors.forestGreen),
                  const SizedBox(height: 24),
                  _ViewAllLink(onTap: onViewAll),
                  const SizedBox(height: 28),
                  Container(width: 40, height: 1, color: AppColors.hairlineOnPaper),
                  const SizedBox(height: 20),
                  Text(
                    'BROWSE BY TYPE',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 9 * 0.12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final type in PassportFilterType.values)
                        _FilterChip(type: type, onTap: () => onFilterTap(type)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Thank you for exploring your\ngastronomic journey with Mantelier',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 14,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0x33000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewAllLink extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewAllLink({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'View all visits',
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View all visits',
                  style: GoogleFonts.cormorantGaramond(
                    color: AppColors.forestGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.forestGreen,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.forestGreen,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final PassportFilterType type;
  final VoidCallback onTap;
  const _FilterChip({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: type.label,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.forestGreen, width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              type.label,
              style: GoogleFonts.inter(
                color: AppColors.forestGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
