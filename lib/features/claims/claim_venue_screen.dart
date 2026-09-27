import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/missing_listing_repository.dart';
import '../../data/repositories/private_chef_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/venue_claim.dart';
import '../reports/widgets/report_missing_listing_sheet.dart';
import 'claim_venue_details_screen.dart';

/// Step 1 of the claim flow — pick a venue type, search for it by name,
/// and either proceed to [ClaimVenueDetailsScreen] with the one you meant
/// or, if it isn't listed at all, fall through to the EXISTING missing-
/// listing report sheet rather than this flow inventing a second "we
/// don't have this" path. Pushed from Profile's ACCOUNT section
/// ("Claim your venue"), never reached any other way.
class ClaimVenueScreen extends StatefulWidget {
  // Optional DI seams, matching NewsArticleDetailScreen/NotificationsScreen's
  // established convention — default to the real Supabase-backed
  // repositories so every existing call site (just Profile's "Claim your
  // venue" row) is unaffected; a preview harness or widget test supplies
  // fakes instead.
  final RestaurantRepository? restaurantRepo;
  final HotelRepository? hotelRepo;
  final PrivateChefRepository? privateChefRepo;

  const ClaimVenueScreen({
    super.key,
    this.restaurantRepo,
    this.hotelRepo,
    this.privateChefRepo,
  });

  @override
  State<ClaimVenueScreen> createState() => _ClaimVenueScreenState();
}

/// A search result the person can tap to proceed — just enough to both
/// show it in a list and pass it forward to [ClaimVenueDetailsScreen]
/// (id/name/city are plain fields there, not this private class, since
/// Dart's per-file privacy means a private type here can't cross into
/// another file anyway).
class _SearchResult {
  final String id;
  final String name;
  final String? city;
  const _SearchResult({required this.id, required this.name, this.city});
}

class _ClaimVenueScreenState extends State<ClaimVenueScreen> {
  late final _restaurantRepo =
      widget.restaurantRepo ?? RestaurantRepository(Supabase.instance.client);
  late final _hotelRepo = widget.hotelRepo ?? HotelRepository(Supabase.instance.client);
  late final _privateChefRepo =
      widget.privateChefRepo ?? PrivateChefRepository(Supabase.instance.client);

  VenueClaimVenueType _type = VenueClaimVenueType.restaurant;
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;
  bool _searching = false;
  bool _hasSearched = false;
  List<_SearchResult> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(VenueClaimVenueType type) {
    setState(() {
      _type = type;
      _results = [];
      _hasSearched = false;
    });
    if (_query.length >= 2) _runSearch();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    _query = trimmed;
    if (trimmed.length < 2) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _query;
    if (query.length < 2 || !mounted) return;
    setState(() => _searching = true);
    List<_SearchResult> results;
    switch (_type) {
      case VenueClaimVenueType.restaurant:
        final rows = await _restaurantRepo.search(query);
        results = [
          for (final r in rows) _SearchResult(id: r.id, name: r.name, city: r.cityName),
        ];
      case VenueClaimVenueType.hotel:
        final rows = await _hotelRepo.search(query);
        results = [
          for (final h in rows) _SearchResult(id: h.id, name: h.name, city: h.cityName),
        ];
      case VenueClaimVenueType.privateChef:
        final rows = await _privateChefRepo.search(query);
        results = [
          for (final c in rows) _SearchResult(id: c.id, name: c.displayName, city: c.homeCity),
        ];
    }
    if (!mounted || query != _query) return;
    setState(() {
      _results = results;
      _searching = false;
      _hasSearched = true;
    });
  }

  void _selectResult(_SearchResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClaimVenueDetailsScreen(
          venueType: _type,
          venueId: result.id,
          venueName: result.name,
          venueCity: result.city,
        ),
      ),
    );
  }

  void _reportMissing() {
    showReportMissingListingSheet(
      context,
      initialQuery: _searchCtrl.text.trim(),
      initialType: switch (_type) {
        VenueClaimVenueType.restaurant => MissingListingSubjectType.restaurant,
        VenueClaimVenueType.hotel => MissingListingSubjectType.hotel,
        VenueClaimVenueType.privateChef => MissingListingSubjectType.privateChef,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Claim your venue',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: CsSpacing.md),
            Text(
              'What kind of venue is it?',
              style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.sm),
            for (final type in VenueClaimVenueType.values)
              _TypeRow(
                label: type.label,
                selected: _type == type,
                onTap: () => _onTypeChanged(type),
              ),
            const SizedBox(height: CsSpacing.md),
            CsTextField(
              label: 'Search by name',
              controller: _searchCtrl,
              surface: CsSurface.light,
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: CsSpacing.md),
            Expanded(child: _resultsArea()),
          ],
        ),
      ),
    );
  }

  Widget _resultsArea() {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forestGreen, strokeWidth: 1.5),
      );
    }
    if (!_hasSearched) return const SizedBox.shrink();
    if (_results.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "We couldn't find that.",
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
          const SizedBox(height: CsSpacing.xs),
          TextButton(
            onPressed: _reportMissing,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            child: Text(
              "Report it as missing",
              style: CsTypography.body.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => Container(height: 1, color: AppColors.cardBorder),
      itemBuilder: (context, i) {
        final result = _results[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            result.name,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
          subtitle: result.city == null
              ? null
              : Text(result.city!, style: CsTypography.metadata.copyWith(color: AppColors.taupe)),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.taupe),
          onTap: () => _selectResult(result),
        );
      },
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? AppColors.forestGreen : AppColors.taupe,
          ),
          const SizedBox(width: CsSpacing.sm),
          Text(label, style: CsTypography.body.copyWith(color: AppColors.forestGreen)),
        ],
      ),
    ),
  );
}
