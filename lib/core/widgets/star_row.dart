import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StarRow extends StatelessWidget {
  final int count;
  final double size;

  const StarRow({super.key, required this.count, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (_) =>
            Icon(Icons.star_rounded, color: AppColors.starFilled, size: size),
      ),
    );
  }
}
