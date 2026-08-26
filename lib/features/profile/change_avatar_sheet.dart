import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/profile_repository.dart';
import 'avatar_picker.dart';

/// PROFILE UI REDESIGN V1 — the one canonical "change my photo" flow,
/// reached identically from the Profile identity hero's own avatar tap
/// and from Edit Profile's avatar row (§26 of this feature's own spec:
/// "Profile avatar tap and Edit Profile both lead to one canonical
/// photo-edit mechanism").
///
/// Returns `true` via [Navigator.pop] iff the avatar actually changed
/// (replaced or removed) — `null`/`false` otherwise — so callers know
/// whether to reload. Never pops with `true` before the corresponding
/// write has actually succeeded (no optimistic close), matching this
/// app's established "no false success" rule for every other
/// destructive/account-level action (Delete Account, the Discoverability
/// toggle).
///
/// [pickImage]/[replaceAvatar]/[removeAvatar] are optional DI seams —
/// this session's established constructor-injection convention — so the
/// REAL widget can be pumped directly in tests without a live Supabase
/// session or a real photo library. Defaults resolve `Supabase.instance`
/// only inside the closures, never eagerly.
class ChangeAvatarSheet extends StatefulWidget {
  final String userId;
  final String? currentAvatarPath;
  final Future<StagedAvatar?> Function()? pickImage;
  final Future<String> Function(StagedAvatar staged)? replaceAvatar;
  final Future<void> Function()? removeAvatar;

  const ChangeAvatarSheet({
    super.key,
    required this.userId,
    required this.currentAvatarPath,
    this.pickImage,
    this.replaceAvatar,
    this.removeAvatar,
  });

  @override
  State<ChangeAvatarSheet> createState() => _ChangeAvatarSheetState();

  static Future<bool?> show(
    BuildContext context, {
    required String userId,
    required String? currentAvatarPath,
  }) => showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeAvatarSheet(
      userId: userId,
      currentAvatarPath: currentAvatarPath,
    ),
  );
}

class _ChangeAvatarSheetState extends State<ChangeAvatarSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _choosePhoto() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pick = widget.pickImage ?? pickAvatarImage;
      final staged = await pick();
      if (staged == null) {
        // Picker cancelled — not an error, just nothing changed.
        if (mounted) setState(() => _busy = false);
        return;
      }
      final replace =
          widget.replaceAvatar ??
          (StagedAvatar s) => ProfileRepository(Supabase.instance.client)
              .replaceAvatar(
                userId: widget.userId,
                bytes: s.bytes,
                fileExtension: extensionOfStagedAvatar(s),
                currentAvatarPath: widget.currentAvatarPath,
              );
      await replace(staged);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not update your photo. Please try again.';
      });
    }
  }

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final remove =
          widget.removeAvatar ??
          () => ProfileRepository(Supabase.instance.client).removeAvatar(
            userId: widget.userId,
            currentAvatarPath: widget.currentAvatarPath!,
          );
      await remove();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not remove your photo. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        widget.currentAvatarPath != null && widget.currentAvatarPath!.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.brandGreenLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textOnDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: CsSpacing.xl),
            Text(
              'PROFILE PHOTO',
              style: CsTypography.eyebrow.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.lg),
            _SheetActionRow(
              label: hasAvatar ? 'Replace photo' : 'Choose photo',
              busy: _busy,
              onTap: _busy ? null : _choosePhoto,
            ),
            if (hasAvatar)
              _SheetActionRow(
                label: 'Remove photo',
                busy: _busy,
                destructive: true,
                onTap: _busy ? null : _remove,
              ),
            if (_error != null) ...[
              const SizedBox(height: CsSpacing.base),
              Text(
                _error!,
                style: CsTypography.metadata.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: CsSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
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
    );
  }
}

class _SheetActionRow extends StatelessWidget {
  final String label;
  final bool busy;
  final bool destructive;
  final VoidCallback? onTap;

  const _SheetActionRow({
    required this.label,
    required this.busy,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textOnDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: CsTypography.bodyMedium.copyWith(color: color),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.secondaryOnDark,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
