import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_fonts.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_content_sheet.dart';
import '../../../data/repositories/friendship_repository.dart';
import '../../../data/repositories/visit_companion_repository.dart';
import '../../../models/friendship.dart';
import '../../friends/widgets/identity_row.dart';

/// A friend chosen for a visit, before or after saving. [status] is the
/// tag's own state once it exists ('pending', 'accepted', 'declined');
/// null while it is only chosen here.
class CompanionChoice {
  final String userId;
  final String label;
  final String? avatarUrl;
  final String? status;

  const CompanionChoice({
    required this.userId,
    required this.label,
    this.avatarUrl,
    this.status,
  });

  factory CompanionChoice.fromCompanion(VisitCompanion c) => CompanionChoice(
    userId: c.userId,
    label: c.label,
    avatarUrl: c.avatarUrl,
    status: c.status,
  );

  factory CompanionChoice.fromFriend(Friendship f) =>
      CompanionChoice(userId: f.friendId, label: f.label, avatarUrl: f.avatarUrl);
}

/// "Who were you with?" on the visit sheet: the friends chosen so far and
/// a way to change them. Same light card as [VisitPrivacyToggle] above it.
class VisitCompanionsField extends StatelessWidget {
  final List<CompanionChoice> companions;
  final ValueChanged<List<CompanionChoice>> onChanged;
  final bool friendsVisible;

  /// For tests: the friends to choose from, instead of the server's.
  final Future<List<Friendship>> Function()? loadFriends;

  const VisitCompanionsField({
    super.key,
    required this.companions,
    required this.onChanged,
    required this.friendsVisible,
    this.loadFriends,
  });

  Future<void> _edit(BuildContext context) async {
    final load =
        loadFriends ??
        () => FriendshipRepository(Supabase.instance.client).getFriends();
    final picked = await showModalBottomSheet<List<CompanionChoice>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FriendPickerSheet(
        load: load,
        selected: {for (final c in companions) c.userId: c},
      ),
    );
    if (picked != null) onChanged(picked);
  }

  String get _subtitle {
    if (companions.isEmpty) return 'Add the friends you were with.';
    final names = [for (final c in companions) c.label.split(' ').first];
    final waiting = companions.where((c) => c.status == 'pending').length;
    final line = 'With ${companionsLine(names)}';
    if (waiting > 0) {
      return '$line. ${waiting == 1 ? 'One friend has' : '$waiting friends have'} '
          'not confirmed yet.';
    }
    return friendsVisible
        ? '$line.'
        : '$line. Only they see it while the visit is private.';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _edit(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CsSpacing.base,
            vertical: CsSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Who were you with?',
                      style: CsFonts.sans(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: CsFonts.sans(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              const Icon(
                Icons.person_add_alt_1_outlined,
                size: 20,
                color: AppColors.terracotta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendPickerSheet extends StatefulWidget {
  final Future<List<Friendship>> Function() load;
  final Map<String, CompanionChoice> selected;

  const _FriendPickerSheet({required this.load, required this.selected});

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  late final Future<List<Friendship>> _future = widget.load();
  late final Map<String, CompanionChoice> _selected = {...widget.selected};
  String _query = '';

  void _toggle(Friendship f) => setState(() {
    if (_selected.containsKey(f.friendId)) {
      _selected.remove(f.friendId);
    } else if (_selected.length < 12) {
      _selected[f.friendId] = CompanionChoice.fromFriend(f);
    }
  });

  @override
  Widget build(BuildContext context) {
    return CsContentSheet(
      maxHeightFraction: 0.85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.md,
              CsSpacing.pageHorizontal,
              CsSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Who were you with?', style: CsTypography.sectionTitle),
                const SizedBox(height: 2),
                Text(
                  'They are asked to confirm before anyone else sees it.',
                  style: CsTypography.metadata,
                ),
                const SizedBox(height: CsSpacing.sm),
                TextField(
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search your friends',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: FutureBuilder<List<Friendship>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(CsSpacing.xl),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.forestGreen,
                        strokeWidth: 1.5,
                      ),
                    ),
                  );
                }
                final friends = [
                  for (final f in snap.data ?? const <Friendship>[])
                    if (_query.isEmpty ||
                        f.label.toLowerCase().contains(_query) ||
                        (f.username ?? '').toLowerCase().contains(_query))
                      f,
                ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
                if (friends.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(CsSpacing.xl),
                    child: Text(
                      snap.hasError
                          ? 'Your friends could not be loaded.'
                          : _query.isEmpty
                          ? 'Add friends first, then tag them on a visit.'
                          : 'No friend by that name.',
                      textAlign: TextAlign.center,
                      style: CsTypography.metadata,
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CsSpacing.pageHorizontal,
                  ),
                  itemCount: friends.length,
                  itemBuilder: (_, i) {
                    final f = friends[i];
                    final on = _selected.containsKey(f.friendId);
                    return InkWell(
                      onTap: () => _toggle(f),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            IdentityAvatar(label: f.label, avatarUrl: f.avatarUrl),
                            const SizedBox(width: CsSpacing.md),
                            Expanded(
                              child: Text(f.label, style: CsTypography.bodyMedium),
                            ),
                            Icon(
                              on
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: on ? AppColors.terracotta : AppColors.taupe,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.sm,
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
            ),
            child: FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _selected.values.toList()),
              child: Text(
                _selected.isEmpty
                    ? 'Nobody else'
                    : 'Done, ${_selected.length} ${_selected.length == 1 ? 'friend' : 'friends'}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
