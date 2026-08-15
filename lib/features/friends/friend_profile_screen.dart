import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/event.dart';
import '../../models/passport_venue.dart';
import '../../models/profile_identity.dart';
import '../../models/venue_entry.dart';
import '../../models/visit.dart';
import '../events/event_detail_screen.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'widgets/friend_going_tile.dart';
import 'widgets/friend_visit_tile.dart';
import 'widgets/friend_wishlist_tile.dart';

/// One screen for both a friend's profile and a non-friend's — the
/// difference is entirely in which action [relationshipStatus] resolves
/// to (§34-35 of the task). Identity-only for anyone not an accepted
/// friend — no visits, ratings, photos, wishlist, or trips, per the
/// non-friend-profile rule Step 1 established.
///
/// For an ACCEPTED friend (Social Foundation Step 2), also shows VISITED
/// (every visit the database's own RLS allows this viewer to read — see
/// [VisitedRepository.loadPassportVenues], unchanged, reused as-is: the
/// friends-visibility rewrite lives entirely in visits_read/photos_read,
/// never in this screen) and WISHLIST (same reuse of
/// [WishlistRepository.loadWishlistVenues]). Trips are never shown here —
/// planned_trips/planned_venues RLS is untouched by Step 2 and remains
/// strictly owner-only.
class FriendProfileScreen extends StatefulWidget {
  final String userId;
  const FriendProfileScreen({super.key, required this.userId});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  late final _repo = FriendshipRepository(Supabase.instance.client);
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _wishlistRepo = WishlistRepository(Supabase.instance.client);
  late final _attendanceRepo = EventAttendanceRepository(
    Supabase.instance.client,
  );
  late Future<ProfileIdentity?> _future;

  // Only populated once identity resolves as an accepted friendship — see
  // _load below. Left null otherwise so _ProfileBody never even attempts
  // these sections for a non-friend, pending, or declined relationship.
  Future<List<VenueEntry>>? _visitedFuture;
  Future<List<PassportVenue>>? _wishlistFuture;
  Future<List<Event>>? _goingFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _repo.getProfileIdentity(widget.userId);
      _visitedFuture = null;
      _wishlistFuture = null;
      _goingFuture = null;
    });
    _future.then((identity) {
      if (!mounted ||
          identity?.relationshipStatus != RelationshipStatus.accepted) {
        return;
      }
      setState(() {
        _visitedFuture = _visitedRepo.loadPassportVenues(widget.userId);
        _wishlistFuture = _wishlistRepo.loadWishlistVenues(widget.userId);
        _goingFuture = _attendanceRepo.getFriendUpcomingAttendance(
          widget.userId,
        );
      });
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: CsTypography.metadata.copyWith(
            color: isError ? AppColors.textOnDark : Colors.black,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.gold,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendRequest() async {
    try {
      await _repo.sendRequest(widget.userId);
      _load();
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _accept(String friendshipId) async {
    try {
      await _repo.acceptRequest(friendshipId);
      _load();
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _decline(String friendshipId) async {
    try {
      await _repo.declineRequest(friendshipId);
      _load();
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _removeFriend() async {
    // Needs the friendship id, which get_profile_identity doesn't
    // return — the outgoing/incoming id isn't relevant once accepted, so
    // resolve it via the friends list rather than adding a new RPC solely
    // to look up one id (getFriends() is already cheap and cached-free).
    final friends = await _repo.getFriends();
    final match = friends.where((f) => f.friendId == widget.userId);
    if (match.isEmpty) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.brandGreenLight,
        title: Text(
          'Remove friend?',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.textOnDark,
            fontSize: 20,
          ),
        ),
        content: Text(
          'You will no longer be friends. Either of you can send a new '
          'request later.',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.removeFriendship(match.first.friendshipId);
      _load();
    } catch (_) {
      _showSnack('Could not remove. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                CsSpacing.base,
                CsSpacing.sm,
                CsSpacing.base,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: EditorialBackButton(),
              ),
            ),
            Expanded(
              child: FutureBuilder<ProfileIdentity?>(
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
                  final identity = snap.data;
                  if (snap.hasError || identity == null) {
                    return Center(
                      child: Text(
                        'Could not load this profile',
                        style: CsTypography.body.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    );
                  }
                  return _ProfileBody(
                    identity: identity,
                    visitedFuture: _visitedFuture,
                    wishlistFuture: _wishlistFuture,
                    goingFuture: _goingFuture,
                    onSendRequest: _sendRequest,
                    onAccept: () async {
                      final friendshipId = await _incomingFriendshipId(
                        identity.id,
                      );
                      if (friendshipId != null) _accept(friendshipId);
                    },
                    onDecline: () async {
                      final friendshipId = await _incomingFriendshipId(
                        identity.id,
                      );
                      if (friendshipId != null) _decline(friendshipId);
                    },
                    onRemove: _removeFriend,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _incomingFriendshipId(String requesterId) async {
    final incoming = await _repo.getIncomingRequests();
    final match = incoming.where((r) => r.otherUserId == requesterId);
    return match.isEmpty ? null : match.first.friendshipId;
  }
}

class _ProfileBody extends StatelessWidget {
  final ProfileIdentity identity;
  final Future<List<VenueEntry>>? visitedFuture;
  final Future<List<PassportVenue>>? wishlistFuture;
  final Future<List<Event>>? goingFuture;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onRemove;

  const _ProfileBody({
    required this.identity,
    required this.visitedFuture,
    required this.wishlistFuture,
    required this.goingFuture,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final words = identity.label.trim().split(' ').where((w) => w.isNotEmpty);
    final initials = words.isEmpty
        ? '?'
        : words.map((w) => w[0]).take(2).join().toUpperCase();
    final accepted = identity.relationshipStatus == RelationshipStatus.accepted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: CsSpacing.pageHorizontal,
      ).copyWith(bottom: CsSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: CsSpacing.xl),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandGreenLight,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child:
                (identity.avatarUrl != null && identity.avatarUrl!.isNotEmpty)
                ? ClipOval(
                    child: Image.network(
                      identity.avatarUrl!,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Text(
                        initials,
                        style: CsTypography.screenTitle.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  )
                : Text(
                    initials,
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
          ),
          const SizedBox(height: CsSpacing.lg),
          Text(
            identity.displayName?.trim().isNotEmpty == true
                ? identity.displayName!
                : identity.label,
            textAlign: TextAlign.center,
            style: CsTypography.screenTitle.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          if (identity.username != null) ...[
            const SizedBox(height: 4),
            Text(
              '@${identity.username}',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
          const SizedBox(height: CsSpacing.xxl),
          _RelationshipAction(
            status: identity.relationshipStatus,
            onSendRequest: onSendRequest,
            onAccept: onAccept,
            onDecline: onDecline,
            onRemove: onRemove,
          ),
          if (accepted) ...[
            const SizedBox(height: CsSpacing.section),
            Align(
              alignment: Alignment.centerLeft,
              child: _FriendVisitedSection(future: visitedFuture),
            ),
            const SizedBox(height: CsSpacing.xxl),
            Align(
              alignment: Alignment.centerLeft,
              child: _FriendWishlistSection(future: wishlistFuture),
            ),
            const SizedBox(height: CsSpacing.xxl),
            Align(
              alignment: Alignment.centerLeft,
              child: _FriendGoingSection(future: goingFuture),
            ),
          ],
        ],
      ),
    );
  }
}

class _RelationshipAction extends StatelessWidget {
  final RelationshipStatus status;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onRemove;

  const _RelationshipAction({
    required this.status,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case RelationshipStatus.none:
        return SizedBox(
          width: double.infinity,
          child: CsPrimaryButton(
            label: 'Add friend',
            icon: Icons.person_add_alt_1_rounded,
            onTap: onSendRequest,
          ),
        );
      case RelationshipStatus.pendingSent:
        return Text(
          'Request sent',
          style: CsTypography.bodyMedium.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        );
      case RelationshipStatus.pendingReceived:
        return Row(
          children: [
            Expanded(
              child: CsSecondaryButton(label: 'Decline', onTap: onDecline),
            ),
            const SizedBox(width: CsSpacing.md),
            Expanded(
              child: CsPrimaryButton(label: 'Accept', onTap: onAccept),
            ),
          ],
        );
      case RelationshipStatus.accepted:
        return Column(
          children: [
            Text(
              'Friends',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: CsSpacing.md),
            TextButton(
              onPressed: onRemove,
              child: Text(
                'Remove friend',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ),
          ],
        );
      case RelationshipStatus.declined:
        return Text(
          'Unavailable',
          style: CsTypography.bodyMedium.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        );
    }
  }
}

/// One (venue, visit) pair — [VenueEntry] groups every visit under its
/// venue for Passport's own grouped display; VISITED instead flattens to
/// one row per visit, newest first overall, per the task's own explicit
/// ordering rule.
class _VenueVisit {
  final PassportVenue venue;
  final Visit visit;
  const _VenueVisit(this.venue, this.visit);
}

// Shared by VISITED and WISHLIST (Step 2B §2/§3): opens the canonical,
// unmodified RestaurantDetailScreen/HotelDetailScreen — never a
// friend-specific detail wrapper. Every normal venue action there
// (Wishlist toggle, external links, Add Visit) already targets only
// Supabase.instance.client.auth.currentUser — the viewer's own data —
// regardless of how the screen was reached, so no extra plumbing is
// needed to keep a friend's own Wishlist/visits untouched.
void _openVenue(BuildContext context, PassportVenue venue) {
  switch (venue) {
    case RestaurantVenue(:final restaurant):
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
        ),
      );
    case HotelVenue(:final hotel):
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
      );
  }
}

class _FriendVisitedSection extends StatelessWidget {
  final Future<List<VenueEntry>>? future;
  const _FriendVisitedSection({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VenueEntry>>(
      future: future,
      builder: (context, snap) {
        final entries = snap.data ?? const <VenueEntry>[];
        final loading = snap.connectionState == ConnectionState.waiting;
        final rows = <_VenueVisit>[
          for (final entry in entries)
            for (final visit in entry.visits) _VenueVisit(entry.venue, visit),
        ]..sort((a, b) => b.visit.visitedOn.compareTo(a.visit.visitedOn));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VISITED',
              style: CsTypography.eyebrow.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.md),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
                  child: CircularProgressIndicator(
                    color: AppColors.gold,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else if (snap.hasError)
              Text(
                'Could not load visits.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              )
            else if (rows.isEmpty)
              // Deliberately doesn't say "hasn't visited anywhere" —
              // they may simply have no visits marked visible to friends
              // (task §13's explicit empty-state instruction).
              Text(
                'No shared visits yet.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: CsSpacing.md),
                    FriendVisitTile(
                      venue: rows[i].venue,
                      visit: rows[i].visit,
                      onTap: () => _openVenue(context, rows[i].venue),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class _FriendWishlistSection extends StatelessWidget {
  final Future<List<PassportVenue>>? future;
  const _FriendWishlistSection({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PassportVenue>>(
      future: future,
      builder: (context, snap) {
        final items = snap.data ?? const <PassportVenue>[];
        final loading = snap.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WISHLIST',
              style: CsTypography.eyebrow.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.md),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
                  child: CircularProgressIndicator(
                    color: AppColors.gold,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else if (snap.hasError)
              Text(
                'Could not load wishlist.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              )
            else if (items.isEmpty)
              Text(
                'Nothing saved yet.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: CsSpacing.md),
                    FriendWishlistTile(
                      venue: items[i],
                      onTap: () => _openVenue(context, items[i]),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class _FriendGoingSection extends StatelessWidget {
  final Future<List<Event>>? future;
  const _FriendGoingSection({required this.future});

  void _openEvent(BuildContext context, String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Event>>(
      future: future,
      builder: (context, snap) {
        final events = snap.data ?? const <Event>[];
        final loading = snap.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GOING',
              style: CsTypography.eyebrow.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(height: CsSpacing.md),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
                  child: CircularProgressIndicator(
                    color: AppColors.gold,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else if (snap.hasError)
              Text(
                'Could not load events.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              )
            else if (events.isEmpty)
              // Omitted entirely by the caller would also be reasonable
              // (task §13) — a restrained empty state is kept instead so
              // the section's presence doesn't silently shift depending
              // on data, matching VISITED/WISHLIST's own empty-state
              // treatment.
              Text(
                'No upcoming events yet.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < events.length; i++) ...[
                    if (i > 0) const SizedBox(height: CsSpacing.md),
                    FriendGoingTile(
                      event: events[i],
                      onTap: () => _openEvent(context, events[i].id),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}
