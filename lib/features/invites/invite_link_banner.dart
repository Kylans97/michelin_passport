import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/member_avatar.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../models/invite_link.dart';
import 'pending_invite.dart';

/// The strip at the top of the entrance (LoginScreen) for someone who
/// came through an invitation link.
///
/// With an invitation waiting on the phone: "Elise Laurent invited you.
/// Sign in to accept." With none but text on the clipboard, which iOS
/// reports without showing it: "Opening an invitation? Paste it". Only
/// that tap reads the clipboard, and iOS asks first. Otherwise nothing.
class InviteLinkBanner extends StatefulWidget {
  const InviteLinkBanner({super.key, this.pending, this.repository});

  final PendingInvite? pending;
  final InviteLinkRepository? repository;

  @override
  State<InviteLinkBanner> createState() => _InviteLinkBannerState();
}

class _InviteLinkBannerState extends State<InviteLinkBanner> {
  late final PendingInvite _store = widget.pending ?? PendingInvite.instance;
  late final InviteLinkRepository _repo =
      widget.repository ?? InviteLinkRepository(Supabase.instance.client);

  InviteLinkPreview? _preview;
  String? _previewFor;
  bool _canPaste = false;
  String? _pasteNote;

  @override
  void initState() {
    super.initState();
    _store.token.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    _store.token.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final token = _store.token.value;
    if (token == null) {
      final canPaste = await _store.clipboardMayHoldText();
      if (mounted) setState(() => _canPaste = canPaste);
      return;
    }
    if (token == _previewFor) return;
    _previewFor = token;
    try {
      final p = await _repo.preview(token);
      if (mounted && _store.token.value == token) setState(() => _preview = p);
    } catch (_) {
      // The strip is a courtesy; signing in works without it.
    }
  }

  Future<void> _paste() async {
    final found = await _store.pasteFromClipboard();
    if (!mounted) return;
    setState(
      () => _pasteNote = found
          ? null
          : 'No invitation link found. After signing in you can enter its '
                'code under Friends.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = _store.token.value;
    final p = _preview;
    if (token != null && p != null && p.isOpen) {
      return _Strip(
        leading: MemberAvatar(avatarUrl: null, displayName: p.sender, size: 38),
        title: '${p.sender} invited you',
        body: switch (p.kind) {
          InviteLinkKind.visit when p.venueName != null =>
            'Sign in to accept. ${p.venueName} is waiting.',
          InviteLinkKind.trip when p.tripTitle != null =>
            'Sign in to accept. ${p.tripTitle} is waiting.',
          _ => 'Sign in to accept.',
        },
      );
    }
    if (token == null && _canPaste) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _paste,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.textOnDark.withValues(alpha: 0.08),
                foregroundColor: AppColors.textOnDark,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: CsSpacing.base,
                  vertical: CsSpacing.sm,
                ),
                minimumSize: const Size(44, 44),
              ),
              child: Text.rich(
                TextSpan(
                  text: 'Opening an invitation? ',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.textOnDark,
                  ),
                  children: [
                    TextSpan(
                      text: 'Paste it',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_pasteNote != null) ...[
            const SizedBox(height: CsSpacing.xs),
            Text(
              _pasteNote!,
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.leading,
    required this.title,
    required this.body,
  });

  final Widget leading;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CsSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.textOnDark.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        leading,
        const SizedBox(width: CsSpacing.md),
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
              Text(
                body,
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
