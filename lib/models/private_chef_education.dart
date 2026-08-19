// Maps a row from `public.private_chef_education` (see
// supabase/migrations/20260818130000_add_private_chef_education.sql).
// One item in a chef's "Background" section — deliberately NOT modeled
// as a variant of PrivateChefRestaurantHistory: education background has
// a genuinely different, simpler shape (an institution and a program,
// no canonical FK, no Michelin-adjacent recognition, never tappable) —
// see the migration's own header comment for why a single generalized
// "background" model was rejected in favor of two small, typed tables.
class PrivateChefEducation {
  final String id;
  final String privateChefId;
  final String institution;
  final String program;
  final String? periodText;
  final int displayOrder;

  const PrivateChefEducation({
    required this.id,
    required this.privateChefId,
    required this.institution,
    required this.program,
    this.periodText,
    this.displayOrder = 0,
  });

  factory PrivateChefEducation.fromJson(Map<String, dynamic> json) =>
      PrivateChefEducation(
        id: json['id'].toString(),
        privateChefId: json['private_chef_id'].toString(),
        institution: (json['institution'] as String?) ?? '',
        program: (json['program'] as String?) ?? '',
        periodText: json['period_text'] as String?,
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      );
}
