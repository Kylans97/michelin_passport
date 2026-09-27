import '../models/passport_stamp_award.dart';
import '../models/passport_stamp_item.dart';

const _fullMonths = [
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

/// "ABAC, Barcelona, Spain, 3 Michelin stars, 14 January 2026" — the
/// accessibility label for one stamp, per the September 2026 stamp
/// redesign brief's own literal example (previously "visited January
/// 2026" — month+year only, with a "visited" prefix the new brief drops
/// in favor of the exact same full day/month/year format the stamp's own
/// visual date slot now shows). [countryName] is the full country name
/// resolved from `public.countries` (see [_PassportCollectionBodyState
/// ._countryNames] in passport_collection_body.dart) — [item] itself only
/// ever carries the ISO code (which is what the *visual* "CITY · CC" line
/// deliberately shows); falls back to the bare code only if that lookup
/// is unavailable (e.g. it failed to load), never blocking the label
/// entirely on it.
///
/// A verified stamp (see `models/passport_stamp_item.dart`'s `verified`
/// field) appends ", verified by {venue}" — literally the venue's own
/// name again, per the brief's own example; redundant-looking next to the
/// name already leading the label, but that repetition is what the brief
/// asks for, not a bug to quietly "fix" by omitting it.
String stampSemanticLabel(PassportStampItem item, {String? countryName}) {
  final award = stampAwardFor(item);
  final awardPhrase = switch (award) {
    null => null,
    StarsAward(:final count) =>
      count == 1 ? '1 Michelin star' : '$count Michelin stars',
    KeysAward(:final count) =>
      count == 1 ? '1 MICHELIN Key' : '$count MICHELIN Keys',
    EventTypeAward(:final label) => label.toLowerCase(),
  };
  final country = (countryName != null && countryName.isNotEmpty)
      ? countryName
      : item.countryCode;

  final parts = [
    item.venueName,
    if (item.cityName.isNotEmpty) item.cityName,
    if (country.isNotEmpty) country,
    ?awardPhrase,
    '${item.date.day} ${_fullMonths[item.date.month - 1]} ${item.date.year}',
  ];
  final label = parts.join(', ');
  return item.verified ? '$label, verified by ${item.venueName}' : label;
}
