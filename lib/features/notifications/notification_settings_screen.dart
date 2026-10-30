import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/push/push_channel.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/push_repository.dart';
import '../../models/notification_preferences.dart';
import 'push_service.dart';

/// Profile → Notification settings: one toggle per kind of push, nothing
/// else. What iOS allows decides what is shown above them:
///
/// - never asked: a single "Turn on notifications" action (the person
///   asked, so this goes straight to iOS's prompt);
/// - turned off in iOS Settings: one quiet line and a way there, instead
///   of toggles that would do nothing;
/// - allowed: just the toggles.
///
/// The toggles only decide push. The in-app Notifications list always
/// shows everything. Non-optimistic, like PrivacySettingsScreen: a switch
/// moves only once its write has succeeded.
class NotificationSettingsScreen extends StatefulWidget {
  final Future<NotificationPreferences> Function()? loadPreferences;
  final Future<void> Function(NotificationPreferences prefs)? savePreferences;
  final Future<PushAuthorization> Function()? authorizationStatus;
  final Future<bool> Function()? requestPermission;
  final Future<void> Function()? openSystemSettings;

  const NotificationSettingsScreen({
    super.key,
    this.loadPreferences,
    this.savePreferences,
    this.authorizationStatus,
    this.requestPermission,
    this.openSystemSettings,
  });

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  NotificationPreferences? _prefs; // null while loading
  PushAuthorization? _status;
  bool _loadError = false;
  bool _saving = false;
  String? _saveError;

  static String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<NotificationPreferences> Function() get _loadPrefs =>
      widget.loadPreferences ??
      () => PushRepository(Supabase.instance.client).getPreferences(_uid);

  Future<void> Function(NotificationPreferences) get _savePrefs =>
      widget.savePreferences ??
      (prefs) => PushRepository(Supabase.instance.client).savePreferences(_uid, prefs);

  Future<PushAuthorization> Function() get _authStatus =>
      widget.authorizationStatus ?? PushService.instance.authorizationStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from iOS Settings: what's allowed may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await _authStatus();
    if (!mounted) return;
    setState(() => _status = status);
    if (status == PushAuthorization.authorized && widget.authorizationStatus == null) {
      await PushService.instance.syncRegistration();
    }
  }

  Future<void> _load() async {
    setState(() {
      _prefs = null;
      _loadError = false;
      _saveError = null;
    });
    try {
      final results = await Future.wait([_loadPrefs(), _authStatus()]);
      if (!mounted) return;
      setState(() {
        _prefs = results[0] as NotificationPreferences;
        _status = results[1] as PushAuthorization;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  Future<void> _save(NotificationPreferences next) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _savePrefs(next);
      if (!mounted) return;
      setState(() {
        _prefs = next;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not update. Please try again.';
      });
    }
  }

  Future<void> _turnOn() async {
    final request = widget.requestPermission ?? PushService.instance.requestFromSettings;
    await request();
    await _refreshStatus();
  }

  Future<void> _openSystemSettings() async {
    final open =
        widget.openSystemSettings ?? () => launchUrl(Uri.parse('app-settings:')).then((_) {});
    await open();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(CsSpacing.base, CsSpacing.sm, CsSpacing.base, 0),
            child: const Align(alignment: Alignment.centerLeft, child: EditorialBackButton()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
              CsSpacing.pageHorizontal,
              CsSpacing.xl,
            ),
            child: Text(
              'Notification settings',
              style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
              child: _loadError
                  ? _LoadError(onRetry: _load)
                  : _prefs == null
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.textOnDark, strokeWidth: 1.5),
                    )
                  : _body(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    final prefs = _prefs!;
    if (_status == PushAuthorization.denied) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications are turned off for this app in iOS Settings.',
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: _openSystemSettings,
            child: Text(
              'Open Settings',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_status == PushAuthorization.notDetermined) ...[
          Text(
            'Get a notification on your phone for the things below.',
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.base),
          CsPrimaryButton(label: 'Turn on notifications', surface: CsSurface.dark, onTap: _turnOn),
          const SizedBox(height: CsSpacing.xxl),
        ],
        _ToggleRow(
          title: 'Friend requests',
          subtitle: 'When someone sends you a friend request.',
          value: prefs.friendRequests,
          busy: _saving,
          onChanged: (v) => _save(prefs.copyWith(friendRequests: v)),
        ),
        const SizedBox(height: CsSpacing.xl),
        _ToggleRow(
          title: 'Events from venues you follow',
          subtitle: 'When a restaurant, hotel or chef you follow announces an event.',
          value: prefs.followedVenueEvents,
          busy: _saving,
          onChanged: (v) => _save(prefs.copyWith(followedVenueEvents: v)),
        ),
        if (_saveError != null) ...[
          const SizedBox(height: CsSpacing.sm),
          Text(_saveError!, style: CsTypography.metadata.copyWith(color: AppColors.error)),
        ],
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: CsTypography.bodyMedium.copyWith(color: AppColors.textOnDark)),
            const SizedBox(height: CsSpacing.xs),
            Text(subtitle, style: CsTypography.metadata.copyWith(color: AppColors.secondaryOnDark)),
          ],
        ),
      ),
      const SizedBox(width: CsSpacing.md),
      Switch(
        value: value,
        onChanged: busy ? null : onChanged,
        activeTrackColor: AppColors.forestGreen,
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.secondaryOnDark, size: 32),
        const SizedBox(height: CsSpacing.base),
        Text(
          'Could not load your notification settings',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.md),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory)),
        ),
      ],
    ),
  );
}
