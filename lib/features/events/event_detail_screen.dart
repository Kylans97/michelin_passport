import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/detail_hero.dart';
import '../../data/repositories/events_repository.dart';
import '../../models/event.dart';
import '../explore/widgets/hotel_tile.dart';
import '../explore/widgets/restaurant_tile.dart';
import '../restaurants/widgets/detail_section.dart';
import 'event_date_format.dart';

/// Full event details: hero (photo-ready, brand-green fallback — same
/// pattern as Restaurant/Hotel Detail's own hero, since no event has a
/// verified image yet either), date/time, location, description, official
/// links, and every linked restaurant/hotel — reusing RestaurantTile/
/// HotelTile outright rather than a third venue-row widget, since those
/// already navigate to the real Detail screens on tap.
class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventsRepository _repo = EventsRepository(
    Supabase.instance.client,
  );

  bool _loading = true;
  bool _loadError = false;
  Event? _event;
  EventVenues _venues = const EventVenues(restaurants: [], hotels: []);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final eventFuture = _repo.loadEventById(widget.eventId);
      final venuesFuture = _repo.loadLinkedVenues(widget.eventId);
      final event = await eventFuture;
      final venues = await venuesFuture;
      if (!mounted) return;
      if (event == null) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
        return;
      }
      setState(() {
        _event = event;
        _venues = venues;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.gold,
            strokeWidth: 1.5,
          ),
        ),
      );
    }
    final event = _event;
    if (_loadError || event == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.textSecondary,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load this event',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _load,
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(color: AppColors.gold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final location = [
      if (event.venueName != null && event.venueName!.isNotEmpty)
        event.venueName,
      if (event.city != null && event.city!.isNotEmpty) event.city,
      event.countryCode,
    ].join(', ');
    final hasWebsite =
        event.officialUrl != null && event.officialUrl!.isNotEmpty;
    final hasTickets = event.ticketUrl != null && event.ticketUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          DetailHero(
            title: event.name,
            awardBadge: HeroBadge(
              icon: Icons.event_rounded,
              label: event.eventType.label,
            ),
            extraBadges: [
              if (event.isCancelled)
                const HeroBadge(
                  icon: Icons.cancel_outlined,
                  label: 'Cancelled',
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              // No horizontal inset here — RestaurantTile/HotelTile below
              // already carry their own 20px margin (they're designed for
              // full-bleed lists, see Explore), so every OTHER child in
              // this column pads itself individually instead, keeping a
              // single consistent left/right edge throughout.
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(location, style: AppTypography.metadata),
                  ),
                  const SizedBox(height: 28),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DetailCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            text:
                                '${formatEventDateTime(event.startAt)}\n'
                                'to ${formatEventDateTime(event.endAt)}',
                          ),
                          if (event.address != null &&
                              event.address!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _InfoRow(
                              icon: Icons.place_outlined,
                              text: event.address!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (event.description != null &&
                      event.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 28),
                          const SectionLabel('ABOUT'),
                          const SizedBox(height: 12),
                          Text(event.description!, style: AppTypography.body),
                        ],
                      ),
                    ),

                  if (hasWebsite || hasTickets)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              if (hasWebsite)
                                Expanded(
                                  child: SecondaryButton(
                                    icon: Icons.language_rounded,
                                    label: 'Website',
                                    onTap: () => _openUrl(event.officialUrl!),
                                  ),
                                ),
                              if (hasWebsite && hasTickets)
                                const SizedBox(width: 8),
                              if (hasTickets)
                                Expanded(
                                  child: SecondaryButton(
                                    icon: Icons.confirmation_number_outlined,
                                    label: 'Tickets',
                                    onTap: () => _openUrl(event.ticketUrl!),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  if (_venues.restaurants.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SectionLabel(
                        'RESTAURANTS (${_venues.restaurants.length})',
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final restaurant in _venues.restaurants)
                      RestaurantTile(restaurant: restaurant),
                  ],

                  if (_venues.hotels.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SectionLabel('HOTELS (${_venues.hotels.length})'),
                    ),
                    const SizedBox(height: 12),
                    for (final hotel in _venues.hotels) HotelTile(hotel: hotel),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.textSecondary, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}
