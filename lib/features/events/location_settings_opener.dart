/// Events V2 Near Me Phase N2.4 — the seam for platform Settings
/// navigation ("Open Settings" / "Open Location Settings"), deliberately
/// separate from [CurrentLocationProvider] (`current_location_provider
/// .dart`): settings navigation is a UI-edge RECOVERY action for a
/// failure [CurrentLocationProvider] already reported, not part of
/// "resolve my current location once" — the task's own explicit guidance
/// is to keep that interface focused on `getCurrentLocation()` only. A
/// future adapter or test fake can satisfy this without touching
/// [CurrentLocationProvider]'s contract at all, and vice versa.
abstract interface class LocationSettingsOpener {
  /// Opens this app's own OS Settings page — the only recovery action for
  /// [CurrentLocationFailureType.permissionDeniedForever]
  /// (`current_location_provider.dart`), where no further in-app
  /// permission prompt can ever be shown again. Returns whether the
  /// settings page could be opened; never throws for an expected platform
  /// failure (a `false` result is how that's represented).
  Future<bool> openAppSettings();

  /// Opens the device's Location Services settings page — distinct from
  /// [openAppSettings]: this is for
  /// [CurrentLocationFailureType.servicesDisabled], a device-wide toggle
  /// with no per-app permission dialog involved at all.
  Future<bool> openLocationSettings();
}
