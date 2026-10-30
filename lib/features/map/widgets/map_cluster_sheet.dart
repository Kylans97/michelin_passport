import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/map_pin.dart';

/// Lists the places behind a merged globe marker that can never be pulled
/// apart by zooming — a hotel and its restaurant at one address, say.
/// Choosing one closes this sheet and hands that pin to [onSelect], which
/// opens the same preview sheet a single pin tap does.
Future<void> showMapClusterSheet(
  BuildContext context,
  List<MapPin> pins, {
  required ValueChanged<MapPin> onSelect,
}) => showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: pins.length,
          separatorBuilder: (_, _) => const Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 22,
            endIndent: 22,
            color: AppColors.cardBorder,
          ),
          itemBuilder: (_, i) {
            final pin = pins[i];
            return InkWell(
              onTap: () {
                Navigator.pop(sheetContext);
                onSelect(pin);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      switch (pin.type) {
                        MapPinType.restaurant => Icons.restaurant_rounded,
                        MapPinType.hotel => Icons.vpn_key_rounded,
                        MapPinType.event => Icons.event_rounded,
                      },
                      size: 18,
                      color: AppColors.deepGreen,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pin.title,
                            style: GoogleFonts.playfairDisplay(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (pin.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              pin.subtitle,
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
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
);
