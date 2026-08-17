import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/section_divider.dart';
import '../../data/repositories/private_chef_repository.dart';
import '../../models/private_chef.dart';
import '../../models/private_chef_restaurant_history.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'widgets/private_chef_connect_section.dart';
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
/// Canonical hierarchy (PRIVATE_CHEFS.md, Step 2 brief §12): HERO → ABOUT →
/// RESTAURANT PROVENANCE → THE EXPERIENCE → CONNECT. No enquiry form yet
/// (Step 3) — no CTA of any kind is rendered here in the meantime; see
/// [_body]'s trailing comment for the seam.
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
      // Both requests fire immediately off the known chefId — never one
      // query waiting on the other's result — matching
      // EventsRepository.loadLinkedVenues' "start together, await in
      // turn" shape. The history result is simply discarded if the chef
      // itself doesn't resolve.
      final chefFuture = _repo.getPrivateChefById(widget.chefId);
      final historyFuture = _repo.getRestaurantHistory(widget.chefId);
      final chef = await chefFuture;
      final history = chef == null
          ? const <PrivateChefRestaurantHistory>[]
          : await historyFuture;
      if (!mounted) return;
      setState(() {
        _chef = chef;
        _history = history;
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

  String? _location(PrivateChef chef) {
    final parts = [
      if ((chef.homeCity ?? '').trim().isNotEmpty) chef.homeCity!.trim(),
      if ((chef.homeCountryCode ?? '').trim().isNotEmpty)
        chef.homeCountryCode!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  Widget _body(PrivateChef chef) {
    final biography = (chef.biography ?? '').trim();
    final hasBiography = biography.isNotEmpty;
    final hasProvenance = _history.isNotEmpty;
    final hasInstagram = (chef.instagramUrl ?? '').trim().isNotEmpty;
    final hasWebsite = (chef.websiteUrl ?? '').trim().isNotEmpty;

    final sections = <Widget>[
      if (hasBiography) _aboutSection(biography),
      if (hasProvenance) _provenanceSection(),
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

  Widget _provenanceSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'RESTAURANT PROVENANCE',
        style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
      ),
      const SizedBox(height: CsSpacing.xs),
      for (final row in _history)
        PrivateChefProvenanceRow(
          history: row,
          onTap: row.isCanonical ? () => _openRestaurant(row) : null,
        ),
    ],
  );
}
