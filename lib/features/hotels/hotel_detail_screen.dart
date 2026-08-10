import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/circular_score_badge.dart';
import '../../core/widgets/personal_photos_preview.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/hotel.dart';
import '../../models/restaurant.dart';
import '../../models/save_outcome.dart';
import '../../models/visit.dart';
import '../restaurants/widgets/detail_section.dart';
import '../stays/widgets/add_stay_sheet.dart';
import 'widgets/hotel_actions.dart';
import 'widgets/hotel_hero.dart';
import 'widgets/hotel_info_card.dart';
import 'widgets/hotel_links.dart';
import 'widgets/hotel_restaurants_card.dart';
import 'widgets/hotel_stays_card.dart';

const _signInMessage = 'Sign in to save stays.';

/// Hotel detail screen: identity, location, external links, the Michelin
/// restaurants linked to this hotel (when any exist), and the user's own
/// stay history. No stay photos, ratings aggregation, or wishlist yet;
/// those are later slices.
class HotelDetailScreen extends StatefulWidget {
  final Hotel hotel;

  const HotelDetailScreen({super.key, required this.hotel});

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _photoRepo = PhotoRepository(Supabase.instance.client);
  late final Future<List<Restaurant>> _linkedRestaurantsFuture =
      widget.hotel.hasMichelinRestaurant
      ? _hotelRepo.getLinkedRestaurants(widget.hotel.id)
      : Future.value(const <Restaurant>[]);

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  bool _loadingStays = true;
  List<Visit> _stays = [];

  @override
  void initState() {
    super.initState();
    _loadStays();
  }

  Future<void> _loadStays() async {
    final uid = _userId;
    if (uid == null) {
      // Not signed in: nothing to load, catalogue browsing stays available.
      setState(() => _loadingStays = false);
      return;
    }
    try {
      final stays = await _visitedRepo.loadStaysForHotel(uid, widget.hotel.id);
      if (!mounted) return;
      setState(() {
        _stays = stays;
        _loadingStays = false;
      });
    } catch (_) {
      // A failed personal-state load shouldn't block catalogue browsing —
      // fall back to "not yet" rather than showing an error for this.
      if (!mounted) return;
      setState(() => _loadingStays = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: isError ? AppColors.textPrimary : Colors.black,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.gold,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAddStaySheet() async {
    final uid = _userId;
    if (uid == null) {
      _showSnack(_signInMessage, isError: true);
      return;
    }
    final result = await showAddStaySheet(
      context,
      hotel: widget.hotel,
      userId: uid,
      visitedRepository: _visitedRepo,
      photoRepository: _photoRepo,
    );
    if (result != null && mounted) {
      await _loadStays();
      if (!mounted) return;
      final photoErrors = result == SaveOutcome.savedWithPhotoErrors;
      _showSnack(
        photoErrors
            ? 'Stay saved, but some photos could not be uploaded.'
            : 'Stay saved',
        isError: photoErrors,
      );
    }
  }

  Future<void> _openMaps() async {
    final hotel = widget.hotel;
    final Uri uri;
    if (hotel.googlePlaceId != null && hotel.googlePlaceId!.isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${hotel.googlePlaceId}&query_place_id=${hotel.googlePlaceId}',
      );
    } else {
      final query = Uri.encodeComponent('${hotel.name} ${hotel.cityName}');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final hotel = widget.hotel;
    final michelinUrl = hotel.michelinUrl;
    final websiteUrl = hotel.websiteUrl;
    final isAuthenticated = _userId != null;
    final latestStay = _stays.isEmpty ? null : _stays.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          HotelHero(hotel: hotel),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The hero is the single primary identity area — the
                  // hotel name lives there only, never repeated here. Just
                  // city/country as light supporting context.
                  Text(
                    '${hotel.flagEmoji}  ${hotel.cityName}, '
                    '${hotel.countryName}',
                    style: AppTypography.metadata,
                  ),
                  const SizedBox(height: 36),

                  HotelActions(onTapAddStay: _openAddStaySheet),
                  const SizedBox(height: 24),

                  const SectionLabel('LINKS'),
                  const SizedBox(height: 12),
                  HotelLinks(
                    onOpenMaps: _openMaps,
                    onOpenMichelin:
                        (michelinUrl != null && michelinUrl.isNotEmpty)
                        ? () => _openUrl(michelinUrl)
                        : null,
                    onOpenWebsite: (websiteUrl != null && websiteUrl.isNotEmpty)
                        ? () => _openUrl(websiteUrl)
                        : null,
                  ),

                  if (hotel.hasMichelinRestaurant) ...[
                    const SizedBox(height: 36),
                    const SectionLabel('RESTAURANTS AT THIS HOTEL'),
                    const SizedBox(height: 12),
                    HotelRestaurantsCard(future: _linkedRestaurantsFuture),
                  ],
                  const SizedBox(height: 36),

                  if (isAuthenticated && latestStay != null) ...[
                    const SectionLabel('YOUR SCORE'),
                    const SizedBox(height: 14),
                    DetailCard(
                      child: Row(
                        children: [
                          CircularScoreBadge(
                            score: latestStay.rating,
                            caption: 'Overall',
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Latest stay',
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatStayDate(latestStay.visitedOn),
                                  style: AppTypography.metadata,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],

                  const SectionLabel('YOUR STAYS'),
                  const SizedBox(height: 12),
                  HotelStaysCard(
                    isAuthenticated: isAuthenticated,
                    loading: _loadingStays,
                    stays: _stays,
                    hotel: hotel,
                    signInMessage: _signInMessage,
                    onReturn: _loadStays,
                  ),

                  if (latestStay != null) ...[
                    const SizedBox(height: 36),
                    const SectionLabel('PERSONAL PHOTOS'),
                    const SizedBox(height: 12),
                    PersonalPhotosPreview(latestVisitId: latestStay.id),
                  ],

                  const SizedBox(height: 36),
                  const SectionLabel('INFORMATION'),
                  const SizedBox(height: 12),
                  HotelInfoCard(hotel: hotel),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatStayDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
