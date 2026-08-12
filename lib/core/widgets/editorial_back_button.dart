import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A small, understated back/close arrow for pushed screens and modal
/// sheets on the dark canvas — deliberately NOT [HeroIconButton]'s
/// translucent black circle: that treatment is built for sitting over a
/// photographic hero image, and reads as barely-there on a flat deep-green
/// canvas (low contrast, no image to separate it from). Just an ivory
/// glyph with a generous invisible tap target, so it sits in the layout
/// rather than looking like a floating Material control.
///
/// [icon] defaults to a back chevron (pushed screens); pass
/// [Icons.close_rounded] with [semanticLabel] "Close" for a modal sheet's
/// dismiss control instead — same visual treatment, different glyph/label
/// for the different dismissal semantics. [onTap] defaults to
/// [Navigator.maybePop] — the existing navigation stack, never a
/// hardcoded destination.
class EditorialBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String semanticLabel;

  const EditorialBackButton({
    super.key,
    this.onTap,
    this.icon = Icons.arrow_back_ios_new_rounded,
    this.semanticLabel = 'Back',
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.maybePop(context),
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
        highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Icon(icon, color: AppColors.textOnDark, size: 18),
        ),
      ),
    ),
  );
}
