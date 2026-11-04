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

  // Defaults to the dark-canvas ivory this widget was originally built
  // for; pass an override (e.g. AppColors.textPrimary) to reuse the exact
  // same treatment on a light-card surface — e.g. the legacy-styled Add
  // Visit/Add Stay sheets — rather than building a second one-off
  // back/close widget for that surface.
  final Color? color;

  // Over a photo, which can be as light as the glyph: the same translucent
  // black circle as the hero's own wishlist button beside it, so the arrow
  // stays visible on a pale wall or sky. Off on a flat canvas, per above.
  final bool onPhoto;

  const EditorialBackButton({
    super.key,
    this.onTap,
    this.icon = Icons.arrow_back_ios_new_rounded,
    this.semanticLabel = 'Back',
    this.color,
    this.onPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: onPhoto
            ? Colors.black.withValues(alpha: 0.24)
            : Colors.transparent,
        shape: onPhoto ? const CircleBorder() : null,
        clipBehavior: onPhoto ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTap: onTap ?? () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(20),
          splashColor: (color ?? AppColors.textOnDark).withValues(alpha: 0.06),
          highlightColor: (color ?? AppColors.textOnDark).withValues(
            alpha: 0.04,
          ),
          child: Padding(
            // 9 + 9 + 19 on a photo: the size of the wishlist circle beside it.
            padding: EdgeInsets.all(onPhoto ? 9 : 13),
            child: Icon(
              icon,
              color: color ?? AppColors.textOnDark,
              size: onPhoto ? 19 : 18,
            ),
          ),
        ),
      ),
    );
    // Centred, or the toolbar stretches the circle to its own height.
    return onPhoto ? Center(child: button) : button;
  }
}
