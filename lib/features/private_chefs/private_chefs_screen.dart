import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/private_chef_repository.dart';
import '../../models/private_chef.dart';
import '../../models/private_chef_photo.dart';
import '../../models/venue_country.dart';
import 'private_chef_detail_screen.dart';
import 'private_chef_grouping.dart';
import 'private_chef_location.dart';
import 'widgets/private_chef_discovery_card.dart';
import 'widgets/private_chef_states.dart';

/// Private Chefs landing — an editorial discovery collection (Step 2C),
/// not a directory/search-results list: chefs are grouped by country under
/// a quiet heading, each rendered as a large [PrivateChefDiscoveryCard]
/// with generous whitespace between them. The deepGreen masthead below is
/// unchanged from the original Step 2 approval — only the body beneath it
/// was redesigned.
class PrivateChefsScreen extends StatefulWidget {
  const PrivateChefsScreen({super.key});
  @override
  State<PrivateChefsScreen> createState() => _PrivateChefsScreenState();
}

class _PrivateChefsScreenState extends State<PrivateChefsScreen> {
  late final _repo = PrivateChefRepository(Supabase.instance.client);
  List<PrivateChef>? _chefs;
  Map<String, PrivateChefPhoto> _coverPhotos = const {};
  Map<String, VenueCountry> _countryNames = const {};
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final chefs = await _repo.getPublishedChefs();
      final chefIds = [for (final chef in chefs) chef.id];
      final countryCodes = {
        for (final chef in chefs)
          if ((chef.homeCountryCode ?? '').trim().isNotEmpty)
            chef.homeCountryCode!.trim(),
      };
      // Two more queries total, never one per chef — same batched shape
      // as PrivateChefRepository.getRestaurantHistory.
      final coverPhotosFuture = _repo.getCoverPhotos(chefIds);
      final countryNamesFuture = _repo.getCountryNames(countryCodes);
      final coverPhotos = await coverPhotosFuture;
      final countryNames = await countryNamesFuture;
      if (!mounted) return;
      setState(() {
        _chefs = chefs;
        _coverPhotos = coverPhotos;
        _countryNames = countryNames;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _openChef(PrivateChef chef) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PrivateChefDetailScreen(chefId: chef.id)),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: ColoredBox(
              color: AppColors.deepGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      CsSpacing.base,
                      0,
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
                      CsSpacing.xs,
                      CsSpacing.pageHorizontal,
                      CsSpacing.base,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Private Chefs',
                          style: CsTypography.screenTitle.copyWith(
                            color: AppColors.ivory,
                          ),
                        ),
                        const SizedBox(height: CsSpacing.xs),
                        Text(
                          'Exceptional private dining, personally selected.',
                          style: CsTypography.body.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.ivory,
              child: SafeArea(top: false, child: _body()),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) return const PrivateChefsLoadingState();
    if (_error) return PrivateChefsErrorState(onRetry: _load);
    final chefs = _chefs ?? const [];
    if (chefs.isEmpty) return const PrivateChefsEmptyState();

    final groups = groupChefsByCountry(chefs, _countryNames);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) =>
          _countrySection(groups[index], isFirst: index == 0),
    );
  }

  Widget _countrySection(
    PrivateChefCountryGroup group, {
    required bool isFirst,
  }) => Padding(
    padding: EdgeInsets.only(top: isFirst ? 0 : CsSpacing.section),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.countryName != null) ...[
          Text(
            group.countryName!.toUpperCase(),
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.lg),
        ],
        for (var i = 0; i < group.chefs.length; i++) ...[
          if (i > 0) const SizedBox(height: CsSpacing.section),
          _chefCard(group.chefs[i]),
        ],
      ],
    ),
  );

  Widget _chefCard(PrivateChef chef) => PrivateChefDiscoveryCard(
    chef: chef,
    coverImageUrl: _coverPhotos[chef.id]?.imageUrl,
    location: formatChefLocation(
      city: chef.homeCity,
      countryCode: chef.homeCountryCode,
      countryNames: _countryNames,
    ),
    onTap: () => _openChef(chef),
  );
}
