import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../models/event.dart';
import '../../../models/event_discovery_filters.dart';
import '../../../models/event_tag.dart';

/// Events V2 Discovery Taxonomy Phase C Correction Pass §10 — the
/// advanced Filters sheet now covers ONLY Social/Type/Theme. Location
/// (country) and Date were promoted to their own first-class, always-
/// visible, immediately-committing controls on the Events screen
/// (`event_location_context.dart`'s own `CountryFilterControl` reuse,
/// `event_date_control.dart`) — this sheet no longer knows about either
/// dimension at all, not even to read them. Reason: Location/Date are
/// primary discovery context ("where"/"when" a user wants to browse),
/// materially different from Social/Type/Theme's role as deeper
/// refinement on top of an already-chosen where/when — burying all five
/// together inside one Apply-gated sheet is what produced the physical-
/// device confusion this correction pass fixes (see
/// EVENTS_DISCOVERY_TAXONOMY_PHASE_C_PRE_FINAL.md's "Physical Device
/// Correction Pass" section for the full root-cause writeup).
class EventFilterSheetResult {
  final EventDiscoveryFilters filters;
  const EventFilterSheetResult({required this.filters});
}

/// Opens the Filters sheet with [committed] as its starting draft state.
/// Returns `null` when dismissed without tapping Apply (swipe-down, tap
/// outside, back gesture) — the caller's committed filter state must stay
/// completely unchanged in that case (Phase C §13's "sheet-local draft,
/// Apply commits" model — retained for Social/Type/Theme, since these
/// remain genuine refinement a user composes deliberately before
/// committing, unlike Location/Date's own "commits immediately"
/// contract). [signedIn] hides the Social group entirely for a
/// signed-out viewer (§22) rather than presenting selectable options that
/// would deterministically resolve to zero results.
Future<EventFilterSheetResult?> showEventFilterSheet(
  BuildContext context, {
  required EventDiscoveryFilters committed,
  required List<EventTag> tags,
  required bool signedIn,
}) {
  return showModalBottomSheet<EventFilterSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _EventFilterSheet(committed: committed, tags: tags, signedIn: signedIn),
  );
}

const _socialOptions = [
  (EventSocialFilter.friendsGoing, 'Friends Going'),
  (EventSocialFilter.friendsInterested, 'Friends Interested'),
  (EventSocialFilter.following, 'Following'),
];

class _EventFilterSheet extends StatefulWidget {
  final EventDiscoveryFilters committed;
  final List<EventTag> tags;
  final bool signedIn;

  const _EventFilterSheet({
    required this.committed,
    required this.tags,
    required this.signedIn,
  });

  @override
  State<_EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<_EventFilterSheet> {
  late Set<EventSocialFilter> _social = Set.of(widget.committed.social);
  late Set<EventType> _types = Set.of(widget.committed.eventTypes);
  late Set<String> _tagSlugs = Set.of(widget.committed.tagSlugs);

  void _apply() {
    // Location (countryCodes) and Date (dateRange) are never read from or
    // written by this sheet's draft — EventsScreen's own
    // _effectiveFilters getter re-attaches its independently-held
    // Location/Date state to whatever this sheet returns, so those two
    // dimensions are simply absent here, never zeroed-out or
    // accidentally overwritten.
    final filters = EventDiscoveryFilters(
      social: _social,
      eventTypes: _types,
      tagSlugs: _tagSlugs,
    );
    Navigator.pop(context, EventFilterSheetResult(filters: filters));
  }

  // Clears the DRAFT only — the sheet stays open so a user who cleared by
  // mistake can still Cancel out with the original committed filters
  // intact, and one who meant it can review the now-empty sheet before
  // Apply. Search/Location/Date all live entirely outside this sheet's
  // state, so Clear All has no way to touch any of them even by accident.
  void _clearAll() {
    setState(() {
      _social = {};
      _types = {};
      _tagSlugs = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.top - bottomInset;
    final maxHeight = availableHeight * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
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
                  padding: const EdgeInsets.fromLTRB(24, 18, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Filters',
                            style: AppTypography.editorialHeading,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearAll,
                        child: Text(
                          'Clear all',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.signedIn) ...[
                          _FilterGroup(
                            title: 'SOCIAL',
                            child: _OptionWrap(
                              options: [
                                for (final (value, label) in _socialOptions)
                                  _Option(
                                    label: label,
                                    selected: _social.contains(value),
                                    onTap: () => setState(
                                      () => _social.contains(value)
                                          ? _social.remove(value)
                                          : _social.add(value),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const _GroupDivider(),
                        ],
                        _FilterGroup(
                          title: 'TYPE',
                          child: _OptionWrap(
                            options: [
                              for (final type
                                  in EventDiscoveryFilters.selectableEventTypes)
                                _Option(
                                  label: type.label,
                                  selected: _types.contains(type),
                                  onTap: () => setState(
                                    () => _types.contains(type)
                                        ? _types.remove(type)
                                        : _types.add(type),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const _GroupDivider(),
                        _FilterGroup(
                          title: 'THEMES',
                          child: widget.tags.isEmpty
                              ? _EmptyGroupNote(
                                  text: 'Themes are unavailable right now.',
                                )
                              : _OptionWrap(
                                  options: [
                                    for (final tag in widget.tags)
                                      _Option(
                                        label: tag.name,
                                        selected: _tagSlugs.contains(tag.slug),
                                        onTap: () => setState(
                                          () => _tagSlugs.contains(tag.slug)
                                              ? _tagSlugs.remove(tag.slug)
                                              : _tagSlugs.add(tag.slug),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: CsPrimaryButton(
                    label: 'Apply',
                    onTap: _apply,
                    surface: CsSurface.light,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final Widget child;
  const _FilterGroup({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.sectionHeading),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Divider(height: 1, thickness: 0.5, color: AppColors.divider),
  );
}

class _EmptyGroupNote extends StatelessWidget {
  final String text;
  const _EmptyGroupNote({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
  );
}

class _OptionWrap extends StatelessWidget {
  final List<_Option> options;
  const _OptionWrap({required this.options});

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: options);
}

/// One restrained, multi-select toggle — thin border, brand green when
/// selected, no fill, no gold, no chip-cloud saturation. Reused for every
/// Social/Type/Theme option so the sheet reads as one coherent control
/// language.
class _Option extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.brandGreen.withValues(alpha: 0.5)
                : AppColors.cardBorder,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.brandGreen,
              ),
              const SizedBox(width: 4),
            ],
            // Flexible + ellipsis (not a bare Text): at large text scale a
            // long label combined with Wrap's own available-width
            // constraint can otherwise overflow the pill by a few pixels
            // — caught by this widget's own 1.6x-text-scale test.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: selected
                      ? AppColors.brandGreen
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
