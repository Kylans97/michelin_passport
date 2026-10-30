import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_content_sheet.dart';
import '../../core/widgets/cs_primary_button.dart';

/// Why the app is offering notifications right now — the action the
/// person just took, which is what makes the offer make sense.
sealed class PushPromptReason {
  const PushPromptReason();
}

class FollowedVenuePrompt extends PushPromptReason {
  final String venueName;
  const FollowedVenuePrompt(this.venueName);
}

class FriendsPrompt extends PushPromptReason {
  const FriendsPrompt();
}

/// The app's own ask, shown before iOS's one-time prompt so that prompt
/// only ever appears to someone who has already said yes. Returns true
/// for "Turn on", false for "Not now", null if dismissed.
Future<bool?> showPushPromptSheet(BuildContext context, PushPromptReason reason) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PushPromptSheet(reason: reason),
  );
}

class PushPromptSheet extends StatelessWidget {
  final PushPromptReason reason;
  const PushPromptSheet({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (reason) {
      FollowedVenuePrompt(:final venueName) => (
        'Hear about new events',
        'We can let you know when $venueName announces an event.',
      ),
      FriendsPrompt() => (
        'Know when friends reach out',
        'We can let you know when someone sends you a friend request.',
      ),
    };

    return CsContentSheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.xl,
          CsSpacing.xl,
          CsSpacing.xl,
          CsSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: CsTypography.sectionTitle.copyWith(color: AppColors.forestGreen)),
            const SizedBox(height: CsSpacing.sm),
            Text(body, style: CsTypography.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: CsSpacing.xs),
            Text(
              'You can change this any time in Profile → Notification settings.',
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.xl),
            CsPrimaryButton(
              label: 'Turn on notifications',
              surface: CsSurface.light,
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: CsSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Not now',
                  style: CsTypography.bodyMedium.copyWith(color: AppColors.forestGreen),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
