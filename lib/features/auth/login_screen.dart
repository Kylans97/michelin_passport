import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/auth_repository.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'widgets/auth_presentation.dart';

/// The entrance to Mantelier — Step 4A of the visual redesign. Every
/// piece of authentication behavior below (form/validation, the Supabase
/// call, error/loading state, AuthGate's own session listener picking up
/// the new session automatically) is UNCHANGED from before this pass; only
/// what [build] renders is new.
///
/// Password recovery — "Forgot password?" below, pushing
/// [ForgotPasswordScreen] — added later, once Universal Links (iOS
/// Associated Domains + AASA) and the Android App Link scaffold existed to
/// carry a recovery link back into the app; see AuthRepository.
/// resetPasswordForEmail()/AuthGate's own passwordRecovery handling.
///
/// [notice] is what AuthGate passes when an emailed link opened the app but
/// didn't sign anyone in (see auth_link_notice.dart). A sign-in refused
/// with `email_not_confirmed` offers to send a new confirmation link, so an
/// expired one is never a dead end. [signIn] and [resendConfirmation] are
/// optional DI seams (same convention as ChangePasswordScreen's
/// `changePassword`), defaulting to the real AuthRepository calls.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.notice,
    this.signIn,
    this.resendConfirmation,
  });

  final String? notice;
  final Future<void> Function({
    required String email,
    required String password,
  })?
  signIn;
  final Future<void> Function(String email)? resendConfirmation;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  bool _loading = false;
  String? _error;
  // The address a sign-in was just refused for as unconfirmed — non-null
  // shows "Send a new confirmation link" under the error.
  String? _unconfirmedEmail;
  bool _resending = false;
  bool _resent = false;

  late final AuthRepository _auth = AuthRepository(Supabase.instance.client);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return; // guards against a duplicate submit mid-flight
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _unconfirmedEmail = null;
      _resent = false;
    });
    final email = _emailCtrl.text.trim();
    try {
      await (widget.signIn ?? _auth.signIn)(
        email: email,
        password: _passCtrl.text,
      );
      // AuthGate's StreamBuilder will navigate automatically on session change.
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') {
        setState(() {
          _error =
              'Your email isn\'t confirmed yet. Use the link in the email '
              'we sent you, or send a new one.';
          _unconfirmedEmail = email;
        });
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _unconfirmedEmail;
    if (email == null || _resending) return;
    setState(() => _resending = true);
    try {
      await (widget.resendConfirmation ?? _auth.resendSignupConfirmation)(
        email,
      );
      if (mounted) {
        setState(() {
          _resent = true;
          _error = null;
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A real Scaffold (not a bare ColoredBox) — unlike Passport/Explore,
    // LoginScreen is used directly as MaterialApp.home via AuthGate's
    // session-null branch, with no enclosing Scaffold anywhere above it,
    // so it must provide its own Material ancestor for TextField/InkWell.
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.xxl,
            CsSpacing.xxl,
            CsSpacing.xxl,
            CsSpacing.xxl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthBrandHeader(
                  tagline: 'Some evenings only happen once',
                ),
                const SizedBox(height: CsSpacing.section),

                if (widget.notice != null) ...[
                  AuthNoticeBanner(message: widget.notice!),
                  const SizedBox(height: CsSpacing.xl),
                ],

                CsTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passFocus.requestFocus(),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: CsSpacing.lg),
                CsTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  focusNode: _passFocus,
                  obscureText: true,
                  showVisibilityToggle: true,
                  hintText: '••••••••',
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Minimum 6 characters'
                      : null,
                ),
                const SizedBox(height: CsSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: Text(
                      'Forgot password?',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: CsSpacing.base),
                  AuthErrorBanner(message: _error!),
                ],
                if (_resent) ...[
                  const SizedBox(height: CsSpacing.base),
                  AuthNoticeBanner(
                    message:
                        'A new confirmation link is on its way to '
                        '$_unconfirmedEmail. Open it, then sign in here.',
                  ),
                ] else if (_unconfirmedEmail != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _resending ? null : _resendConfirmation,
                      child: Text(
                        _resending
                            ? 'Sending…'
                            : 'Send a new confirmation link',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: CsSpacing.xl),
                CsPrimaryButton(
                  label: 'Sign in',
                  onTap: _submit,
                  loading: _loading,
                ),
                const SizedBox(height: CsSpacing.xxl),

                SecondaryAuthLink(
                  question: 'New to Mantelier?',
                  actionLabel: 'Create an account',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
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
