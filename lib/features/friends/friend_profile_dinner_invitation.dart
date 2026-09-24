/// STUB — no `dinner_invitations` table or RPC exists in the backend yet.
/// This model exists so "Plan a dinner" (7d) has a real, typed shape to
/// build against rather than passing loose maps around, but constructing
/// one here does NOT persist anything anywhere — see
/// FriendProfilePlanDinnerSheet's own `_send` for exactly what happens
/// today (a local confirmation only) and
/// docs/Architecture/EDITORIAL_REDESIGN_TRACKING.md for the backend work
/// this is waiting on.
///
/// TODO(dinner-invitations): once a real table/RPC exists, this needs:
/// - `dinner_invitations` table: id, from_user, to_user, venue_id,
///   venue_type (restaurant/hotel — this app never assumes id uniqueness
///   across tables, see CLAUDE.md's own "Identity" rule), proposed_dates
///   (date[]), meal_type, note, status, chosen_date, created_at.
/// - RLS: both participants can read; only `from_user` can insert; only
///   `to_user` can update `status`/`chosen_date` (accept/decline/pick a
///   date); neither can update anything else after creation.
/// - A repository (`DinnerInvitationRepository`) wrapping that table —
///   `sendInvitation`, `respondToInvitation`, `getInvitation`.
/// - The recipient-side UI this same card promises ("de vriend ziet in-
///   app dezelfde kaart, met de voorgestelde datums om te kiezen, plus
///   Decline") — nothing renders this today; there is no inbox/
///   notification surface for it yet either (see the existing in-app
///   notifications feature for the likely integration point).
enum DinnerInvitationStatus { pending, accepted, declined }

enum DinnerMealType {
  dinner,
  lunch;

  String get label => switch (this) {
    DinnerMealType.dinner => 'Dinner',
    DinnerMealType.lunch => 'Lunch',
  };
}

class DinnerInvitation {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String venueId;
  final bool venueIsHotel;
  final List<DateTime> proposedDates;
  final DinnerMealType mealType;
  final String? note;
  final DinnerInvitationStatus status;
  final DateTime? chosenDate;

  const DinnerInvitation({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.venueId,
    required this.venueIsHotel,
    required this.proposedDates,
    required this.mealType,
    this.note,
    this.status = DinnerInvitationStatus.pending,
    this.chosenDate,
  });
}
