import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/star_row.dart';
import '../../models/restaurant.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final Restaurant restaurant;
  final bool isVisited;
  final bool isWishlisted;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onToggleWishlist;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
    this.isVisited = false,
    this.isWishlisted = false,
    this.onToggleVisited,
    this.onToggleWishlist,
  });

  Future<void> _openMaps() async {
    final Uri uri;
    if (restaurant.googlePlaceId != null &&
        restaurant.googlePlaceId!.isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${restaurant.googlePlaceId}&query_place_id=${restaurant.googlePlaceId}',
      );
    } else {
      final query = Uri.encodeComponent(
        '${restaurant.name} ${restaurant.cityName}',
      );
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1C1400),
                      Color(0xFF110E00),
                      AppColors.background,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (restaurant.hasMichelinStar)
                          StarRow(count: restaurant.michelinStars!, size: 16),
                        if (restaurant.isWorlds50Best) ...[
                          const SizedBox(height: 8),
                          Text(
                            '#${restaurant.worlds50BestRank} — World’s 50 Best',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          restaurant.name,
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location. Cuisine is omitted: restaurants_full does not
                  // expose a cuisine display column.
                  _InfoRow(
                    Icons.location_on_rounded,
                    '${restaurant.flagEmoji}  ${restaurant.cityName}, ${restaurant.countryName}',
                  ),
                  if (restaurant.address.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(Icons.map_outlined, restaurant.address),
                  ],
                  const SizedBox(height: 28),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: isVisited
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                          label: isVisited ? 'Visited' : 'Mark visited',
                          active: isVisited,
                          onTap: onToggleVisited,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: isWishlisted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: isWishlisted
                              ? 'Wishlisted'
                              : 'Add to wishlist',
                          active: isWishlisted,
                          onTap: onToggleWishlist,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Reserve button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _openMaps,
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: Text(
                        'Reserve via Google Maps',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  // Michelin URL
                  if (restaurant.michelinUrl != null &&
                      restaurant.michelinUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(restaurant.michelinUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          'View on Michelin Guide',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(
                            color: AppColors.cardBorder,
                            width: 0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.textSecondary, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: active ? AppColors.goldMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.goldBorder60 : AppColors.cardBorder,
          width: active ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? AppColors.gold : AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: active ? AppColors.gold : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}
