import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/password_rules.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/auth_repository.dart';

/// Change password for an already-signed-in user — the ACCOUNT-section
/// counterpart to [DeleteAccountScreen] (same page chrome: deep-green
/// canvas, back button row, SingleChildScrollView, plain error Text), but
/// not a destructive action, so it borrows its form shape (Form + validated
/// CsTextFields, CsPrimaryButton) from SignupScreen instead of Delete
/// account's confirm-dialog + red OutlinedButton.
///
/// [changePassword] is an optional DI seam (same constructor-injection
/// convention as [DeleteAccountScreen]'s own `deleteAccount`/`signOut`)
/// defaulting to the real AuthRepository-backed call — overridden in tests
/// so this screen's validation/error/success behavior can be verified
/// without a live Supabase session.
class ChangePasswordScreen extends StatefulWidget {
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })?
  changePassword;

  const ChangePasswordScreen({super.key, this.changePassword});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _loading = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _newFocus.dispose();
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
      final change =
          widget.changePassword ??
          AuthRepository(Supabase.instance.client).changePassword;
      await change(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) setState(() => _success = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.base,
              CsSpacing.sm,
              CsSpacing.base,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: EditorialBackButton(),
            ),
          ),
          Expanded(
            // _success renders through Center, not the SingleChildScrollView
            // the form uses — a SingleChildScrollView never centers a child
            // shorter than the viewport, it just pins it to the top (see
            // SignupScreen's own _CheckInboxBody fix for the same issue).
            child: _success
                ? Center(
                    child: _SuccessBody(onDone: () => Navigator.pop(context)),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      CsSpacing.lg,
                      CsSpacing.pageHorizontal,
                      CsSpacing.section,
                    ),
                    child: _buildForm(),
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _buildForm() {
    return Form(
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
            'Change password',
            style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.md),
          Text(
            'Confirm your current password, then choose a new one. '
            "You'll stay signed in on this device, but any other devices "
            'signed in to your account will be signed out.',
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.xl),
          CsTextField(
            label: 'Current password',
            controller: _currentCtrl,
            obscureText: true,
            showVisibilityToggle: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _newFocus.requestFocus(),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
          ),
          const SizedBox(height: CsSpacing.lg),
          CsTextField(
            label: 'New password',
            controller: _newCtrl,
            focusNode: _newFocus,
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
            label: 'Change password',
            onTap: _submit,
            loading: _loading,
          ),
          const SizedBox(height: CsSpacing.md),
          Center(
            child: TextButton(
              onPressed: _loading ? null : () => Navigator.maybePop(context),
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
    );
  }
}

/// Shown once the password change succeeds — same "swap the form for a
/// confirmation" shape as SignupScreen's post-signup `_CheckInboxBody`,
/// rather than a SnackBar that would vanish the instant this screen pops.
class _SuccessBody extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessBody({required this.onDone});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
    child: Column(
      // Was CrossAxisAlignment.start, left-aligning everything below — a
      // confirmation screen reads as centered, not as a left-aligned form.
      // MainAxisSize.min so Center (now this widget's parent — see the
      // build() fix above) has something shorter than the full viewport
      // to actually center.
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.textOnDark,
          size: 32,
        ),
        const SizedBox(height: CsSpacing.lg),
        Text(
          'Password changed',
          textAlign: TextAlign.center,
          style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          'Your password has been updated, and any other devices signed '
          "in to your account have been signed out. You're still signed "
          'in here.',
          textAlign: TextAlign.center,
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.xl),
        CsPrimaryButton(label: 'Done', onTap: onDone),
      ],
    ),
  );
}
