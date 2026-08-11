import 'package:flutter/material.dart';
import 'widgets/guide_catalogue_layout.dart';

/// Michelin Guide → Hotels. Step 2A: header only — no repository, no
/// search/filter content, no venues. See GuideCatalogueLayout for why.
class MichelinHotelGuideScreen extends StatelessWidget {
  const MichelinHotelGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => const GuideCatalogueLayout(
    source: 'MICHELIN GUIDE',
    title: 'Hotels',
    subtitle: 'Exceptional hotels recognised with Michelin Keys.',
  );
}
