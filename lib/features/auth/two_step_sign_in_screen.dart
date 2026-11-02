import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/two_step_repository.dart';
import 'widgets/auth_presentation.dart';

/// The code step after the password, for an account with two-step sign-in
/// on. AuthGate shows it while the session is aal1 and the account has a
/// verified authenticator; a right code raises the session to aal2, and
/// AuthGate moves on by itself on the mfaChallengeVerified event.
class TwoStepSignInScreen extends StatefulWidget {
  final TwoStepRepository? repository;

  const TwoStepSignInScreen({super.key, this.repository});

  @override
  State<TwoStepSignInScreen> createState() => _TwoStepSignInScreenState();
}

class _TwoStepSignInScreenState extends State<TwoStepSignInScreen> {
  late final _repo =
      widget.repository ?? TwoStepRepository(Supabase.instance.client.auth);
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (twoStepDigits(_codeCtrl.text).length != 6) {
      setState(() => _error = 'Enter the six-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.verifySignIn(_codeCtrl.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "That code didn't match. Try the newest one.";
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CsSpacing.xxl),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(tagline: 'Two-step sign-in'),
              const SizedBox(height: CsSpacing.section),
              Text(
                'Enter the code from your authenticator app.',
                style: CsTypography.body.copyWith(color: AppColors.textOnDark),
              ),
              const SizedBox(height: CsSpacing.lg),
              CsTextField(
                label: 'Code',
                controller: _codeCtrl,
                hintText: '123 456',
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                inputFormatters: twoStepCodeFormatters,
                onChanged: (v) {
                  if (v.length == 6) _submit();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: CsSpacing.base),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: CsSpacing.xl),
              CsPrimaryButton(
                label: 'Continue',
                onTap: _submit,
                loading: _loading,
              ),
              const SizedBox(height: CsSpacing.xl),
              Text(
                'Lost the phone with your authenticator? Write to '
                'hello@mantelier.app and we will help you back in.',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(height: CsSpacing.base),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading ? null : _repo.signOut,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    'Sign out',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.secondaryOnDark,
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
