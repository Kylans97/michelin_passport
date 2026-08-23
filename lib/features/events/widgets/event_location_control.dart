import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/event_location_context.dart';
import '../../../models/event_near_me_location.dart';
import '../../../models/venue_country.dart';
import '../current_location_provider.dart';
import '../location_settings_opener.dart';
import 'event_location_sheet.dart';

/// Events V2 Near Me Phase N2.3 — the closed-control trigger for the
/// Events-only [showEventLocationSheet]. Replaces the shared
/// `CountryFilterControl` (`lib/core/widgets/country_filter_control.dart`)
/// at Events' own header Row call site ONLY — that shared widget itself,
/// and Explore's own use of it, are completely untouched by this phase
/// (task §4). Visual language deliberately mirrors `EventDateControl`
/// (`event_date_control.dart`), its immediate neighbor in that Row, rather
/// than the legacy gold-accented `CountryFilterControl` style: dark green
/// + ivory, restrained, no gold (task §15).
///
/// [locationProvider] flows straight through to the sheet, which is the
/// ONLY place that ever calls it — opening this control, or picking a
/// Country from the sheet, never touches [locationProvider] at all (task
/// §17's "no automatic location access" — location is requested only after
/// an explicit Near-me tap inside the sheet itself).
class EventLocationControl extends StatelessWidget {
  final EventLocationContext location;
  final List<VenueCountry> countries;
  final CurrentLocationProvider locationProvider;
  final LocationSettingsOpener settingsOpener;
  final ValueChanged<EventLocationContext> onChanged;

  const EventLocationControl({
    super.key,
    required this.location,
    required this.countries,
    required this.locationProvider,
    required this.settingsOpener,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final selection = await showEventLocationSheet(
      context,
      current: location,
      countries: countries,
      locationProvider: locationProvider,
      settingsOpener: settingsOpener,
    );
    if (selection == null) return;
    switch (selection) {
      case EventLocationCountrySelection(:final country):
        onChanged(EventLocationContext(country: country));
      case EventLocationNearMeSelection(:final coordinate):
        // Never a manual radius here — EventNearMeLocation's own default
        // (defaultEventNearMeRadiusKm, 100km) applies untouched, exactly
        // the fixed V1 Near-me radius this whole phase is scoped to (task
        // §7).
        onChanged(
          EventLocationContext.nearMe(
            EventNearMeLocation(coordinate: coordinate),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = !location.isAny;
    final label = location.label;
    final icon = location.isNearMe
        ? Icons.my_location_rounded
        : Icons.public_rounded;

    return Semantics(
      button: true,
      label: active ? 'Location, $label selected' : 'Location, all locations',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.brandGreen.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? AppColors.brandGreen.withValues(alpha: 0.4)
                    : AppColors.cardBorder,
                width: active ? 1.0 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active
                      ? AppColors.brandGreen
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: active
                          ? AppColors.brandGreen
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: active
                      ? AppColors.brandGreen
                      : AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
