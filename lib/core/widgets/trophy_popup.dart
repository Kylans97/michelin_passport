import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../../models/trophy.dart';

/// Shows a full-screen dialog for each newly earned trophy, one at a time.
Future<void> showTrophyPopups(BuildContext context, List<Trophy> trophies) async {
  for (final trophy in trophies) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _TrophyDialog(trophy: trophy),
    );
  }
}

class _TrophyDialog extends StatelessWidget {
  final Trophy trophy;
  const _TrophyDialog({required this.trophy});

  String get _categoryLabel {
    switch (trophy.category) {
      case 'milestone': return 'Milestone';
      case 'travel':    return 'Travel';
      case 'country':   return 'Country';
      case 'social':    return 'Social';
      default:          return trophy.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.goldBorder60, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldMuted,
                border: Border.all(color: AppColors.goldBorder60, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.emoji_events_rounded,
                  color: AppColors.gold, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Trophy Unlocked!',
                style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(trophy.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(trophy.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_categoryLabel,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Awesome!',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
