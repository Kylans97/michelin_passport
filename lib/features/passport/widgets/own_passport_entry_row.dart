import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_fonts.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// One of the member's own Passport entries on an estate's or a journey's
/// page: the line, and the same menu a restaurant visit has (Edit, Delete).
/// Tapping the line edits it too.
class OwnPassportEntryRow extends StatelessWidget {
  final String text;
  final String editLabel;
  final String deleteLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const OwnPassportEntryRow({
    super.key,
    required this.text,
    required this.editLabel,
    required this.deleteLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onEdit,
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: CsTypography.body.copyWith(color: AppColors.textPrimary),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: AppColors.taupe,
            size: 20,
          ),
          color: AppColors.card,
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    editLabel,
                    style: CsFonts.sans(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    deleteLabel,
                    style: CsFonts.sans(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The confirmation before an entry and its stamp leave the Passport, in
/// the restaurant visit's own dialog style. True when confirmed.
Future<bool> confirmDeletePassportEntry(
  BuildContext context, {
  required String title,
  required String body,
  required String actionLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(
        title,
        style: CsFonts.serif(color: AppColors.textPrimary, fontSize: 18),
      ),
      content: Text(
        body,
        style: CsFonts.sans(
          color: AppColors.textSecondary,
          fontSize: 14.5,
          height: 1.5,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        CsSpacing.base,
        0,
        CsSpacing.base,
        CsSpacing.sm,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: CsFonts.sans(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            actionLabel,
            style: CsFonts.sans(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}
