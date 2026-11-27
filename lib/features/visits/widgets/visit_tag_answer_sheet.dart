import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_content_sheet.dart';

/// How a tagged friend answers "were you there?".
enum VisitTagAnswer { addToPassport, confirmOnly, notMe }

/// "Dined together" for a restaurant, "stayed together" for a hotel.
String togetherVerb(String? entityType) =>
    entityType == 'hotel' ? 'stayed' : 'dined';

/// Asks the tagged friend how to answer. Null when the sheet is dismissed.
Future<VisitTagAnswer?> showVisitTagAnswerSheet(
  BuildContext context, {
  required String ownerName,
  required String venueName,
  String? entityType,
}) => showModalBottomSheet<VisitTagAnswer>(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => CsContentSheet(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.xl,
      ),
      children: [
        Text(
          'You ${togetherVerb(entityType)} at $venueName',
          style: CsTypography.sectionTitle,
        ),
        const SizedBox(height: 2),
        Text(
          '$ownerName added you to this visit. Once you say yes, their '
          'friends see that you were there together.',
          style: CsTypography.metadata,
        ),
        const SizedBox(height: CsSpacing.sm),
        _Choice(
          title: 'Add to my Passport',
          subtitle: 'The visit and its stamp go into your Passport too.',
          onTap: () =>
              Navigator.pop(sheetContext, VisitTagAnswer.addToPassport),
        ),
        _Choice(
          title: 'Yes, but not in my Passport',
          subtitle: 'You confirm you were there, nothing more.',
          onTap: () => Navigator.pop(sheetContext, VisitTagAnswer.confirmOnly),
        ),
        _Choice(
          title: "That wasn't me",
          subtitle: 'The tag goes away. Nobody else saw it.',
          onTap: () => Navigator.pop(sheetContext, VisitTagAnswer.notMe),
          last: true,
        ),
      ],
    ),
  ),
);

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CsTypography.bodyMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: CsTypography.metadata),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.taupe),
        ],
      ),
    ),
  );
}
