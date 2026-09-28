import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/venue_manager_repository.dart';
import '../../models/managed_venue.dart';
import 'venue_management_screen.dart';

/// My Venues — read-only itself: lists what the signed-in user actively
/// manages and opens the management view for the one tapped. Editing
/// (about text today; photos/events/problem-reporting are each their own
/// later task) lives in [VenueManagementScreen], not here — this screen
/// was previously wired to open each venue's PUBLIC detail page instead
/// (per the task that built it, before a management view existed to
/// route to); now that one exists, tapping a row opens management, which
/// is the more useful default for someone who opened "My venues"
/// specifically. The public detail page itself is unchanged and still
/// reachable the normal way (Explore/search/etc.) — nothing about it was
/// removed or restructured.
///
/// Reads venue_managers_restaurants/_hotels/_private_chefs only (via
/// [VenueManagerRepository], already scoped to revoked_at is null) —
/// never claims_restaurants/claims_hotels/claims_private_chefs, which
/// are a historical request, not the current state. Only reachable from
/// Profile's own entry point, which hides itself entirely when this
/// screen would have nothing to show — see profile_screen.dart's own
/// FutureBuilder-gated row.
class MyVenuesScreen extends StatefulWidget {
  // Optional DI seam, matching ClaimVenueScreen/NotificationsScreen's own
  // established convention — defaults to the real Supabase-backed
  // repository so the one real call site (Profile) is unaffected.
  final VenueManagerRepository? repository;

  const MyVenuesScreen({super.key, this.repository});

  @override
  State<MyVenuesScreen> createState() => _MyVenuesScreenState();
}

class _MyVenuesScreenState extends State<MyVenuesScreen> {
  late final _repository = widget.repository ?? VenueManagerRepository(Supabase.instance.client);

  late Future<List<ManagedVenue>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _repository.loadMyManagedVenues();
    });
  }

  void _openVenue(ManagedVenue venue) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => VenueManagementScreen(venue: venue)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'My venues',
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: FutureBuilder<List<ManagedVenue>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.forestGreen, strokeWidth: 1.5),
            );
          }
          if (snap.hasError) return _errorState();

          final venues = snap.data ?? const [];
          if (venues.isEmpty) return _emptyState();

          return RefreshIndicator(
            color: AppColors.forestGreen,
            backgroundColor: AppColors.warmWhite,
            onRefresh: () async => _load(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
                vertical: CsSpacing.md,
              ),
              itemCount: venues.length,
              separatorBuilder: (_, _) => Container(height: 1, color: AppColors.cardBorder),
              itemBuilder: (context, i) {
                final venue = venues[i];
                return _ManagedVenueRow(venue: venue, onTap: () => _openVenue(venue));
              },
            ),
          );
        },
      ),
    );
  }

  Widget _errorState() {
    return RefreshIndicator(
      color: AppColors.forestGreen,
      backgroundColor: AppColors.warmWhite,
      onRefresh: () async => _load(),
      child: ListView(
        // A scrollable single child, not a bare Center — RefreshIndicator
        // needs a scrollable descendant to arm its pull gesture even when
        // the content itself doesn't scroll.
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(CsSpacing.xl),
                child: Text(
                  'Something went wrong. Pull down to try again.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Not reachable from the UI — Profile's own entry point hides itself
  // whenever there's nothing to show (see profile_screen.dart) — but
  // handled gracefully anyway: access could be revoked while this
  // screen is already open. Same RefreshIndicator-over-ListView shape
  // as the error state, so pulling down still works here too.
  Widget _emptyState() {
    return RefreshIndicator(
      color: AppColors.forestGreen,
      backgroundColor: AppColors.warmWhite,
      onRefresh: () async => _load(),
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(CsSpacing.xl),
                child: Text(
                  "You don't manage any venues right now.",
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagedVenueRow extends StatelessWidget {
  final ManagedVenue venue;
  final VoidCallback onTap;

  const _ManagedVenueRow({required this.venue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final city = venue.cityName;
    final subtitle = (city != null && city.isNotEmpty) ? '$city · ${venue.typeLabel}' : venue.typeLabel;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(venue.name, style: CsTypography.body.copyWith(color: AppColors.forestGreen)),
      subtitle: Text(subtitle, style: CsTypography.metadata.copyWith(color: AppColors.taupe)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.taupe),
      onTap: onTap,
    );
  }
}
