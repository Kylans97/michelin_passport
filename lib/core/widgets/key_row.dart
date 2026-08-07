import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Michelin Keys, rendered as a row of key icons — deliberately a different
/// icon (and glyph shape) from [StarRow]'s stars, so Keys (hotels) are never
/// mistaken for Stars (restaurants) at a glance.
class KeyRow extends StatelessWidget {
  final int count;
  final double size;

  const KeyRow({super.key, required this.count, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (_) => Icon(Icons.vpn_key_rounded, color: AppColors.gold, size: size),
      ),
    );
  }
}
