import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// The compact "icon above label" utility row shared by Restaurant and
/// Hotel Detail, per the Clove Club reference's "DIRECTIONS · WEBSITE ·
/// CALL" pattern (UI Consistency Step 1D — final action alignment). Share
/// is deliberately not offered (`share_plus` is not a dependency).
///
/// Only real, currently-available actions are ever shown — never a dead/
/// disabled button pretending to be real. [onOpenMaps] is the only
/// required callback (every venue can always be located); [onOpenWebsite]
/// and [onCall] are each omitted individually when that
/// action isn't available. [onCall] was a prepared seam until Restaurant
/// Enrichment Step 1D added `phone` to [Restaurant] — RestaurantDetailScreen
/// now wires a real callback whenever `buildTelUri` resolves one; Hotel
/// Detail still passes `null` (no `phone` field on [Hotel] yet, a natural
/// future follow-up, not implemented in Step 1D). The row already renders
/// correctly with 1, 2 or 3 actions and rebalances automatically, so
/// Hotel's own day-phone-data-lands change would only touch its call site.
/// Existing URL-generation logic is untouched — this widget only ever
/// receives already-resolved callbacks.
///
/// The guide pages (MICHELIN, World's 50 Best, Gault&Millau) used to be
/// actions here too, and on a venue with every award the row grew to six.
/// They moved to VenueGuideLinks beside Award history (2026-10-30), so
/// this row is only ever the practical Directions · Website · Call, plus
/// Instagram when the venue has an approved account (20261101170000).
class VenueUtilityActions extends StatelessWidget {
  final VoidCallback onOpenMaps;
  final VoidCallback? onOpenWebsite;
  final VoidCallback? onOpenInstagram;
  final VoidCallback? onCall;

  const VenueUtilityActions({
    super.key,
    required this.onOpenMaps,
    this.onOpenWebsite,
    this.onOpenInstagram,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _UtilityAction(
            icon: Icons.directions_rounded,
            label: 'Directions',
            onTap: onOpenMaps,
          ),
        ),
        if (onOpenWebsite != null)
          Expanded(
            child: _UtilityAction(
              icon: Icons.language_rounded,
              label: 'Website',
              onTap: onOpenWebsite!,
            ),
          ),
        if (onOpenInstagram != null)
          Expanded(
            child: _UtilityAction(
              glyph: const InstagramGlyph(color: AppColors.forestGreen),
              label: 'Instagram',
              onTap: onOpenInstagram!,
            ),
          ),
        if (onCall != null)
          Expanded(
            child: _UtilityAction(
              icon: Icons.call_rounded,
              label: 'Call',
              onTap: onCall!,
            ),
          ),
      ],
    );
  }
}

class _UtilityAction extends StatelessWidget {
  final IconData? icon;

  /// A drawn icon in place of [icon], for a mark Material doesn't have.
  final Widget? glyph;
  final String label;
  final VoidCallback onTap;

  const _UtilityAction({
    this.icon,
    this.glyph,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      splashColor: AppColors.forestGreen.withValues(alpha: 0.08),
      highlightColor: AppColors.forestGreen.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph ?? Icon(icon, color: AppColors.forestGreen, size: 20),
            const SizedBox(height: CsSpacing.xs),
            // Scales down rather than truncating, should a label ever be
            // too wide for its share of a narrow phone.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: CsTypography.smallLabel.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Instagram's camera mark, drawn in the row's own colour and size:
/// Material has no Instagram icon, and the brand's own gradient logo
/// would be the one coloured thing in a calm row.
class InstagramGlyph extends StatelessWidget {
  final Color color;
  final double size;

  const InstagramGlyph({super.key, required this.color, this.size = 20});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _InstagramPainter(color),
  );
}

class _InstagramPainter extends CustomPainter {
  final Color color;
  const _InstagramPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 20;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2 * s, 2 * s, 16 * s, 16 * s),
        Radius.circular(4.5 * s),
      ),
      stroke,
    );
    canvas.drawCircle(Offset(10 * s, 10 * s), 3.6 * s, stroke);
    canvas.drawCircle(Offset(14.4 * s, 5.6 * s), 1.1 * s, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InstagramPainter old) => old.color != color;
}
