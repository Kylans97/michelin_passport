import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/utils/mailto_uri.dart';

/// The welcome for a venue's new host: what Mantelier is for them, in
/// four short sections — write in English, events are one-off evenings,
/// why that matters, and the Passport stamp to come. The same words go
/// out in the approval email (notify-venue-claim's `approved` event) and
/// sit on mantelier.app/hosts, so the three stay one message.
///
/// Shown once, the first time a host opens their venue's management page
/// ([VenueHostWelcomeSeen]), when they tap the claim-approved
/// notification, and from "Hosting on Mantelier" on that page at any time.
class VenueHostWelcomeScreen extends StatelessWidget {
  final String venueName;

  /// The closing button. Absent, the button just closes the welcome.
  final String actionLabel;
  final VoidCallback? onAction;

  const VenueHostWelcomeScreen({
    super.key,
    required this.venueName,
    this.actionLabel = 'Continue',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _hero(context),
          const _Section(
            eyebrow: '01 · ONE LANGUAGE',
            title: 'Write for a world of guests',
            body:
                'Mantelier is read by members across Europe and beyond. Please '
                'write your about text, photo captions and event descriptions in '
                'English, so every member can discover what you offer.',
          ),
          const _Section(
            eyebrow: '02 · EVENTS',
            title: 'Evenings that happen once',
            body:
                'Events on Mantelier are not your regular menu. They are the '
                'nights guests plan a journey around:',
            examples: [
              (
                Icons.wine_bar_outlined,
                'A special tasting, from a rare vintage to a single-ingredient menu',
              ),
              (
                Icons.groups_outlined,
                'A collaboration with another kitchen, four hands or a guest chef',
              ),
              (
                Icons.place_outlined,
                'An exceptional setting, away from your usual dining room',
              ),
            ],
          ),
          const _Section(
            eyebrow: '03 · WHY IT MATTERS',
            title: 'Unique for guests, visible for you',
            body:
                'Every event gives the Mantelier community the chance to '
                'experience something they could not find anywhere else. In '
                'return, we bring your evening to members who follow you, plan '
                'trips nearby and travel for moments like this.',
          ),
          const _Section(
            eyebrow: '04 · THE PASSPORT',
            title: 'A stamp of your own',
            body:
                "Members keep every visit in their Passport. Soon you can design "
                "your venue's stamp with us, so each guest leaves with a keepsake "
                'that is unmistakably yours.',
            trailing: _StampPlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.xl,
              CsSpacing.sm,
              CsSpacing.xl,
              CsSpacing.hero,
            ),
            child: Column(
              children: [
                CsPrimaryButton(
                  label: actionLabel,
                  onTap: onAction ?? () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: CsSpacing.md),
                InkWell(
                  onTap: () async {
                    final uri = mailtoUri(
                      'claimedvenues@mantelier.app',
                      subject: 'Venue question — $venueName',
                    );
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(CsSpacing.xs),
                    child: Text(
                      'Questions? claimedvenues@mantelier.app',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      color: AppColors.deepGreen,
      padding: EdgeInsets.fromLTRB(
        CsSpacing.xl,
        MediaQuery.paddingOf(context).top + CsSpacing.sm,
        CsSpacing.xl,
        CsSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.secondaryOnDark,
              ),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: CsSpacing.base),
          Text(
            'FOR VENUE HOSTS',
            style: CsTypography.eyebrow.copyWith(color: AppColors.mutedBrass),
          ),
          const SizedBox(height: CsSpacing.sm),
          Text(
            'Welcome to Mantelier',
            style: CsTypography.screenTitle.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: CsSpacing.md),
          Text(
            '$venueName is now part of a community that travels for exceptional '
            'gastronomy. Here is how to make the most of it.',
            style: CsTypography.body.copyWith(
              color: AppColors.secondaryOnDark,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final List<(IconData, String)> examples;
  final Widget? trailing;

  const _Section({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.examples = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.subtleBorderLight)),
      ),
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.xl,
        CsSpacing.xl,
        CsSpacing.xl,
        CsSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: CsTypography.eyebrow.copyWith(
              color: AppColors.mutedBrassOnLight,
            ),
          ),
          const SizedBox(height: CsSpacing.sm),
          Text(
            title,
            style: CsTypography.sectionTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: CsSpacing.sm),
          Text(
            body,
            style: CsTypography.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          for (final (icon, text) in examples)
            Padding(
              padding: const EdgeInsets.only(top: CsSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppColors.mutedBrassOnLight),
                  const SizedBox(width: CsSpacing.md),
                  Expanded(
                    child: Text(
                      text,
                      style: CsTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(height: CsSpacing.lg),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// The stamp to come: a dashed brass ring with "Coming soon" centred in
/// it, both lines on one axis.
class _StampPlaceholder extends StatelessWidget {
  const _StampPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        painter: const _DashedCirclePainter(AppColors.mutedBrass),
        child: SizedBox(
          width: 104,
          height: 104,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 20,
                color: AppColors.mutedBrassOnLight,
              ),
              const SizedBox(height: CsSpacing.xs),
              Text(
                'COMING SOON',
                textAlign: TextAlign.center,
                style: CsTypography.eyebrow.copyWith(
                  color: AppColors.mutedBrassOnLight,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    const dashes = 36;
    const sweep = 2 * 3.141592653589793 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(1), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Whether this device has shown the host welcome to this user yet —
/// once per user, not per venue, so a host who later takes on a second
/// venue is not walked through it again. Local only: worst case a host
/// sees it once more on a new phone, which needs no table.
class VenueHostWelcomeSeen {
  VenueHostWelcomeSeen._();

  static String _key(String userId) => 'venue_host_welcome_seen_$userId';

  /// True the first time for the signed-in user, and records it; false
  /// after, and false when nobody is signed in.
  static Future<bool> takeFirstShow() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key(userId)) ?? false) return false;
      await prefs.setBool(_key(userId), true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
