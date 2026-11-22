import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_fonts.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/auth_repository.dart';
import 'password_sign_in_screen.dart';
import 'widgets/auth_presentation.dart';

/// Sign in, or create an account, with a six digit code sent by email: no
/// password. Two steps on one screen: the address, then the code, in six
/// boxes that iOS can fill from Mail in one tap (one-time-code autofill);
/// the sixth digit sends it, no button. A new address becomes a new
/// account; AuthGate then asks for name, username and home country
/// (ProfileSetupScreen). On success AuthGate's own session listener takes
/// over, so this screen only pops back to the root. A new code can be
/// sent after a minute, Supabase's own wait between two codes to one
/// address.
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
  static const _resendWait = 60;

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  late final AuthRepository _auth = AuthRepository(Supabase.instance.client);

  /// The address a code was sent to; null while asking for the address.
  String? _sentTo;
  bool _loading = false;
  bool _resent = false;
  String? _error;
  int _secondsLeft = 0;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    setState(() => _secondsLeft = _resendWait);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
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
        _codeCtrl.clear();
      });
      _startCountdown();
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

  void _onCodeChanged(String code) {
    setState(() => _error = null);
    if (code.length == 6) _verify();
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

  void _backToAddress() {
    _countdown?.cancel();
    setState(() {
      _sentTo = null;
      _codeCtrl.clear();
      _error = null;
      _resent = false;
      _secondsLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    if (sentTo == null) {
      return AuthStepLayout(
        leading: AuthBackButton(onTap: () => Navigator.maybePop(context)),
        title: 'Your email',
        subtitle:
            'We send you a six digit code. New to Mantelier? The same code '
            'opens your account.',
        children: [
          CsTextField(
            label: 'Email',
            controller: _emailCtrl,
            hintText: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _send(),
          ),
          if (_error != null) ...[
            const SizedBox(height: CsSpacing.base),
            AuthErrorBanner(message: _error!),
          ],
          const SizedBox(height: CsSpacing.xl),
          CsPrimaryButton(label: 'Send code', onTap: _send, loading: _loading),
          const SizedBox(height: CsSpacing.xs),
          Center(
            child: AuthQuietAction(
              label: 'Use my password instead',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const PasswordSignInScreen()),
              ),
            ),
          ),
        ],
      );
    }
    final waiting = _secondsLeft > 0;
    return AuthStepLayout(
      leading: AuthBackButton(onTap: _backToAddress),
      title: 'Check your mail',
      subtitle: 'A six digit code is on its way to $sentTo.',
      children: [
        CodeBoxes(
          controller: _codeCtrl,
          focusNode: _codeFocus,
          enabled: !_loading,
          onChanged: _onCodeChanged,
        ),
        if (_loading) ...[
          const SizedBox(height: CsSpacing.base),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textOnDark,
              ),
            ),
          ),
        ],
        if (_resent) ...[
          const SizedBox(height: CsSpacing.base),
          const AuthNoticeBanner(message: 'A new code is on its way.'),
        ],
        if (_error != null) ...[
          const SizedBox(height: CsSpacing.base),
          AuthErrorBanner(message: _error!),
        ],
        const SizedBox(height: CsSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            waiting
                ? Text(
                    'Send a new code in ${_secondsLeft ~/ 60}:'
                    '${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  )
                : Transform.translate(
                    offset: const Offset(-8, 0),
                    child: AuthQuietAction(
                      label: 'Send a new code',
                      onTap: _loading ? null : () => _send(again: true),
                    ),
                  ),
            Transform.translate(
              offset: const Offset(8, 0),
              child: AuthQuietAction(
                label: 'Other address',
                onTap: _loading ? null : _backToAddress,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Six boxes for a six digit code. One real, invisible text field lies
/// over them, so typing, pasting and iOS's "From Mail" one-time-code
/// suggestion all work as in any field; the boxes only draw its digits,
/// with the next one to fill outlined brighter.
class CodeBoxes extends StatelessWidget {
  const CodeBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final code = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: CsSpacing.sm),
                    Expanded(
                      child: _box(
                        i < code.length ? code[i] : '',
                        active: focusNode.hasFocus && i == code.length,
                        filled: i < code.length,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Semantics(
              label: 'Six digit code',
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                onChanged: onChanged,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                // No decoration: the boxes beneath are the whole look.
                decoration: null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(String digit, {required bool active, required bool filled}) {
    final border = active
        ? Border.all(color: AppColors.textOnDark, width: 1.5)
        : Border.all(
            color: AppColors.textOnDark.withValues(alpha: filled ? 0.55 : 0.22),
          );
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: border,
          color: AppColors.textOnDark.withValues(
            alpha: active ? 0.10 : (filled ? 0.06 : 0),
          ),
        ),
        child: Text(
          digit,
          style: CsFonts.serif(fontSize: 28, color: AppColors.textOnDark),
        ),
      ),
    );
  }
}
