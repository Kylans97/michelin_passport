import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/restaurant.dart';
import '../../../models/visit.dart';
import '../../visits/visit_detail_screen.dart';
import 'detail_section.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatVisitDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// Every logged visit to this restaurant, newest first, each independently
/// tappable into [VisitDetailScreen]. Repeat visits are never merged: a
/// restaurant visited three times shows three rows.
class RestaurantVisitsCard extends StatelessWidget {
  final bool isAuthenticated;
  final bool loading;
  final List<Visit> visits;
  final Restaurant restaurant;
  final String signInMessage;

  // Called after returning from VisitDetailScreen, regardless of what
  // happened there — covers a deleted visit just as much as a no-op back
  // tap; a harmless extra refresh either way.
  final VoidCallback onReturn;

  const RestaurantVisitsCard({
    super.key,
    required this.isAuthenticated,
    required this.loading,
    required this.visits,
    required this.restaurant,
    required this.signInMessage,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return _StatusCard(
        icon: Icons.lock_outline_rounded,
        message: signInMessage,
        color: AppColors.textSecondary,
      );
    }
    if (loading) {
      return const _StatusCard(
        icon: Icons.hourglass_empty_rounded,
        message: 'Checking your visits…',
        color: AppColors.textSecondary,
      );
    }
    if (visits.isEmpty) {
      return const _StatusCard(
        icon: Icons.menu_book_outlined,
        message: "You haven't visited this restaurant yet.",
        color: AppColors.textSecondary,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < visits.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _VisitTile(
            visit: visits[i],
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitDetailScreen(
                    restaurant: restaurant,
                    visit: visits[i],
                  ),
                ),
              );
              onReturn();
            },
          ),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _StatusCard({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
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

class _VisitTile extends StatelessWidget {
  final Visit visit;
  final VoidCallback onTap;
  const _VisitTile({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rating = visit.rating;
    final menuType = visit.menuType;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatVisitDate(visit.visitedOn),
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (rating != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Overall $rating/10',
                        style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (menuType != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        menuType.label,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
