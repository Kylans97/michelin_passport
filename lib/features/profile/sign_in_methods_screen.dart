import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/auth_repository.dart';

/// "Ways to sign in", in the ACCOUNT section of Profile (2026-11-22): the
/// member's email address, with which a code always works, and Sign in
/// with Apple, linked or not. Linking adds Apple to this account, so a
/// member who already has one can use Apple too, also when Apple hides
/// their email; without it, a hidden-email Apple sign-in makes a second,
/// empty account. Unlinking is not offered.
///
/// [hasAppleLinked], [linkApple], [email] and [showApple] are DI seams for
/// tests, defaulting to AuthRepository and the current session.
class SignInMethodsScreen extends StatefulWidget {
  const SignInMethodsScreen({
    super.key,
    this.hasAppleLinked,
    this.linkApple,
    this.email,
    this.showApple,
  });

  final Future<bool> Function()? hasAppleLinked;

  /// Returns false when the member cancelled Apple's sheet.
  final Future<bool> Function()? linkApple;
  final String? email;

  /// Whether Apple can be linked here; defaults to iOS only.
  final bool? showApple;

  @override
  State<SignInMethodsScreen> createState() => _SignInMethodsScreenState();
}

class _SignInMethodsScreenState extends State<SignInMethodsScreen> {
  late final AuthRepository _auth = AuthRepository(Supabase.instance.client);
  bool? _appleLinked;
  bool _linking = false;
  String? _error;
  bool _justLinked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final linked = await (widget.hasAppleLinked ?? _auth.hasAppleLinked)();
      if (mounted) setState(() => _appleLinked = linked);
    } catch (_) {
      if (mounted) setState(() => _appleLinked = false);
    }
  }

  Future<void> _link() async {
    if (_linking) return;
    setState(() {
      _linking = true;
      _error = null;
    });
    try {
      final linked = await (widget.linkApple ?? _auth.linkApple)();
      if (linked && mounted) {
        setState(() {
          _appleLinked = true;
          _justLinked = true;
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Linking Apple didn\'t work. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        widget.email ?? Supabase.instance.client.auth.currentUser?.email;
    final showApple = widget.showApple ?? Platform.isIOS;
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.lg,
                  CsSpacing.pageHorizontal,
                  CsSpacing.section,
                ),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.key_outlined,
                      color: AppColors.textOnDark,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.lg),
                  Text(
                    'Ways to sign in',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.md),
                  Text(
                    'However you sign in, it is this one account, with your '
                    'Passport, friends and wines.',
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xl),
                  _MethodRow(
                    title: 'Email',
                    detail: email == null || email.isEmpty
                        ? 'No email address on this account.'
                        : '$email\nA six digit code sent here always works.',
                    trailing: const Icon(
                      Icons.check_rounded,
                      color: AppColors.textOnDark,
                      size: 20,
                    ),
                  ),
                  _MethodRow(
                    title: 'Apple',
                    detail: switch (_appleLinked) {
                      null => 'Checking…',
                      true =>
                        _justLinked
                            ? 'Linked. You can now sign in with Apple, here '
                                  'and on mantelier.app.'
                            : 'Linked. Sign in with Apple, here and on '
                                  'mantelier.app.',
                      false =>
                        showApple
                            ? 'Not linked. Link it to sign in with Apple, '
                                  'also when Apple hides your email.'
                            : 'Not linked. You can link Apple on an iPhone.',
                    },
                    trailing: _appleLinked == true
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.textOnDark,
                            size: 20,
                          )
                        : null,
                  ),
                  if (_appleLinked == false && showApple) ...[
                    const SizedBox(height: CsSpacing.lg),
                    SizedBox(
                      height: 52,
                      child: SignInWithAppleButton(
                        // One of the titles Apple's guidelines allow on its
                        // button; the line above says it links.
                        text: 'Continue with Apple',
                        style: SignInWithAppleButtonStyle.white,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(26),
                        ),
                        onPressed: _linking ? () {} : _link,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: CsSpacing.base),
                    Text(
                      _error!,
                      style: CsTypography.body.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.title, required this.detail, this.trailing});

  final String title;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: CsSpacing.base),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.hairlineOnGreen)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(height: CsSpacing.xs),
              Text(
                detail,
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
