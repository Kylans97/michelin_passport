import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// The redesigned text input — a visible eyebrow-weight label above a
/// warm-neutral field (never a placeholder standing in as the only label),
/// dual-surface aware per [CsSurface] like every other Step 1 component.
/// ~52-56px visual field height via content padding rather than a fixed
/// [SizedBox], so a validation error can grow the field downward instead
/// of being clipped. No gold border ever — the focused state uses
/// [AppColors.mutedBrass] as a single restrained hairline accent, mirroring
/// [CsSearchField]'s own focused-border treatment exactly.
///
/// First built for Login/Sign up (Step 4A) — kept general enough (label,
/// hint, obscure/visibility toggle, validator, autofill, keyboard actions)
/// for other forms (Edit Profile, account settings) to reuse later without
/// changes.
class CsTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;

  /// Only meaningful when [obscureText] is true — shows a restrained
  /// show/hide icon rather than leaving the field permanently obscured.
  final bool showVisibilityToggle;

  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final CsSurface surface;

  const CsTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.surface = CsSurface.dark,
  });

  @override
  State<CsTextField> createState() => _CsTextFieldState();
}

class _CsTextFieldState extends State<CsTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final onDark = widget.surface == CsSurface.dark;
    final background = onDark ? AppColors.ivory : AppColors.warmWhite;
    final labelColor = onDark ? AppColors.secondaryOnDark : AppColors.taupe;
    final hint = AppColors.taupe;
    final border = onDark ? Colors.transparent : AppColors.subtleBorderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: CsTypography.eyebrow.copyWith(color: labelColor),
        ),
        const SizedBox(height: CsSpacing.sm),
        // The visible label above already identifies this field; Semantics
        // links it explicitly for screen readers too, rather than relying
        // on hintText alone (which disappears once text is entered and was
        // never associated with the field semantically to begin with).
        Semantics(
          textField: true,
          label: widget.label,
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            validator: widget.validator,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            focusNode: widget.focusNode,
            style: CsTypography.body.copyWith(color: AppColors.charcoal),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: CsTypography.body.copyWith(color: hint),
              filled: true,
              fillColor: background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.base,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.mutedBrass,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.error, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.5,
                ),
              ),
              errorStyle: CsTypography.metadata.copyWith(
                color: AppColors.error,
                fontSize: 12,
              ),
              errorMaxLines: 2,
              suffixIcon: widget.obscureText && widget.showVisibilityToggle
                  ? Semantics(
                      button: true,
                      label: _obscured ? 'Show password' : 'Hide password',
                      child: IconButton(
                        icon: Icon(
                          _obscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: hint,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscured = !_obscured),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
