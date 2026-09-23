import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/password_rules.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/auth_repository.dart';

/// Shown by AuthGate in place of the whole app — never pushed via
/// Navigator — while `_passwordRecoveryPending` is true (see AuthGate's own
/// doc comment). No "current password" field: the recovery link already
/// proved the person controls the account's inbox, which is why this is a
/// separate, simpler screen from ChangePasswordScreen rather than a shared
/// one with an optional field.
///
/// No back button either — there is no previous screen to return to in
/// this context (a deep link replaced the app's own launch sequence).
/// "Cancel" instead ends the recovery session outright via [cancel] and
/// returns to LoginScreen the same way a completed reset does.
///
/// [completePasswordRecovery]/[cancel] are optional DI seams (same
/// constructor-injection convention as every other auth-adjacent screen in
/// this app) defaulting to the real AuthRepository-backed calls —
/// overridden in tests so this screen's validation/error/success behavior
/// can be verified without a live Supabase session.
class ResetPasswordScreen extends StatefulWidget {
  final Future<void> Function(String newPassword)? completePasswordRecovery;
  final Future<void> Function()? cancel;

  const ResetPasswordScreen({
    super.key,
    this.completePasswordRecovery,
    this.cancel,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _confirmFocus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return; // guards against a duplicate submit mid-flight
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final complete =
          widget.completePasswordRecovery ??
          AuthRepository(Supabase.instance.client).completePasswordRecovery;
      await complete(_newCtrl.text);
      // No further navigation here — the completion signs this session
      // out, and AuthGate's own signedOut handling (see its doc comment)
      // takes it from there, rendering LoginScreen.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final cancel =
        widget.cancel ?? AuthRepository(Supabase.instance.client).signOut;
    await cancel();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.xxl,
          CsSpacing.pageHorizontal,
          CsSpacing.section,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_reset_outlined,
                color: AppColors.textOnDark,
                size: 32,
              ),
              const SizedBox(height: CsSpacing.lg),
              Text(
                'Set a new password',
                style: CsTypography.screenTitle.copyWith(
                  color: AppColors.ivory,
                ),
              ),
              const SizedBox(height: CsSpacing.md),
              Text(
                'Choose a new password for your account. Any other '
                "devices signed in will be signed out, and you'll sign in "
                'here again with the new password.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(height: CsSpacing.xl),
              CsTextField(
                label: 'New password',
                controller: _newCtrl,
                obscureText: true,
                showVisibilityToggle: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                validator: PasswordRules.validate,
              ),
              const SizedBox(height: CsSpacing.lg),
              CsTextField(
                label: 'Confirm new password',
                controller: _confirmCtrl,
                focusNode: _confirmFocus,
                obscureText: true,
                showVisibilityToggle: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    v != _newCtrl.text ? "Passwords don't match" : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: CsSpacing.lg),
                Text(
                  _error!,
                  style: CsTypography.body.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: CsSpacing.xl),
              CsPrimaryButton(
                label: 'Set new password',
                onTap: _submit,
                loading: _loading,
              ),
              const SizedBox(height: CsSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _cancel,
                  child: Text(
                    'Cancel',
                    style: CsTypography.bodyMedium.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
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
