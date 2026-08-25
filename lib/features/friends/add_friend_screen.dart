import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_search_field.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../models/profile_identity.dart';
import '../community/widgets/community_shared.dart';
import 'widgets/identity_row.dart';

/// "Find friends" — username search → send request. Server-side
/// eligibility (blocked pairs excluded, self excluded, minimum query
/// length) is enforced by search_profiles itself — see
/// FriendshipRepository — this screen only renders whatever it returns.
///
/// COMMUNITY V1 UI REFINEMENT: full visual redesign onto the current
/// Chasing Stars deep-green canvas (this screen previously predated that
/// system — almost entirely ivory background, generic search-page
/// styling). Renamed from "Add Friend" to "Find friends" in the visible
/// copy — finding someone and sending a request are separate actions, so
/// the screen-level label describes discovery, not the eventual action.
/// The class name itself is unchanged (`AddFriendScreen`) since every
/// existing call site/test targets that type — this is a copy/visual
/// rename, not a new screen.
///
/// [searchProfiles]/[sendFriendRequest] are optional DI seams (same
/// constructor-injection convention as `CommunityScreen`/`PassportScreen`)
/// defaulting to the real `FriendshipRepository`-backed calls — overridden
/// in tests so this screen's real search-results/no-results/send-request
/// behavior can be verified without a live Supabase session.
class AddFriendScreen extends StatefulWidget {
  final Future<List<ProfileIdentity>> Function(String query)? searchProfiles;
  final Future<void> Function(String targetUserId)? sendFriendRequest;

  const AddFriendScreen({
    super.key,
    this.searchProfiles,
    this.sendFriendRequest,
  });

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  late final _repo = FriendshipRepository(Supabase.instance.client);
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<ProfileIdentity> _results = [];
  bool _searching = false;
  bool _hasSearched = false;
  final Set<String> _sentTo = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _hasSearched = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final search = widget.searchProfiles ?? _repo.searchProfiles;
        final results = await search(value);
        if (mounted) setState(() => _results = results);
      } finally {
        if (mounted) {
          setState(() {
            _searching = false;
            _hasSearched = true;
          });
        }
      }
    });
  }

  Future<void> _send(ProfileIdentity target) async {
    try {
      final send = widget.sendFriendRequest ?? _repo.sendRequest;
      await send(target.id);
      if (mounted) {
        setState(() => _sentTo.add(target.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Friend request sent',
              style: CsTypography.metadata.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            backgroundColor: AppColors.forestGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
            style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.base,
                CsSpacing.sm,
                CsSpacing.base,
                0,
              ),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: EditorialBackButton(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.lg,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find friends',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xs),
                  Text(
                    'Build your circle.',
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.lg,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: CsSearchField(
                controller: _searchCtrl,
                hintText: 'Search by username…',
                onChanged: _onQueryChanged,
                autofocus: true,
                surface: CsSurface.dark,
              ),
            ),
            const SizedBox(height: CsSpacing.lg),
            Expanded(
              child: _searching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.secondaryOnDark,
                        strokeWidth: 1.5,
                      ),
                    )
                  : _results.isEmpty
                  ? (_hasSearched
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CsSpacing.pageHorizontal,
                            ),
                            child: Text(
                              'No members found.',
                              style: CsTypography.metadata.copyWith(
                                color: AppColors.secondaryOnDark,
                              ),
                            ),
                          )
                        : const SizedBox.shrink())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        CsSpacing.pageHorizontal,
                        0,
                        CsSpacing.pageHorizontal,
                        CsSpacing.section,
                      ),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: CsSpacing.sm),
                      itemBuilder: (context, i) {
                        final result = _results[i];
                        return CommunityIvoryCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CsSpacing.md,
                            vertical: CsSpacing.xs,
                          ),
                          child: IdentityRow(
                            label: result.label,
                            username: result.username,
                            avatarUrl: result.avatarUrl,
                            trailing: _ActionForStatus(
                              status: result.relationshipStatus,
                              justSent: _sentTo.contains(result.id),
                              onAdd: () => _send(result),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionForStatus extends StatelessWidget {
  final RelationshipStatus status;
  final bool justSent;
  final VoidCallback onAdd;
  const _ActionForStatus({
    required this.status,
    required this.justSent,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (justSent || status == RelationshipStatus.pendingSent) {
      return Text(
        'Request sent',
        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
      );
    }
    switch (status) {
      case RelationshipStatus.accepted:
        return Text(
          'Friends',
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        );
      case RelationshipStatus.pendingReceived:
        return Text(
          'Respond in requests',
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        );
      case RelationshipStatus.declined:
        return Text(
          'Unavailable',
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        );
      case RelationshipStatus.none:
      case RelationshipStatus.pendingSent:
        return TextButton(
          onPressed: onAdd,
          child: Text(
            'Add',
            style: CsTypography.metadata.copyWith(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }
}
