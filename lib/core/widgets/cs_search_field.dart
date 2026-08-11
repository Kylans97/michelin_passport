import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// The redesigned search field — height 52 / radius 16 per the brief,
/// dual-surface aware per [CsSurface]: a warm ivory surface on a green
/// environment, or a soft neutral/subtle-border surface on a light one.
/// Icons stay simple/functional (a plain search glyph), matching the
/// brief's restrained-iconography direction.
///
/// A [StatefulWidget] only so the clear (×) button can appear/disappear as
/// [controller]'s text changes — everything else about this widget is as
/// stateless as before. First wired into a real screen by Explore (Step 3);
/// no other screen used this widget prior to that, so this clear-button
/// addition doesn't change how anything already looks.
class CsSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final CsSurface surface;
  final bool autofocus;

  const CsSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search…',
    this.onChanged,
    this.surface = CsSurface.dark,
    this.autofocus = false,
  });

  @override
  State<CsSearchField> createState() => _CsSearchFieldState();
}

class _CsSearchFieldState extends State<CsSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onDark = widget.surface == CsSurface.dark;
    final background = onDark ? AppColors.ivory : AppColors.warmWhite;
    final foreground = AppColors.charcoal;
    final hint = AppColors.taupe;
    final border = onDark ? Colors.transparent : AppColors.subtleBorderLight;
    final hasText = _controller.text.isNotEmpty;

    return SizedBox(
      height: 52,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        autofocus: widget.autofocus,
        style: CsTypography.body.copyWith(color: foreground),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: CsTypography.body.copyWith(color: hint),
          prefixIcon: Icon(Icons.search_rounded, color: hint, size: 20),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: hint, size: 18),
                  tooltip: 'Clear',
                  onPressed: _clear,
                )
              : null,
          filled: true,
          fillColor: background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
        ),
      ),
    );
  }
}
