import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../models/friendship.dart';

/// Incoming friend requests. Fixed to compile against Social Foundation
/// Step 1's FriendshipRepository (getPendingRequests/declineOrRemove and
/// Friendship.id/friendDisplayName no longer exist — see the migration
/// and model rewrite) — this screen's entire feature set already WAS
/// "pending friend requests, accept/decline inline," so the fix is a
/// like-for-like API update, not new functionality. The trophy-awarding
/// side effect on accept (`first_friend`/`friends_10`) is removed rather
/// than fixed: `TrophyRepository.awardSocialTrophy` reads `trophies`/
/// `user_trophies`, tables that don't exist in the live schema either
/// (confirmed via the same live read-only audit that found `friendships`
/// missing) — trophies are out of this task's scope entirely, not merely
/// deferred, so this stops trying to call into that dead path rather than
/// fixing it. Visual system (light/legacy) is intentionally untouched —
/// out of this task's scope; only what was required to compile changed.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final FriendshipRepository _friendRepo;

  late Future<List<FriendRequest>> _future;

  @override
  void initState() {
    super.initState();
    _friendRepo = FriendshipRepository(Supabase.instance.client);
    _load();
  }

  void _load() {
    setState(() {
      _future = _friendRepo.getIncomingRequests();
    });
  }

  Future<void> _accept(FriendRequest f) async {
    await _friendRepo.acceptRequest(f.friendshipId);
    _load();
  }

  Future<void> _decline(FriendRequest f) async {
    await _friendRepo.declineRequest(f.friendshipId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.background,
      ),
      body: FutureBuilder<List<FriendRequest>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 1.5,
              ),
            );
          }
          final requests = snap.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Friend requests will appear here.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final f = requests[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.goldMuted,
                        border: Border.all(color: AppColors.goldBorder40),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        f.label.isNotEmpty ? f.label[0].toUpperCase() : '?',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.label,
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sent you a friend request',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Decline
                    GestureDetector(
                      onTap: () => _decline(f),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Accept
                    GestureDetector(
                      onTap: () => _accept(f),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.goldMuted,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.goldBorder60,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppColors.gold,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
