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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasHotelBadge =
        restaurant.isInHotel && (restaurant.hotelName?.isNotEmpty ?? false);
    final michelinUrl = restaurant.michelinUrl;
    final websiteUrl = restaurant.websiteUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _Hero(restaurant: restaurant, hasHotelBadge: hasHotelBadge),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('INFORMATION'),
                  const SizedBox(height: 12),
                  _InfoCard(
                    restaurant: restaurant,
                    hasHotelBadge: hasHotelBadge,
                  ),
                  const SizedBox(height: 28),

                  const _SectionLabel('ACTIONS'),
                  const SizedBox(height: 12),
                  _PrimaryActions(
                    isVisited: isVisited,
                    isWishlisted: isWishlisted,
                    onToggleVisited: onToggleVisited,
                    onToggleWishlist: onToggleWishlist,
                    onOpenMaps: _openMaps,
                    onOpenMichelin:
                        (michelinUrl != null && michelinUrl.isNotEmpty)
                        ? () => _openUrl(michelinUrl)
                        : null,
                    onOpenWebsite: (websiteUrl != null && websiteUrl.isNotEmpty)
                        ? () => _openUrl(websiteUrl)
                        : null,
                  ),
                  const SizedBox(height: 28),

                  _AwardsSection(restaurant: restaurant),

                  const SizedBox(height: 28),
                  const _SectionLabel('YOUR VISITS'),
                  const SizedBox(height: 12),
                  _VisitsCard(isVisited: isVisited),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final Restaurant restaurant;
  final bool hasHotelBadge;
  const _Hero({required this.restaurant, required this.hasHotelBadge});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (restaurant.isWorlds50Best)
        _HeroBadge(
          icon: Icons.emoji_events_rounded,
          label: "World's 50 Best · #${restaurant.worlds50BestRank}",
        ),
      if (hasHotelBadge)
        _HeroBadge(icon: Icons.hotel_rounded, label: restaurant.hotelName!),
    ];

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.background,
      title: Text(
        restaurant.name,
        style: GoogleFonts.playfairDisplay(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
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
                    StarRow(count: restaurant.michelinStars!, size: 18),
                  if (badges.isNotEmpty) ...[
                    SizedBox(height: restaurant.hasMichelinStar ? 10 : 0),
                    Wrap(spacing: 8, runSpacing: 8, children: badges),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    restaurant.name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.goldAlpha10,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.goldBorder40, width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.gold),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ── Shared section chrome ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      color: AppColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.cardBorder, width: 0.5),
    ),
    child: child,
  );
}

// ── Information card ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Restaurant restaurant;
  final bool hasHotelBadge;
  const _InfoCard({required this.restaurant, required this.hasHotelBadge});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _InfoRow(Icons.location_city_rounded, restaurant.cityName),
      _InfoRow(
        Icons.public_rounded,
        '${restaurant.flagEmoji}  ${restaurant.countryName}'.trim(),
      ),
      if (restaurant.address.isNotEmpty)
        _InfoRow(Icons.map_outlined, restaurant.address),
      if (hasHotelBadge) _InfoRow(Icons.hotel_rounded, restaurant.hotelName!),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const SizedBox(height: 12),
          ],
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

// ── Primary actions ───────────────────────────────────────────────────────────

class _PrimaryActions extends StatelessWidget {
  final bool isVisited;
  final bool isWishlisted;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onToggleWishlist;
  final VoidCallback onOpenMaps;
  final VoidCallback? onOpenMichelin;
  final VoidCallback? onOpenWebsite;

  const _PrimaryActions({
    required this.isVisited,
    required this.isWishlisted,
    required this.onToggleVisited,
    required this.onToggleWishlist,
    required this.onOpenMaps,
    required this.onOpenMichelin,
    required this.onOpenWebsite,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ToggleButton(
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
              child: _ToggleButton(
                icon: isWishlisted
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: isWishlisted ? 'Wishlisted' : 'Wishlist',
                active: isWishlisted,
                onTap: onToggleWishlist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LinkButton(
          icon: Icons.map_rounded,
          label: 'Google Maps',
          filled: true,
          onTap: onOpenMaps,
        ),
        if (onOpenMichelin != null) ...[
          const SizedBox(height: 10),
          _LinkButton(
            icon: Icons.open_in_new_rounded,
            label: 'Michelin Guide',
            filled: false,
            onTap: onOpenMichelin!,
          ),
        ],
        if (onOpenWebsite != null) ...[
          const SizedBox(height: 10),
          _LinkButton(
            icon: Icons.language_rounded,
            label: 'Website',
            filled: false,
            onTap: onOpenWebsite!,
          ),
        ],
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _ToggleButton({
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

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: filled ? 52 : 50,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
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
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label, style: GoogleFonts.inter(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
    );
  }
}

// ── Awards section ────────────────────────────────────────────────────────────

class _AwardsSection extends StatelessWidget {
  final Restaurant restaurant;
  const _AwardsSection({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final rows = <_AwardRow>[
      if (restaurant.hasMichelinStar)
        _AwardRow(
          icon: Icons.star_rounded,
          label: 'Michelin Stars',
          value:
              '${restaurant.michelinStars} Star${restaurant.michelinStars == 1 ? '' : 's'}',
        ),
      if (restaurant.isWorlds50Best)
        _AwardRow(
          icon: Icons.emoji_events_rounded,
          label: "World's 50 Best",
          value: '#${restaurant.worlds50BestRank}',
        ),
      if (restaurant.isHallOfFame)
        const _AwardRow(
          icon: Icons.military_tech_rounded,
          label: 'Hall of Fame',
          value: 'Best of the Best',
        ),
    ];

    // Every catalogued restaurant qualifies on at least one of the above by
    // construction, but stay defensive rather than assume.
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('AWARDS'),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1) ...[
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 14),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AwardRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AwardRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.gold, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Text(
        value,
        style: GoogleFonts.inter(
          color: AppColors.gold,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

// ── Visits ─────────────────────────────────────────────────────────────────────
// Deliberately minimal: reflects the isVisited flag already passed into this
// screen. Per-visit detail (dates, ratings, notes) is a later redesign.

class _VisitsCard extends StatelessWidget {
  final bool isVisited;
  const _VisitsCard({required this.isVisited});

  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      children: [
        Icon(
          isVisited ? Icons.check_circle_rounded : Icons.menu_book_outlined,
          color: isVisited ? AppColors.gold : AppColors.textSecondary,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isVisited
                ? 'You have visited this restaurant.'
                : "You haven't visited this restaurant yet.",
            style: GoogleFonts.inter(
              color: isVisited
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
