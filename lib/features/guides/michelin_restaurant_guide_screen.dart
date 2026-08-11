import 'package:flutter/material.dart';
import 'widgets/guide_catalogue_layout.dart';

/// Michelin Guide → Restaurants. Step 2A: header only — no repository, no
/// search/filter content, no venues. See GuideCatalogueLayout for why.
class MichelinRestaurantGuideScreen extends StatelessWidget {
  const MichelinRestaurantGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => const GuideCatalogueLayout(
    source: 'MICHELIN GUIDE',
    title: 'Restaurants',
    subtitle: 'Exceptional restaurants recognised by the Michelin Guide.',
  );
}
