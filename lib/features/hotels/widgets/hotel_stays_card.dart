import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/hotel.dart';
import '../../../models/visit.dart';
import '../../restaurants/widgets/detail_section.dart';
import '../../stays/stay_detail_screen.dart';

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

String _formatStayDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// Every logged stay at this hotel, newest first, each independently
/// tappable into [StayDetailScreen]. Repeat stays are never merged: a
/// hotel stayed at three times shows three rows.
class HotelStaysCard extends StatelessWidget {
  final bool isAuthenticated;
  final bool loading;
  final List<Visit> stays;
  final Hotel hotel;
  final String signInMessage;

  const HotelStaysCard({
    super.key,
    required this.isAuthenticated,
    required this.loading,
    required this.stays,
    required this.hotel,
    required this.signInMessage,
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
        message: 'Checking your stays…',
        color: AppColors.textSecondary,
      );
    }
    if (stays.isEmpty) {
      return const _StatusCard(
        icon: Icons.hotel_outlined,
        message: "You haven't stayed at this hotel yet.",
        color: AppColors.textSecondary,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < stays.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _StayTile(
            stay: stays[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StayDetailScreen(hotel: hotel, stay: stays[i]),
              ),
            ),
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

class _StayTile extends StatelessWidget {
  final Visit stay;
  final VoidCallback onTap;
  const _StayTile({required this.stay, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rating = stay.rating;

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
                      _formatStayDate(stay.visitedOn),
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
