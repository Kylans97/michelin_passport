import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/username_rules.dart';
import '../../core/widgets/country_picker_sheet.dart';
import '../../core/widgets/cs_picker_field.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../models/venue_country.dart';
import 'widgets/auth_presentation.dart';

/// The step between a first sign-in with Apple or an email code and the
/// app: the account exists, but its profile has no name or username yet
/// (handle_new_user only has them when sign-up passed them, as the
/// password form does). AuthGate shows this until the profile has a
/// username. Apple's name, when it shared one, is offered as the name.
///
/// [save] is a DI seam for tests; [onSaved] tells AuthGate to look again.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.userId,
    this.suggestedName,
    required this.onSaved,
    this.save,
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

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.suggestedName);
  final _usernameCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  late final ProfileRepository _profiles = ProfileRepository(
    Supabase.instance.client,
  );
  VenueCountry? _country;
  bool _loading = false;
  String? _error;
  Timer? _availabilityDebounce;
  bool? _usernameAvailable;
  String? _usernameChecked;

  @override
  void dispose() {
    _availabilityDebounce?.cancel();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String raw) {
    _availabilityDebounce?.cancel();
    setState(() => _usernameAvailable = null);
    final normalized = UsernameRules.normalize(raw);
    if (UsernameRules.validate(normalized) != null) return;
    _availabilityDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final available = await _profiles.isUsernameAvailable(normalized);
        if (mounted &&
            UsernameRules.normalize(_usernameCtrl.text) == normalized) {
          setState(() {
            _usernameAvailable = available;
            _usernameChecked = normalized;
          });
        }
      } catch (_) {
        // A hint only; the database decides at save time.
      }
    });
  }

  Future<void> _pickCountry() async {
    try {
      final all = await _profiles.getAllCountries();
      if (!mounted) return;
      final picked = await showCountryPickerSheet(context, countries: all);
      if (picked != null && mounted) setState(() => _country = picked);
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

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await (widget.save ?? _defaultSave)(
        displayName: _nameCtrl.text.trim(),
        username: UsernameRules.normalize(_usernameCtrl.text),
        homeCountryCode: _country?.code,
      );
      widget.onSaved();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CsSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthBrandHeader(compact: true, tagline: 'One more step.'),
                const SizedBox(height: CsSpacing.base),
                Text(
                  'Choose how friends find you. You can change both later '
                  'in your profile.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
                const SizedBox(height: CsSpacing.xxl),
                CsTextField(
                  label: 'Name',
                  controller: _nameCtrl,
                  hintText: 'Jane Doe',
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _usernameFocus.requestFocus(),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: CsSpacing.lg),
                CsTextField(
                  label: 'Username',
                  controller: _usernameCtrl,
                  focusNode: _usernameFocus,
                  hintText: 'jane.doe',
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  onChanged: _onUsernameChanged,
                  validator: (v) =>
                      UsernameRules.validate(UsernameRules.normalize(v ?? '')),
                ),
                if (_usernameAvailable != null &&
                    _usernameChecked ==
                        UsernameRules.normalize(_usernameCtrl.text)) ...[
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
                const SizedBox(height: CsSpacing.lg),
                CsPickerField(
                  label: 'Country',
                  value: _country?.name,
                  placeholder: 'Optional',
                  leading: _country == null || _country!.flag.isEmpty
                      ? null
                      : Text(
                          _country!.flag,
                          style: const TextStyle(fontSize: 18),
                        ),
                  helper:
                      'Helps us show what is popular near you. You can '
                      'change it any time in your profile.',
                  onTap: _loading ? null : _pickCountry,
                  onClear: _loading
                      ? null
                      : () => setState(() => _country = null),
                ),
                if (_error != null) ...[
                  const SizedBox(height: CsSpacing.base),
                  AuthErrorBanner(message: _error!),
                ],
                const SizedBox(height: CsSpacing.xl),
                const AuthTermsAgreement(),
                const SizedBox(height: CsSpacing.base),
                CsPrimaryButton(
                  label: 'Continue',
                  onTap: _submit,
                  loading: _loading,
                ),
                const SizedBox(height: CsSpacing.lg),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () =>
                            AuthRepository(Supabase.instance.client).signOut(),
                  child: Text(
                    'Sign out',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
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
