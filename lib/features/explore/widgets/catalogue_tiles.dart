import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cs_header_drawing.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/journey.dart';
import '../../../models/vineyard.dart';
import '../../journeys/journey_detail_screen.dart';
import '../../vineyards/vineyard_detail_screen.dart';

/// The ivory search card RestaurantTile and HotelTile use, for the wine
/// estates and the trains and ships Explore search returns — one look for
/// every kind of result in the list.
class _CatalogueTile extends StatelessWidget {
  final HeaderDrawing drawing;
  final String title;
  final String detail;
  final String? note;
  final VoidCallback onTap;

  const _CatalogueTile({
    required this.drawing,
    required this.title,
    required this.detail,
    required this.onTap,
    this.note,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.55),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VenueThumbnail(imageUrl: null, drawing: drawing),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.editorialHeading.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metadata,
                ),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Claret, never gold: the 50 Best Vineyards rank is
                    // not a MICHELIN distinction.
                    style: AppTypography.metadata.copyWith(
                      color: AppColors.claret,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class VineyardTile extends StatelessWidget {
  final Vineyard vineyard;
  const VineyardTile({super.key, required this.vineyard});

  @override
  Widget build(BuildContext context) => _CatalogueTile(
    drawing: HeaderDrawing.vineyard(vineyard.id),
    title: vineyard.name,
    detail: vineyard.cardPlaceLabel,
    note: vineyard.worlds50BestRank == null
        ? null
        : "No. ${vineyard.worlds50BestRank} · World's 50 Best Vineyards",
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VineyardDetailScreen(vineyardId: vineyard.id),
      ),
    ),
  );
}

class JourneyTile extends StatelessWidget {
  final Journey journey;
  const JourneyTile({super.key, required this.journey});

  @override
  Widget build(BuildContext context) => _CatalogueTile(
    drawing: HeaderDrawing.journey(
      journey.id,
      journey.kind,
      shipType: journey.shipType,
    ),
    title: journey.name,
    detail: '${journey.kindLabel} · ${journey.operatorName}',
    note: null,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JourneyDetailScreen(journeyId: journey.id),
      ),
    ),
  );
}
