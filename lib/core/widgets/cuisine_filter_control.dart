import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/cuisine_family.dart';
import '../constants/app_colors.dart';

/// Explore's cuisine filter: one compact "All cuisines ▾" trigger beside
/// CountryFilterControl, never a permanent chip row. It opens a sheet of
/// cuisine families to tick (any number); the trigger itself is the
/// active-filter summary ("Japanese", "Japanese +1").
///
/// Dark-surface only (Explore's deep green), styled exactly like
/// CountryFilterControl's [CsSurface.dark] look — no gold.
class CuisineFilterControl extends StatelessWidget {
  final Set<String> selected;
  final List<CuisineFamily> families;
  final ValueChanged<Set<String>> onChanged;

  const CuisineFilterControl({
    super.key,
    required this.selected,
    required this.families,
    required this.onChanged,
  });

  /// The trigger's label: "All cuisines", the one family's name, or the
  /// first chosen family (in [families] order) plus how many more.
  static String labelFor(Set<String> selected, List<CuisineFamily> families) {
    final chosen = [
      for (final f in families)
        if (selected.contains(f.slug)) f.name,
    ];
    if (chosen.isEmpty) return 'All cuisines';
    if (chosen.length == 1) return chosen.first;
    return '${chosen.first} +${chosen.length - 1}';
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CuisinePickerSheet(families: families, initial: selected),
    );
    // Dismissed without "Show restaurants": no change.
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final active = selected.isNotEmpty;
    final color = active ? AppColors.textOnDark : AppColors.secondaryOnDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: families.isEmpty ? null : () => _open(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.subtleBorderDark, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu_rounded, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  labelFor(selected, families),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textOnDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sheet behind [CuisineFilterControl]: every family as a tickable row,
/// "Clear" to untick all, and "Show restaurants" to apply. Pops the chosen
/// slugs; a dismiss pops null (no change). Same light modal as the country
/// picker.
class CuisinePickerSheet extends StatefulWidget {
  final List<CuisineFamily> families;
  final Set<String> initial;

  const CuisinePickerSheet({
    super.key,
    required this.families,
    required this.initial,
  });

  @override
  State<CuisinePickerSheet> createState() => _CuisinePickerSheetState();
}

class _CuisinePickerSheetState extends State<CuisinePickerSheet> {
  late final Set<String> _selected = {...widget.initial};

  void _toggle(String slug) => setState(() {
    if (!_selected.remove(slug)) _selected.add(slug);
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = (mediaQuery.size.height - mediaQuery.padding.top) * 0.9;
    final rowStyle = GoogleFonts.inter(
      color: AppColors.textPrimary,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        // Material, not a decorated Container: the ListTiles paint their
        // ink on the nearest Material, which a coloured box would hide.
        child: Material(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cuisine',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(_selected.clear),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: widget.families.length,
                  itemBuilder: (context, i) {
                    final family = widget.families[i];
                    final on = _selected.contains(family.slug);
                    return ListTile(
                      onTap: () => _toggle(family.slug),
                      title: Text(family.name, style: rowStyle),
                      trailing: Icon(
                        on
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: on
                            ? AppColors.forestGreen
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: AppColors.textOnDark,
                    ),
                    onPressed: () => Navigator.pop(context, {..._selected}),
                    child: const Text('Show restaurants'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
