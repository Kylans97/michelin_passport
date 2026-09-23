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
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
    });
    try {
      await _auth.signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      // AuthGate's StreamBuilder will navigate automatically on session change.
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
