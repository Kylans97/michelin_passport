import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_content_sheet.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../models/invite_link.dart';

/// "Who is this link for?": one person or a group (up to 12), then the
/// iOS share sheet with a message ready to send. Each share makes a new
/// link, open for 14 days (product owner, 2026-11-22). [context] must be
/// under a Navigator; [origin] is the widget the share sheet points at on
/// iPad.
///
/// Returns true when a link was made.
Future<bool> showShareInviteSheet(
  BuildContext context, {
  required InviteLinkKind kind,
  String? visitId,
  String? tripId,
  String? subtitle,
  InviteLinkRepository? repository,
}) async {
  final made = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareInviteSheet(
      kind: kind,
      visitId: visitId,
      tripId: tripId,
      subtitle: subtitle,
      repo: repository ?? InviteLinkRepository(Supabase.instance.client),
    ),
  );
  return made == true;
}

class _ShareInviteSheet extends StatefulWidget {
  const _ShareInviteSheet({
    required this.kind,
    required this.visitId,
    required this.tripId,
    required this.subtitle,
    required this.repo,
  });

  final InviteLinkKind kind;
  final String? visitId;
  final String? tripId;
  final String? subtitle;
  final InviteLinkRepository repo;

  @override
  State<_ShareInviteSheet> createState() => _ShareInviteSheetState();
}

class _ShareInviteSheetState extends State<_ShareInviteSheet> {
  static const _maxGroup = 12;

  // A dinner was usually shared by a table, so a group comes first there;
  // a friend link and a trip default to one person.
  late bool _group = widget.kind == InviteLinkKind.visit;
  int _size = 6;
  bool _busy = false;
  String? _error;

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await widget.repo.create(
        kind: widget.kind,
        visitId: widget.visitId,
        tripId: widget.tripId,
        maxUses: _group ? _size : 1,
      );
      // The same summary the web page shows, so the message can't drift
      // from what the recipient then sees.
      final preview = await widget.repo.preview(link.token);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: preview.shareMessage(link.url),
          subject: 'An invitation to Mantelier',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not make the link. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupNote = switch (widget.kind) {
      InviteLinkKind.visit =>
        'For a group chat. Everyone who accepts becomes your friend and gets '
            'this visit. You can remove anyone afterwards.',
      InviteLinkKind.trip =>
        'For a group chat. Everyone who accepts becomes your friend; you let '
            'each of them in on the trip yourself.',
      // A venue's link is shared from its own screen, never this sheet.
      InviteLinkKind.friend || InviteLinkKind.venue =>
        'For a group chat. Everyone who accepts becomes your friend. You can '
            'remove anyone afterwards.',
    };
    return CsContentSheet(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.md,
          CsSpacing.pageHorizontal,
          CsSpacing.xl,
        ),
        children: [
          Text('Who is this link for?', style: CsTypography.sectionTitle),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(widget.subtitle!, style: CsTypography.metadata),
          ],
          const SizedBox(height: CsSpacing.lg),
          _Choice(
            selected: !_group,
            title: 'One person',
            body: 'Works once. For a direct message.',
            onTap: () => setState(() => _group = false),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _Choice(
            selected: _group,
            title: 'A group',
            body: groupNote,
            onTap: () => setState(() => _group = true),
          ),
          if (_group) ...[
            const SizedBox(height: CsSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.base,
                vertical: CsSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text('Up to', style: CsTypography.bodyMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fewer people',
                    onPressed: _size > 2 ? () => setState(() => _size--) : null,
                    icon: const Icon(Icons.remove_rounded),
                    color: AppColors.forestGreen,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$_size',
                      textAlign: TextAlign.center,
                      style: CsTypography.sectionTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'More people',
                    onPressed: _size < _maxGroup
                        ? () => setState(() => _size++)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    color: AppColors.forestGreen,
                  ),
                  const Spacer(),
                  Text('people', style: CsTypography.metadata),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: CsSpacing.md),
            Text(
              _error!,
              style: CsTypography.metadata.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: CsSpacing.lg),
          CsPrimaryButton(
            label: 'Share link',
            loading: _busy,
            onTap: _busy ? null : _share,
          ),
          const SizedBox(height: CsSpacing.sm),
          Text(
            'The link is open for 14 days.',
            textAlign: TextAlign.center,
            style: CsTypography.metadata,
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: AppColors.forestGreen,
              size: 22,
            ),
            const SizedBox(width: CsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CsTypography.bodyMedium),
                  const SizedBox(height: 2),
                  Text(body, style: CsTypography.metadata),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
