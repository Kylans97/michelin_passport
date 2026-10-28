import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';

/// Sets an event's location with a map pin: tap where it is held, then
/// "Use this location". Pops the chosen point, or nothing on back. Same
/// OpenStreetMap tiles as the visited map.
class PickEventLocationScreen extends StatefulWidget {
  final LatLng? initial;
  const PickEventLocationScreen({super.key, this.initial});

  @override
  State<PickEventLocationScreen> createState() => _PickEventLocationScreenState();
}

class _PickEventLocationScreenState extends State<PickEventLocationScreen> {
  // Europe, when there's nothing to start from.
  static const _fallbackCenter = LatLng(50.5, 8.0);
  late LatLng? _pin = widget.initial;

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
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.initial ?? _fallbackCenter,
                initialZoom: widget.initial == null ? 4 : 15,
                onTap: (_, point) => setState(() => _pin = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
