import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/private_chef_repository.dart';
import '../../models/private_chef.dart';
import '../guides/widgets/guide_venue_card.dart' show GuideVenueCardDivider;
import 'private_chef_detail_screen.dart';
import 'widgets/private_chef_row.dart';
import 'widgets/private_chef_states.dart';

/// Private Chefs' landing/catalogue — reached from Explore only, never a
/// 6th bottom-navigation tab (PRIVATE_CHEFS.md §37). Pushed via
/// [MaterialPageRoute], so it owns its own [Scaffold] — mirrors
/// [GuideCatalogueLayout]'s proven `Scaffold(deepGreen)` →
/// `SafeArea(bottom: false)` masthead → ivory `ColoredBox` +
/// `SafeArea(top: false)` content architecture, the exact fix for the
/// ivory-strip-behind-the-status-bar bug that shell already solved. Uses a
/// single `screenTitle` + `body` heading (matching Explore/Wishlist's
/// primary-tab header language) rather than Guides' two-level source/
/// title split, since Private Chefs has no family-of-catalogues hierarchy
/// above it — this screen IS the destination, not a sub-catalogue of one.
///
/// Production currently has zero published chefs — the empty state (see
/// [PrivateChefsEmptyState]) is a first-class, expected experience, not a
/// placeholder for missing data.
class PrivateChefsScreen extends StatefulWidget {
  const PrivateChefsScreen({super.key});

  @override
  State<PrivateChefsScreen> createState() => _PrivateChefsScreenState();
}

class _PrivateChefsScreenState extends State<PrivateChefsScreen> {
  late final _repo = PrivateChefRepository(Supabase.instance.client);

  List<PrivateChef>? _chefs;
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
      if (!mounted) return;
      setState(() {
        _chefs = chefs;
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
                      CsSpacing.xs,
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: CsSpacing.pageHorizontal,
        vertical: CsSpacing.sm,
      ),
      itemCount: chefs.length,
      separatorBuilder: (_, _) => const GuideVenueCardDivider(),
      itemBuilder: (context, index) => PrivateChefRow(
        chef: chefs[index],
        onTap: () => _openChef(chefs[index]),
      ),
    );
  }
}
