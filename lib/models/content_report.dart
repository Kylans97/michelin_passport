/// What kind of content a report targets — mirrors `content_reports`'
/// `content_type` check constraint exactly. `event` is included for
/// schema forward-compatibility (Apple's own stated content categories)
/// but has no Report action wired to it yet — no screen shows another
/// user's event content today, only aggregate/anonymous attendance.
enum ReportContentType {
  photo,
  rating,
  profile,
  event;

  String get wireValue => name;
}

/// Deliberately short and generic — refined once real reports start
/// coming in, per the product decision behind this table.
enum ReportReason {
  inappropriate,
  spam,
  misleading,
  other;

  String get wireValue => name;

  String get label => switch (this) {
    ReportReason.inappropriate => 'Inappropriate content',
    ReportReason.spam => 'Spam',
    ReportReason.misleading => 'Misleading',
    ReportReason.other => 'Something else',
  };
}
