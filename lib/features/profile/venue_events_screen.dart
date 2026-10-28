import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/event_time.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/venue_events_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/venue_event.dart';
import '../events/event_date_format.dart';
import 'venue_event_form_screen.dart';

/// The groups a venue's events fall into, in the order shown.
enum VenueEventGroup {
  awaitingReview('AWAITING REVIEW'),
  notApproved('NOT APPROVED'),
  upcoming('LIVE'),
  past('PAST'),
  cancelled('CANCELLED');

  final String heading;
  const VenueEventGroup(this.heading);

  static VenueEventGroup of(VenueEvent e, DateTime now) {
    final ended = eventHasEnded(
      endAt: e.event.endAt,
      endDate: e.event.endDate,
      timezone: e.event.timezone,
      now: now,
    );
    return switch (e.status) {
      VenueEventStatus.cancelled => VenueEventGroup.cancelled,
      _ when ended => VenueEventGroup.past,
      VenueEventStatus.awaitingReview => VenueEventGroup.awaitingReview,
      VenueEventStatus.notApproved => VenueEventGroup.notApproved,
      VenueEventStatus.live => VenueEventGroup.upcoming,
    };
  }
}

/// A venue's own events, in every status (venue events phase 3):
/// awaiting review, not approved (with the reviewer's note), live, past
/// and cancelled — from get_venue_events, so every active manager sees
/// the same list. "Create an event" opens the form; tapping an event
/// edits it. Reached from the landing page (VenueManagementScreen).
class VenueEventsScreen extends StatefulWidget {
  final ManagedVenue venue;
  final VenueEventsRepository? repository;

  /// Test seam for "now".
  final DateTime Function()? now;

  const VenueEventsScreen({super.key, required this.venue, this.repository, this.now});

  /// The landing page's one-line summary of [events].
  static String summary(List<VenueEvent> events, DateTime now) {
    int count(VenueEventGroup g) =>
        events.where((e) => VenueEventGroup.of(e, now) == g).length;
    final upcoming = count(VenueEventGroup.upcoming);
    final waiting = count(VenueEventGroup.awaitingReview);
    final notApproved = count(VenueEventGroup.notApproved);
    final parts = [
      if (upcoming > 0) '$upcoming upcoming',
      if (waiting > 0) '$waiting awaiting review',
      if (notApproved > 0) '$notApproved not approved',
    ];
    return parts.isEmpty ? 'None upcoming' : parts.join(' · ');
  }

  @override
  State<VenueEventsScreen> createState() => _VenueEventsScreenState();
}

class _VenueEventsScreenState extends State<VenueEventsScreen> {
  late final _repo =
      widget.repository ?? VenueEventsRepository(Supabase.instance.client);
  late Future<List<VenueEvent>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _repo.loadVenueEvents(widget.venue);
    });
  }

  Future<void> _openForm([VenueEvent? existing]) async {
    final result = await Navigator.push<VenueEventFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => VenueEventFormScreen(
          venue: widget.venue,
          existing: existing,
          repository: widget.repository,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (result) {
          VenueEventFormResult.cancelled => 'Event cancelled.',
          _ when existing == null => 'Submitted for review.',
          _ when existing.status == VenueEventStatus.notApproved => 'Resubmitted for review.',
          _ => 'Saved.',
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Events',
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: FutureBuilder<List<VenueEvent>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.forestGreen, strokeWidth: 1.5),
            );
          }
          final now = widget.now?.call() ?? DateTime.now();
          final events = snap.data ?? const <VenueEvent>[];
          return RefreshIndicator(
            color: AppColors.forestGreen,
            backgroundColor: AppColors.warmWhite,
            onRefresh: () async => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.md,
                CsSpacing.pageHorizontal,
                CsSpacing.section,
              ),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: CsPrimaryButton(
                    label: 'Create an event',
                    surface: CsSurface.light,
                    onTap: () => _openForm(),
                  ),
                ),
                const SizedBox(height: CsSpacing.lg),
                if (snap.hasError)
                  Text(
                    'Could not load events. Pull down to try again.',
                    style: CsTypography.body.copyWith(color: AppColors.taupe),
                  )
                else if (events.isEmpty)
                  Text(
                    'No events yet. New events are reviewed by hand before they appear.',
                    style: CsTypography.body.copyWith(color: AppColors.taupe),
                  )
                else
                  for (final group in VenueEventGroup.values)
                    if (events.any((e) => VenueEventGroup.of(e, now) == group)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: CsSpacing.md, bottom: CsSpacing.sm),
                        child: Text(
                          group.heading,
                          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                        ),
                      ),
                      for (final e in events.where((e) => VenueEventGroup.of(e, now) == group))
                        _VenueEventRow(
                          event: e,
                          onTap: e.canEdit && group != VenueEventGroup.past
                              ? () => _openForm(e)
                              : null,
                        ),
                    ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VenueEventRow extends StatelessWidget {
  final VenueEvent event;
  final VoidCallback? onTap;
  const _VenueEventRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final note = event.reviewNote?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: CsSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CsRadius.medium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(CsSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.warmWhite,
              borderRadius: BorderRadius.circular(CsRadius.medium),
              border: Border.all(color: AppColors.subtleBorderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.event.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.bodyMedium.copyWith(color: AppColors.forestGreen),
                      ),
                      const SizedBox(height: 4),
                      // Precision-aware: a date-only event shows its date only.
                      Text(formatEventDateAndTime(event.event), style: CsTypography.metadata),
                      if (event.status == VenueEventStatus.notApproved &&
                          note != null &&
                          note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"$note"',
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.taupe,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded, color: AppColors.taupe),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
