/// One person's push toggles (`notification_preferences`). All default
/// to on: iOS's own permission prompt is the real opt-in. They decide
/// push only — the in-app Notifications list always shows everything.
class NotificationPreferences {
  final bool friendRequests;
  final bool followedVenueEvents;

  /// The day before a planned month's bookings open (20261101400000).
  final bool bookingReminders;

  const NotificationPreferences({
    this.friendRequests = true,
    this.followedVenueEvents = true,
    this.bookingReminders = true,
  });

  factory NotificationPreferences.fromRow(Map<String, dynamic> row) =>
      NotificationPreferences(
        friendRequests: row['push_friend_requests'] as bool? ?? true,
        followedVenueEvents: row['push_followed_venue_events'] as bool? ?? true,
        bookingReminders: row['push_booking_reminders'] as bool? ?? true,
      );

  Map<String, dynamic> toRow() => {
    'push_friend_requests': friendRequests,
    'push_followed_venue_events': followedVenueEvents,
    'push_booking_reminders': bookingReminders,
  };

  NotificationPreferences copyWith({
    bool? friendRequests,
    bool? followedVenueEvents,
    bool? bookingReminders,
  }) => NotificationPreferences(
    friendRequests: friendRequests ?? this.friendRequests,
    followedVenueEvents: followedVenueEvents ?? this.followedVenueEvents,
    bookingReminders: bookingReminders ?? this.bookingReminders,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.friendRequests == friendRequests &&
      other.followedVenueEvents == followedVenueEvents &&
      other.bookingReminders == bookingReminders;

  @override
  int get hashCode =>
      Object.hash(friendRequests, followedVenueEvents, bookingReminders);
}
