import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_content_sheet.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../models/invite_link.dart';
import '../friends/widgets/identity_row.dart';
import 'pending_invite.dart';
import 'share_invite_sheet.dart';

/// Inviting, behind Friends' person-plus icon (product owner, 2026-11-24:
/// Friends opens on the friends themselves, not on a green block and a
/// list of links). Share a link, find someone already here by username,
/// or enter a code from the invitation page.
Future<void> showInviteSheet(
  BuildContext context, {
  required VoidCallback onFindByUsername,
  InviteLinkRepository? repository,
  VoidCallback? onLinkMade,
}) async {
  final repo = repository ?? InviteLinkRepository(Supabase.instance.client);
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => CsContentSheet(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.md,
          CsSpacing.pageHorizontal,
          CsSpacing.xl,
        ),
        children: [
          Text('Add a friend', style: CsTypography.sectionTitle),
          const SizedBox(height: CsSpacing.sm),
          _SheetChoice(
            title: 'Share a link',
            subtitle: 'When they sign up, you are friends right away.',
            onTap: () => Navigator.pop(sheetContext, 'share'),
          ),
          _SheetChoice(
            title: 'Find by username',
            subtitle: 'For someone already on Mantelier.',
            onTap: () => Navigator.pop(sheetContext, 'find'),
          ),
          _SheetChoice(
            title: 'Enter a code',
            subtitle: 'The eight characters on an invitation page.',
            onTap: () => Navigator.pop(sheetContext, 'code'),
            last: true,
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'share':
      final made = await showShareInviteSheet(
        context,
        kind: InviteLinkKind.friend,
        repository: repo,
      );
      if (made) onLinkMade?.call();
    case 'find':
      onFindByUsername();
    case 'code':
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EnterCodeSheet(repo: repo),
      );
  }
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CsTypography.bodyMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: CsTypography.metadata),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.taupe),
        ],
      ),
    ),
  );
}

/// One quiet line under the friends list: "3 open links", opening the
/// links still open. Nothing at all while none is. Links that expired,
/// were cancelled or are used up wait folded away in that list, for a
/// Remove or a late trip request.
class OpenInviteLinksLine extends StatefulWidget {
  const OpenInviteLinksLine({super.key, this.repository, this.onChanged});

  final InviteLinkRepository? repository;

  /// After a Remove or a decision, so the friends list can reload.
  final VoidCallback? onChanged;

  @override
  State<OpenInviteLinksLine> createState() => _OpenInviteLinksLineState();
}

class _OpenInviteLinksLineState extends State<OpenInviteLinksLine> {
  late final InviteLinkRepository _repo =
      widget.repository ?? InviteLinkRepository(Supabase.instance.client);
  late Future<List<MyInviteLink>> _links = _load();

  Future<List<MyInviteLink>> _load() async {
    try {
      return await _repo.myLinks();
    } catch (_) {
      // Before the migration, or offline: just no line.
      return const [];
    }
  }

  Future<void> _open(List<MyInviteLink> links) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OpenLinksSheet(links: links, repo: _repo),
    );
    if (!mounted) return;
    setState(() => _links = _load());
    if (changed == true) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MyInviteLink>>(
    future: _links,
    builder: (context, snap) {
      final links = snap.data ?? const <MyInviteLink>[];
      final now = DateTime.now();
      final open = links.where((l) => l.isOpen(now)).length;
      if (open == 0) return const SizedBox.shrink();
      return InkWell(
        onTap: () => _open(links),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  open == 1 ? '1 open link' : '$open open links',
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.taupe,
                size: 20,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The open links, newest first; the rest folded under "Show earlier".
class _OpenLinksSheet extends StatefulWidget {
  const _OpenLinksSheet({required this.links, required this.repo});

  final List<MyInviteLink> links;
  final InviteLinkRepository repo;

  @override
  State<_OpenLinksSheet> createState() => _OpenLinksSheetState();
}

class _OpenLinksSheetState extends State<_OpenLinksSheet> {
  late List<MyInviteLink> _links = widget.links;
  bool _showEarlier = false;
  bool _changed = false;

  Future<void> _manage(MyInviteLink link) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageLinkSheet(link: link, repo: widget.repo),
    );
    if (changed != true || !mounted) return;
    _changed = true;
    try {
      final links = await widget.repo.myLinks();
      if (mounted) setState(() => _links = links);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final open = _links.where((l) => l.isOpen(now)).toList();
    final earlier = _links.where((l) => !l.isOpen(now)).toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: CsContentSheet(
        maxHeightFraction: 0.85,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.md,
            CsSpacing.pageHorizontal,
            CsSpacing.xl,
          ),
          children: [
            Text('Open links', style: CsTypography.sectionTitle),
            const SizedBox(height: 2),
            Text(
              'Links you shared that can still be used.',
              style: CsTypography.metadata,
            ),
            const SizedBox(height: CsSpacing.sm),
            if (open.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
                child: Text('None open now.', style: CsTypography.metadata),
              ),
            for (final l in open)
              _LinkRow(link: l, now: now, onManage: () => _manage(l)),
            if (earlier.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _showEarlier = !_showEarlier),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.taupe,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(
                    _showEarlier
                        ? 'Hide earlier links'
                        : 'Show earlier links (${earlier.length})',
                  ),
                ),
              ),
              if (_showEarlier)
                for (final l in earlier)
                  _LinkRow(link: l, now: now, onManage: () => _manage(l)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.link,
    required this.now,
    required this.onManage,
  });

  final MyInviteLink link;
  final DateTime now;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onManage,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.title, style: CsTypography.bodyMedium),
                Text(link.statusLine(now), style: CsTypography.metadata),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.taupe),
        ],
      ),
    ),
  );
}

/// Who used one link: Let in or Decline for a trip request, Remove for
/// anyone, and Cancel link while it is still open.
class _ManageLinkSheet extends StatefulWidget {
  const _ManageLinkSheet({required this.link, required this.repo});

  final MyInviteLink link;
  final InviteLinkRepository repo;

  @override
  State<_ManageLinkSheet> createState() => _ManageLinkSheetState();
}

class _ManageLinkSheetState extends State<_ManageLinkSheet> {
  late Future<List<InviteLinkUse>> _uses = widget.repo.uses(widget.link.id);
  bool _changed = false;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _changed = true;
      setState(() => _uses = widget.repo.uses(widget.link.id));
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not update. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(InviteLinkUse use) async {
    final link = widget.link;
    final what = switch (link.kind) {
      InviteLinkKind.visit =>
        'You stop being friends, unless you were before, and the visit '
            'leaves their Passport with anything they added to it.',
      InviteLinkKind.trip =>
        'You stop being friends, unless you were before, and they leave the trip.',
      _ => 'You stop being friends, unless you were before.',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Remove ${use.label}?', style: CsTypography.sectionTitle),
        content: Text(what, style: CsTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => widget.repo.removeUse(use.id));
  }

  Future<void> _cancelLink() async {
    await _run(() => widget.repo.revoke(widget.link.id));
    if (mounted && _error == null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final open = link.isOpen(DateTime.now());
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: CsContentSheet(
        maxHeightFraction: 0.85,
        child: FutureBuilder<List<InviteLinkUse>>(
          future: _uses,
          builder: (context, snap) {
            final uses = (snap.data ?? const <InviteLinkUse>[])
                .where((u) => u.status != 'removed')
                .toList();
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.md,
                CsSpacing.pageHorizontal,
                CsSpacing.xl,
              ),
              children: [
                Text(link.title, style: CsTypography.sectionTitle),
                const SizedBox(height: 2),
                Text(
                  link.isGroup
                      ? 'Group link for up to ${link.maxUses} people'
                      : 'Link for one person',
                  style: CsTypography.metadata,
                ),
                const SizedBox(height: CsSpacing.lg),
                if (snap.connectionState == ConnectionState.waiting)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                      strokeWidth: 1.5,
                    ),
                  )
                else if (uses.isEmpty)
                  Text('Nobody has used it yet.', style: CsTypography.metadata)
                else
                  for (final u in uses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: CsSpacing.md),
                      child: IdentityRow(
                        label: u.label,
                        username: u.username,
                        trailing: _actions(u),
                      ),
                    ),
                if (_error != null) ...[
                  const SizedBox(height: CsSpacing.sm),
                  Text(
                    _error!,
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                if (open) ...[
                  const SizedBox(height: CsSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Code ${link.code.substring(0, 4)} ${link.code.substring(4)}',
                          style: CsTypography.metadata,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: inviteLinkUrl(link.token)),
                          );
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(content: Text('Link copied.')),
                          );
                        },
                        child: const Text('Copy link'),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _busy ? null : _cancelLink,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text('Cancel link'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _actions(InviteLinkUse u) {
    final small = CsTypography.smallLabel.copyWith(color: AppColors.taupe);
    if (u.status == 'awaiting_approval') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _busy
                ? null
                : () =>
                      _run(() => widget.repo.decideJoin(u.id, approve: false)),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => widget.repo.decideJoin(u.id, approve: true)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.deepGreen,
              foregroundColor: AppColors.textOnDark,
              shape: const StadiumBorder(),
            ),
            child: const Text('Let in'),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (u.status == 'declined') Text('Not let in', style: small),
        IconButton(
          tooltip: 'Remove',
          onPressed: _busy ? null : () => _remove(u),
          icon: const Icon(
            Icons.close_rounded,
            color: AppColors.taupe,
            size: 18,
          ),
        ),
      ],
    );
  }
}

/// A code typed from the web page, for when the link itself was lost
/// between the page and the app. Ten wrong codes an hour, then a pause
/// (the server's own message).
class _EnterCodeSheet extends StatefulWidget {
  const _EnterCodeSheet({required this.repo});

  final InviteLinkRepository repo;

  @override
  State<_EnterCodeSheet> createState() => _EnterCodeSheetState();
}

class _EnterCodeSheetState extends State<_EnterCodeSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await widget.repo.previewByCode(_code.text);
      if (!mounted) return;
      if (p.state == 'not_found' || p.token.isEmpty) {
        setState(
          () => _error = 'That code was not found. Check it and try again.',
        );
        return;
      }
      Navigator.pop(context);
      // InviteLinkGate opens the invitation itself.
      await PendingInvite.instance.set(p.token);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check the code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CsContentSheet(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.xl,
      ),
      children: [
        Text('Enter an invitation code', style: CsTypography.sectionTitle),
        const SizedBox(height: 2),
        Text(
          'The eight characters on the invitation page.',
          style: CsTypography.metadata,
        ),
        const SizedBox(height: CsSpacing.lg),
        CsTextField(
          label: 'Code',
          controller: _code,
          hintText: 'K7Q2 M9XD',
          textCapitalization: TextCapitalization.characters,
          onFieldSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: CsSpacing.sm),
          Text(
            _error!,
            style: CsTypography.metadata.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: CsSpacing.lg),
        CsPrimaryButton(
          label: 'Open invitation',
          loading: _busy,
          onTap: _busy ? null : _submit,
        ),
      ],
    ),
  );
}
