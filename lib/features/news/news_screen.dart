import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_coming_soon.dart';

/// News — Navigation & Information Architecture V2's third primary
/// destination. "What's happening?" — stories, interviews, and the world
/// of Mantelier. News V1's real content system (Latest/Mantelier/
/// Interviews/Restaurants/Events/Awards categories, three launch stories)
/// is deliberately NOT built here — this phase is IA migration only; News
/// V1 is its own, later workstream. A bottom-tab body (no own [Scaffold],
/// matching [ExploreScreen]/[PassportScreen]'s established convention —
/// the shared tab shell in `app.dart` already provides one).
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.deepGreen,
    child: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'News',
                  style: CsTypography.screenTitle.copyWith(
                    color: AppColors.ivory,
                  ),
                ),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  'Stories, interviews and the world of Mantelier.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Expanded(
          child: CsComingSoon(
            title: 'Coming soon',
            description:
                'Launch stories, interviews and gastronomic news are on '
                'the way.',
            icon: Icons.article_outlined,
          ),
        ),
      ],
    ),
  );
}
