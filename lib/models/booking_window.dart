import 'opening_hours.dart' show HoursTime;

/// When a restaurant's books open (restaurant_booking_windows,
/// 20261101400000). A verified fact, never an estimate: a window that
/// isn't known means no reminder, not a guess.
enum BookingWindowKind {
  /// On day X at [BookingWindow.releaseTime], day X + N days (or months)
  /// becomes bookable.
  rolling,

  /// On day D of each month, the month M months ahead opens, all of it.
  monthly,

  /// One-off releases, each opening a run of dates.
  seasonal,

  /// Looked into, not known. Never reminded.
  unknown;

  static BookingWindowKind fromWire(String value) => switch (value) {
    'rolling' => BookingWindowKind.rolling,
    'monthly' => BookingWindowKind.monthly,
    'seasonal' => BookingWindowKind.seasonal,
    _ => BookingWindowKind.unknown,
  };
}

/// Where the restaurant takes bookings. Optional, informational.
enum BookingPlatform {
  ownSite('own_site', 'Own website'),
  tock('tock', 'Tock'),
  resy('resy', 'Resy'),
  sevenrooms('sevenrooms', 'SevenRooms'),
  thefork('thefork', 'TheFork'),
  opentable('opentable', 'OpenTable'),
  phone('phone', 'Phone'),
  email('email', 'Email'),
  other('other', 'Other');

  final String wire;
  final String label;
  const BookingPlatform(this.wire, this.label);

  static BookingPlatform? fromWire(String? value) {
    for (final p in values) {
      if (p.wire == value) return p;
    }
    return null;
  }
}

/// A seasonal release: on [releaseOn] at [releaseTime] (null: not known),
/// the dates [coversFrom]–[coversTo] open.
class BookingRelease {
  final DateTime releaseOn;
  final HoursTime? releaseTime;
  final DateTime coversFrom;
  final DateTime coversTo;

  const BookingRelease({
    required this.releaseOn,
    this.releaseTime,
    required this.coversFrom,
    required this.coversTo,
  });

  factory BookingRelease.fromRow(Map<String, dynamic> row) => BookingRelease(
    releaseOn: DateTime.parse(row['release_on'] as String),
    releaseTime: row['release_time'] == null
        ? null
        : HoursTime.parse(row['release_time'] as String),
    coversFrom: DateTime.parse(row['covers_from'] as String),
    coversTo: DateTime.parse(row['covers_to'] as String),
  );

  Map<String, dynamic> toJson() => {
    'release_on': isoDate(releaseOn),
    'release_time': releaseTime?.label,
    'covers_from': isoDate(coversFrom),
    'covers_to': isoDate(coversTo),
  };
}

class BookingWindow {
  final BookingWindowKind kind;
  final String timezone;
  final int? rollingAmount;

  /// 'day' or 'month'.
  final String? rollingUnit;
  final int? releaseDay;
  final int? monthsAhead;

  /// Rolling and monthly. Null: the time is not known.
  final HoursTime? releaseTime;
  final BookingPlatform? platform;

  /// 'venue' (the restaurant's manager) or 'research'.
  final String sourceKind;
  final String? sourceUrl;
  final DateTime? verifiedOn;
  final List<BookingRelease> releases;

  const BookingWindow({
    required this.kind,
    required this.timezone,
    this.rollingAmount,
    this.rollingUnit,
    this.releaseDay,
    this.monthsAhead,
    this.releaseTime,
    this.platform,
    this.sourceKind = 'venue',
    this.sourceUrl,
    this.verifiedOn,
    this.releases = const [],
  });

  factory BookingWindow.fromRow(
    Map<String, dynamic> row, {
    List<BookingRelease> releases = const [],
  }) => BookingWindow(
    kind: BookingWindowKind.fromWire(row['kind'] as String),
    timezone: row['timezone'] as String,
    rollingAmount: row['rolling_amount'] as int?,
    rollingUnit: row['rolling_unit'] as String?,
    releaseDay: row['release_day'] as int?,
    monthsAhead: row['months_ahead'] as int?,
    releaseTime: row['release_time'] == null
        ? null
        : HoursTime.parse(row['release_time'] as String),
    platform: BookingPlatform.fromWire(row['platform'] as String?),
    sourceKind: row['source_kind'] as String? ?? 'venue',
    sourceUrl: row['source_url'] as String?,
    verifiedOn: row['verified_on'] == null
        ? null
        : DateTime.parse(row['verified_on'] as String),
    releases: releases,
  );

  /// set_restaurant_booking_window's p_window.
  Map<String, dynamic> toRpcJson() => {
    'kind': kind.name,
    'timezone': timezone,
    if (kind == BookingWindowKind.rolling) ...{
      'rolling_amount': rollingAmount,
      'rolling_unit': rollingUnit,
    },
    if (kind == BookingWindowKind.monthly) ...{
      'release_day': releaseDay,
      'months_ahead': monthsAhead,
    },
    if (kind != BookingWindowKind.seasonal) 'release_time': releaseTime?.label,
    if (kind == BookingWindowKind.seasonal)
      'releases': [for (final r in releases) r.toJson()],
    'platform': platform?.wire,
    'source_url': sourceUrl,
  };

  /// What is missing or wrong before saving, or null. Mirrors the
  /// table's own checks so the manager hears it before the server does.
  String? validationError() {
    switch (kind) {
      case BookingWindowKind.rolling:
        final max = rollingUnit == 'month' ? 24 : 730;
        if (rollingAmount == null ||
            rollingAmount! < 1 ||
            rollingAmount! > max) {
          return rollingUnit == 'month'
              ? 'Choose between 1 and 24 months.'
              : 'Choose between 1 and 730 days.';
        }
      case BookingWindowKind.monthly:
        if (releaseDay == null || releaseDay! < 1 || releaseDay! > 31) {
          return 'Choose the day of the month bookings open.';
        }
        if (monthsAhead == null || monthsAhead! < 1 || monthsAhead! > 24) {
          return 'Choose how many months ahead open.';
        }
      case BookingWindowKind.seasonal:
        if (releases.isEmpty) return 'Add at least one release.';
        for (final r in releases) {
          if (r.coversTo.isBefore(r.coversFrom)) {
            return 'A release must end on or after the day it starts.';
          }
          if (r.releaseOn.isAfter(r.coversFrom)) {
            return 'Bookings must open on or before the first date they cover.';
          }
        }
      case BookingWindowKind.unknown:
        return 'Choose how your bookings open.';
    }
    return null;
  }

  /// One line for the venue's landing page and the manager screen.
  String get summary {
    final at = releaseTime == null ? '' : ' at ${releaseTime!.label}';
    return switch (kind) {
      BookingWindowKind.rolling =>
        'Bookable ${_count(rollingAmount ?? 0, rollingUnit ?? 'day')} ahead, '
            'a new day opens daily$at',
      BookingWindowKind.monthly =>
        'On the ${ordinal(releaseDay ?? 1)} of each month$at, '
            'the month ${_count(monthsAhead ?? 0, 'month')} ahead opens',
      BookingWindowKind.seasonal =>
        releases.length == 1 ? '1 release' : '${releases.length} releases',
      BookingWindowKind.unknown => 'Not known',
    };
  }
}

/// The open status of a planned month, as get_my_wishlist_plans() judged
/// it in the restaurant's timezone.
enum BookingStatus {
  open,
  opensToday,
  upcoming;

  static BookingStatus? fromWire(String? value) => switch (value) {
    'open' => BookingStatus.open,
    'opens_today' => BookingStatus.opensToday,
    'upcoming' => BookingStatus.upcoming,
    _ => null,
  };
}

/// A restaurant on the member's wishlist with a month set.
class WishlistPlan {
  final String restaurantId;

  /// Always the 1st of the month.
  final DateTime plannedMonth;

  /// When that month opens, local to [timezone]; null when the window
  /// isn't known.
  final DateTime? opensOn;
  final HoursTime? opensTime;
  final String? timezone;
  final BookingStatus? status;
  final bool remindersEnabled;

  const WishlistPlan({
    required this.restaurantId,
    required this.plannedMonth,
    this.opensOn,
    this.opensTime,
    this.timezone,
    this.status,
    this.remindersEnabled = true,
  });

  factory WishlistPlan.fromRow(Map<String, dynamic> row) => WishlistPlan(
    restaurantId: row['restaurant_id'] as String,
    plannedMonth: DateTime.parse(row['planned_month'] as String),
    opensOn: row['opens_on'] == null
        ? null
        : DateTime.parse(row['opens_on'] as String),
    opensTime: row['opens_time'] == null
        ? null
        : HoursTime.parse(row['opens_time'] as String),
    timezone: row['timezone'] as String?,
    status: BookingStatus.fromWire(row['status'] as String?),
    remindersEnabled: row['reminders_enabled'] as bool? ?? true,
  );

  /// "Going in May 2027".
  String get monthLabel => 'Going in ${monthYear(plannedMonth)}';

  /// The second line, or null when the window isn't known — then the card
  /// says nothing rather than guess. [now] decides whether the opening
  /// date needs its year.
  String? statusLine(DateTime now) {
    final month = monthNames[plannedMonth.month - 1];
    switch (status) {
      case BookingStatus.open:
        return '$month is open for booking now.';
      case BookingStatus.opensToday:
        return 'Bookings for $month open today.';
      case BookingStatus.upcoming:
        final on = opensOn!;
        final date = on.year == now.year
            ? '${on.day} ${monthNames[on.month - 1]}'
            : '${on.day} ${monthNames[on.month - 1]} ${on.year}';
        final time = opensTime == null
            ? ''
            : ' at ${opensTime!.label} (${timezoneCity(timezone ?? '')} time)';
        final remind = remindersEnabled
            ? ' We’ll remind you the day before.'
            : '';
        return 'Bookings for $month open $date$time.$remind';
      case null:
        return null;
    }
  }
}

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "May 2027".
String monthYear(DateTime month) =>
    '${monthNames[month.month - 1]} ${month.year}';

/// "Paris" for Europe/Paris, "New York" for America/New_York.
String timezoneCity(String timezone) =>
    timezone.split('/').last.replaceAll('_', ' ');

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

String _count(int n, String unit) => n == 1 ? '1 $unit' : '$n ${unit}s';

/// yyyy-mm-dd.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
