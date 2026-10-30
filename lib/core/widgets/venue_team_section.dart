import 'package:flutter/material.dart';
import '../../models/venue_team_member.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// "THE TEAM" on a restaurant's or hotel's page: the chef and the manager
/// the venue chose to show, each a role line, a name and their short
/// text. Same register as [VenueAboutSection] — eyebrow, serif name,
/// plain body — and, like it, nothing at all when there is no one to
/// show, never an empty heading.
class VenueTeamSection extends StatelessWidget {
  final List<VenueTeamMember> members;
  final String venueType;

  const VenueTeamSection({
    super.key,
    required this.members,
    required this.venueType,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE TEAM',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        for (var i = 0; i < members.length; i++) ...[
          SizedBox(height: i == 0 ? CsSpacing.md : CsSpacing.lg),
          _Member(member: members[i], venueType: venueType),
        ],
      ],
    );
  }
}

class _Member extends StatelessWidget {
  final VenueTeamMember member;
  final String venueType;
  const _Member({required this.member, required this.venueType});

  @override
  Widget build(BuildContext context) {
    final bio = member.bio?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          member.role.labelFor(venueType),
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: 2),
        Text(
          member.name,
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: CsSpacing.xs),
          Text(
            bio,
            style: CsTypography.body.copyWith(
              color: AppColors.forestGreen,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}
