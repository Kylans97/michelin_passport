import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/profile_repository.dart';

/// Profile → Settings → Privacy — PROFILE PRIVACY & DISCOVERABILITY V1.
/// Currently a single setting: **Allow members to find me**, which
/// controls `profiles.is_discoverable` — Find Friends discovery only.
/// Never touches, and this screen never claims to touch, visits/
/// ratings/photos/wishlist/Trips/event visibility, which remain governed
/// entirely by friendship status and their own existing rules (see the
/// migration's own column comment for the full statement this screen's
/// copy is deliberately consistent with).
///
/// [loadDiscoverable]/[setDiscoverable] are optional, deliberately
/// zero-argument DI seams (this session's established constructor-
/// injection convention — mirrors `DeleteAccountScreen`'s own identical
/// pattern). Defaulting to the real `ProfileRepository`-backed calls
/// means `Supabase.instance` is only ever touched from inside those
/// default closures, never from a field initializer — so a test
/// supplying both fakes never has to satisfy a live Supabase session,
/// exactly like `DeleteAccountScreen`'s own `deleteAccount`/`signOut`
/// seams. The real defaults resolve "which user" themselves
/// (`Supabase.instance.client.auth.currentUser`), matching
/// `RestaurantDetailScreen`'s own `_userId` convention — this screen
/// never needs to know the id itself, only the two repository calls.
///
/// Non-optimistic, matching `RestaurantDetailScreen._toggleWishlist`'s
/// own established rationale: the switch's own visible state never
/// moves until the write has actually succeeded, so a failure never
/// needs a rollback step and the UI can never show a persisted state
/// that isn't real.
class PrivacySettingsScreen extends StatefulWidget {
  final Future<bool> Function()? loadDiscoverable;
  final Future<void> Function(bool value)? setDiscoverable;

  const PrivacySettingsScreen({
    super.key,
    this.loadDiscoverable,
    this.setDiscoverable,
  });

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool? _isDiscoverable; // null while the initial load is in flight.
  bool _loadError = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<void> _load() async {
    setState(() {
      _isDiscoverable = null;
      _loadError = false;
      _saveError = null;
    });
    try {
      final load =
          widget.loadDiscoverable ??
          () => ProfileRepository(Supabase.instance.client).getDiscoverable(
            _uid,
          );
      final value = await load();
      if (!mounted) return;
      setState(() => _isDiscoverable = value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  Future<void> _toggle(bool next) async {
    if (_saving || _isDiscoverable == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final set =
          widget.setDiscoverable ??
          (value) => ProfileRepository(
            Supabase.instance.client,
          ).setDiscoverable(userId: _uid, value: value);
      await set(next);
      if (!mounted) return;
      setState(() {
        _isDiscoverable = next;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.base,
              CsSpacing.sm,
              CsSpacing.base,
              0,
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: EditorialBackButton(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
              CsSpacing.pageHorizontal,
              CsSpacing.xl,
            ),
            child: Text(
              'Privacy',
              style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ),
              child: _isDiscoverable == null && !_loadError
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.textOnDark,
                        strokeWidth: 1.5,
                      ),
                    )
                  : _loadError
                  ? _PrivacyLoadError(onRetry: _load)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DiscoverabilityToggleRow(
                          value: _isDiscoverable!,
                          busy: _saving,
                          onChanged: _toggle,
                        ),
                        if (_saveError != null) ...[
                          const SizedBox(height: CsSpacing.sm),
                          Text(
                            _saveError!,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PrivacyLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _PrivacyLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.secondaryOnDark,
          size: 32,
        ),
        const SizedBox(height: CsSpacing.base),
        Text(
          'Could not load your privacy settings',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.md),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory),
          ),
        ),
      ],
    ),
  );
}

/// "Allow members to find me" — the single Find Friends discoverability
/// toggle. Copy is deliberately specific about what turning this OFF
/// does *not* hide, so it's never read as a general "make my account
/// private" switch.
class _DiscoverabilityToggleRow extends StatelessWidget {
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _DiscoverabilityToggleRow({
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
            Text(
              'Allow members to find me',
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.xs),
            Text(
              'Let other Chasing Stars members find your name and '
              'username in Find Friends.',
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your visits, wishlist and trips keep their existing '
              'privacy settings.',
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
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
