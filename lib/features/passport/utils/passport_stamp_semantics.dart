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

/// "ABAC, Barcelona, Spain, 3 Michelin stars, visited January 2026" — the
/// accessibility label for one stamp. [countryName] is the full country
/// name resolved from `public.countries` (see [_PassportCollectionBodyState
/// ._countryNames] in passport_collection_body.dart) — [item] itself only
/// ever carries the ISO code (which is what the *visual* "CITY · CC" line
/// deliberately shows); falls back to the bare code only if that lookup
/// is unavailable (e.g. it failed to load), never blocking the label
/// entirely on it.
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
    'visited ${_fullMonths[item.date.month - 1]} ${item.date.year}',
  ];
  return parts.join(', ');
}
