import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_content_sheet.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/app_release_repository.dart';

const appStoreUrl = 'https://apps.apple.com/app/id6806217056';

/// Asks members on an old version to update (20261101680000).
///
/// Below `minimum_version`: a screen with only "Update", over everything,
/// the entrance included, until the app is updated. Below `latest_version`:
/// once per new version, a quiet sheet with Update and Later. Checked at
/// launch and when the app comes back to the front, at most once an hour.
/// A failed read, an unknown version or a missing row asks nothing, so
/// this can never lock anyone out by accident.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
    this.loadRelease,
    this.currentVersion,
    this.openStore,
  });

  final Widget child;

  /// Test seams.
  final Future<AppRelease?> Function()? loadRelease;
  final Future<String> Function()? currentVersion;
  final Future<void> Function()? openStore;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  static const _promptedKey = 'update_prompted_for';

  bool _blocked = false;
  bool _sheetOpen = false;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final now = DateTime.now();
    final last = _lastCheck;
    // A blocked app checks on every return, so updating lets it in.
    if (!_blocked && last != null && now.difference(last).inMinutes < 60) {
      return;
    }
    _lastCheck = now;

    final AppRelease? release;
    final String current;
    try {
      release =
          await (widget.loadRelease ??
              () => AppReleaseRepository(Supabase.instance.client).load())();
      current =
          await (widget.currentVersion ??
              () async => (await PackageInfo.fromPlatform()).version)();
    } catch (_) {
      return;
    }
    if (!mounted || release == null) return;

    final blocked = compareVersions(current, release.minimumVersion) < 0;
    if (blocked != _blocked) setState(() => _blocked = blocked);
    if (blocked) return;

    if (compareVersions(current, release.latestVersion) < 0) {
      await _offer(release.latestVersion);
    }
  }

  Future<void> _offer(String latest) async {
    if (_sheetOpen) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_promptedKey) == latest) return;
      await prefs.setString(_promptedKey, latest);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _UpdateSheet(
        version: latest,
        onUpdate: () {
          Navigator.pop(sheetContext);
          _openStore();
        },
        onLater: () => Navigator.pop(sheetContext),
      ),
    );
    _sheetOpen = false;
  }

  Future<void> _openStore() async {
    try {
      await (widget.openStore ??
          () => launchUrl(
            Uri.parse(appStoreUrl),
            mode: LaunchMode.externalApplication,
          ))();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) return _UpdateRequiredScreen(onUpdate: _openStore);
    return widget.child;
  }
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({
    required this.version,
    required this.onUpdate,
    required this.onLater,
  });

  final String version;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) => CsContentSheet(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('A new version of Mantelier', style: CsTypography.sectionTitle),
          const SizedBox(height: CsSpacing.xs),
          Text(
            'Version $version is in the App Store, with what is new since '
            'yours.',
            style: CsTypography.metadata,
          ),
          const SizedBox(height: CsSpacing.lg),
          CsPrimaryButton(label: 'Update', onTap: onUpdate),
          const SizedBox(height: CsSpacing.xs),
          TextButton(
            onPressed: onLater,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.taupe,
              minimumSize: const Size(44, 44),
            ),
            child: const Text('Later'),
          ),
        ],
      ),
    ),
  );
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen({required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CsSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              'Time for an update',
              style: CsTypography.screenTitle.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.sm),
            Text(
              'This version of Mantelier no longer works. Update in the App '
              'Store and everything is where you left it.',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const Spacer(),
            CsPrimaryButton(
              label: 'Update',
              surface: CsSurface.dark,
              onTap: onUpdate,
            ),
          ],
        ),
      ),
    ),
  );
}
