import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../core/widgets/detail_hero.dart' show HeroIconButton;
import '../../data/repositories/auth_repository.dart';
import 'widgets/auth_presentation.dart';

/// Reached from LoginScreen's "Forgot password?" link. Same push/chrome
/// pattern as SignupScreen (Stack + Positioned back button, not the
/// EditorialBackButton row ChangePasswordScreen/ResetPasswordScreen use —
/// those belong to the profile-settings/AuthGate families respectively;
/// this one is part of the LoginScreen→SignupScreen push chain).
///
/// The confirmation is deliberately identical whether or not [email]
/// belongs to an account — AuthRepository.resetPasswordForEmail() never
/// reveals that either (GoTrue itself doesn't), so this screen can't become
/// a way to probe which addresses are registered.
///
/// [resetPasswordForEmail] is an optional DI seam (same convention as every
/// other auth screen in this app) defaulting to the real
/// AuthRepository-backed call.
class ForgotPasswordScreen extends StatefulWidget {
  final Future<void> Function(String email)? resetPasswordForEmail;

  const ForgotPasswordScreen({super.key, this.resetPasswordForEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
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
      final reset =
          widget.resetPasswordForEmail ??
          AuthRepository(Supabase.instance.client).resetPasswordForEmail;
      await reset(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.xxl,
                CsSpacing.hero,
                CsSpacing.xxl,
                CsSpacing.xxl,
              ),
              child: _sent
                  ? const _CheckInboxBody()
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Reset your password',
                            textAlign: TextAlign.center,
                            style: CsTypography.screenTitle.copyWith(
                              color: AppColors.ivory,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.sm),
                          Text(
                            "Enter your account's email and we'll send you "
                            'a link to set a new password.',
                            textAlign: TextAlign.center,
                            style: CsTypography.body.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.xxl),
                          CsTextField(
                            label: 'Email',
                            controller: _emailCtrl,
                            hintText: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: CsSpacing.base),
                            AuthErrorBanner(message: _error!),
                          ],
                          const SizedBox(height: CsSpacing.xl),
                          CsPrimaryButton(
                            label: 'Send reset link',
                            onTap: _submit,
                            loading: _loading,
                          ),
                        ],
                      ),
                    ),
            ),
            Positioned(
              left: CsSpacing.base,
              top: CsSpacing.sm,
              child: HeroIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same shape as SignupScreen's own post-signup confirmation — a neutral
/// "check your inbox" state, never confirming or denying the email exists.
class _CheckInboxBody extends StatelessWidget {
  const _CheckInboxBody();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: CsSpacing.hero),
    child: Column(
      children: [
        const Icon(
          Icons.mail_outline_rounded,
          color: AppColors.textOnDark,
          size: 40,
        ),
        const SizedBox(height: CsSpacing.xl),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: CsTypography.screenTitle.copyWith(color: AppColors.textOnDark),
        ),
        const SizedBox(height: CsSpacing.sm),
        Text(
          "If that address is registered, we've sent a link to reset "
          'your password.',
          textAlign: TextAlign.center,
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.xxl),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.md,
                vertical: CsSpacing.sm,
              ),
              child: Text(
                'Back to sign in',
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
