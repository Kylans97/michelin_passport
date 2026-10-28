import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../models/trip_member.dart';
import '../trip_legs.dart';

/// A trip someone invited the user to, at the top of Trips: an ivory card
/// (the same surface as [TripHeroCard]) with the inviter, the trip and
/// its dates, and Accept/Decline. Accepting makes the trip theirs too —
/// it then shows among their trips with everyone's plans.
class TripInvitationCard extends StatefulWidget {
  final TripInvitation invitation;
  final Future<void> Function(bool accept) onRespond;

  const TripInvitationCard({
    super.key,
    required this.invitation,
    required this.onRespond,
  });

  @override
  State<TripInvitationCard> createState() => _TripInvitationCardState();
}

class _TripInvitationCardState extends State<TripInvitationCard> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    setState(() => _busy = true);
    await widget.onRespond(accept);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invitation;
    final who = invite.inviterLabel ?? 'A friend';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CsSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(CsRadius.card),
        border: Border.all(color: AppColors.subtleBorderLight, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${who.toUpperCase()} INVITED YOU',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.eyebrow.copyWith(color: AppColors.forestGreen),
          ),
          const SizedBox(height: CsSpacing.sm),
          Text(
            invite.tripTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.placeTitle.copyWith(color: AppColors.deepGreen),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            '${formatLegDateRange(invite.startDate, invite.endDate)} '
            '${invite.endDate.year}',
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.base),
          Row(
            children: [
              Expanded(
                child: CsSecondaryButton(
                  label: 'Decline',
                  onTap: _busy ? null : () => _respond(false),
                  surface: CsSurface.light,
                  height: 44,
                ),
              ),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: CsPrimaryButton(
                  label: 'Join trip',
                  onTap: _busy ? null : () => _respond(true),
                  loading: _busy,
                  surface: CsSurface.light,
                  height: 44,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
