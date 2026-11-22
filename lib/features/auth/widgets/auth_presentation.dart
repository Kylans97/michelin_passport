import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart'
    show csMonogramAssetPath;

/// Monogram + wordmark + a short line of supporting copy — the calm,
/// editorial "entrance" moment shared by Login and Sign up (Step 4A), so
/// both screens unmistakably read as the same experience. The monogram is
/// the official asset rendered directly via [csMonogramAssetPath]
/// (SvgPicture.asset, BoxFit.contain — no recolor, no redraw), not
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
    // mark-ivory-ink.svg carries generous whitespace around the ink
    // itself (unlike the old filled-square asset these sizes were tuned
    // for), so the same pixel box now reads noticeably smaller — bumped
    // so the login screen's mark reads at ~80 logical px again, compact
    // scaled by the same 0.75 ratio the two sizes always had (48/64).
    final monogramSize = compact ? 60.0 : 80.0;
    return Column(
      children: [
        SvgPicture.asset(
          csMonogramAssetPath,
          width: monogramSize,
          height: monogramSize,
          fit: BoxFit.contain,
        ),
        SizedBox(height: compact ? CsSpacing.base : CsSpacing.lg),
        Text(
          'MANTELIER',
          textAlign: TextAlign.center,
          style: CsTypography.screenTitle.copyWith(
            color: AppColors.textOnDark,
            letterSpacing: 1.0,
            fontSize: compact ? 23.5 : 29,
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

/// The neutral sibling of [AuthErrorBanner] — for news that isn't a
/// failure of what the person just typed (a link that already confirmed
/// their email, a confirmation link on its way). Ivory hairline, no red.
class AuthNoticeBanner extends StatelessWidget {
  final String message;
  const AuthNoticeBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CsSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.textOnDark.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.textOnDark.withValues(alpha: 0.28),
        width: 0.5,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          color: AppColors.secondaryOnDark,
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

/// "New to Mantelier? / Create an account →" (or the Sign up
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

/// "By creating an account you agree to the Terms and the Privacy Policy",
/// with both linked. App Review 1.2: members agree to the terms before they
/// can post anything; every way of creating an account shows it.
class AuthTermsAgreement extends StatelessWidget {
  const AuthTermsAgreement({
    super.key,
    this.lead = 'By creating an account you agree to the ',
  });

  final String lead;

  static Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final base = CsTypography.metadata.copyWith(
      color: AppColors.secondaryOnDark,
    );
    final link = base.copyWith(
      color: AppColors.textOnDark,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.secondaryOnDark,
    );
    WidgetSpan linkSpan(String label, String url) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: () => _open(url),
        child: Text(label, style: link),
      ),
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: lead),
          linkSpan('Terms', 'https://mantelier.app/terms'),
          const TextSpan(text: ' and the '),
          linkSpan('Privacy Policy', 'https://mantelier.app/privacy'),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The official ivory lockup: the emblem, "Mantelier" and the line
/// "Some evenings only happen once", in one drawing.
const String csWordmarkAssetPath = 'assets/branding/wordmark-ivory.svg';

/// The entrance's brand moment since 2026-11-22: the official lockup on
/// its own (product owner: "you're using the wrong Mantelier Logo, please
/// use the right one"), which already carries the emblem and the tagline.
class AuthBrandLockup extends StatelessWidget {
  const AuthBrandLockup({super.key});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    csWordmarkAssetPath,
    width: 300,
    height: 100,
    fit: BoxFit.contain,
    semanticsLabel: 'Mantelier. Some evenings only happen once',
  );
}

/// The 44pt back chevron at the top left of every step of signing in and
/// setting up (the canvas of 2026-11-22: one quiet control, no pill).
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: IconButton(
      onPressed: onTap,
      tooltip: 'Back',
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18,
        color: AppColors.textOnDark,
      ),
    ),
  );
}

/// "Step 2 of 3" as three short ivory bars, the filled ones solid.
class AuthStepProgress extends StatelessWidget {
  const AuthStepProgress({super.key, required this.step, this.of = 3});

  /// 1-based.
  final int step;
  final int of;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step $step of $of',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= of; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= step
                    ? AppColors.textOnDark
                    : AppColors.textOnDark.withValues(alpha: 0.22),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// One question per screen: a top row (back, progress, a quiet action),
/// a serif title and a line under it, the step's own content, and the
/// primary button at the foot, above the keyboard when it is open. Short
/// screens scroll rather than overflow.
class AuthStepLayout extends StatelessWidget {
  const AuthStepLayout({
    super.key,
    this.leading,
    this.center,
    this.trailing,
    required this.title,
    this.subtitle,
    this.header,
    required this.children,
    this.footer = const [],
  });

  final Widget? leading;
  final Widget? center;
  final Widget? trailing;
  final String title;
  final String? subtitle;

  /// Above the title (the Passport being filled in).
  final Widget? header;
  final List<Widget> children;

  /// Pinned to the bottom: the primary button and anything under it.
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.xl,
            CsSpacing.sm,
            CsSpacing.xl,
            CsSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (leading != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.translate(
                          offset: const Offset(-12, 0),
                          child: leading,
                        ),
                      ),
                    ?center,
                    if (trailing != null)
                      Align(alignment: Alignment.centerRight, child: trailing),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: CsSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (header != null) ...[
                        header!,
                        const SizedBox(height: CsSpacing.xxl),
                      ],
                      Text(
                        title,
                        style: CsTypography.screenTitle.copyWith(
                          color: AppColors.textOnDark,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: CsSpacing.sm),
                        Text(
                          subtitle!,
                          style: CsTypography.body.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: CsSpacing.xl),
                      ...children,
                    ],
                  ),
                ),
              ),
              if (footer.isNotEmpty) ...[
                const SizedBox(height: CsSpacing.base),
                ...footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet text action on the green ground, at least 44pt tall.
class AuthQuietAction extends StatelessWidget {
  const AuthQuietAction({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
    child: Text(
      label,
      style: CsTypography.metadata.copyWith(color: AppColors.secondaryOnDark),
    ),
  );
}
