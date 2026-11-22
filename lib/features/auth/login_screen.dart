import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/auth_repository.dart';
import 'email_code_screen.dart';
import 'password_sign_in_screen.dart';
import 'widgets/auth_presentation.dart';

/// The entrance to Mantelier. Since the sign-up flow of 2026-11-22 (the
/// canvas at https://claude.ai/artifact/52X3JjNRkYriERiRx2odGe, product
/// owner: "bouw deze aanmeldflow in de app voor 1.9.0, met dezelfde
/// keuzes als op het canvas") there is one way in for new and returning
/// members alike: Continue with Apple (iOS only, Apple's own button) or
/// Continue with email (a six digit code, EmailCodeScreen). An account
/// made either way gets its name, username and home country next
/// (ProfileSetupScreen). Members with a password sign in behind the quiet
/// "I have a password" (PasswordSignInScreen); a new account is no longer
/// made with a password, so nobody waits on a confirmation link.
///
/// [notice] is what AuthGate passes when an emailed link opened the app but
/// didn't sign anyone in (see auth_link_notice.dart). [signInWithApple] and
/// [showApple] are DI seams for tests.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.notice,
    this.signInWithApple,
    this.showApple,
  });

  final String? notice;

  /// Returns false when the member cancelled Apple's sheet.
  final Future<bool> Function()? signInWithApple;

  /// Whether to offer Continue with Apple; defaults to iOS only.
  final bool? showApple;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _error;
  bool _appleLoading = false;

  late final AuthRepository _auth = AuthRepository(Supabase.instance.client);

  Future<void> _continueWithApple() async {
    if (_appleLoading) return;
    setState(() {
      _appleLoading = true;
      _error = null;
    });
    try {
      await (widget.signInWithApple ?? _auth.signInWithApple)();
      // AuthGate picks up the new session.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Signing in with Apple didn\'t work. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final showApple = widget.showApple ?? Platform.isIOS;
    // A real Scaffold: LoginScreen is MaterialApp.home via AuthGate's
    // session-null branch, with no Material ancestor above it.
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              AppColors.forestGreen,
              AppColors.deepGreen,
              AppColors.darkGreen,
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.xl,
                      CsSpacing.xxl,
                      CsSpacing.xl,
                      CsSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.notice != null)
                          AuthNoticeBanner(message: widget.notice!),
                        const Spacer(),
                        const AuthBrandLockup(),
                        const Spacer(),
                        const SizedBox(height: CsSpacing.section),
                        if (_error != null) ...[
                          AuthErrorBanner(message: _error!),
                          const SizedBox(height: CsSpacing.base),
                        ],
                        if (showApple) ...[
                          SizedBox(
                            height: 54,
                            child: SignInWithAppleButton(
                              text: 'Continue with Apple',
                              style: SignInWithAppleButtonStyle.white,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(27),
                              ),
                              onPressed: _appleLoading
                                  ? () {}
                                  : _continueWithApple,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.md),
                        ],
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: () => _push(const EmailCodeScreen()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textOnDark,
                              side: BorderSide(
                                color: AppColors.textOnDark.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Continue with email',
                              style: CsTypography.bodyMedium.copyWith(
                                color: AppColors.textOnDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: CsSpacing.base),
                        const AuthTermsAgreement(
                          lead:
                              'New or returning, it is the same step. By '
                              'continuing you agree to the ',
                        ),
                        const SizedBox(height: CsSpacing.xs),
                        Center(
                          child: AuthQuietAction(
                            label: 'I have a password',
                            onTap: () => _push(const PasswordSignInScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
