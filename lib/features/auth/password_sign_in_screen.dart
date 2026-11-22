import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../core/theme/cs_spacing.dart';
import '../../data/repositories/auth_repository.dart';
import 'forgot_password_screen.dart';
import 'widgets/auth_presentation.dart';

/// Signing in with a password, for members who have one: behind "I have a
/// password" on the entrance since the sign-up flow of 2026-11-22, which
/// made Apple and an email code the way in. The form, its validation, the
/// refused-as-unconfirmed path ("Send a new confirmation link") and
/// "Forgot password?" are the ones LoginScreen carried before, moved here
/// unchanged. On success AuthGate's session listener shows the app; this
/// screen pops back to the root so it isn't left on top.
///
/// [signIn] and [resendConfirmation] are DI seams for tests, defaulting to
/// AuthRepository.
class PasswordSignInScreen extends StatefulWidget {
  const PasswordSignInScreen({super.key, this.signIn, this.resendConfirmation});

  final Future<void> Function({
    required String email,
    required String password,
  })?
  signIn;
  final Future<void> Function(String email)? resendConfirmation;

  @override
  State<PasswordSignInScreen> createState() => _PasswordSignInScreenState();
}

class _PasswordSignInScreenState extends State<PasswordSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  bool _loading = false;
  String? _error;
  // The address a sign-in was just refused for as unconfirmed; non-null
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
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
    return Form(
      key: _formKey,
      child: AuthStepLayout(
        leading: AuthBackButton(onTap: () => Navigator.maybePop(context)),
        title: 'Sign in with your password',
        subtitle: 'For members who made an account with a password.',
        footer: [
          CsPrimaryButton(label: 'Sign in', onTap: _submit, loading: _loading),
        ],
        children: [
          CsTextField(
            label: 'Email',
            controller: _emailCtrl,
            hintText: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passFocus.requestFocus(),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
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
            validator: (v) =>
                (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AuthQuietAction(
              label: 'Forgot password?',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: CsSpacing.sm),
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
              child: AuthQuietAction(
                label: _resending ? 'Sending…' : 'Send a new confirmation link',
                onTap: _resending ? null : _resendConfirmation,
              ),
            ),
        ],
      ),
    );
  }
}
