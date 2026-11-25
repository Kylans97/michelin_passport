import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/username_rules.dart';
import '../../core/widgets/country_picker_sheet.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../models/venue_country.dart';
import '../claims/venue_claim_intro_screen.dart';
import 'widgets/auth_presentation.dart';
import 'widgets/passport_preview_card.dart';

/// The step between a first sign-in with Apple or an email code and the
/// app: the account exists, but its profile has no name or username yet.
/// AuthGate shows this until the profile has a username.
///
/// Since the sign-up flow of 2026-11-22 (canvas
/// https://claude.ai/artifact/52X3JjNRkYriERiRx2odGe) it asks one question
/// per screen, with the member's Passport filling in above: the name
/// (Apple's, when it shared one), a username made from it (checked, with
/// alternatives that are free), and home, preselected from the iPhone's
/// region. Saving issues the Passport: the next screen shows it with the
/// member number and a welcome stamp, and "Show me around" hands over to
/// the welcome flow.
///
/// [save], [loadCountries], [isUsernameAvailable], [loadMemberNumber] and
/// [deviceCountryCode] are DI seams for tests; [onSaved] tells AuthGate to
/// look again.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.userId,
    this.suggestedName,
    required this.onSaved,
    this.save,
    this.loadCountries,
    this.isUsernameAvailable,
    this.loadMemberNumber,
    this.deviceCountryCode,
    this.today,
  });

  final String userId;
  final String? suggestedName;
  final VoidCallback onSaved;
  final Future<void> Function({
    required String displayName,
    required String username,
    String? homeCountryCode,
  })?
  save;
  final Future<List<VenueCountry>> Function()? loadCountries;
  final Future<bool> Function(String username)? isUsernameAvailable;
  final Future<int?> Function()? loadMemberNumber;

  /// The device region's country code; defaults to the platform locale's.
  final String? deviceCountryCode;
  final DateTime? today;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  /// The Benelux first, then the neighbours, after the device's own.
  static const _shortlist = ['NL', 'BE', 'LU', 'FR', 'DE'];

  final _nameKey = GlobalKey<FormState>();
  final _usernameKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.suggestedName);
  final _usernameCtrl = TextEditingController();
  late final ProfileRepository _profiles = ProfileRepository(
    Supabase.instance.client,
  );

  /// 0 name, 1 username, 2 home, 3 issued.
  int _step = 0;
  bool _loading = false;
  String? _error;

  Timer? _availabilityDebounce;
  bool? _usernameAvailable;
  String? _usernameChecked;
  List<String> _alternatives = const [];

  List<VenueCountry> _countries = const [];
  VenueCountry? _country;
  bool _countryTouched = false;

  int? _memberNumber;
  late final DateTime _issuedOn = widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _availabilityDebounce?.cancel();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  String get _name => _nameCtrl.text.trim();
  String get _username => UsernameRules.normalize(_usernameCtrl.text);

  Future<bool> _available(String candidate) =>
      (widget.isUsernameAvailable ?? _profiles.isUsernameAvailable)(candidate);

  Future<void> _loadCountries() async {
    try {
      final all = await (widget.loadCountries ?? _profiles.getAllCountries)();
      if (!mounted) return;
      final device =
          (widget.deviceCountryCode ??
                  WidgetsBinding.instance.platformDispatcher.locale.countryCode)
              ?.toUpperCase();
      setState(() {
        _countries = all;
        if (!_countryTouched) {
          _country = all.where((c) => c.code == device).firstOrNull;
        }
      });
    } catch (_) {
      // Home is optional; the list then offers only the search.
    }
  }

  List<VenueCountry> get _rows {
    final rows = <VenueCountry>[];
    void add(VenueCountry? c) {
      if (c != null && !rows.any((r) => r.code == c.code)) rows.add(c);
    }

    add(_country);
    for (final code in _shortlist) {
      add(_countries.where((c) => c.code == code).firstOrNull);
    }
    return rows.take(6).toList();
  }

  // Step 1 to 2: the name gives a username, checked at once, and up to
  // three free alternatives.
  Future<void> _toUsername() async {
    if (!_nameKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final suggestions = UsernameRules.suggestionsFor(_name);
    if (_usernameCtrl.text.isEmpty && suggestions.isNotEmpty) {
      _usernameCtrl.text = suggestions.first;
    }
    setState(() {
      _step = 1;
      _error = null;
      _alternatives = const [];
    });
    _checkUsername(_username);
    final free = <String>[];
    for (final s in suggestions.where((s) => s != _username)) {
      try {
        if (await _available(s)) free.add(s);
      } catch (_) {
        // Alternatives are a courtesy; none is fine.
      }
    }
    if (mounted) setState(() => _alternatives = free.take(3).toList());
  }

  void _onUsernameChanged(String raw) {
    _availabilityDebounce?.cancel();
    setState(() => _usernameAvailable = null);
    final normalized = UsernameRules.normalize(raw);
    if (UsernameRules.validate(normalized) != null) return;
    _availabilityDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _checkUsername(normalized),
    );
  }

  Future<void> _checkUsername(String normalized) async {
    if (UsernameRules.validate(normalized) != null) return;
    try {
      final available = await _available(normalized);
      if (mounted && _username == normalized) {
        setState(() {
          _usernameAvailable = available;
          _usernameChecked = normalized;
        });
      }
    } catch (_) {
      // A hint only; the database decides at save time.
    }
  }

  void _toHome() {
    if (!_usernameKey.currentState!.validate()) return;
    if (_usernameAvailable == false && _usernameChecked == _username) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _step = 2;
      _error = null;
    });
  }

  Future<void> _searchCountries() async {
    try {
      final all = _countries.isNotEmpty
          ? _countries
          : await (widget.loadCountries ?? _profiles.getAllCountries)();
      if (!mounted) return;
      final picked = await showCountryPickerSheet(context, countries: all);
      if (picked != null && mounted) {
        setState(() {
          _country = picked;
          _countryTouched = true;
        });
      }
    } catch (_) {
      // Optional field.
    }
  }

  Future<void> _defaultSave({
    required String displayName,
    required String username,
    String? homeCountryCode,
  }) async {
    try {
      await _profiles.updateProfile(
        userId: widget.userId,
        displayName: displayName,
        username: username,
      );
    } on PostgrestException catch (e) {
      // Same translations as AuthRepository.signUp, for the same
      // constraints (unique, format, blocklist).
      if (e.code == '23505') {
        throw const AuthException('That username is already taken.');
      }
      if (e.code == '23514') {
        throw const AuthException(
          'Usernames are 3 to 30 characters: lowercase letters, numbers, '
          '"_" or "." only.',
        );
      }
      if (e.code == 'MT001') {
        throw const AuthException('That username is not allowed.');
      }
      rethrow;
    }
    if (homeCountryCode != null) {
      await _profiles.updateHomeCountryCode(
        userId: widget.userId,
        homeCountryCode: homeCountryCode,
      );
    }
  }

  Future<int?> _defaultMemberNumber() async =>
      (await _profiles.getWelcomeGreeting(userId: widget.userId)).memberNumber;

  Future<void> _issue({required bool withHome}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await (widget.save ?? _defaultSave)(
        displayName: _name,
        username: _username,
        homeCountryCode: withHome ? _country?.code : null,
      );
    } on AuthException catch (e) {
      // Every refusal is about the username: back to that question.
      if (mounted) {
        setState(() {
          _loading = false;
          _step = 1;
          _error = e.message;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
      return;
    }
    if (!withHome) setState(() => _country = null);
    int? number;
    try {
      number = await (widget.loadMemberNumber ?? _defaultMemberNumber)();
    } catch (_) {
      // The Passport shows "NO. —"; the number is on the Passport tab.
    }
    if (!mounted) return;
    setState(() {
      _memberNumber = number;
      _loading = false;
      _step = 3;
    });
  }

  void _back() => setState(() {
    _step -= 1;
    _error = null;
  });

  Widget get _passport => PassportPreviewCard(
    name: _name,
    username: _step >= 1 && _username.isNotEmpty ? _username : null,
    home: _step >= 2 ? _country?.name : null,
  );

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (_step) {
      0 => _nameStep(),
      1 => _usernameStep(),
      2 => _homeStep(),
      _ => _issuedStep(),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && _step < 3 && !_loading) _back();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: KeyedSubtree(key: ValueKey(_step), child: page),
      ),
    );
  }

  Widget _nameStep() => Form(
    key: _nameKey,
    child: AuthStepLayout(
      center: const AuthStepProgress(step: 1),
      trailing: AuthQuietAction(
        label: 'Sign out',
        onTap: () => AuthRepository(Supabase.instance.client).signOut(),
      ),
      header: _passport,
      title: 'What should we call you?',
      subtitle: 'This is the name on your Passport, and what friends see.',
      footer: [CsPrimaryButton(label: 'Continue', onTap: _toUsername)],
      children: [
        CsTextField(
          label: 'Name',
          controller: _nameCtrl,
          hintText: 'Your name',
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: (_) => _toUsername(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
        ),
        if ((widget.suggestedName ?? '').isNotEmpty &&
            _name == widget.suggestedName!.trim()) ...[
          const SizedBox(height: CsSpacing.xs),
          Text(
            'From your Apple Account. Change it if you like.',
            style: CsTypography.metadata.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _usernameStep() {
    final checked = _usernameChecked == _username;
    return Form(
      key: _usernameKey,
      child: AuthStepLayout(
        leading: AuthBackButton(onTap: _back),
        center: const AuthStepProgress(step: 2),
        header: _passport,
        title: 'Pick a username',
        subtitle: 'How friends find you. We made one from your name.',
        footer: [CsPrimaryButton(label: 'Continue', onTap: _toHome)],
        children: [
          CsTextField(
            label: 'Username',
            controller: _usernameCtrl,
            hintText: 'your.name',
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onChanged: _onUsernameChanged,
            onFieldSubmitted: (_) => _toHome(),
            validator: (v) =>
                UsernameRules.validate(UsernameRules.normalize(v ?? '')),
          ),
          if (_usernameAvailable != null && checked) ...[
            const SizedBox(height: CsSpacing.xs),
            Text(
              _usernameAvailable!
                  ? 'Available'
                  : 'That username is already taken',
              style: CsTypography.metadata.copyWith(
                color: _usernameAvailable!
                    ? AppColors.secondaryOnDark
                    : AppColors.error,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: CsSpacing.base),
            AuthErrorBanner(message: _error!),
          ],
          if (_alternatives.isNotEmpty) ...[
            const SizedBox(height: CsSpacing.base),
            Wrap(
              spacing: CsSpacing.sm,
              runSpacing: CsSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Or',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
                for (final alt in _alternatives)
                  OutlinedButton(
                    onPressed: () {
                      _usernameCtrl.text = alt;
                      setState(() {
                        _usernameAvailable = true;
                        _usernameChecked = alt;
                        _error = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textOnDark,
                      minimumSize: const Size(44, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: CsSpacing.base,
                      ),
                      side: BorderSide(
                        color: AppColors.textOnDark.withValues(alpha: 0.3),
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      alt,
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _homeStep() {
    final device =
        widget.deviceCountryCode ??
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return AuthStepLayout(
      leading: AuthBackButton(onTap: _loading ? () {} : _back),
      center: const AuthStepProgress(step: 3),
      trailing: AuthQuietAction(
        label: 'Skip',
        onTap: _loading ? null : () => _issue(withHome: false),
      ),
      title: 'Where is home?',
      subtitle:
          'So we can show what is happening near you first. You can change '
          'it later.',
      footer: [
        if (_error != null) ...[
          AuthErrorBanner(message: _error!),
          const SizedBox(height: CsSpacing.base),
        ],
        CsPrimaryButton(
          label: 'Issue my Passport',
          onTap: () => _issue(withHome: true),
          loading: _loading,
        ),
      ],
      children: [
        const Divider(height: 1, color: AppColors.hairlineOnGreen),
        for (final c in _rows)
          _CountryRow(
            country: c,
            selected: _country?.code == c.code,
            hint: c.code == device?.toUpperCase()
                ? 'From your iPhone settings'
                : null,
            onTap: _loading
                ? null
                : () => setState(() {
                    _country = c;
                    _countryTouched = true;
                  }),
          ),
        InkWell(
          onTap: _loading ? null : _searchCountries,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Search all countries',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _issuedStep() {
    final first = _name.split(RegExp(r'\s+')).first;
    return AuthStepLayout(
      title: 'Your Passport is ready, $first',
      subtitle:
          'Every table, stay and evening you record from now on is kept '
          'here.',
      header: Padding(
        padding: const EdgeInsets.only(top: CsSpacing.base),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.rotate(
                angle: -0.08,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.coverLeather,
                        AppColors.coverLeatherDeep,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            PassportPreviewCard(
              name: _name,
              username: _username,
              home: _country?.name,
              issuedOn: _issuedOn,
              memberNumber: _memberNumber,
            ),
          ],
        ),
      ),
      footer: [
        CsPrimaryButton(label: 'Show me around', onTap: widget.onSaved),
        // One quiet way in for whoever runs a venue (product owner,
        // 2026-11-25). Ignoring it adds no step; coming back from the
        // explainer or the claim leaves them here, on Show me around.
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const VenueClaimIntroScreen(),
            ),
          ),
          child: Text.rich(
            TextSpan(
              text: 'Run a restaurant, hotel or vineyard?\n',
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
              children: [
                TextSpan(
                  text: 'Link your venue',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
      children: const [],
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.selected,
    this.hint,
    this.onTap,
  });

  final VenueCountry country;
  final bool selected;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairlineOnGreen)),
        ),
        child: Row(
          children: [
            if (country.flag.isNotEmpty) ...[
              Text(country.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: CsSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country.name,
                    style: CsTypography.body.copyWith(
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.secondaryOnDark,
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint!,
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: AppColors.textOnDark,
              ),
          ],
        ),
      ),
    ),
  );
}
