import '../../models/journey.dart';

/// One kind of cabin and how many there are, as the cabins text states it:
/// "Suites (16)" is a group named Suites with 16; "35 sleeper cabins" is a
/// single unnamed group of 35.
class CabinGroup {
  final String? name;
  final int count;

  const CabinGroup({required this.name, required this.count});
}

/// The cabins a journey's own text counts, or nothing. Read straight from
/// `cabins_text`, never estimated: a text without numbers draws no cabins.
class CabinLayout {
  final List<CabinGroup> groups;

  /// True when the text speaks only of suites, so the figure reads
  /// "Suites" rather than "Cabins".
  final bool suitesOnly;

  const CabinLayout({required this.groups, required this.suitesOnly});

  int get total => groups.fold(0, (sum, g) => sum + g.count);
}

// "Historic Cabins (32)", one part of a comma-separated list.
final _groupPart = RegExp(r'^(.+?)\s*\((\d+)\)$');
// "35 sleeper cabins: twin and bunk-bed cabins", "123 cabins and suites".
final _leadingCount = RegExp(r'^(\d+)\s+([A-Za-z][^:;,(]*)');

/// Parses [cabinsText] into counted cabins. Two shapes are recognised, and
/// only when the whole text fits one: a leading count ("95 suites"), or a
/// list in which every part carries its count in brackets. Anything else
/// (a list of cabin types with no numbers) returns null.
CabinLayout? parseCabins(String? cabinsText) {
  final text = (cabinsText ?? '').trim();
  if (text.isEmpty) return null;

  final parts = text.split(',').map((p) => p.trim()).toList();
  final groupMatches = [for (final part in parts) _groupPart.firstMatch(part)];
  if (parts.length > 1 && groupMatches.every((m) => m != null)) {
    final groups = [
      for (final m in groupMatches)
        CabinGroup(name: m!.group(1)!.trim(), count: int.parse(m.group(2)!)),
    ];
    final words = groups.map((g) => g.name!.toLowerCase());
    return _valid(
      CabinLayout(
        groups: groups,
        suitesOnly: words.every((w) => w.contains('suite')),
      ),
    );
  }

  final lead = _leadingCount.firstMatch(text);
  if (lead != null) {
    final unit = lead.group(2)!.toLowerCase();
    return _valid(
      CabinLayout(
        groups: [CabinGroup(name: null, count: int.parse(lead.group(1)!))],
        suitesOnly: unit.contains('suite') && !unit.contains('cabin'),
      ),
    );
  }
  return null;
}

CabinLayout? _valid(CabinLayout layout) =>
    layout.total > 0 && layout.groups.every((g) => g.count > 0) ? layout : null;

/// One serif figure in the row under the summary: "2" over "NIGHTS".
class JourneyFigure {
  final String value;
  final String label;

  const JourneyFigure(this.value, this.label);
}

/// The figures a journey actually states, in a fixed order of interest,
/// at most three. Fewer than two returns none: a lone number reads as a
/// gap, not a picture.
List<JourneyFigure> journeyFigures({
  required Journey journey,
  required List<JourneyRoute> routes,
  required CabinLayout? cabins,
  required int countryCount,
}) {
  final nights = routes.length == 1 ? routes.single.nights : null;
  final figures = [
    if (routes.length > 1) JourneyFigure('${routes.length}', 'Routes'),
    if (nights != null && nights > 0)
      JourneyFigure('$nights', nights == 1 ? 'Night' : 'Nights'),
    if (cabins != null)
      JourneyFigure('${cabins.total}', switch ((
        cabins.suitesOnly,
        cabins.total == 1,
      )) {
        (true, true) => 'Suite',
        (true, false) => 'Suites',
        (false, true) => 'Cabin',
        (false, false) => 'Cabins',
      }),
    if (journey.guestCapacity != null)
      JourneyFigure('${journey.guestCapacity}', 'Guests'),
    if (countryCount > 1) JourneyFigure('$countryCount', 'Countries'),
  ];
  return figures.length < 2 ? const [] : figures.take(3).toList();
}

/// Every country the journey is known to touch: its own country, both
/// ends of every route, and every stop.
Set<String> journeyCountryCodes(
  Journey journey,
  Iterable<JourneyRouteStop> stops,
) => {
  ?journey.primaryCountryCode,
  ...journey.routeCountryCodes,
  for (final stop in stops) stop.countryCode,
}..removeWhere((code) => code.isEmpty);
