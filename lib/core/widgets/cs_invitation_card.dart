import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// The magazine pass's one recurring "formal notice" shape — an ivory
/// surface with a genuine double border (a 1px gold outline, then an
/// 8–9pt gap, then a second 1px gold outline around the content) and a
/// pronounced shadow, standing in wherever this pass needs to present a
/// single, considered message rather than a list: a concierge note, an
/// event invitation, a shared-wishlist match, an empty ranking state.
///
/// Content-agnostic — the caller supplies [child] (text, columns,
/// whatever the moment needs) and this widget only owns the double frame
/// and shadow. Not centered on screen by itself; the caller centers it
/// within whatever it's placed in (a screen's body, a sheet).
class CsInvitationCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const CsInvitationCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.maxWidth = 360,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ivory,
        border: Border.all(color: AppColors.gold600, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold600, width: 1),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}
