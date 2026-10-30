/// One person's push toggles (`notification_preferences`). Both default
/// to on: iOS's own permission prompt is the real opt-in. They decide
/// push only — the in-app Notifications list always shows everything.
class NotificationPreferences {
  final bool friendRequests;
  final bool followedVenueEvents;

  const NotificationPreferences({
    this.friendRequests = true,
    this.followedVenueEvents = true,
  });

  factory NotificationPreferences.fromRow(Map<String, dynamic> row) =>
      NotificationPreferences(
        friendRequests: row['push_friend_requests'] as bool? ?? true,
        followedVenueEvents: row['push_followed_venue_events'] as bool? ?? true,
      );

  Map<String, dynamic> toRow() => {
    'push_friend_requests': friendRequests,
    'push_followed_venue_events': followedVenueEvents,
  };

  NotificationPreferences copyWith({bool? friendRequests, bool? followedVenueEvents}) =>
      NotificationPreferences(
        friendRequests: friendRequests ?? this.friendRequests,
        followedVenueEvents: followedVenueEvents ?? this.followedVenueEvents,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.friendRequests == friendRequests &&
      other.followedVenueEvents == followedVenueEvents;

  @override
  int get hashCode => Object.hash(friendRequests, followedVenueEvents);
}
