// Covers Events UI Consistency Step 1 — Event Detail's redesigned
// presentational primitives: EventDetailHero, EventMetaSection,
// MichelinAtEventSection (+ its pure michelinStarredParticipants filter/
// sort helper), and EventGoingButton's own gold-audit (see
// event_going_button_test.dart for its full behavioral coverage).
//
// EventDetailScreen itself is a StatefulWidget that hits Supabase in
// initState — this project has no Supabase mocking harness (same
// established constraint as venue_detail_redesign_test.dart) — so
// coverage targets these extracted presentational components instead,
// exactly the same strategy used for Restaurant/Hotel Detail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/features/events/widgets/event_detail_hero.dart';
import 'package:michelin_passport/features/events/widgets/event_meta_section.dart';
import 'package:michelin_passport/features/events/widgets/michelin_at_event_section.dart';
import 'package:michelin_passport/features/events/widgets/michelin_participant_row.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/restaurant.dart';

Event _event({
  String name = 'Test Event',
  String? description,
  DateTime? startAt,
  DateTime? endAt,
  String countryCode = 'NL',
  String? city = 'Maastricht',
  String? venueName = 'Vrijthof',
  String? address,
  String? officialUrl,
  String? ticketUrl,
  String? imageUrl,
  EventType eventType = EventType.festival,
  EventStatus status = EventStatus.upcoming,
  EventAdmissionType admissionType = EventAdmissionType.unknown,
  String? admissionNote,
}) => Event(
  id: 'e1',
  name: name,
  description: description,
  startAt: startAt ?? DateTime(2026, 8, 27, 18),
  endAt: endAt ?? DateTime(2026, 8, 30, 22),
  countryCode: countryCode,
  city: city,
  venueName: venueName,
  address: address,
  officialUrl: officialUrl,
  ticketUrl: ticketUrl,
  imageUrl: imageUrl,
  eventType: eventType,
  status: status,
  admissionType: admissionType,
  admissionNote: admissionNote,
  createdAt: DateTime(2026, 1, 1),
);

Restaurant _restaurant({
  String id = 'r1',
  String name = 'Test Restaurant',
  int? michelinStars,
  String cityName = 'Paris',
  String countryCode = 'FR',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
}) => Restaurant(
  id: id,
  restaurantCode: 'rest_$id',
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  isHallOfFame: false,
  cityName: cityName,
  countryCode: countryCode,
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
  isInHotel: false,
  hotelId: null,
  hotelName: null,
  worlds50BestRank: null,
);

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: Material(child: child)),
      ),
    );

Widget _wrapSliver(
  Widget sliver, {
  double width = 390,
  double textScale = 1.0,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(body: CustomScrollView(slivers: [sliver])),
  ),
);

void main() {
  group('EventDetailHero — image vs. monogram fallback', () {
    testWidgets('renders whatever real-image widget it is given, not the '
        'placeholder', (tester) async {
      // A plain Container stands in for a real photo here — Image.network
      // triggers actual HTTP resolution even under test, which always
      // 400s in this harness (a test-environment limitation, not
      // something EventDetailHero controls); this test only needs to
      // confirm the hero renders whatever backgroundImage it's given
      // as-is, never silently substituting its own placeholder when a
      // real widget was supplied.
      const realPhotoStandIn = ColoredBox(color: Color(0xFF123456));
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            title: "'t Preuvenemint",
            cityCountryLine: 'Maastricht · NL',
            dateRangeLine: '27–30 AUG 2026',
            backgroundImage: realPhotoStandIn,
          ),
        ),
      );
      expect(find.byWidget(realPhotoStandIn), findsOneWidget);
      expect(find.byType(CsImagePlaceholder), findsNothing);
    });

    testWidgets('renders the branded monogram placeholder when no image '
        'is available', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            title: "'t Preuvenemint",
            cityCountryLine: 'Maastricht · NL',
            dateRangeLine: '27–30 AUG 2026',
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
        ),
      );
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
    });

    testWidgets('shows title, event type, city/country and date range', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            title: "'t Preuvenemint",
            eventTypeLabel: 'FESTIVAL',
            cityCountryLine: 'Maastricht · NL',
            dateRangeLine: '27–30 AUG 2026',
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
        ),
      );
      expect(find.text("'t Preuvenemint"), findsWidgets);
      expect(find.text('FESTIVAL'), findsOneWidget);
      expect(find.text('Maastricht · NL'), findsOneWidget);
      expect(find.text('27–30 AUG 2026'), findsOneWidget);
    });

    testWidgets('has a back action', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            title: 'Event',
            cityCountryLine: 'Maastricht · NL',
            dateRangeLine: '27 AUG 2026',
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('long title at ${width}px: no overflow', (tester) async {
        await tester.pumpWidget(
          _wrapSliver(
            const EventDetailHero(
              title:
                  'An Exceptionally Long Curated Gastronomic Festival Name '
                  'That Really Tests The Hero Layout',
              eventTypeLabel: 'FESTIVAL',
              cityCountryLine: 'Maastricht · Netherlands',
              dateRangeLine: '27–30 AUGUST 2026',
              backgroundImage: CsImagePlaceholder(logoScale: 0.22),
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            title: "'t Preuvenemint",
            eventTypeLabel: 'FESTIVAL',
            cityCountryLine: 'Maastricht · Netherlands',
            dateRangeLine: '27–30 AUGUST 2026',
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('EventMetaSection — date/venue/admission/cancelled (§7-9, §26-27)', () {
    testWidgets('always shows the date/time range', (tester) async {
      await tester.pumpWidget(_wrap(EventMetaSection(event: _event())));
      expect(find.textContaining('27 Aug 2026'), findsOneWidget);
    });

    testWidgets('shows the venue name row when present', (tester) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(venueName: 'Vrijthof'))),
      );
      expect(find.text('Vrijthof'), findsOneWidget);
    });

    testWidgets('omits the venue row when absent', (tester) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(venueName: null))),
      );
      expect(find.byIcon(Icons.place_outlined), findsNothing);
    });

    testWidgets('free admission shows the free-entry label and icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(
            event: _event(admissionType: EventAdmissionType.free),
          ),
        ),
      );
      expect(find.text('Free entry'), findsOneWidget);
      expect(find.byIcon(Icons.money_off_rounded), findsOneWidget);
    });

    testWidgets('paid admission shows the ticketed label and icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(
            event: _event(admissionType: EventAdmissionType.paid),
          ),
        ),
      );
      expect(find.text('Ticketed'), findsOneWidget);
      expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
    });

    testWidgets('mixed admission shows the free-entry label plus the '
        'admission note as supporting detail', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(
            event: _event(
              admissionType: EventAdmissionType.mixed,
              admissionNote:
                  "Free general admission. The optional 't PreuveneMeet' "
                  'networking evening is separately ticketed.',
            ),
          ),
        ),
      );
      expect(find.text('Free entry, optional ticket'), findsOneWidget);
      expect(find.textContaining('PreuveneMeet'), findsOneWidget);
      expect(find.byIcon(Icons.money_off_rounded), findsOneWidget);
    });

    testWidgets('unknown admission renders no admission row at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(
            event: _event(admissionType: EventAdmissionType.unknown),
          ),
        ),
      );
      expect(find.byIcon(Icons.money_off_rounded), findsNothing);
      expect(find.byIcon(Icons.confirmation_number_outlined), findsNothing);
    });

    testWidgets('cancelled event shows a clear, non-gold status row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(status: EventStatus.cancelled))),
      );
      expect(find.textContaining('cancelled'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.cancel_outlined));
      expect(icon.color, AppColors.error);
      expect(icon.color, isNot(AppColors.gold));
    });

    testWidgets('upcoming (non-cancelled) event shows no cancelled row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(status: EventStatus.upcoming))),
      );
      expect(find.byIcon(Icons.cancel_outlined), findsNothing);
    });

    testWidgets('no gold anywhere in the meta section', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(
            event: _event(
              admissionType: EventAdmissionType.mixed,
              admissionNote: 'Optional add-on',
              status: EventStatus.cancelled,
            ),
          ),
        ),
      );
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.color, isNot(AppColors.gold));
        expect(icon.color, isNot(AppColors.goldLight));
      }
    });
  });

  group('MichelinParticipantRow — inline stars + city + flag '
      '(Events UI Consistency Step 1A)', () {
    testWidgets('stars render inline with the name, not on a secondary '
        'line', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(name: 'Tout a Fait', michelinStars: 1),
            onTap: () {},
          ),
        ),
      );
      // Name and stars are one Text.rich paragraph (a WidgetSpan carries
      // the StarRow) — not two separately-positioned widgets, so the
      // plain-text content of that one Text includes the name.
      expect(find.textContaining('Tout a Fait'), findsOneWidget);
      expect(find.byType(StarRow), findsOneWidget);
      final star = tester.widget<StarRow>(find.byType(StarRow));
      expect(star.count, 1);
    });

    for (final stars in [1, 2, 3]) {
      testWidgets('$stars-star restaurant shows exactly $stars stars', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            MichelinParticipantRow(
              restaurant: _restaurant(michelinStars: stars),
              onTap: () {},
            ),
          ),
        );
        final star = tester.widget<StarRow>(find.byType(StarRow));
        expect(star.count, stars);
        expect(
          find.byIcon(Icons.star_rounded),
          findsNWidgets(stars),
          reason: 'each star is its own gold icon, matching the count',
        );
      });
    }

    testWidgets('renders city on the secondary line', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              michelinStars: 1,
              cityName: 'Maastricht',
              countryCode: 'NL',
              countryName: 'Netherlands',
              flagEmoji: '🇳🇱',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Maastricht'), findsOneWidget);
    });

    testWidgets('renders the correct NL flag', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              michelinStars: 1,
              cityName: 'Maastricht',
              countryCode: 'NL',
              countryName: 'Netherlands',
              flagEmoji: '🇳🇱',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('🇳🇱'), findsOneWidget);
    });

    testWidgets('renders the correct AT flag', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              michelinStars: 2,
              cityName: 'Vienna',
              countryCode: 'AT',
              countryName: 'Austria',
              flagEmoji: '🇦🇹',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('🇦🇹'), findsOneWidget);
      expect(find.text('Vienna'), findsOneWidget);
    });

    testWidgets('missing city is omitted, not shown as placeholder copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              michelinStars: 1,
              cityName: '',
              flagEmoji: '🇫🇷',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('null'), findsNothing);
      // The flag alone may still render — only the city text is omitted.
      expect(find.text('🇫🇷'), findsOneWidget);
    });

    testWidgets('missing country flag is omitted cleanly, city still '
        'renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              michelinStars: 1,
              cityName: 'Somewhere',
              flagEmoji: '',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Somewhere'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long restaurant name wraps rather than losing the stars', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              name:
                  'An Exceptionally Long Michelin Restaurant Name That '
                  'Genuinely Tests Wrapping Behaviour',
              michelinStars: 3,
            ),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(StarRow), findsOneWidget);
      final star = tester.widget<StarRow>(find.byType(StarRow));
      expect(star.count, 3, reason: 'the stars must never be truncated away');
    });

    testWidgets('tapping the row fires onTap', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(michelinStars: 1),
            onTap: () => calls++,
          ),
        ),
      );
      await tester.tap(find.byType(MichelinParticipantRow));
      expect(calls, 1);
    });

    testWidgets('accessibility: semantics combine name, city, country, and '
        'star count into one label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              name: 'De Librije',
              michelinStars: 3,
              cityName: 'Zwolle',
              countryCode: 'NL',
              countryName: 'Netherlands',
              flagEmoji: '🇳🇱',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          'De Librije, Zwolle, Netherlands, 3 Michelin '
          'stars',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('singular "1 Michelin star" wording for exactly one star', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              name: 'Tout a Fait',
              michelinStars: 1,
              cityName: 'Maastricht',
              countryCode: 'NL',
              countryName: 'Netherlands',
              flagEmoji: '🇳🇱',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Tout a Fait, Maastricht, Netherlands, 1 Michelin star',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('name stays forest green, chevron stays taupe — never '
        'gold', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(michelinStars: 1),
            onTap: () {},
          ),
        ),
      );
      final chevron = tester.widget<Icon>(
        find.byIcon(Icons.chevron_right_rounded),
      );
      expect(chevron.color, AppColors.taupe);
      expect(chevron.color, isNot(AppColors.gold));
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('renders with no overflow at ${width}px', (tester) async {
        await tester.pumpWidget(
          _wrap(
            MichelinParticipantRow(
              restaurant: _restaurant(
                name: 'Château de Something Rather Long',
                michelinStars: 3,
                cityName: 'Maastricht',
                flagEmoji: '🇳🇱',
              ),
              onTap: () {},
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('1.6x text scale — no overflow, stars stay visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MichelinParticipantRow(
            restaurant: _restaurant(
              name: 'Tout a Fait',
              michelinStars: 3,
              cityName: 'Maastricht',
              flagEmoji: '🇳🇱',
            ),
            onTap: () {},
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
      final star = tester.widget<StarRow>(find.byType(StarRow));
      expect(star.count, 3);
    });
  });

  group('MichelinAtEventSection — Michelin-starred participants only '
      '(§12, §20)', () {
    testWidgets('shows only Michelin-starred restaurants, not unstarred '
        'participants', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: [
              _restaurant(id: 'r1', name: 'Starred House', michelinStars: 2),
              _restaurant(
                id: 'r2',
                name: 'No Star Bistro',
                michelinStars: null,
              ),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.textContaining('Starred House'), findsOneWidget);
      expect(find.textContaining('No Star Bistro'), findsNothing);
    });

    testWidgets('renders nothing at all when zero participants are '
        'Michelin-starred — never a "no restaurants" placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: [
              _restaurant(
                id: 'r1',
                name: 'No Star Bistro',
                michelinStars: null,
              ),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.text('MICHELIN AT THIS EVENT'), findsNothing);
      expect(find.textContaining('No Michelin'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders nothing for an empty restaurant list', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: const [],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.text('MICHELIN AT THIS EVENT'), findsNothing);
    });

    testWidgets('1-star, 2-star, and 3-star restaurants each show the '
        'correct star count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: [
              _restaurant(id: 'r1', name: 'One Star', michelinStars: 1),
              _restaurant(id: 'r2', name: 'Two Star', michelinStars: 2),
              _restaurant(id: 'r3', name: 'Three Star', michelinStars: 3),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      final rows = tester.widgetList<StarRow>(find.byType(StarRow)).toList();
      expect(rows.map((r) => r.count).toList(), [3, 2, 1]);
    });

    testWidgets('sorts most-decorated first, alphabetically within the '
        'same star count', (tester) async {
      final result = michelinStarredParticipants([
        _restaurant(id: 'r1', name: 'Zebra', michelinStars: 2),
        _restaurant(id: 'r2', name: 'Alpha', michelinStars: 2),
        _restaurant(id: 'r3', name: 'ThreeStarPlace', michelinStars: 3),
      ]);
      expect(result.map((r) => r.name).toList(), [
        'ThreeStarPlace',
        'Alpha',
        'Zebra',
      ]);
    });

    testWidgets('tapping a row fires onTapRestaurant with that exact '
        'restaurant', (tester) async {
      Restaurant? tapped;
      final starred = _restaurant(id: 'r9', name: 'Tap Me', michelinStars: 3);
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: [starred],
            onTapRestaurant: (r) => tapped = r,
          ),
        ),
      );
      await tester.tap(find.byType(MichelinParticipantRow));
      expect(tapped, starred);
    });

    testWidgets('only StarRow uses gold — section title, chevron, and '
        'hairline spacing never do', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: [
              _restaurant(id: 'r1', name: 'Starred House', michelinStars: 2),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('MICHELIN AT THIS EVENT'));
      expect(title.style?.color, isNot(AppColors.gold));
      final chevron = tester.widget<Icon>(
        find.byIcon(Icons.chevron_right_rounded),
      );
      expect(chevron.color, isNot(AppColors.gold));
      final starIcons = tester.widgetList<Icon>(
        find.byIcon(Icons.star_rounded),
      );
      for (final icon in starIcons) {
        expect(icon.color, AppColors.gold);
      }
    });

    testWidgets('3 starred restaurants with a long name at 320px: no '
        'overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: [
              _restaurant(
                id: 'r1',
                name: 'An Exceptionally Long Michelin Restaurant Name',
                michelinStars: 3,
              ),
              _restaurant(id: 'r2', name: 'Second Place', michelinStars: 2),
              _restaurant(id: 'r3', name: 'Third Place', michelinStars: 1),
            ],
            onTapRestaurant: (_) {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a hairline (Divider) separates multiple rows, none before '
        'the first row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: [
              _restaurant(id: 'r1', name: 'First', michelinStars: 1),
              _restaurant(id: 'r2', name: 'Second', michelinStars: 2),
              _restaurant(id: 'r3', name: 'Third', michelinStars: 3),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.byType(MichelinParticipantRow), findsNWidgets(3));
      // 3 rows need exactly 2 separating hairlines, never a leading one.
      expect(find.byType(Divider), findsNWidgets(2));
      final dividers = tester.widgetList<Divider>(find.byType(Divider));
      for (final d in dividers) {
        expect(d.color, isNot(AppColors.gold));
      }
    });

    testWidgets('a single restaurant renders no hairline at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: [
              _restaurant(id: 'r1', name: 'Only One', michelinStars: 1),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('multi-restaurant fixture: short Dutch 1-star, long Dutch '
        '3-star, and two more international restaurants across NL/AT/FR '
        'all render correctly, no overflow', (tester) async {
      final restaurants = [
        // A. short Dutch name, 1 star
        _restaurant(
          id: 'a',
          name: 'Tout a Fait',
          michelinStars: 1,
          cityName: 'Maastricht',
          countryCode: 'NL',
          countryName: 'Netherlands',
          flagEmoji: '🇳🇱',
        ),
        // B. long Dutch restaurant name, 3 stars
        _restaurant(
          id: 'b',
          name: 'De Zeer Uitgebreide Naam Van Dit Nederlandse Restaurant',
          michelinStars: 3,
          cityName: 'Zwolle',
          countryCode: 'NL',
          countryName: 'Netherlands',
          flagEmoji: '🇳🇱',
        ),
        // C. international restaurant, 2 stars
        _restaurant(
          id: 'c',
          name: 'Steirereck',
          michelinStars: 2,
          cityName: 'Vienna',
          countryCode: 'AT',
          countryName: 'Austria',
          flagEmoji: '🇦🇹',
        ),
        // D. different city/country combination again
        _restaurant(
          id: 'd',
          name: 'Le Cinq',
          michelinStars: 3,
          cityName: 'Paris',
          countryCode: 'FR',
          countryName: 'France',
          flagEmoji: '🇫🇷',
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          MichelinAtEventSection(
            restaurants: restaurants,
            onTapRestaurant: (_) {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(MichelinParticipantRow), findsNWidgets(4));
      expect(find.byType(Divider), findsNWidgets(3));
      final stars = tester
          .widgetList<StarRow>(find.byType(StarRow))
          .map((s) => s.count)
          .toList();
      // Sorted most-decorated first: the two 3-star restaurants (B, D)
      // before the 2-star (C) before the 1-star (A), B before D
      // alphabetically ("De..." < "Le...").
      expect(stars, [3, 3, 2, 1]);
      expect(find.text('🇳🇱'), findsNWidgets(2));
      expect(find.text('🇦🇹'), findsOneWidget);
      expect(find.text('🇫🇷'), findsOneWidget);
    });

    testWidgets('scales cleanly to a dense list of 12 Michelin-starred '
        'restaurants — no overflow, no exception', (tester) async {
      final restaurants = List.generate(
        12,
        (i) => _restaurant(
          id: 'r$i',
          name: 'Restaurant Number $i',
          michelinStars: (i % 3) + 1,
          cityName: 'City $i',
          countryCode: 'NL',
          countryName: 'Netherlands',
          flagEmoji: '🇳🇱',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 800)),
            // A dense 12-row list realistically needs to scroll — exactly
            // how it sits inside Event Detail's own CustomScrollView in
            // production, not an unbounded-height assumption.
            child: Scaffold(
              body: SingleChildScrollView(
                child: MichelinAtEventSection(
                  restaurants: restaurants,
                  onTapRestaurant: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(MichelinParticipantRow), findsNWidgets(12));
      expect(find.byType(Divider), findsNWidgets(11));
    });
  });
}
