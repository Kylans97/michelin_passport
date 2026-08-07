import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import 'detail_section.dart';

/// Deliberately minimal status text. Per-visit history (list, edit, delete
/// one visit) is a later redesign — the schema supports repeat visits, this
/// screen just doesn't browse them yet.
class RestaurantVisitsCard extends StatelessWidget {
  final bool isAuthenticated;
  final bool loading;
  final bool isVisited;
  final String signInMessage;
  const RestaurantVisitsCard({
    super.key,
    required this.isAuthenticated,
    required this.loading,
    required this.isVisited,
    required this.signInMessage,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String message;
    final Color color;

    if (!isAuthenticated) {
      icon = Icons.lock_outline_rounded;
      message = signInMessage;
      color = AppColors.textSecondary;
    } else if (loading) {
      icon = Icons.hourglass_empty_rounded;
      message = 'Checking your visits…';
      color = AppColors.textSecondary;
    } else if (isVisited) {
      icon = Icons.check_circle_rounded;
      message = 'You have visited this restaurant.';
      color = AppColors.textPrimary;
    } else {
      icon = Icons.menu_book_outlined;
      message = "You haven't visited this restaurant yet.";
      color = AppColors.textSecondary;
    }

    return DetailCard(
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey(icon),
              color: isVisited && isAuthenticated && !loading
                  ? AppColors.gold
                  : AppColors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
