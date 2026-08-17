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
import 'widgets/identity_row.dart';

/// Username search → send request. Server-side eligibility (blocked pairs
/// excluded, self excluded, minimum query length) is enforced by
/// search_profiles itself — see FriendshipRepository — this screen only
/// renders whatever it returns.
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  late final _repo = FriendshipRepository(Supabase.instance.client);
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<ProfileIdentity> _results = [];
  bool _searching = false;
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
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _repo.searchProfiles(value);
        if (mounted) setState(() => _results = results);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _send(ProfileIdentity target) async {
    try {
      await _repo.sendRequest(target.id);
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
      backgroundColor: AppColors.ivory,
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
                child: EditorialBackButton(color: AppColors.forestGreen),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.xl,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: Text(
                'Add Friend',
                style: CsTypography.screenTitle.copyWith(
                  color: AppColors.forestGreen,
                ),
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
                surface: CsSurface.light,
              ),
            ),
            const SizedBox(height: CsSpacing.lg),
            Expanded(
              child: _searching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.forestGreen,
                        strokeWidth: 1.5,
                      ),
                    )
                  : _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CsSpacing.xxl,
                      ),
                      child: Center(
                        child: Text(
                          _searchCtrl.text.trim().length < 2
                              ? 'Type at least 2 characters to search.'
                              : 'No one found with that username.',
                          textAlign: TextAlign.center,
                          style: CsTypography.body.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        CsSpacing.pageHorizontal,
                        0,
                        CsSpacing.pageHorizontal,
                        CsSpacing.section,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final result = _results[i];
                        return IdentityRow(
                          label: result.label,
                          username: result.username,
                          avatarUrl: result.avatarUrl,
                          trailing: _ActionForStatus(
                            status: result.relationshipStatus,
                            justSent: _sentTo.contains(result.id),
                            onAdd: () => _send(result),
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
