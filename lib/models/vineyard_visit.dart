import 'vineyard.dart';

/// What a member did at an estate — the fixed set the
/// `vineyard_visits.activities` check allows (20261101570000).
enum VineyardActivity {
  tasting('tasting', 'Tasting'),
  cellarTour('cellar_tour', 'Cellar tour'),
  lunch('lunch', 'Lunch'),
  vineyardWalk('vineyard_walk', 'Walk in the vines'),
  stay('stay', 'Stayed the night');

  const VineyardActivity(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static VineyardActivity? fromDb(String value) {
    for (final a in values) {
      if (a.dbValue == value) return a;
    }
    return null;
  }
}

/// One visit to a wine estate (`public.vineyard_visits`). Its own table,
/// not a `visits` row: shipped builds read `visits` as hotel-else-
/// restaurant. Private unless the member shares it with friends.
class VineyardVisit {
  final String id;
  final String vineyardId;
  final DateTime visitedOn;
  final Set<VineyardActivity> activities;
  final int? rating;
  final String? comment;
  final bool friendsVisible;

  const VineyardVisit({
    required this.id,
    required this.vineyardId,
    required this.visitedOn,
    this.activities = const {},
    this.rating,
    this.comment,
    this.friendsVisible = false,
  });

  factory VineyardVisit.fromMap(Map<String, dynamic> map) => VineyardVisit(
    id: map['id'] as String,
    vineyardId: map['vineyard_id'] as String,
    visitedOn: DateTime.parse(map['visited_on'] as String),
    activities: {
      for (final value in (map['activities'] as List?) ?? const [])
        ?VineyardActivity.fromDb(value as String),
    },
    rating: (map['rating'] as num?)?.toInt(),
    comment: map['comment'] as String?,
    friendsVisible: map['visibility'] == 'friends',
  );
}

/// One visit plus the estate it was at — what a Passport estate stamp
/// needs. A plain pair beside JourneyTravelEntry, not a PassportVenue, for
/// the same reason journeys were kept out of that sealed type.
class VineyardVisitEntry {
  final VineyardVisit visit;
  final Vineyard vineyard;

  const VineyardVisitEntry({required this.visit, required this.vineyard});
}

/// The insert map for a visit — pure, so its shape is unit-testable
/// without a Supabase client.
Map<String, dynamic> buildVineyardVisitInsert({
  required String userId,
  required String vineyardId,
  required DateTime visitedOn,
  Set<VineyardActivity> activities = const {},
  String? comment,
  bool friendsVisible = false,
}) => {
  'user_id': userId,
  'vineyard_id': vineyardId,
  'visited_on': _isoDate(visitedOn),
  'activities': [
    for (final a in VineyardActivity.values)
      if (activities.contains(a)) a.dbValue,
  ],
  if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
  'visibility': friendsVisible ? 'friends' : 'private',
};

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
