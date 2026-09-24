import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// The magazine pass's small section ornament — 120pt wide: hairline ·
/// 5×5 diamond (a square rotated 45°) · hairline, in gold. Purely
/// decorative (excluded from semantics); used wherever this pass needs a
/// quiet break between blocks instead of a card boundary.
class CsOrnamentDivider extends StatelessWidget {
  final Color color;

  const CsOrnamentDivider({super.key, this.color = AppColors.gold600});

  static const double _width = 120;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: _width,
      height: 8,
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: color)),
          const SizedBox(width: 8),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 5, height: 5, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: color)),
        ],
      ),
    ),
  );
}
