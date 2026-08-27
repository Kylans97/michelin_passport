import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/account_deletion_repository.dart';
import '../../data/repositories/auth_repository.dart';

/// Account deletion — a required App Store readiness capability, built as
/// real functionality, not a Coming Soon placeholder. Never deletes on
/// the first tap: this screen's own explanation + primary action is
/// itself step one, a system [AlertDialog] with an explicit "Delete"
/// action is step two, and only that second, explicit confirmation calls
/// [deleteAccount]. A failure never claims success and never signs the
/// user out — it shows a restrained error and leaves the account (and
/// the session) untouched so the user can try again.
///
/// [deleteAccount] and [signOut] are injectable (hand-rolled fakes, no
/// mocking framework — the same constructor-injection pattern
/// `_EditProfileSheet` already uses for its own repo) so this destructive
/// flow can be pumped and exercised directly in widget tests without a
/// live Supabase session. Both default to the real implementations
/// ([AccountDeletionRepository]/[AuthRepository] against
/// `Supabase.instance.client`) when omitted, which is the only place this
/// screen ever touches Supabase directly — production behavior is
/// unaffected by the injection seam existing.
class DeleteAccountScreen extends StatefulWidget {
  final Future<void> Function()? deleteAccount;
  final Future<void> Function()? signOut;

  const DeleteAccountScreen({super.key, this.deleteAccount, this.signOut});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _deleting = false;
  String? _error;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.brandGreenLight,
        title: Text(
          'Delete your account?',
          style: CsTypography.placeTitle.copyWith(color: AppColors.textOnDark),
        ),
        content: Text(
          "This permanently removes your Mantelier account and your "
          "personal data. This can't be undone.",
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _delete();
  }

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final delete =
          widget.deleteAccount ??
          AccountDeletionRepository(Supabase.instance.client).deleteCurrentAccount;
      await delete();
      final signOut =
          widget.signOut ?? AuthRepository(Supabase.instance.client).signOut;
      await signOut();
      if (!mounted) return;
      // AuthGate (the app's root route) is already listening to the auth
      // state stream and will now render LoginScreen — but it sits
      // BENEATH this pushed screen in the same Navigator (no nested
      // Navigator in this app), so it stays hidden until we pop back to
      // it explicitly.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not delete your account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.lg,
                CsSpacing.pageHorizontal,
                CsSpacing.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                  const SizedBox(height: CsSpacing.lg),
                  Text(
                    'Delete your account',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.md),
                  Text(
                    'This permanently deletes your Mantelier account '
                    'and all associated personal data — visits, ratings, '
                    "wishlist, trips and photos. This can't be undone.",
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: CsSpacing.lg),
                    Text(
                      _error!,
                      style: CsTypography.body.copyWith(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: CsSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _deleting ? null : _confirmAndDelete,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.error,
                              ),
                            )
                          : Text(
                              'Delete my account',
                              style: CsTypography.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: CsSpacing.md),
                  Center(
                    child: TextButton(
                      onPressed: _deleting
                          ? null
                          : () => Navigator.maybePop(context),
                      child: Text(
                        'Cancel',
                        style: CsTypography.bodyMedium.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
