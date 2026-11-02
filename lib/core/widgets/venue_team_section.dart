import 'package:flutter/material.dart';
import '../../models/venue_team_member.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// "THE TEAM" on a restaurant's or hotel's page: one row of up to three
/// portraits (chef, manager, sommelier, in that order), each with its role
/// and name. Tapping one opens [VenueTeamMemberSheet] with the full text.
/// The row stays one portrait high however many people there are, so a
/// venue that shows all three doesn't make its page longer (option B,
/// decided 2026-11-02, over a separate Team tab). Like the about text,
/// nothing at all when there is no one to show — never an empty heading,
/// never an empty slot for a role that wasn't filled.
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
    final ordered = VenueTeamMember.ordered(members);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE TEAM',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < ordered.length; i++) ...[
              if (i > 0) const SizedBox(width: CsSpacing.md),
              Expanded(
                child: _MemberCard(
                  member: ordered[i],
                  onTap: () => showVenueTeamMemberSheet(
                    context,
                    member: ordered[i],
                    venueType: venueType,
                  ),
                ),
              ),
            ],
            // Keeps one or two cards at a third of the width each, so a
            // lone chef reads as a portrait, not a banner.
            for (var i = ordered.length; i < 3; i++) ...[
              const SizedBox(width: CsSpacing.md),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final VenueTeamMember member;
  final VoidCallback onTap;

  const _MemberCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${member.role.shortLabel}, ${member.name}',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: TeamPortrait(member: member, radius: 8),
            ),
            const SizedBox(height: CsSpacing.sm),
            Text(
              member.role.shortLabel,
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
            Text(
              member.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.placeTitle.copyWith(
                color: AppColors.forestGreen,
                fontSize: 16,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A team member's portrait, or — without one — a calm ivory panel with
/// their initials, so a missing photo never looks like a broken image.
class TeamPortrait extends StatelessWidget {
  final VenueTeamMember member;
  final double radius;

  const TeamPortrait({super.key, required this.member, this.radius = 8});

  String get _initials {
    final words = member.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.ivory,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: CsTypography.placeTitle.copyWith(
          color: AppColors.mutedBrassOnLight,
          fontSize: 22,
        ),
      ),
    );
    final url = member.photoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// One team member in full: a large portrait, their role, name and text.
Future<void> showVenueTeamMemberSheet(
  BuildContext context, {
  required VenueTeamMember member,
  required String venueType,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.warmWhite,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) =>
      VenueTeamMemberSheet(member: member, venueType: venueType),
);

class VenueTeamMemberSheet extends StatelessWidget {
  final VenueTeamMember member;
  final String venueType;

  const VenueTeamMemberSheet({
    super.key,
    required this.member,
    required this.venueType,
  });

  @override
  Widget build(BuildContext context) {
    final bio = member.bio?.trim();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.md,
          CsSpacing.pageHorizontal,
          CsSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.subtleBorderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: CsSpacing.lg),
          // Without a photo the sheet opens on the name: a large panel of
          // initials would only push the text down.
          if (member.photoUrl != null) ...[
            AspectRatio(
              aspectRatio: 4 / 3,
              child: TeamPortrait(member: member, radius: 12),
            ),
            const SizedBox(height: CsSpacing.lg),
          ],
          Text(
            member.role.labelFor(venueType),
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: 2),
          Text(
            member.name,
            style: CsTypography.placeTitle.copyWith(
              color: AppColors.forestGreen,
              fontSize: 24,
            ),
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: CsSpacing.md),
            Text(
              bio,
              style: CsTypography.body.copyWith(
                color: AppColors.forestGreen,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
