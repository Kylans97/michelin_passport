import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_content_sheet.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../models/invite_link.dart';
import '../friends/widgets/identity_row.dart';
import 'pending_invite.dart';
import 'share_invite_sheet.dart';

/// Friends' own invitation corner: "Bring someone to Mantelier" with a
/// friend link, "Have a code?" for a link that got lost on the way, and
/// the member's links of the last 60 days, each with who used it.
class InviteLinksSection extends StatefulWidget {
  const InviteLinksSection({super.key, this.repository, this.onChanged});

  final InviteLinkRepository? repository;

  /// After a Remove or a decision, so the friends list can reload.
  final VoidCallback? onChanged;

  @override
  State<InviteLinksSection> createState() => _InviteLinksSectionState();
}

class _InviteLinksSectionState extends State<InviteLinksSection> {
  late final InviteLinkRepository _repo =
      widget.repository ?? InviteLinkRepository(Supabase.instance.client);
  late Future<List<MyInviteLink>> _links = _load();

  Future<List<MyInviteLink>> _load() async {
    try {
      return await _repo.myLinks();
    } catch (_) {
      // Before the migration, or offline: just no list.
      return const [];
    }
  }

  void _reload() => setState(() => _links = _load());

  Future<void> _shareFriendLink() async {
    final made = await showShareInviteSheet(
      context,
      kind: InviteLinkKind.friend,
      repository: _repo,
    );
    if (made) _reload();
  }

  Future<void> _enterCode() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EnterCodeSheet(repo: _repo),
    );
  }

  Future<void> _manage(MyInviteLink link) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageLinkSheet(link: link, repo: _repo),
    );
    if (changed == true) {
      _reload();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(CsSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.deepGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bring someone to Mantelier',
              style: CsTypography.sectionTitle.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.xs),
            Text(
              'Send a link. When they sign up, you are friends right away.',
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.base),
            CsPrimaryButton(
              label: 'Share a link',
              surface: CsSurface.dark,
              onTap: _shareFriendLink,
            ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _enterCode,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.forestGreen,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 44),
          ),
          child: Text(
            'Have an invitation code? Enter it',
            style: CsTypography.bodyMedium.copyWith(fontSize: 14.5),
          ),
        ),
      ),
      FutureBuilder<List<MyInviteLink>>(
        future: _links,
        builder: (context, snap) {
          final links = snap.data ?? const <MyInviteLink>[];
          if (links.isEmpty) return const SizedBox.shrink();
          final now = DateTime.now();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: CsSpacing.sm),
              Text(
                'YOUR LINKS',
                style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
              ),
              for (final l in links)
                _LinkRow(link: l, now: now, onManage: () => _manage(l)),
              const SizedBox(height: CsSpacing.lg),
            ],
          );
        },
      ),
    ],
  );
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

  String get _status {
    final parts = <String>[
      if (link.isGroup)
        'Group link · ${link.useCount} of ${link.maxUses} joined'
      else if (link.useCount > 0 && link.lastUsedByName != null)
        'Accepted by ${link.lastUsedByName}',
    ];
    if (link.isRevoked) {
      parts.add('Cancelled');
    } else if (link.isExpired(now)) {
      parts.add('Expired');
    } else if (!link.isUsedUp) {
      final days = link.expiresAt.difference(now).inDays;
      parts.add(days < 1 ? 'Open until tomorrow' : 'Open for $days more days');
    }
    return parts.join(' · ');
  }

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
                Text(_status, style: CsTypography.metadata),
              ],
            ),
          ),
          Text(
            'Manage',
            style: CsTypography.metadata.copyWith(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
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
