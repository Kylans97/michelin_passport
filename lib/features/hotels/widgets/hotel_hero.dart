import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/detail_hero.dart';
import '../../../core/widgets/key_row.dart';
import '../../../models/hotel.dart';

class HotelHero extends StatelessWidget {
  final Hotel hotel;
  final bool isWishlisted;
  final bool wishlistSaving;
  final VoidCallback onTapWishlist;

  const HotelHero({
    super.key,
    required this.hotel,
    required this.isWishlisted,
    required this.wishlistSaving,
    required this.onTapWishlist,
  });

  @override
  Widget build(BuildContext context) {
    return DetailHero(
      title: hotel.name,
      awardBadge: KeyRow(count: hotel.michelinKeys, size: 18),
      overlayAction: HeroIconButton(
        icon: isWishlisted
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: isWishlisted ? AppColors.goldLight : AppColors.textOnDark,
        onTap: wishlistSaving ? () {} : onTapWishlist,
      ),
    );
  }
}
