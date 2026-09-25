import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/country_lookup.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/content_report.dart';
import '../../models/passport_venue.dart';
import '../../models/profile_identity.dart';
import '../../models/venue_entry.dart';
import '../../models/visit.dart';
import '../events/event_detail_screen.dart';
import '../hotels/hotel_detail_screen.dart';
import '../reports/widgets/report_content_sheet.dart';
import '../restaurants/restaurant_detail_screen.dart';
import '../stays/stay_detail_screen.dart';
import '../visits/visit_detail_screen.dart';
import 'friend_profile_data.dart';
import 'tabs/friend_profile_overview_tab.dart';
import 'tabs/friend_profile_passport_tab.dart';
import 'tabs/friend_profile_together_tab.dart';
import 'widgets/friend_profile_header.dart';
import 'widgets/friend_profile_plan_dinner_sheet.dart';

/// One (venue, visit) pair — [VenueEntry] groups every visit under its
/// venue for Passport's own grouped display; this screen instead flattens
/// to one row per visit, newest first overall — every stamp/verdict row
/// across all three tabs is built from this same shape.
class FriendVenueVisit {
  final PassportVenue venue;
  final Visit visit;
  const FriendVenueVisit(this.venue, this.visit);
}

/// Flattens/sorts VenueEntry groups into one row per visit, newest first.
List<FriendVenueVisit> flattenFriendVisits(List<VenueEntry> entries) => [
  for (final entry in entries)
    for (final visit in entry.visits) FriendVenueVisit(entry.venue, visit),
]..sort((a, b) => b.visit.visitedOn.compareTo(a.visit.visitedOn));

// Opens the canonical, unmodified RestaurantDetailScreen/HotelDetailScreen
// — never a friend-specific detail wrapper.
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

/// Opens the existing VisitDetailScreen/StayDetailScreen for [fv] — "Tik op
/// een stempel/rij opent de bestaande visit-detail", reused exactly as it
/// already exists, not a friend-specific copy.
///
/// The owner-only-controls gap this doc comment used to flag here is
/// fixed — both screens now gate their edit/delete controls on actual
/// ownership (`visit.userId == currentUser.id`), not just on RLS blocking
/// the mutation server-side (see EDITORIAL_REDESIGN_TRACKING.md's own
/// note on that fix, and VisitDetailScreen/StayDetailScreen's own
/// `_isOwner` getters). Safe to open for someone else's visit — including
/// from the Passport tab's own read-only friend booklet — without
/// re-checking anything here.
void openVisitDetail(BuildContext context, FriendVenueVisit fv) {
  switch (fv.venue) {
    case RestaurantVenue(:final restaurant):
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisitDetailScreen(restaurant: restaurant, visit: fv.visit),
        ),
      );
    case HotelVenue(:final hotel):
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StayDetailScreen(hotel: hotel, stay: fv.visit),
        ),
      );
  }
}

// Still exported for friend_activity_list_screen.dart's own
// FriendGoingListScreen/FriendInterestedListScreen (unchanged, out of
// scope for this pass — see this file's own class doc) — those two
// screens are reached from elsewhere, not from this redesigned profile
// itself anymore.
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

/// The friend-profile screen — reached from Community → Friends. Identity-
/// only for anyone not an accepted friend (unchanged legacy hero/action
/// UI, out of scope for this pass; the redesign below applies only once
/// [RelationshipStatus.accepted] is confirmed, the only case Friends' own
/// list can ever navigate here from).
///
/// ONE profile, three tabs (Overview / Passport / Together) plus a "Plan a
/// dinner" sheet — replaces the earlier three-separate-layouts-behind-a-
/// debug-picker pass entirely (see
/// docs/Architecture/EDITORIAL_REDESIGN_TRACKING.md for that history).
///
/// "Remove friend" lives in the shared header's "⋯" menu, with a
/// confirmation dialog — no standalone "Friends" text/button anywhere.
///
/// "Friends since" is deliberately NOT shown anywhere: neither
/// `get_profile_identity` nor `get_friends` returns when a friendship was
/// accepted (confirmed by reading both RPCs' own Dart models — no
/// createdAt/acceptedAt field exists on [ProfileIdentity] or `Friendship`).
/// TODO(friend-profile): surface a friendship acceptance date from the
/// backend (`get_friends`/`get_profile_identity` would need to start
/// returning the friendship row's own `created_at`/`accepted_at`) before
/// this can ever be shown — not guessed, not left as a silent gap.
class FriendProfileScreen extends StatefulWidget {
  final String userId;
  const FriendProfileScreen({super.key, required this.userId});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen>
    with SingleTickerProviderStateMixin {
  late final _repo = FriendshipRepository(Supabase.instance.client);
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _wishlistRepo = WishlistRepository(Supabase.instance.client);
  late final _photoRepo = PhotoRepository(Supabase.instance.client);
  // Constructed eagerly in initState, NOT as a `late final` field
  // initializer: `late final x = TabController(...)` only actually runs
  // the initializer the first time `x` is read, and this widget's own
  // `build()` doesn't always reach the point that reads it (its own
  // loading/error states return before ever building the tab view). A
  // widget test that only ever exercises those earlier states confirmed
  // the real failure mode this avoids: dispose() was the very first
  // read, lazily constructing a brand-new TabController — which needs
  // `vsync: this` to do a live ancestor lookup — AFTER this element was
  // already deactivated, throwing "Looking up a deactivated widget's
  // ancestor is unsafe." Eager construction in initState is the standard
  // TabController lifecycle for exactly this reason.
  late final TabController _tabController;
  late Future<ProfileIdentity?> _future;

  Future<FriendProfileLayoutData>? _layoutFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = _repo.getProfileIdentity(widget.userId);
      _layoutFuture = null;
    });
    _future
        .then((identity) {
          if (!mounted ||
              identity?.relationshipStatus != RelationshipStatus.accepted) {
            return;
          }
          setState(() {
            _layoutFuture = _loadLayoutData(identity!);
          });
        })
        .catchError((_) {});
  }

  Future<FriendProfileLayoutData> _loadLayoutData(
    ProfileIdentity identity,
  ) async {
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final results = await Future.wait([
      _visitedRepo.loadPassportVenues(widget.userId),
      _wishlistRepo.loadWishlistVenues(widget.userId),
      _wishlistRepo.loadWishlistVenues(myId),
      _repo.getProfileIdentity(myId),
    ]);
    final entries = results[0] as List<VenueEntry>;
    final wishlist = results[1] as List<PassportVenue>;
    final myWishlist = results[2] as List<PassportVenue>;
    final myIdentity = results[3] as ProfileIdentity?;
    final visits = flattenFriendVisits(entries);

    var coverPhotos = <String, String>{};
    try {
      coverPhotos = await _photoRepo.loadCoverPhotoUrlsForVisits(
        visits.map((v) => v.visit.id).toList(),
      );
    } catch (_) {
      // Photo rows just fall back to PhotoOrTile's own tile — never
      // blocks the rest of the screen.
    }

    // For the Passport tab's booklet — country chips, stamp semantic
    // labels. Same "never blocks the rest of the screen, falls back to
    // the bare country code" precedent as the main Passport screen's own
    // identical load.
    var countryNameByCode = <String, String>{};
    try {
      final countries = await getAllCountries(Supabase.instance.client);
      countryNameByCode = {for (final c in countries) c.code: c.name};
    } catch (_) {}

    return FriendProfileLayoutData(
      identity: identity,
      myIdentity: myIdentity,
      visitedEntries: entries,
      visits: visits,
      wishlist: wishlist,
      myWishlist: myWishlist,
      sharedKeys: sharedWishlistKeys(wishlist: wishlist, myWishlist: myWishlist),
      stats: FriendProfileStats.from(entries),
      coverPhotoByVisitId: coverPhotos,
      countryNameByCode: countryNameByCode,
    );
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
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      _showSnack('Could not remove. Please try again.', isError: true);
    }
  }

  Future<void> _blockUser(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        title: Text(
          'Block $name?',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        content: Text(
          "You'll no longer see each other's content, and any existing "
          'friendship will end.',
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
              'Block',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.blockUser(widget.userId);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Blocked $name.',
            style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
          ),
          backgroundColor: AppColors.forestGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not block. Please try again.', isError: true);
    }
  }

  Future<void> _reportProfile() => showReportSheet(
    context,
    contentType: ReportContentType.profile,
    contentId: widget.userId,
  );

  Future<String?> _incomingFriendshipId(String requesterId) async {
    final incoming = await _repo.getIncomingRequests();
    final match = incoming.where((r) => r.otherUserId == requesterId);
    return match.isEmpty ? null : match.first.friendshipId;
  }

  String _labelFor(ProfileIdentity identity) =>
      identity.displayName?.trim().isNotEmpty == true
      ? identity.displayName!
      : identity.label;

  Future<void> _planDinner(FriendProfileLayoutData data, PassportVenue? preselected) async {
    final sent = await showPlanDinnerSheet(
      context,
      data: data,
      viewerUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      preselected: preselected,
    );
    if (!sent || !mounted) return;
    _showSnack('Sent to ${data.friendName}.');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: FutureBuilder<ProfileIdentity?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }
            final identity = snap.data;
            if (snap.hasError || identity == null) {
              return const _ErrorState();
            }
            if (identity.relationshipStatus != RelationshipStatus.accepted) {
              return _NonFriendBody(
                identity: identity,
                onSendRequest: _sendRequest,
                onAccept: () async {
                  final friendshipId = await _incomingFriendshipId(identity.id);
                  if (friendshipId != null) _accept(friendshipId);
                },
                onDecline: () async {
                  final friendshipId = await _incomingFriendshipId(identity.id);
                  if (friendshipId != null) _decline(friendshipId);
                },
                onBlock: () => _blockUser(_labelFor(identity)),
                onReport: _reportProfile,
              );
            }
            return FutureBuilder<FriendProfileLayoutData>(
              future: _layoutFuture,
              builder: (context, layoutSnap) {
                if (layoutSnap.connectionState == ConnectionState.waiting ||
                    _layoutFuture == null) {
                  return const _LoadingState();
                }
                final data = layoutSnap.data;
                if (layoutSnap.hasError || data == null) {
                  return const _ErrorState();
                }
                return NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: FriendProfileHeaderTop(
                        friendPhoto: data.identity.avatarUrl,
                        friendLabel: data.friendName,
                        myPhoto: data.myIdentity?.avatarUrl,
                        myLabel: data.myIdentity?.label ?? 'You',
                        name: data.friendName,
                        username: data.identity.username,
                        stamps: data.stats.stamps,
                        stars: data.stats.totalStars,
                        onBack: () => Navigator.pop(context),
                        onRemoveFriend: _removeFriend,
                        onBlock: () => _blockUser(data.friendName),
                        onReport: _reportProfile,
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: FriendProfileTabBarDelegate(controller: _tabController),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      FriendProfileOverviewTab(
                        data: data,
                        onPlanTapped: () => _tabController.animateTo(2),
                      ),
                      FriendProfilePassportTab(data: data),
                      FriendProfileTogetherTab(
                        data: data,
                        wishlistRepo: _wishlistRepo,
                        viewerUserId:
                            Supabase.instance.client.auth.currentUser?.id ?? '',
                        onPlanDinner: (venue) => _planDinner(data, venue),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SimpleBackRow(),
      Expanded(
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.textOnDark,
            strokeWidth: 1.5,
          ),
        ),
      ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SimpleBackRow(),
      Expanded(
        child: Center(
          child: Text(
            'Could not load this profile',
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
        ),
      ),
    ],
  );
}

class _SimpleBackRow extends StatelessWidget {
  const _SimpleBackRow();

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(CsSpacing.base, CsSpacing.sm, CsSpacing.base, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: EditorialBackButton(color: AppColors.ivory),
      ),
    ),
  );
}

// ── Non-friend / pending relationship — unchanged legacy UI ────────────
// Out of scope for the editorial redesign (see this file's own class doc):
// Friends' own list only ever opens this screen for an accepted friend,
// so this path only matters for other entry points (e.g. search) this
// task wasn't asked to touch.

class _NonFriendBody extends StatelessWidget {
  final ProfileIdentity identity;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const _NonFriendBody({
    required this.identity,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: SafeArea(
          bottom: false,
          child: _Hero(
            identity: identity,
            onSendRequest: onSendRequest,
            onAccept: onAccept,
            onDecline: onDecline,
            onBlock: onBlock,
            onReport: onReport,
          ),
        ),
      ),
      SliverFillRemaining(
        hasScrollBody: false,
        child: ColoredBox(
          color: AppColors.ivory,
          child: SafeArea(top: false, child: const SizedBox.shrink()),
        ),
      ),
    ],
  );
}

class _Hero extends StatelessWidget {
  final ProfileIdentity identity;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const _Hero({
    required this.identity,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
    required this.onReport,
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
            padding: const EdgeInsets.fromLTRB(CsSpacing.base, CsSpacing.sm, CsSpacing.base, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                EditorialBackButton(color: AppColors.ivory),
                if (identity.id != Supabase.instance.client.auth.currentUser?.id)
                  _ProfileOverflowMenu(onBlock: onBlock, onReport: onReport),
              ],
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
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ivory),
                  alignment: Alignment.center,
                  child: (identity.avatarUrl != null && identity.avatarUrl!.isNotEmpty)
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
                  style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
                ),
                if (identity.username != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@${identity.username}',
                    style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
                  ),
                ],
                const SizedBox(height: CsSpacing.xl),
                _RelationshipAction(
                  status: identity.relationshipStatus,
                  onSendRequest: onSendRequest,
                  onAccept: onAccept,
                  onDecline: onDecline,
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

  const _RelationshipAction({
    required this.status,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
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
          style: CsTypography.bodyMedium.copyWith(color: AppColors.secondaryOnDark),
        );
      case RelationshipStatus.pendingReceived:
        return Row(
          children: [
            Expanded(child: CsSecondaryButton(label: 'Decline', onTap: onDecline)),
            const SizedBox(width: CsSpacing.md),
            Expanded(child: CsPrimaryButton(label: 'Accept', onTap: onAccept)),
          ],
        );
      case RelationshipStatus.accepted:
        return const SizedBox.shrink();
      case RelationshipStatus.declined:
        return Text(
          'Unavailable',
          style: CsTypography.bodyMedium.copyWith(color: AppColors.secondaryOnDark),
        );
    }
  }
}

class _ProfileOverflowMenu extends StatelessWidget {
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const _ProfileOverflowMenu({required this.onBlock, required this.onReport});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: AppColors.card,
    onSelected: (value) {
      if (value == 'block') onBlock();
      if (value == 'report') onReport();
    },
    itemBuilder: (context) => [
      const PopupMenuItem(
        value: 'report',
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.textPrimary, size: 18),
            SizedBox(width: 10),
            Text('Report profile'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'block',
        child: Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.error, size: 18),
            SizedBox(width: 10),
            Text('Block', style: TextStyle(color: AppColors.error)),
          ],
        ),
      ),
    ],
    child: Material(
      color: Colors.black.withValues(alpha: 0.24),
      shape: const CircleBorder(),
      child: const Padding(
        padding: EdgeInsets.all(9),
        child: Icon(Icons.more_horiz_rounded, color: AppColors.textOnDark, size: 19),
      ),
    ),
  );
}
