import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../core/widgets/section_divider.dart';
import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/event.dart';
import '../../models/event_attendance.dart';
import '../../models/passport_venue.dart';
import '../../models/profile_identity.dart';
import '../../models/venue_entry.dart';
import '../../models/visit.dart';
import '../events/event_detail_screen.dart';
import '../hotels/hotel_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'friend_activity_list_screen.dart';
import 'widgets/friend_going_tile.dart';
import 'widgets/friend_visit_tile.dart';
import 'widgets/friend_wishlist_tile.dart';

/// How many rows each of VISITED/WISHLIST/GOING shows before deferring to
/// "View all" — one shared constant so the three sections stay in lockstep
/// rather than drifting to different preview depths over time.
const _previewLimit = 4;

/// One screen for both a friend's profile and a non-friend's — the
/// difference is entirely in which action [relationshipStatus] resolves
/// to. Identity-only for anyone not an accepted friend — no visits,
/// ratings, photos, wishlist, or trips, per the non-friend-profile rule
/// Step 1 established.
///
/// Community/Friends UX Step 1: forest-green hero (back arrow, avatar,
/// name, relationship action) over an ivory body — the same canvas-split
/// composition Guides' catalogue headers established, deliberately
/// connecting this screen to the rest of the app's editorial language
/// rather than staying on the legacy dark canvas. VISITED/WISHLIST/GOING
/// are omitted entirely once loaded and confirmed empty, rather than each
/// showing its own "nothing here" line — see
/// docs/Architecture/COMMUNITY_FRIENDS_UX.md for the full reasoning.
///
/// For an ACCEPTED friend, also shows VISITED (every visit the database's
/// own RLS allows this viewer to read — see
/// [VisitedRepository.loadPassportVenues], unchanged, reused as-is: the
/// friends-visibility rewrite lives entirely in visits_read/photos_read,
/// never in this screen) and WISHLIST (same reuse of
/// [WishlistRepository.loadWishlistVenues]). Trips are never shown here —
/// planned_trips/planned_venues RLS remains strictly owner-only.
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
        _goingFuture = _attendanceRepo.getFriendUpcomingEvents(
          userId: widget.userId,
          status: EventIntentStatus.going,
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
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
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
        backgroundColor: AppColors.warmWhite,
        title: Text(
          'Remove friend?',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        content: Text(
          'You will no longer be friends. Either of you can send a new '
          'request later.',
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.taupe),
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
    // UI Polish pass: Scaffold.backgroundColor is deep-green (not ivory)
    // so the iOS status-bar area continues the hero seamlessly instead of
    // showing an ivory strip above it — see _Hero's own doc comment for
    // the full root-cause explanation (identical fix to
    // GuideCatalogueLayout's). AnnotatedRegion forces light status-bar
    // icons for exactly this screen.
    //
    // Green Token Consistency Migration: AppColors.deepGreen, not
    // forestGreen — the canonical primary brand dark surface.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: FutureBuilder<ProfileIdentity?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackRow(),
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.ivory,
                      child: SafeArea(
                        top: false,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.forestGreen,
                            strokeWidth: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            final identity = snap.data;
            if (snap.hasError || identity == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackRow(),
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.ivory,
                      child: SafeArea(
                        top: false,
                        child: Center(
                          child: Text(
                            'Could not load this profile',
                            style: CsTypography.body.copyWith(
                              color: AppColors.taupe,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return _ProfileBody(
              identity: identity,
              visitedFuture: _visitedFuture,
              wishlistFuture: _wishlistFuture,
              goingFuture: _goingFuture,
              onSendRequest: _sendRequest,
              onAccept: () async {
                final friendshipId = await _incomingFriendshipId(identity.id);
                if (friendshipId != null) _accept(friendshipId);
              },
              onDecline: () async {
                final friendshipId = await _incomingFriendshipId(identity.id);
                if (friendshipId != null) _decline(friendshipId);
              },
              onRemove: _removeFriend,
            );
          },
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

/// The back arrow while identity is still loading/failed — [_ProfileBody]
/// renders its own copy inside the forest-green hero once identity
/// resolves, so this standalone version only ever appears briefly. Ivory
/// (not forest-green) to stay legible now that the Scaffold behind it is
/// forest-green everywhere; `SafeArea(bottom: false)` gives it the correct
/// top inset without also padding the ivory content below it a second
/// time.
class _BackRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.base,
        CsSpacing.sm,
        CsSpacing.base,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: EditorialBackButton(color: AppColors.ivory),
      ),
    ),
  );
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
    final accepted = identity.relationshipStatus == RelationshipStatus.accepted;

    // The whole body scrolls as one unit, hero included — never a fixed
    // hero with no escape route. A user-generated display name can be
    // arbitrarily long, and for a non-accepted relationship there's no
    // activity content below to absorb overflow, so the hero itself must
    // stay inside the scrollable rather than being pinned.
    //
    // UI Polish pass: CustomScrollView + SliverFillRemaining(hasScrollBody:
    // false) rather than SingleChildScrollView+Column — the ivory content
    // area still needs to visually reach the bottom of the screen even
    // when short (a non-accepted profile, or a friend with little
    // activity), which SingleChildScrollView alone can't do; SliverFill-
    // Remaining gives it a MINIMUM height of "whatever's left in the
    // viewport" while still letting the whole page grow/scroll normally if
    // the hero or the activity sections end up taller than the screen —
    // preserving the original no-overflow guarantee above.
    return Expanded(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: _Hero(
                identity: identity,
                onSendRequest: onSendRequest,
                onAccept: onAccept,
                onDecline: onDecline,
                onRemove: onRemove,
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: ColoredBox(
              color: AppColors.ivory,
              child: SafeArea(
                top: false,
                child: accepted
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CsSpacing.pageHorizontal,
                        ).copyWith(top: CsSpacing.lg, bottom: CsSpacing.xxl),
                        child: _ActivitySections(
                          userId: identity.id,
                          friendLabel:
                              identity.displayName?.trim().isNotEmpty == true
                              ? identity.displayName!
                              : identity.label,
                          visitedFuture: visitedFuture,
                          wishlistFuture: wishlistFuture,
                          goingFuture: goingFuture,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// UI Polish pass: this paints its own deep-green [ColoredBox] as
/// always, but the top iOS safe-area strip above it is no longer a
/// separate concern — [_FriendProfileScreenState.build] now sets
/// [Scaffold.backgroundColor] to deep-green directly, so that gap (and
/// every other bit of unpainted space this screen has) reads as a
/// seamless continuation of this hero rather than the ivory strip
/// physical-device review found before this pass.
///
/// Green Token Consistency Migration: AppColors.deepGreen, not
/// forestGreen — the canonical primary brand dark surface.
class _Hero extends StatelessWidget {
  final ProfileIdentity identity;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onRemove;

  const _Hero({
    required this.identity,
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

    return ColoredBox(
      color: AppColors.deepGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              child: EditorialBackButton(color: AppColors.ivory),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.sm,
              CsSpacing.pageHorizontal,
              CsSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.ivory,
                  ),
                  alignment: Alignment.center,
                  child:
                      (identity.avatarUrl != null &&
                          identity.avatarUrl!.isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            identity.avatarUrl!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Text(
                              initials,
                              style: CsTypography.screenTitle.copyWith(
                                color: AppColors.forestGreen,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          initials,
                          style: CsTypography.screenTitle.copyWith(
                            color: AppColors.forestGreen,
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
                    color: AppColors.ivory,
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
                const SizedBox(height: CsSpacing.xl),
                _RelationshipAction(
                  status: identity.relationshipStatus,
                  onSendRequest: onSendRequest,
                  onAccept: onAccept,
                  onDecline: onDecline,
                  onRemove: onRemove,
                ),
              ],
            ),
          ),
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
              style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory),
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
/// one row per visit, newest first overall.
class FriendVenueVisit {
  final PassportVenue venue;
  final Visit visit;
  const FriendVenueVisit(this.venue, this.visit);
}

/// Flattens/sorts VenueEntry groups into one row per visit, newest first —
/// shared by the profile's preview section and [FriendVisitedListScreen]'s
/// full list, so the two never drift out of sync on ordering.
List<FriendVenueVisit> flattenFriendVisits(List<VenueEntry> entries) => [
  for (final entry in entries)
    for (final visit in entry.visits) FriendVenueVisit(entry.venue, visit),
]..sort((a, b) => b.visit.visitedOn.compareTo(a.visit.visitedOn));

// Shared by VISITED and WISHLIST: opens the canonical, unmodified
// RestaurantDetailScreen/HotelDetailScreen — never a friend-specific
// detail wrapper. Every normal venue action there (Wishlist toggle,
// external links, Add Visit) already targets only
// Supabase.instance.client.auth.currentUser — the viewer's own data —
// regardless of how the screen was reached, so no extra plumbing is
// needed to keep a friend's own Wishlist/visits untouched.
void openFriendVenue(BuildContext context, PassportVenue venue) {
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

void openFriendEvent(BuildContext context, String eventId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: eventId,
        sourceSurface: AnalyticsSourceSurface.friendActivity,
        sourceContext: AnalyticsSourceContext.friendSignal,
      ),
    ),
  );
}

/// The three activity sections together, each entirely omitted once its
/// future resolves to zero items — never a stack of "nothing here" lines
/// (Community/Friends UX Step 1 §18). Hairlines are only inserted between
/// two sections that both actually render, so an omitted middle section
/// never leaves an orphan divider.
class _ActivitySections extends StatelessWidget {
  final String userId;
  final String friendLabel;
  final Future<List<VenueEntry>>? visitedFuture;
  final Future<List<PassportVenue>>? wishlistFuture;
  final Future<List<Event>>? goingFuture;

  const _ActivitySections({
    required this.userId,
    required this.friendLabel,
    required this.visitedFuture,
    required this.wishlistFuture,
    required this.goingFuture,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FriendVisitedSection(
        userId: userId,
        friendLabel: friendLabel,
        future: visitedFuture,
      ),
      _FriendWishlistSection(
        userId: userId,
        friendLabel: friendLabel,
        future: wishlistFuture,
      ),
      _FriendGoingSection(
        userId: userId,
        friendLabel: friendLabel,
        future: goingFuture,
      ),
    ],
  );
}

/// Section eyebrow + optional "View all" trigger — one consistent pattern
/// shared by VISITED/WISHLIST/GOING.
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: CsTypography.eyebrow.copyWith(color: AppColors.taupe)),
      if (onViewAll != null)
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            'View all',
            style: CsTypography.metadata.copyWith(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );
}

class _FriendVisitedSection extends StatelessWidget {
  final String userId;
  final String friendLabel;
  final Future<List<VenueEntry>>? future;
  const _FriendVisitedSection({
    required this.userId,
    required this.friendLabel,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VenueEntry>>(
      future: future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        if (!loading && !snap.hasError) {
          final rows = flattenFriendVisits(snap.data ?? const []);
          if (rows.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'VISITED',
                onViewAll: rows.length > _previewLimit
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FriendVisitedListScreen(
                            userId: userId,
                            friendLabel: friendLabel,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: CsSpacing.sm),
              for (var i = 0; i < rows.length && i < _previewLimit; i++) ...[
                if (i > 0) const _RowDivider(),
                FriendVisitTile(
                  venue: rows[i].venue,
                  visit: rows[i].visit,
                  onTap: () => openFriendVenue(context, rows[i].venue),
                ),
              ],
              const SectionDivider(),
            ],
          );
        }
        if (snap.hasError) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.forestGreen,
              strokeWidth: 1.5,
            ),
          ),
        );
      },
    );
  }
}

class _FriendWishlistSection extends StatelessWidget {
  final String userId;
  final String friendLabel;
  final Future<List<PassportVenue>>? future;
  const _FriendWishlistSection({
    required this.userId,
    required this.friendLabel,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PassportVenue>>(
      future: future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        if (!loading && !snap.hasError) {
          final items = snap.data ?? const [];
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'WISHLIST',
                onViewAll: items.length > _previewLimit
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FriendWishlistListScreen(
                            userId: userId,
                            friendLabel: friendLabel,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: CsSpacing.sm),
              for (var i = 0; i < items.length && i < _previewLimit; i++) ...[
                if (i > 0) const _RowDivider(),
                FriendWishlistTile(
                  venue: items[i],
                  onTap: () => openFriendVenue(context, items[i]),
                ),
              ],
              const SectionDivider(),
            ],
          );
        }
        if (snap.hasError) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.forestGreen,
              strokeWidth: 1.5,
            ),
          ),
        );
      },
    );
  }
}

class _FriendGoingSection extends StatelessWidget {
  final String userId;
  final String friendLabel;
  final Future<List<Event>>? future;
  const _FriendGoingSection({
    required this.userId,
    required this.friendLabel,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Event>>(
      future: future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        if (!loading && !snap.hasError) {
          final events = snap.data ?? const [];
          if (events.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'GOING',
                onViewAll: events.length > _previewLimit
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FriendGoingListScreen(
                            userId: userId,
                            friendLabel: friendLabel,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: CsSpacing.sm),
              for (var i = 0; i < events.length && i < _previewLimit; i++) ...[
                if (i > 0) const _RowDivider(),
                FriendGoingTile(
                  event: events[i],
                  onTap: () => openFriendEvent(context, events[i].id),
                ),
              ],
            ],
          );
        }
        if (snap.hasError) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.forestGreen,
              strokeWidth: 1.5,
            ),
          ),
        );
      },
    );
  }
}

/// The same strengthened taupe hairline token established for Guides'
/// dense result lists — [GuideVenueCardDivider]'s own value, inlined here
/// rather than importing across the Guides/Friends feature boundary (see
/// docs/Architecture/COMMUNITY_FRIENDS_UX.md's reuse note).
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.75, color: AppColors.taupe.withValues(alpha: 0.55));
}
