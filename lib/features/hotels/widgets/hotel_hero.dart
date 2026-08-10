import 'package:flutter/material.dart';
import '../../../core/widgets/detail_hero.dart';
import '../../../core/widgets/key_row.dart';
import '../../../models/hotel.dart';

class HotelHero extends StatelessWidget {
  final Hotel hotel;
  const HotelHero({super.key, required this.hotel});

  @override
  Widget build(BuildContext context) {
    return DetailHero(
      title: hotel.name,
      awardBadge: KeyRow(count: hotel.michelinKeys, size: 18),
    );
  }
}
