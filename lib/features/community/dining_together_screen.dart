import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';

/// Dining Together's concept/preview page (Community Typography + Dining
/// Together Refinement) — pushed from Community's "Discover the concept"
/// action. Editorial-only: explains the future vision, contains ZERO real
/// functionality. No matching, chat, messaging, invitations, group
/// creation, booking, reservation coordination, profile verification,
/// location sharing, moderation, or user discovery exists or is started
/// here — Dining Together's actual implementation remains its own,
/// separate future workstream given its privacy/safety/social complexity.
/// No fake waitlist, no fake matching button, no fake member profiles —
/// just the concept, and a restrained "Coming soon" at the end.
///
/// A pushed screen (`Scaffold` + `EditorialBackButton`), matching every
/// other pushed dark-canvas screen in this app.
class DiningTogetherScreen extends StatelessWidget {
  const DiningTogetherScreen({super.key});

  static const _concepts = [
    'Finding others interested in the same restaurant.',
    'Discovering members around a destination or trip.',
    'Creating small dining groups.',
    'Connecting around special Events or hard-to-book experiences.',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.base,
              CsSpacing.sm,
              CsSpacing.base,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: EditorialBackButton(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.sm,
                CsSpacing.pageHorizontal,
                CsSpacing.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dining Together',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  Text(
                    'Great tables are better shared.',
                    style: CsTypography.placeTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.lg),
                  Text(
                    'Mantelier is built for people who travel for '
                    'restaurants, plan around memorable meals, and are '
                    'always looking for the next remarkable table.',
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.md),
                  Text(
                    'In the future, Dining Together will help members '
                    'discover other people who want to experience the '
                    'same restaurants — making it easier to share '
                    'exceptional dining experiences with people who care '
                    'about them just as much.',
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.lg),
                  Text(
                    'Possible future concepts include:',
                    style: CsTypography.bodyMedium.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  for (final concept in _concepts) ...[
                    _ConceptLine(concept),
                    const SizedBox(height: CsSpacing.xs),
                  ],
                  const SizedBox(height: CsSpacing.lg),
                  Text(
                    'Coming soon',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ConceptLine extends StatelessWidget {
  final String text;
  const _ConceptLine(this.text);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '— ',
        style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
      ),
      Expanded(
        child: Text(
          text,
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
      ),
    ],
  );
}
