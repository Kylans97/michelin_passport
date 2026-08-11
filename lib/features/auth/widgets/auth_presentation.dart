import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart'
    show csMonogramAssetPath;

/// Monogram + wordmark + a short line of supporting copy — the calm,
/// editorial "entrance" moment shared by Login and Sign up (Step 4A), so
/// both screens unmistakably read as the same experience. The monogram is
/// the official asset rendered directly via [csMonogramAssetPath]
/// (Image.asset, BoxFit.contain — no recolor, no redraw), not
/// [CsImagePlaceholder]: that widget exists specifically for a venue-photo
/// fallback slot, which isn't the semantic role a brand mark plays here.
/// [compact] shrinks the monogram/wordmark slightly for Sign up, which has
/// more fields below it competing for vertical space.
class AuthBrandHeader extends StatelessWidget {
  final String tagline;
  final bool compact;

  const AuthBrandHeader({
    super.key,
    required this.tagline,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final monogramSize = compact ? 48.0 : 64.0;
    return Column(
      children: [
        Image.asset(
          csMonogramAssetPath,
          width: monogramSize,
          height: monogramSize,
          fit: BoxFit.contain,
        ),
        SizedBox(height: compact ? CsSpacing.base : CsSpacing.lg),
        Text(
          'CHASING STARS',
          textAlign: TextAlign.center,
          style: CsTypography.screenTitle.copyWith(
            color: AppColors.textOnDark,
            letterSpacing: 1.0,
            fontSize: compact ? 26 : 32,
          ),
        ),
        const SizedBox(height: CsSpacing.sm),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
      ],
    );
  }
}

/// A restrained inline error, close to the form — the message itself is
/// whatever the caller's existing auth logic already produced (e.g.
/// AuthException.message), never re-derived or expanded here; only the
/// presentation is new. Copy always renders in [AppColors.textOnDark] so
/// meaning never depends on the (color-only) tint alone.
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CsSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.error.withValues(alpha: 0.4),
        width: 0.5,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 16,
        ),
        const SizedBox(width: CsSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
          ),
        ),
      ],
    ),
  );
}

/// "New to Chasing Stars? / Create an account →" (or the Sign up
/// equivalent, "Already a member? / Sign in →") — one quiet editorial
/// link, never a second button competing with the primary CTA.
class SecondaryAuthLink extends StatelessWidget {
  final String question;
  final String actionLabel;
  final VoidCallback onTap;

  const SecondaryAuthLink({
    super.key,
    required this.question,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        child: Column(
          children: [
            Text(
              question,
              textAlign: TextAlign.center,
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$actionLabel →',
              textAlign: TextAlign.center,
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
