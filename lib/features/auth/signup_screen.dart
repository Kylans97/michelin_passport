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

/// Sign up — the same entrance experience as [LoginScreen] (Step 4A),
/// just with the additional field a new account needs. Every piece of
/// authentication behavior below (form/validation, the Supabase call,
/// the email-confirmation "check your inbox" success state, error/loading
/// state) is UNCHANGED from before this pass; only what [build] renders is
/// new.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _loading = false;
  String? _error;
  bool _success = false;

  late final AuthRepository _auth = AuthRepository(Supabase.instance.client);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
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
      await _auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );
      // If email confirmation is enabled, tell the user to check their inbox.
      // If it's disabled, AuthGate will navigate automatically.
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
  Widget build(BuildContext context) {
    // See LoginScreen's matching note: a real Scaffold, not a bare
    // ColoredBox — this screen has no enclosing Scaffold of its own above
    // it either (pushed directly via MaterialPageRoute from LoginScreen).
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
              child: _success
                  ? const _CheckInboxBody()
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthBrandHeader(
                            compact: true,
                            tagline: 'Create your account.',
                          ),
                          const SizedBox(height: CsSpacing.xxl),

                          CsTextField(
                            label: 'Name',
                            controller: _nameCtrl,
                            hintText: 'Jane Doe',
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: CsSpacing.lg),
                          CsTextField(
                            label: 'Email',
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
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
                            hintText: 'Minimum 6 characters',
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Minimum 6 characters'
                                : null,
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: CsSpacing.base),
                            AuthErrorBanner(message: _error!),
                          ],

                          const SizedBox(height: CsSpacing.xl),
                          CsPrimaryButton(
                            label: 'Create account',
                            onTap: _submit,
                            loading: _loading,
                          ),
                          const SizedBox(height: CsSpacing.xxl),

                          SecondaryAuthLink(
                            question: 'Already a member?',
                            actionLabel: 'Sign in',
                            onTap: () => Navigator.pop(context),
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

/// Shown once sign-up succeeds and email confirmation is required —
/// unchanged condition from before this pass (see _submit), only the
/// presentation is new.
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
          'We sent you a confirmation link.\nClick it to activate your account.',
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
