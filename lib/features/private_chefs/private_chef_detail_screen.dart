import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/section_divider.dart';
import '../../data/repositories/private_chef_repository.dart';
import '../../models/private_chef.dart';
import '../../models/private_chef_education.dart';
import '../../models/private_chef_photo.dart';
import '../../models/private_chef_restaurant_history.dart';
import '../../models/venue_country.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'private_chef_location.dart';
import 'widgets/private_chef_connect_section.dart';
import 'widgets/private_chef_education_row.dart';
import 'widgets/private_chef_experience_section.dart';
import 'widgets/private_chef_hero.dart';
import 'widgets/private_chef_provenance_row.dart';
import 'widgets/private_chef_states.dart';

/// Chef Detail — takes only [chefId] and resolves it internally (matching
/// [EventDetailScreen]'s `eventId`-only convention, not Restaurant/Hotel
/// Detail's "caller already has the full model" convention), because a
/// chef must be independently re-verifiable as currently published (a
/// removed/archived chef must show [PrivateChefNotFoundState], not stale
/// data) and because the repository's own `getPrivateChefById` is a
/// required, genuinely exercised capability here, not spec work.
///
/// Canonical hierarchy (PRIVATE_CHEFS.md, Step 2B): HERO → ABOUT →
/// BACKGROUND → THE EXPERIENCE → CONNECT. No enquiry form yet (Step 3) —
/// no CTA of any kind is rendered here in the meantime; see [_body]'s
/// trailing comment for the seam.
///
/// Step 2B — BACKGROUND (renamed from "Restaurant Provenance"): a chef's
/// relevant professional background is broader than kitchen positions —
/// hospitality, service, wine, and education can all be curation-relevant
/// (PRIVATE_CHEFS.md, Step 2B §1). The section merges two distinct
/// sources — restaurant background ([PrivateChefRestaurantHistory], via
/// [PrivateChefProvenanceRow]) and education background
/// ([PrivateChefEducation], via [PrivateChefEducationRow]) — restaurant
/// items first, then education items, matching the approved worked
/// example exactly. The two stay separate, simply-shaped data sources
/// under one editorial heading; see the education migration's own header
/// comment for why they were deliberately NOT collapsed into one
/// generalized/polymorphic background table.
class PrivateChefDetailScreen extends StatefulWidget {
  final String chefId;

  const PrivateChefDetailScreen({super.key, required this.chefId});

  @override
  State<PrivateChefDetailScreen> createState() =>
      _PrivateChefDetailScreenState();
}

class _PrivateChefDetailScreenState extends State<PrivateChefDetailScreen> {
  late final _repo = PrivateChefRepository(Supabase.instance.client);

  PrivateChef? _chef;
  List<PrivateChefRestaurantHistory> _history = const [];
  List<PrivateChefEducation> _education = const [];
  List<PrivateChefPhoto> _photos = const [];
  Map<String, VenueCountry> _countryNames = const {};
  bool _loading = true;
  bool _error = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _notFound = false;
    });
    try {
      // All four requests fire immediately off the known chefId — never
      // one query waiting on another's result — matching
      // EventsRepository.loadLinkedVenues' "start together, await in
      // turn" shape. The history/education/photos results are simply
      // discarded if the chef itself doesn't resolve.
      final chefFuture = _repo.getPrivateChefById(widget.chefId);
      final historyFuture = _repo.getRestaurantHistory(widget.chefId);
      final educationFuture = _repo.getEducationHistory(widget.chefId);
      final photosFuture = _repo.getChefPhotos(widget.chefId);
      final chef = await chefFuture;
      final history = chef == null
          ? const <PrivateChefRestaurantHistory>[]
          : await historyFuture;
      final education = chef == null
          ? const <PrivateChefEducation>[]
          : await educationFuture;
      final photos = chef == null
          ? const <PrivateChefPhoto>[]
          : await photosFuture;
      // Fired last since it needs the chef's own home_country_code — a
      // single-code lookup, not worth starting speculatively alongside
      // the other three futures above.
      final countryNames = chef == null
          ? const <String, VenueCountry>{}
          : await _repo.getCountryNames({
              if ((chef.homeCountryCode ?? '').trim().isNotEmpty)
                chef.homeCountryCode!.trim(),
            });
      if (!mounted) return;
      setState(() {
        _chef = chef;
        _history = history;
        _education = education;
        _photos = photos;
        _countryNames = countryNames;
        _loading = false;
        _notFound = chef == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openRestaurant(PrivateChefRestaurantHistory history) {
    final restaurant = history.restaurant;
    if (restaurant == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: SafeArea(child: PrivateChefsLoadingState()),
      );
    }
    if (_error) {
      return Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: SafeArea(child: PrivateChefsErrorState(onRetry: _load)),
      );
    }
    if (_notFound || _chef == null) {
      return const Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: SafeArea(child: PrivateChefNotFoundState()),
      );
    }

    final chef = _chef!;
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: CustomScrollView(
        slivers: [
          PrivateChefHero(
            displayName: chef.displayName,
            businessName: chef.businessName,
            location: _location(chef),
            photos: _photos,
            profileImageUrl: chef.profileImageUrl,
          ),
          SliverToBoxAdapter(
            child: ColoredBox(
              color: AppColors.ivory,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.xl,
                  CsSpacing.pageHorizontal,
                  CsSpacing.section,
                ),
                child: _body(chef),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _location(PrivateChef chef) => formatChefLocation(
    city: chef.homeCity,
    countryCode: chef.homeCountryCode,
    countryNames: _countryNames,
  );

  Widget _body(PrivateChef chef) {
    final biography = (chef.biography ?? '').trim();
    final hasBiography = biography.isNotEmpty;
    final hasBackground = _history.isNotEmpty || _education.isNotEmpty;
    final hasInstagram = (chef.instagramUrl ?? '').trim().isNotEmpty;
    final hasWebsite = (chef.websiteUrl ?? '').trim().isNotEmpty;

    final sections = <Widget>[
      if (hasBiography) _aboutSection(biography),
      if (hasBackground) _backgroundSection(),
      PrivateChefExperienceSection(chef: chef),
      if (hasInstagram || hasWebsite)
        PrivateChefConnectSection(
          onTapInstagram: hasInstagram
              ? () => _openUrl(chef.instagramUrl!)
              : null,
          onTapWebsite: hasWebsite ? () => _openUrl(chef.websiteUrl!) : null,
        ),
    ];

    // Step 3 will add "Request an Experience" here as the final section.
    // No CTA — disabled or "coming soon" — is rendered in its place now;
    // see PRIVATE_CHEFS.md's Step 2 documentation for the seam.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SectionDivider(),
          sections[i],
        ],
      ],
    );
  }

  Widget _aboutSection(String biography) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'ABOUT',
        style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
      ),
      const SizedBox(height: CsSpacing.md),
      Text(
        biography,
        style: CsTypography.body.copyWith(color: AppColors.textPrimary),
      ),
    ],
  );

  // Restaurant items first, then education items — matching the
  // approved worked example exactly (PRIVATE_CHEFS.md, Step 2B §12/§13).
  // No sub-headings between them; both read as one curated "Background"
  // list, distinguished purely by their own visual shape (a tappable row
  // with optional recognition for restaurant items, a plain institution/
  // program row for education items).
  Widget _backgroundSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'BACKGROUND',
        style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
      ),
      const SizedBox(height: CsSpacing.xs),
      for (final row in _history)
        PrivateChefProvenanceRow(
          history: row,
          onTap: row.isCanonical ? () => _openRestaurant(row) : null,
        ),
      for (final item in _education) PrivateChefEducationRow(education: item),
    ],
  );
}
