import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_fonts.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// The Passport's data page as it fills in during sign-up: holder,
/// username and home, each "not chosen yet" until answered. With
/// [memberNumber] and [issuedOn] it is the issued page, with the number
/// and a green welcome stamp (stamp ink, never gold).
class PassportPreviewCard extends StatelessWidget {
  const PassportPreviewCard({
    super.key,
    required this.name,
    this.username,
    this.home,
    this.issuedOn,
    this.memberNumber,
  });

  final String name;
  final String? username;
  final String? home;
  final DateTime? issuedOn;
  final int? memberNumber;

  static const _months = [
    'I', 'II', 'III', 'IV', 'V', 'VI', //
    'VII', 'VIII', 'IX', 'X', 'XI', 'XII',
  ];

  @override
  Widget build(BuildContext context) {
    final issued = issuedOn != null;
    final label = CsTypography.smallLabel.copyWith(
      color: AppColors.textSecondary,
      letterSpacing: 1.4,
    );
    Widget field(String title, String? value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: label),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Text(
            value ?? 'not chosen yet',
            key: ValueKey(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.body.copyWith(
              color: value == null
                  ? AppColors.textSecondary.withValues(alpha: 0.7)
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      label: 'Your Passport',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: const _GuillochePainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('PASSPORT', style: label.copyWith(letterSpacing: 2)),
                    const SizedBox(width: CsSpacing.md),
                    // Scales down rather than overflow at large text sizes.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'MANTELIER',
                          style: CsFonts.serif(
                            fontSize: 15,
                            letterSpacing: 2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CsSpacing.md),
                Text('HOLDER', style: label),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'Your name' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CsFonts.serif(
                    fontSize: 26,
                    color: name.isEmpty
                        ? AppColors.textSecondary.withValues(alpha: 0.7)
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: CsSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: field(
                        'Username',
                        username == null ? null : '@$username',
                      ),
                    ),
                    const SizedBox(width: CsSpacing.md),
                    Expanded(child: field('Home', home)),
                  ],
                ),
                if (issued) ...[
                  const SizedBox(height: CsSpacing.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MEMBER NUMBER', style: label),
                            const SizedBox(height: 2),
                            Text(
                              memberNumber == null
                                  ? 'NO. —'
                                  : 'NO. $memberNumber',
                              style: CsFonts.serif(
                                fontSize: 28,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.rotate(
                        angle: -0.21,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.stampInkGreen,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'WELCOME',
                                style: CsTypography.smallLabel.copyWith(
                                  color: AppColors.stampInkGreen,
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                '${issuedOn!.day} ${_months[issuedOn!.month - 1]} '
                                '${issuedOn!.year % 100}',
                                style: CsFonts.serif(
                                  fontSize: 13,
                                  color: AppColors.stampInkGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fine diagonal lines in stamp-green ink, the security printing of the
/// page.
class _GuillochePainter extends CustomPainter {
  const _GuillochePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.stampInkGreen.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
