import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/maps/maptiler_config.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';

/// Sets an event's location with a map pin: tap where it is held, then
/// "Use this location". Pops the chosen point, or nothing on back. Street
/// tiles come from MapTiler (see [MapTilerConfig]); with no key configured
/// the screen says the map is unavailable rather than falling back to
/// OpenStreetMap's own tile servers.
class PickEventLocationScreen extends StatefulWidget {
  final LatLng? initial;

  /// Overrides [MapTilerConfig.key] — for tests, which load no `.env`.
  final String? mapTilerKey;

  const PickEventLocationScreen({super.key, this.initial, this.mapTilerKey});

  @override
  State<PickEventLocationScreen> createState() => _PickEventLocationScreenState();
}

class _PickEventLocationScreenState extends State<PickEventLocationScreen> {
  // Europe, when there's nothing to start from.
  static const _fallbackCenter = LatLng(50.5, 8.0);
  late LatLng? _pin = widget.initial;
  late final String? _tileKey = widget.mapTilerKey ?? MapTilerConfig.key;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Set the location',
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: Column(
        children: [
          Expanded(
            child: _tileKey == null
                ? const _MapUnavailable()
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: widget.initial ?? _fallbackCenter,
                      initialZoom: widget.initial == null ? 4 : 15,
                      onTap: (_, point) => setState(() => _pin = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: MapTilerConfig.urlTemplate(_tileKey),
                        retinaMode: RetinaMode.isHighDensity(context),
                        userAgentPackageName: 'app.mantelier',
                      ),
                      if (_pin != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pin!,
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.forestGreen,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      const _MapAttribution(),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(CsSpacing.pageHorizontal),
              child: Column(
                children: [
                  Text(
                    _pin == null
                        ? 'Tap the map where the event is held.'
                        : 'Tap again to move the pin.',
                    style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: CsPrimaryButton(
                      label: 'Use this location',
                      surface: CsSurface.light,
                      onTap: _pin == null ? null : () => Navigator.of(context).pop(_pin),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// MapTiler's required credit, kept visible in the map's corner. Each name
/// opens its copyright page.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    final style = CsTypography.metadata.copyWith(
      color: AppColors.taupe,
      fontSize: 11,
    );
    Widget link(String label, Uri uri) => GestureDetector(
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Text(label, style: style),
    );
    return Align(
      alignment: Alignment.bottomRight,
      child: Semantics(
        label: MapTilerConfig.attribution,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: AppColors.warmWhite.withValues(alpha: 0.85),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                link('© MapTiler', MapTilerConfig.maptilerCopyright),
                Text(' ', style: style),
                link(
                  '© OpenStreetMap contributors',
                  MapTilerConfig.openStreetMapCopyright,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the map when no MapTiler key is configured.
class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(CsSpacing.pageHorizontal),
      child: Text(
        "The map can't be shown right now.",
        textAlign: TextAlign.center,
        style: CsTypography.body.copyWith(color: AppColors.taupe),
      ),
    ),
  );
}
