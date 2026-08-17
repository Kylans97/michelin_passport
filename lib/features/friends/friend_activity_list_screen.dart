import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/event_attendance_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/event.dart';
import '../../models/passport_venue.dart';
import '../../models/venue_entry.dart';
import 'friend_profile_screen.dart';
import 'widgets/friend_going_tile.dart';
import 'widgets/friend_visit_tile.dart';
import 'widgets/friend_wishlist_tile.dart';

/// The "View all" destination for each of Friend Profile's three preview
/// sections (Community/Friends UX Step 1 §13/§19) — the smallest canonical
/// list screen necessary: a fresh, independent fetch (never data threaded
/// through navigation, matching the rest of this feature's "no caching,
/// always a live RLS-gated read" posture) rendered as the same row/hairline
/// language the preview already uses. No search/filter — a friend's full
/// activity list is expected to stay short; add filtering later only if
/// real usage shows it's needed.
class _FriendActivityHeader extends StatelessWidget {
  final String eyebrow;
  final String title;

  const _FriendActivityHeader({required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.forestGreen,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: CsTypography.eyebrow.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: CsTypography.screenTitle.copyWith(
                  color: AppColors.ivory,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.75, color: AppColors.taupe.withValues(alpha: 0.55));
}

class FriendVisitedListScreen extends StatefulWidget {
  final String userId;
  final String friendLabel;
  const FriendVisitedListScreen({
    super.key,
    required this.userId,
    required this.friendLabel,
  });

  @override
  State<FriendVisitedListScreen> createState() =>
      _FriendVisitedListScreenState();
}

class _FriendVisitedListScreenState extends State<FriendVisitedListScreen> {
  late final _future = VisitedRepository(
    Supabase.instance.client,
  ).loadPassportVenues(widget.userId);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.ivory,
    body: SafeArea(
      child: Column(
        children: [
          _FriendActivityHeader(eyebrow: widget.friendLabel, title: 'Visited'),
          Expanded(
            child: FutureBuilder<List<VenueEntry>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                      strokeWidth: 1.5,
                    ),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Could not load visits.',
                      style: CsTypography.body.copyWith(color: AppColors.taupe),
                    ),
                  );
                }
                final rows = flattenFriendVisits(snap.data ?? const []);
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      'No shared visits yet.',
                      style: CsTypography.body.copyWith(color: AppColors.taupe),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CsSpacing.pageHorizontal,
                    vertical: CsSpacing.lg,
                  ).copyWith(bottom: CsSpacing.xxl),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const _RowDivider(),
                  itemBuilder: (context, i) => FriendVisitTile(
                    venue: rows[i].venue,
                    visit: rows[i].visit,
                    onTap: () => openFriendVenue(context, rows[i].venue),
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

class FriendWishlistListScreen extends StatefulWidget {
  final String userId;
  final String friendLabel;
  const FriendWishlistListScreen({
    super.key,
    required this.userId,
    required this.friendLabel,
  });

  @override
  State<FriendWishlistListScreen> createState() =>
      _FriendWishlistListScreenState();
}

class _FriendWishlistListScreenState extends State<FriendWishlistListScreen> {
  late final _future = WishlistRepository(
    Supabase.instance.client,
  ).loadWishlistVenues(widget.userId);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.ivory,
    body: SafeArea(
      child: Column(
        children: [
          _FriendActivityHeader(eyebrow: widget.friendLabel, title: 'Wishlist'),
          Expanded(
            child: FutureBuilder<List<PassportVenue>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                      strokeWidth: 1.5,
                    ),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Could not load wishlist.',
                      style: CsTypography.body.copyWith(color: AppColors.taupe),
                    ),
                  );
                }
                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Nothing saved yet.',
                      style: CsTypography.body.copyWith(color: AppColors.taupe),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CsSpacing.pageHorizontal,
                    vertical: CsSpacing.lg,
                  ).copyWith(bottom: CsSpacing.xxl),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const _RowDivider(),
                  itemBuilder: (context, i) => FriendWishlistTile(
                    venue: items[i],
                    onTap: () => openFriendVenue(context, items[i]),
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

class FriendGoingListScreen extends StatefulWidget {
  final String userId;
  final String friendLabel;
  const FriendGoingListScreen({
    super.key,
    required this.userId,
    required this.friendLabel,
  });

  @override
  State<FriendGoingListScreen> createState() => _FriendGoingListScreenState();
}

class _FriendGoingListScreenState extends State<FriendGoingListScreen> {
  late final _future = EventAttendanceRepository(
    Supabase.instance.client,
  ).getFriendUpcomingAttendance(widget.userId);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.ivory,
    body: SafeArea(
      child: Column(
        children: [
          _FriendActivityHeader(eyebrow: widget.friendLabel, title: 'Going'),
          Expanded(
            child: FutureBuilder<List<Event>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                      strokeWidth: 1.5,
                    ),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Could not load events.',
                      style: CsTypography.body.copyWith(color: AppColors.taupe),
                    ),
                  );
                }
                final events = snap.data ?? const [];
                if (events.isEmpty) {
                  return Center(
                    child: Text(
                      'No upcoming events yet.',
                      style: CsTypography.body.copyWith(color: AppColors.taupe),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CsSpacing.pageHorizontal,
                    vertical: CsSpacing.lg,
                  ).copyWith(bottom: CsSpacing.xxl),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const _RowDivider(),
                  itemBuilder: (context, i) => FriendGoingTile(
                    event: events[i],
                    onTap: () => openFriendEvent(context, events[i].id),
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
