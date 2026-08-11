import 'package:flutter/material.dart';
import 'widgets/guide_catalogue_layout.dart';

/// The World's 50 Best → Restaurants. Step 2A: header only — no
/// repository, no search/filter content, no rankings. See
/// GuideCatalogueLayout for why.
class FiftyBestRestaurantGuideScreen extends StatelessWidget {
  const FiftyBestRestaurantGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => const GuideCatalogueLayout(
    source: "THE WORLD'S 50 BEST",
    title: 'Restaurants',
    subtitle: 'The restaurants shaping global dining.',
  );
}
