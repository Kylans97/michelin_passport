import 'package:flutter/material.dart';
import 'widgets/guide_catalogue_layout.dart';

/// The World's 50 Best → Hotels. Step 2A: header only — no repository, no
/// search/filter content, no rankings. See GuideCatalogueLayout for why.
class FiftyBestHotelGuideScreen extends StatelessWidget {
  const FiftyBestHotelGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => const GuideCatalogueLayout(
    source: "THE WORLD'S 50 BEST",
    title: 'Hotels',
    subtitle: "The world's most remarkable stays.",
  );
}
