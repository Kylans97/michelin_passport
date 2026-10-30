import 'venue_about_submission.dart';

/// The two people a restaurant or hotel can show on its page
/// (venue_team_submissions.role, 20261030150000).
enum VenueTeamRole {
  manager,
  chef;

  static VenueTeamRole? fromWire(String? value) => switch (value) {
    'manager' => VenueTeamRole.manager,
    'chef' => VenueTeamRole.chef,
    _ => null,
  };

  String get wireValue => name;

  /// What the page calls the role. A hotel's manager is the hotel's, not
  /// a restaurant's.
  String labelFor(String venueType) => switch (this) {
    VenueTeamRole.manager =>
      venueType == 'hotel' ? 'Hotel manager' : 'Restaurant manager',
    VenueTeamRole.chef => 'Chef',
  };
}

/// One person as the page shows them: the latest approved, not removed
/// submission for that role (venue_team_current).
class VenueTeamMember {
  final VenueTeamRole role;
  final String name;
  final String? bio;

  const VenueTeamMember({required this.role, required this.name, this.bio});

  /// Null for a role this build doesn't know.
  static VenueTeamMember? fromJson(Map<String, dynamic> json) {
    final role = VenueTeamRole.fromWire(json['role'] as String?);
    if (role == null) return null;
    return VenueTeamMember(
      role: role,
      name: json['name'] as String,
      bio: json['bio'] as String?,
    );
  }

  /// The page's order: the chef first, then the manager.
  static List<VenueTeamMember> ordered(Iterable<VenueTeamMember> members) =>
      [...members]..sort((a, b) => b.role.index.compareTo(a.role.index));
}

/// The manager's own latest submission for one role, read back with its
/// status. Same statuses as an about text.
class VenueTeamSubmission {
  final String id;
  final VenueTeamRole role;
  final String name;
  final String? bio;
  final VenueAboutSubmissionStatus status;
  final DateTime submittedAt;
  final String? reviewNote;

  /// Set once someone took this role off the page; the submission then
  /// counts for nothing.
  final DateTime? removedAt;

  const VenueTeamSubmission({
    required this.id,
    required this.role,
    required this.name,
    this.bio,
    required this.status,
    required this.submittedAt,
    this.reviewNote,
    this.removedAt,
  });

  static VenueTeamSubmission? fromJson(Map<String, dynamic> json) {
    final role = VenueTeamRole.fromWire(json['role'] as String?);
    if (role == null) return null;
    return VenueTeamSubmission(
      id: json['id'].toString(),
      role: role,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      status: VenueAboutSubmissionStatus.fromWire(json['status'] as String),
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      reviewNote: json['review_note'] as String?,
      removedAt: json['removed_at'] == null
          ? null
          : DateTime.parse(json['removed_at'] as String),
    );
  }

  /// Still waiting for review, and not withdrawn by a removal.
  bool get isOpen =>
      status == VenueAboutSubmissionStatus.pending && removedAt == null;
}

/// The team a manager's "Preview my page" shows: per role, what is still
/// waiting for review if anything, else what is shown now. A rejected or
/// withdrawn submission will not happen, so it changes nothing — the
/// same rule as the about text and photo previews.
List<VenueTeamMember> previewTeam({
  required List<VenueTeamMember> current,
  required Map<VenueTeamRole, VenueTeamSubmission> mine,
}) {
  final byRole = {for (final m in current) m.role: m};
  for (final s in mine.values) {
    if (s.isOpen) {
      byRole[s.role] = VenueTeamMember(role: s.role, name: s.name, bio: s.bio);
    }
  }
  return VenueTeamMember.ordered(byRole.values);
}
