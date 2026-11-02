import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// A form field that opens a picker instead of taking typing: an eyebrow
/// label, an ivory rounded box with the value (or [placeholder]), a cross
/// to clear it once set, and an optional line of help below. The same
/// shape as Edit profile's Country field and [CsTextField], for use on the
/// green sign-up and profile sheets.
class CsPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final Widget? leading;
  final String? helper;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const CsPickerField({
    super.key,
    required this.label,
    required this.value,
    this.placeholder = 'Not set',
    this.leading,
    this.helper,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.sm),
        Material(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.base,
                vertical: 16,
              ),
              child: Row(
                children: [
                  if (hasValue && leading != null) ...[
                    leading!,
                    const SizedBox(width: CsSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      style: CsTypography.body.copyWith(
                        color: hasValue ? AppColors.charcoal : AppColors.taupe,
                      ),
                    ),
                  ),
                  if (hasValue && onClear != null)
                    Semantics(
                      button: true,
                      label: 'Clear $label',
                      child: InkWell(
                        onTap: onClear,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.taupe,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.taupe,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: CsSpacing.xs),
          Text(
            helper!,
            style: CsTypography.metadata.copyWith(color: AppColors.secondaryOnDark),
          ),
        ],
      ],
    );
  }
}
