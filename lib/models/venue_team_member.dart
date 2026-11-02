import 'venue_about_submission.dart';

/// The people a restaurant or hotel can show on its page
/// (venue_team_submissions.role, 20261030170000; sommelier from
/// 20261101170000).
enum VenueTeamRole {
  manager,
  chef,
  sommelier;

  static VenueTeamRole? fromWire(String? value) => switch (value) {
    'manager' => VenueTeamRole.manager,
    'chef' => VenueTeamRole.chef,
    'sommelier' => VenueTeamRole.sommelier,
    _ => null,
  };

  /// The page's order: chef, manager, sommelier (decided 2026-11-02).
  static const pageOrder = [
    VenueTeamRole.chef,
    VenueTeamRole.manager,
    VenueTeamRole.sommelier,
  ];

  String get wireValue => name;

  /// What the page calls the role. A hotel's manager is the hotel's, not
  /// a restaurant's.
  String labelFor(String venueType) => switch (this) {
    VenueTeamRole.manager =>
      venueType == 'hotel' ? 'Hotel manager' : 'Restaurant manager',
    VenueTeamRole.chef => 'Chef',
    VenueTeamRole.sommelier => 'Sommelier',
  };

  /// The short label under a portrait in the page's team strip.
  String get shortLabel => switch (this) {
    VenueTeamRole.manager => 'Manager',
    VenueTeamRole.chef => 'Chef',
    VenueTeamRole.sommelier => 'Sommelier',
  };
}

/// One person as the page shows them: the latest approved, not removed
/// submission for that role (venue_team_current).
class VenueTeamMember {
  final VenueTeamRole role;
  final String name;
  final String? bio;

  /// The published portrait (catalogue-media), or null for none.
  final String? photoUrl;

  const VenueTeamMember({
    required this.role,
    required this.name,
    this.bio,
    this.photoUrl,
  });

  /// Null for a role this build doesn't know.
  static VenueTeamMember? fromJson(Map<String, dynamic> json) {
    final role = VenueTeamRole.fromWire(json['role'] as String?);
    if (role == null) return null;
    return VenueTeamMember(
      role: role,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  /// In the page's order: chef, manager, sommelier.
  static List<VenueTeamMember> ordered(Iterable<VenueTeamMember> members) =>
      [...members]..sort(
        (a, b) => VenueTeamRole.pageOrder
            .indexOf(a.role)
            .compareTo(VenueTeamRole.pageOrder.indexOf(b.role)),
      );
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

  /// A new portrait sent with this submission, in the private
  /// venue-photo-submissions bucket; null when it keeps the current one.
  final String? photoPath;

  /// Asks to take the current portrait off without a new one.
  final bool removePhoto;

  const VenueTeamSubmission({
    required this.id,
    required this.role,
    required this.name,
    this.bio,
    required this.status,
    required this.submittedAt,
    this.reviewNote,
    this.removedAt,
    this.photoPath,
    this.removePhoto = false,
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
      photoPath: json['photo_path'] as String?,
      removePhoto: (json['remove_photo'] as bool?) ?? false,
    );
  }

  /// Still waiting for review, and not withdrawn by a removal.
  bool get isOpen =>
      status == VenueAboutSubmissionStatus.pending && removedAt == null;
}

/// The team a manager's "Preview my page" shows: per role, what is still
/// waiting for review if anything, else what is shown now. A rejected or
/// withdrawn submission will not happen, so it changes nothing — the
/// same rule as the about text and photo previews. A waiting portrait
/// shows through [pendingPhotoUrls] (role -> a signed URL of the private
/// upload); without one, the role keeps its current portrait unless the
/// submission removes it.
List<VenueTeamMember> previewTeam({
  required List<VenueTeamMember> current,
  required Map<VenueTeamRole, VenueTeamSubmission> mine,
  Map<VenueTeamRole, String> pendingPhotoUrls = const {},
}) {
  final byRole = {for (final m in current) m.role: m};
  for (final s in mine.values) {
    if (s.isOpen) {
      final photoUrl = s.photoPath != null
          ? pendingPhotoUrls[s.role]
          : s.removePhoto
          ? null
          : byRole[s.role]?.photoUrl;
      byRole[s.role] = VenueTeamMember(
        role: s.role,
        name: s.name,
        bio: s.bio,
        photoUrl: photoUrl,
      );
    }
  }
  return VenueTeamMember.ordered(byRole.values);
}
