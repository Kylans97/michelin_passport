import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../models/event_location_context.dart';
import '../../../models/geo_coordinate.dart';
import '../../../models/venue_country.dart';
import '../current_location_provider.dart';
import '../location_settings_opener.dart';

/// Events V2 Near Me Phase N2.3 — what [showEventLocationSheet] resolves
/// to on a genuine selection. `null` (the sheet dismissed without picking
/// anything — swipe-down, tap outside, back gesture) means the caller's
/// committed Location state must stay completely unchanged, exactly
/// [showEventDateSheet]'s own "no-op dismiss" contract
/// (`event_date_control.dart`) — never [EventLocationCountrySelection]
/// with a null [EventLocationCountrySelection.country], which is a
/// distinct, explicit "All locations" choice.
sealed class EventLocationSelection {
  const EventLocationSelection();
}

/// An explicit country choice, or an explicit "All locations" clear when
/// [country] is null — mirrors [CountryFilterControl]'s own existing
/// `ValueChanged<VenueCountry?>` contract exactly (`country_filter_control
/// .dart`), so [EventLocationControl] can construct the same
/// `EventLocationContext(country: ...)` shape Events already used before
/// N2.3.
class EventLocationCountrySelection extends EventLocationSelection {
  final VenueCountry? country;
  const EventLocationCountrySelection(this.country);
}

/// A successfully resolved Near-me coordinate. Deliberately carries only
/// the raw [GeoCoordinate] — never an [EventLocationContext] or
/// `EventNearMeLocation` itself, so this sheet never has to know about
/// Near Me's own fixed default radius; the caller ([EventLocationControl])
/// owns constructing `EventLocationContext.nearMe(...)`, letting that
/// factory's own default apply untouched.
class EventLocationNearMeSelection extends EventLocationSelection {
  final GeoCoordinate coordinate;
  const EventLocationNearMeSelection(this.coordinate);
}

/// Events-specific "where" Location sheet (Phase N2.3) — deliberately a
/// NEW file, not an addition to the shared `CountryFilterControl`/
/// `showCountryPickerSheet` (`lib/core/widgets/`), which stays shared with
/// Explore and completely unaware Near Me exists (see the N2 Step 1
/// audit's own explicit recommendation, reconfirmed still valid by this
/// phase's own task spec). Mental model: one "Location" heading, "Near
/// me" first as a location option — not a separate filter category — then
/// the same Country choices ("All locations" plus a searchable list),
/// mirroring `event_date_control.dart`'s own dedicated-sheet precedent
/// rather than being shoehorned into the country picker's shared sheet.
///
/// Reuse boundary (task §5): [countries] is the exact same
/// `List<VenueCountry>` data `_countriesFuture`/`CountryFilterControl`
/// already used — no second country data source. The search+list
/// presentation below duplicates `_CountryPickerSheetState`'s own trivial
/// substring-filter list (that private class cannot be imported from
/// outside `country_picker_sheet.dart`), but the resulting
/// [EventLocationCountrySelection] produces exactly the same
/// `EventLocationContext(country: ...)` shape the old, unchanged
/// `CountryFilterControl` flow already produced — never a second,
/// competing definition of what a Country selection means.
Future<EventLocationSelection?> showEventLocationSheet(
  BuildContext context, {
  required EventLocationContext current,
  required List<VenueCountry> countries,
  required CurrentLocationProvider locationProvider,
  required LocationSettingsOpener settingsOpener,
}) {
  return showModalBottomSheet<EventLocationSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventLocationSheet(
      current: current,
      countries: countries,
      locationProvider: locationProvider,
      settingsOpener: settingsOpener,
    ),
  );
}

class _EventLocationSheet extends StatefulWidget {
  final EventLocationContext current;
  final List<VenueCountry> countries;
  final CurrentLocationProvider locationProvider;
  final LocationSettingsOpener settingsOpener;

  const _EventLocationSheet({
    required this.current,
    required this.countries,
    required this.locationProvider,
    required this.settingsOpener,
  });

  @override
  State<_EventLocationSheet> createState() => _EventLocationSheetState();
}

class _EventLocationSheetState extends State<_EventLocationSheet> {
  String _query = '';
  bool _resolving = false;
  // Events V2 Near Me Phase N2.4 — replaces N2.3's undifferentiated
  // `bool _failed` with the actual failure taxonomy, so the sheet can
  // render the type-specific copy/action task §4-§7 require. `null` means
  // no failure is currently showing.
  CurrentLocationFailureType? _failureType;
  // A failed *Settings-open* attempt is a distinct, separate concern from
  // [_failureType] (task §18) — it never becomes a new domain failure
  // state; it only adds one small extra line under whichever
  // [_failureType] copy/action is already showing.
  bool _settingsOpenFailed = false;

  // Task §7/§8/§9/§10/§17 — the ONLY call site in this whole sheet that
  // ever touches [locationProvider]; opening the sheet, or tapping any
  // Country row, never reaches this method. Guards against duplicate
  // concurrent requests (§8/§10) with the [_resolving] flag; the caller's
  // own committed Location state is untouched until (and unless) this
  // resolves to success — a failure here only ever updates this sheet's
  // own local [_failureType], never [EventLocationContext], so a failed
  // attempt can never leave a half-active Near-me state (§9). Also the
  // "Try again" action for both `permissionDenied` and `unavailable`
  // (§4/§7/§10) — tapping it re-enters this exact same method, clearing
  // whatever failure state was showing before making one new provider
  // call.
  Future<void> _tapNearMe() async {
    if (_resolving) return;
    setState(() {
      _resolving = true;
      _failureType = null;
      _settingsOpenFailed = false;
    });
    final result = await widget.locationProvider.getCurrentLocation();
    if (!mounted) return;
    switch (result) {
      case CurrentLocationSuccess(:final coordinate):
        Navigator.pop(context, EventLocationNearMeSelection(coordinate));
      case CurrentLocationFailure(:final type):
        // A retry can land on a DIFFERENT failure type than the one that
        // preceded it (task §16's own "state transition" requirement,
        // e.g. permissionDenied -> permissionDeniedForever) — always
        // rendering whatever `type` this specific result carries, never
        // the previous one, is what makes that transition work for free.
        setState(() {
          _resolving = false;
          _failureType = type;
        });
    }
  }

  Future<void> _openAppSettings() async {
    final opened = await widget.settingsOpener.openAppSettings();
    if (!mounted) return;
    setState(() => _settingsOpenFailed = !opened);
  }

  Future<void> _openLocationSettings() async {
    final opened = await widget.settingsOpener.openLocationSettings();
    if (!mounted) return;
    setState(() => _settingsOpenFailed = !opened);
  }

  void _pickCountry(VenueCountry? country) {
    Navigator.pop(context, EventLocationCountrySelection(country));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.countries
        : widget.countries
              .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

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
            // A ListTile's own InkWell paints its splash on the nearest
            // Material ancestor — this Material must sit INSIDE the
            // decorated Container (not outside it), mirroring
            // event_filter_sheet.dart's/country_picker_sheet.dart's own
            // established fix for the same "ink splashes may be
            // invisible" pitfall.
            child: Material(
              type: MaterialType.transparency,
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
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Location',
                          style: AppTypography.editorialHeading,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _NearMeTile(
                      selected: widget.current.isNearMe,
                      resolving: _resolving,
                      onTap: _tapNearMe,
                    ),
                  ),
                  if (_failureType != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
                      child: _NearMeFailure(
                        type: _failureType!,
                        settingsOpenFailed: _settingsOpenFailed,
                        onRetry: _tapNearMe,
                        onOpenAppSettings: _openAppSettings,
                        onOpenLocationSettings: _openLocationSettings,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _LocationTile(
                      label: 'All locations',
                      icon: Icons.public_rounded,
                      selected: widget.current.isAny,
                      onTap: () => _pickCountry(null),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppColors.divider,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: TextField(
                      autofocus: false,
                      onChanged: (v) => setState(() => _query = v),
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search countries…',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final country = filtered[i];
                        final selected =
                            widget.current.country?.code == country.code;
                        return ListTile(
                          onTap: () => _pickCountry(country),
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(
                            country.name,
                            style: GoogleFonts.inter(
                              color: selected
                                  ? AppColors.brandGreen
                                  : AppColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.brandGreen,
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Near-me row — a restrained inline spinner replaces its leading icon
/// while [resolving] (task §8's "preferred: inline spinner/progress
/// indicator on the Near-me row/action"), never a full-screen block. No
/// distance/radius text is ever shown here (§16) — "Near me" is the whole
/// label, exactly like every other closed-control label in this app.
class _NearMeTile extends StatelessWidget {
  final bool selected;
  final bool resolving;
  final VoidCallback onTap;

  const _NearMeTile({
    required this.selected,
    required this.resolving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: resolving ? 'Near me, resolving location' : 'Near me',
    child: ListTile(
      onTap: resolving ? null : onTap,
      leading: resolving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandGreen,
                ),
              ),
            )
          : Icon(
              Icons.my_location_rounded,
              color: selected ? AppColors.brandGreen : AppColors.textSecondary,
            ),
      title: Text(
        'Near me',
        style: GoogleFonts.inter(
          color: selected ? AppColors.brandGreen : AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.brandGreen)
          : null,
    ),
  );
}

/// Events V2 Near Me Phase N2.4 — one restrained, type-specific recovery
/// row per [CurrentLocationFailureType] (task §4-§7). Deliberately no
/// icon, no red, no dialog stacked over the sheet (§12) — a short
/// explanatory line plus exactly one explicit, unambiguous action (§13:
/// "Try again" / "Open Settings" / "Open Location Settings", never "Fix"/
/// "Continue"/"Enable"). [settingsOpenFailed] adds one small extra line
/// when a Settings-open attempt itself didn't work — never a new domain
/// failure state (§18), and never shown for the two message/Try-again
/// types, which have no Settings action to fail in the first place.
class _NearMeFailure extends StatelessWidget {
  final CurrentLocationFailureType type;
  final bool settingsOpenFailed;
  final VoidCallback onRetry;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;

  const _NearMeFailure({
    required this.type,
    required this.settingsOpenFailed,
    required this.onRetry,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
  });

  @override
  Widget build(BuildContext context) {
    final String message;
    final String actionLabel;
    final VoidCallback onAction;
    switch (type) {
      case CurrentLocationFailureType.permissionDenied:
        message = 'Location access is needed to show Events near you.';
        actionLabel = 'Try again';
        onAction = onRetry;
      case CurrentLocationFailureType.permissionDeniedForever:
        message =
            'Location access is turned off for Mantelier. Enable it '
            'in Settings to use Near me.';
        actionLabel = 'Open Settings';
        onAction = onOpenAppSettings;
      case CurrentLocationFailureType.servicesDisabled:
        message =
            'Location Services are turned off. Turn them on to use '
            'Near me.';
        actionLabel = 'Open Location Settings';
        onAction = onOpenLocationSettings;
      case CurrentLocationFailureType.unavailable:
        message = "We couldn't determine your current location.";
        actionLabel = 'Try again';
        onAction = onRetry;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CsSecondaryButton(
              label: actionLabel,
              onTap: onAction,
              surface: CsSurface.light,
              height: 40,
            ),
          ],
        ),
        if (settingsOpenFailed) ...[
          const SizedBox(height: 6),
          Text(
            "Couldn't open Settings.",
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LocationTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(
      icon,
      color: selected ? AppColors.brandGreen : AppColors.textSecondary,
    ),
    title: Text(
      label,
      style: GoogleFonts.inter(
        color: selected ? AppColors.brandGreen : AppColors.textPrimary,
        fontSize: 14.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    trailing: selected
        ? const Icon(Icons.check_rounded, color: AppColors.brandGreen)
        : null,
  );
}
