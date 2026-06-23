import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/trophy_repository.dart';
import '../../models/friendship.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final FriendshipRepository _friendRepo;
  late final TrophyRepository _trophyRepo;
  final String _uid =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  late Future<List<Friendship>> _future;

  @override
  void initState() {
    super.initState();
    _friendRepo = FriendshipRepository(Supabase.instance.client);
    _trophyRepo = TrophyRepository(Supabase.instance.client);
    _load();
  }

  void _load() {
    setState(() {
      _future = _friendRepo.getPendingRequests(_uid);
    });
  }

  Future<void> _accept(Friendship f) async {
    await _friendRepo.acceptRequest(f.id);
    // Check first_friend trophy.
    final count = await _friendRepo.getFriendCount(_uid);
    if (count == 1 && mounted) {
      final trophy = await _trophyRepo.awardSocialTrophy(_uid, 'first_friend');
      if (trophy != null && mounted) {
        showDialog(
          context: context,
          builder: (_) => _TrophyMiniDialog(name: trophy.name),
        );
      }
    }
    // Check friends_10 trophy.
    if (count == 10 && mounted) {
      await _trophyRepo.awardSocialTrophy(_uid, 'friends_10');
    }
    _load();
  }

  Future<void> _decline(Friendship f) async {
    await _friendRepo.declineOrRemove(f.id);
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
      body: FutureBuilder<List<Friendship>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 1.5));
          }
          final requests = snap.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      color: AppColors.textSecondary, size: 48),
                  const SizedBox(height: 16),
                  Text('No pending requests',
                      style: GoogleFonts.playfairDisplay(
                          color: AppColors.textSecondary, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Friend requests will appear here.',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.goldMuted,
                        border: Border.all(color: AppColors.goldBorder40),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        f.friendDisplayName.isNotEmpty
                            ? f.friendDisplayName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.playfairDisplay(
                            color: AppColors.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.friendDisplayName,
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Sent you a friend request',
                              style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
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
                              color: AppColors.cardBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary, size: 16),
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
                              color: AppColors.goldBorder60, width: 1),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppColors.gold, size: 16),
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

class _TrophyMiniDialog extends StatelessWidget {
  final String name;
  const _TrophyMiniDialog({required this.name});

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.gold, size: 40),
            const SizedBox(height: 12),
            Text('Trophy earned!',
                style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text(name,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Nice!',
                style:
                    GoogleFonts.inter(color: AppColors.gold)),
          ),
        ],
      );
}
