import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../core/widgets/detail_hero.dart' show HeroIconButton;
import '../../data/repositories/auth_repository.dart';
import 'widgets/auth_presentation.dart';

/// Sign in, or create an account, with a six digit code sent by email: no
/// password. Two steps on one screen: the address, then the code. A new
/// address becomes a new account; AuthGate then asks for a username
/// before the app opens (ProfileSetupScreen). On success AuthGate's own
/// session listener takes over, so this screen only pops itself.
///
/// [sendCode] and [verifyCode] are DI seams for tests, defaulting to
/// AuthRepository.
class EmailCodeScreen extends StatefulWidget {
  const EmailCodeScreen({super.key, this.sendCode, this.verifyCode});

  final Future<void> Function(String email)? sendCode;
  final Future<void> Function({required String email, required String code})?
  verifyCode;

  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  late final AuthRepository _auth = AuthRepository(Supabase.instance.client);

  /// The address a code was sent to; null while asking for the address.
  String? _sentTo;
  bool _loading = false;
  bool _resent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _send({bool again = false}) async {
    final email = again ? _sentTo! : _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _resent = false;
    });
    try {
      await (widget.sendCode ?? _auth.sendEmailCode)(email);
      if (!mounted) return;
      setState(() {
        _sentTo = email;
        _resent = again;
      });
      _codeFocus.requestFocus();
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

  Future<void> _verify() async {
    final email = _sentTo;
    final code = _codeCtrl.text.trim();
    if (email == null || _loading) return;
    if (code.length != 6) {
      setState(() => _error = 'Enter the six digit code from the email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await (widget.verifyCode ?? _auth.verifyEmailCode)(
        email: email,
        code: code,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'That code didn\'t work. Check it, or send a new one; a code '
              'works for a limited time.',
        );
      }
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
    final sentTo = _sentTo;
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.xxl,
                CsSpacing.section,
                CsSpacing.xxl,
                CsSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthBrandHeader(
                    compact: true,
                    tagline: sentTo == null
                        ? 'Continue with email.'
                        : 'Check your email.',
                  ),
                  const SizedBox(height: CsSpacing.xxl),
                  if (sentTo == null) ...[
                    Text(
                      'We\'ll send you a code to sign in. No password '
                      'needed. New here? The same code creates your account.',
                      style: CsTypography.body.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.xl),
                    CsTextField(
                      label: 'Email',
                      controller: _emailCtrl,
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.send,
                      onFieldSubmitted: (_) => _send(),
                    ),
                  ] else ...[
                    Text(
                      'We sent a six digit code to $sentTo.',
                      style: CsTypography.body.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.xl),
                    CsTextField(
                      label: 'Code',
                      controller: _codeCtrl,
                      focusNode: _codeFocus,
                      hintText: '123456',
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _verify(),
                    ),
                    if (_resent) ...[
                      const SizedBox(height: CsSpacing.base),
                      AuthNoticeBanner(message: 'A new code is on its way.'),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: CsSpacing.base),
                    AuthErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: CsSpacing.xl),
                  CsPrimaryButton(
                    label: sentTo == null ? 'Send code' : 'Continue',
                    onTap: sentTo == null ? _send : _verify,
                    loading: _loading,
                  ),
                  if (sentTo != null) ...[
                    const SizedBox(height: CsSpacing.base),
                    TextButton(
                      onPressed: _loading ? null : () => _send(again: true),
                      child: Text(
                        'Send a new code',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _sentTo = null;
                              _codeCtrl.clear();
                              _error = null;
                              _resent = false;
                            }),
                      child: Text(
                        'Use another email address',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: CsSpacing.xl),
                  const AuthTermsAgreement(
                    lead: 'By continuing you agree to the ',
                  ),
                ],
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
