// Covers Events UI Consistency Step 1 — Event Detail's redesigned
// presentational primitives: EventDetailHero, EventMetaSection,
// AtThisEventSection (+ its pure recognizedEventParticipants filter/
// sort helper, and isRecognizedEventParticipant eligibility predicate —
// Events Recognition V2, generalized from the original Michelin-only
// michelinStarredParticipants/MichelinParticipantRow to also admit
// World's 50 Best/Hall of Fame recognition). The former
// EventGoingButton's own gold-audit now lives in
// event_intent_controls_test.dart, covering its Events V2 Step 3
// successor EventIntentControls.
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
import 'package:michelin_passport/features/events/widgets/at_this_event_section.dart';
import 'package:michelin_passport/features/events/widgets/event_actions_row.dart';
import 'package:michelin_passport/features/events/widgets/event_detail_hero.dart';
import 'package:michelin_passport/features/events/widgets/event_meta_section.dart';
import 'package:michelin_passport/features/events/widgets/event_participant_row.dart';
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
  String? timezone = 'UTC',
}) => Event(
  id: 'e1',
  name: name,
  description: description,
  // Re-tagged as UTC (same digits the caller wrote) + paired with an
  // explicit 'UTC' timezone by default, so formatEventDateTime/
  // formatEventDateRange render deterministically regardless of the test
  // machine's own zone — see events_test.dart's _event() for the full
  // rationale.
  startAt: _utc(startAt ?? DateTime(2026, 8, 27, 18)),
  endAt: _utc(endAt ?? DateTime(2026, 8, 30, 22)),
  timezone: timezone,
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

DateTime _utc(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);

Restaurant _restaurant({
  String id = 'r1',
  String name = 'Test Restaurant',
  int? michelinStars,
  String cityName = 'Paris',
  String countryCode = 'FR',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
  bool isHallOfFame = false,
  int? worlds50BestRank,
}) => Restaurant(
  id: id,
  restaurantCode: 'rest_$id',
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  isHallOfFame: isHallOfFame,
  cityName: cityName,
  countryCode: countryCode,
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
  isInHotel: false,
  hotelId: null,
  hotelName: null,
  worlds50BestRank: worlds50BestRank,
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

    testWidgets('background is AppColors.deepGreen — the canonical primary '
        'brand dark surface (Green Token Consistency Migration reference '
        'point: this hero was already correct, never touched, and stays '
        'the audit anchor every migrated masthead now matches)', (
      tester,
    ) async {
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
      final hero = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(hero.backgroundColor, equals(AppColors.deepGreen));
      expect(hero.backgroundColor, isNot(equals(AppColors.forestGreen)));
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

    testWidgets('Events V2 Time Precision Phase B UX correction: the real '
        'Event Detail call site no longer supplies eventTypeLabel or '
        'dateRangeLine — both render nothing when omitted, rather than an '
        'empty line/placeholder', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            title: "'t Preuvenemint",
            cityCountryLine: 'Maastricht · NL',
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
        ),
      );
      expect(find.text("'t Preuvenemint"), findsWidgets);
      expect(find.text('Maastricht · NL'), findsOneWidget);
      expect(find.textContaining('FESTIVAL'), findsNothing);
      expect(find.textContaining('AUG 2026'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hero/Essentials title correction: real Event Detail usage '
        '(only backgroundImage supplied, matching the actual production '
        'call site) renders no text at all — no title, no event type, no '
        'city/country, no date range. The Event name itself moved to '
        'EventMetaSection, so this hero is genuinely photography-ready.', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
      final hero = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(hero.title, isNull);
      expect(tester.takeException(), isNull);
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

    testWidgets('Editorial Hero + Essentials/Actions polish pass: real '
        'Event Detail usage now supplies eventTypeLabel again (and only '
        'that) — the subtle editorial eyebrow renders, but title, '
        'city/country and date range still render nothing, matching the '
        'actual production call site shape exactly', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            eventTypeLabel: 'DINNER',
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
        ),
      );
      expect(find.text('DINNER'), findsOneWidget);
      final hero = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(hero.title, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EventType.other renders no eyebrow at all — the real '
        'call site computes a null eventTypeLabel for this case (the '
        'schema\'s own "no real type known" fallback), which is exactly '
        'the same no-text-at-all shape as the general real-usage case', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            eventTypeLabel: null,
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });
  });

  group('EventDetailHero — EVENT WISHLIST V1 wishlist heart', () {
    testWidgets('onTapWishlist omitted renders no heart action at all — '
        'unaffected default for every pre-existing call site/test', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSliver(
          const EventDetailHero(
            backgroundImage: CsImagePlaceholder(logoScale: 0.22),
          ),
        ),
      );
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('unsaved (isWishlisted: false) shows the outline heart — '
        'never a star, bookmark or bell', (tester) async {
      await tester.pumpWidget(
        _wrapSliver(
          EventDetailHero(
            backgroundImage: const CsImagePlaceholder(logoScale: 0.22),
            isWishlisted: false,
            onTapWishlist: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    });

    testWidgets('saved (isWishlisted: true) shows the filled heart', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSliver(
          EventDetailHero(
            backgroundImage: const CsImagePlaceholder(logoScale: 0.22),
            isWishlisted: true,
            onTapWishlist: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('tapping the heart fires onTapWishlist exactly once — '
        'saving an unsaved Event', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrapSliver(
          EventDetailHero(
            backgroundImage: const CsImagePlaceholder(logoScale: 0.22),
            isWishlisted: false,
            onTapWishlist: () => calls++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(calls, 1);
    });

    testWidgets('tapping the heart fires onTapWishlist exactly once — '
        'removing an already-saved Event', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrapSliver(
          EventDetailHero(
            backgroundImage: const CsImagePlaceholder(logoScale: 0.22),
            isWishlisted: true,
            onTapWishlist: () => calls++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      expect(calls, 1);
    });

    testWidgets('wishlistSaving disables the tap — a busy toggle never '
        'double-fires', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrapSliver(
          EventDetailHero(
            backgroundImage: const CsImagePlaceholder(logoScale: 0.22),
            isWishlisted: false,
            wishlistSaving: true,
            onTapWishlist: () => calls++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(calls, 0);
    });

    testWidgets('the heart icon is ivory regardless of saved state — never '
        'gold, matching Step 1B\'s reserved-for-Michelin-recognition rule', (
      tester,
    ) async {
      for (final saved in [false, true]) {
        await tester.pumpWidget(
          _wrapSliver(
            EventDetailHero(
              backgroundImage: const CsImagePlaceholder(logoScale: 0.22),
              isWishlisted: saved,
              onTapWishlist: () {},
            ),
          ),
        );
        final icon = tester.widget<Icon>(
          find.byIcon(
            saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
        );
        expect(icon.color, AppColors.textOnDark);
        expect(icon.color, isNot(AppColors.gold));
      }
    });
  });

  group('EventDetailHero — Wishlist vs. attendance intent are independent '
      '(EVENT WISHLIST V1 §11)', () {
    testWidgets('EventDetailHero has no attendance/intent concept at all — '
        'saving/removing a Wishlist entry cannot, by construction, touch '
        'Going/Interested state, which this widget never even receives', (
      tester,
    ) async {
      // The strongest proof here is structural: EventDetailHero's own
      // constructor accepts isWishlisted/wishlistSaving/onTapWishlist and
      // nothing attendance-related — there is no EventIntentStatus
      // parameter for a wishlist toggle to accidentally also set. This
      // test pumps the hero with only wishlist params supplied and
      // confirms tapping the heart renders no attendance-related text
      // anywhere in the tree.
      var wishlistCalls = 0;
      await tester.pumpWidget(
        _wrapSliver(
          EventDetailHero(
            backgroundImage: const CsImagePlaceholder(logoScale: 0.22),
            isWishlisted: false,
            onTapWishlist: () => wishlistCalls++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(wishlistCalls, 1);
      expect(find.textContaining('Going'), findsNothing);
      expect(find.textContaining('Interested'), findsNothing);
    });
  });

  group('EventMetaSection — date/venue/admission/cancelled (§7-9, §26-27)', () {
    testWidgets('always shows the date/time range', (tester) async {
      await tester.pumpWidget(_wrap(EventMetaSection(event: _event())));
      // One combined precision-aware line (Events V2 Time Precision Phase
      // B) — date range plus the known start/end times — replacing the
      // former two separate "Thu 27 Aug 2026, 18:00" / "to Sun 30 Aug
      // 2026, 22:00" lines.
      expect(
        find.textContaining('27–30 Aug 2026 · 18:00–22:00'),
        findsOneWidget,
      );
    });

    testWidgets('Editorial Hero + Essentials/Actions polish pass: event '
        'type no longer renders in EventMetaSection at all — it moved '
        'back to the hero as a subtle eyebrow (see the EventDetailHero '
        'group below) — regardless of which EventType value the Event '
        'has', (tester) async {
      for (final type in EventType.values) {
        await tester.pumpWidget(
          _wrap(EventMetaSection(event: _event(eventType: type))),
        );
        expect(
          find.text(type.label.toUpperCase()),
          findsNothing,
          reason: '${type.label} eyebrow should not render in Essentials',
        );
      }
    });

    testWidgets('shows the venue name row when present', (tester) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(venueName: 'Vrijthof'))),
      );
      expect(find.text('Vrijthof'), findsOneWidget);
    });

    testWidgets('venue row also shows city as a secondary line when both '
        'exist — the pilot\'s own "Restaurant Flore / Amsterdam" shape, '
        'now that the hero no longer carries a cityCountryLine at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(
            event: _event(venueName: 'Restaurant Flore', city: 'Amsterdam'),
          ),
        ),
      );
      expect(find.text('Restaurant Flore'), findsOneWidget);
      expect(find.text('Amsterdam'), findsOneWidget);
    });

    testWidgets('venue row falls back to city alone when venue name is '
        'absent but city exists — city must not simply disappear now that '
        'the hero no longer shows it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(event: _event(venueName: null, city: 'Amsterdam')),
        ),
      );
      expect(find.text('Amsterdam'), findsOneWidget);
    });

    testWidgets('omits the venue row entirely only when both venue name '
        'and city are absent', (tester) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(venueName: null, city: null))),
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

  group('Event Detail hierarchy — hero title removal + Essentials '
      'title-first ordering (physical-device pilot correction)', () {
    const longTitle = '4 Hands Dinner: Bas van Kranen x Sang Hoon Degeimbre';

    testWidgets('the Event title renders exactly once, and the event-type '
        'eyebrow renders exactly once too, when Hero and Essentials are '
        'composed together as the real screen does (Hero sliver — now '
        'carrying eventTypeLabel again — then a sliver wrapping '
        'Essentials below it)', (tester) async {
      final event = _event(name: longTitle, eventType: EventType.dinner);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const EventDetailHero(
                  eventTypeLabel: 'DINNER',
                  backgroundImage: CsImagePlaceholder(logoScale: 0.22),
                ),
                SliverToBoxAdapter(
                  child: Material(child: EventMetaSection(event: event)),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text(longTitle), findsOneWidget);
      expect(find.text('DINNER'), findsOneWidget);
    });

    testWidgets('order is Title → Date → Venue → Admission', (tester) async {
      final event = _event(
        name: 'Test Event',
        eventType: EventType.dinner,
        venueName: 'Restaurant Flore',
        city: 'Amsterdam',
        admissionType: EventAdmissionType.paid,
      );
      await tester.pumpWidget(_wrap(EventMetaSection(event: event)));

      double topOf(Finder finder) => tester.getTopLeft(finder).dy;
      final titleY = topOf(find.text('Test Event'));
      final dateY = topOf(find.textContaining('2026'));
      final venueY = topOf(find.text('Restaurant Flore'));
      final admissionY = topOf(find.text(EventAdmissionType.paid.label));

      expect(titleY, lessThan(dateY));
      expect(dateY, lessThan(venueY));
      expect(venueY, lessThan(admissionY));
      // Event type moved back to the hero — confirming it does NOT
      // reappear anywhere in Essentials for this fixture either.
      expect(find.text('DINNER'), findsNothing);
    });

    testWidgets('EventActionsRow renders below Essentials when composed as '
        'the real screen does (Essentials, then Actions)', (tester) async {
      final event = _event(
        name: 'Test Event',
        officialUrl: 'https://example.com',
      );
      await tester.pumpWidget(
        _wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventMetaSection(event: event),
              EventActionsRow(
                ticketUrl: null,
                officialUrl: event.officialUrl,
                ticketLabel: 'Tickets',
                eventName: event.name,
                onTapUrl: (_) {},
              ),
            ],
          ),
        ),
      );
      final titleY = tester.getTopLeft(find.text('Test Event')).dy;
      final websiteY = tester.getTopLeft(find.text('Official website')).dy;
      expect(titleY, lessThan(websiteY));
    });

    testWidgets('the real pilot title wraps naturally with no overflow, '
        'never truncated or ellipsized', (tester) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(name: longTitle))),
      );
      expect(find.text(longTitle), findsOneWidget);
      final titleText = tester.widget<Text>(find.text(longTitle));
      expect(titleText.overflow, isNot(TextOverflow.ellipsis));
      expect(titleText.maxLines, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the real pilot title at 320px: no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(name: longTitle)), width: 320),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the real pilot title at 1.6x text scale: no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventMetaSection(event: _event(name: longTitle)),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('date-only pilot shape: title renders alongside the date '
        'line, and the date line still shows no fabricated time', (
      tester,
    ) async {
      final dateOnlyEvent = Event(
        id: 'pilot-1',
        name: longTitle,
        startDate: DateTime.utc(2026, 10, 19),
        endDate: DateTime.utc(2026, 10, 19),
        timezone: 'Europe/Amsterdam',
        countryCode: 'NL',
        venueName: 'Restaurant Flore',
        eventType: EventType.dinner,
        status: EventStatus.upcoming,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      await tester.pumpWidget(_wrap(EventMetaSection(event: dateOnlyEvent)));
      expect(find.text(longTitle), findsOneWidget);
      // formatEventDateAndTime's date-only shape is exactly the bare date
      // string, with no "· <time>" suffix appended at all — the title
      // itself legitimately contains a colon ("4 Hands Dinner: ..."), so
      // this checks the date TEXT WIDGET itself, not the whole tree, for
      // the absence of a time separator/fake time.
      expect(find.text('19 Oct 2026'), findsOneWidget);
      expect(find.textContaining('00:00'), findsNothing);
    });

    testWidgets('full-time formatting is unaffected by the title now '
        'sitting above it — the default fixture\'s combined date/time line '
        'still renders exactly as before', (tester) async {
      await tester.pumpWidget(
        _wrap(EventMetaSection(event: _event(name: 'Test Event'))),
      );
      expect(find.text('Test Event'), findsOneWidget);
      expect(find.text('27–30 Aug 2026 · 18:00–22:00'), findsOneWidget);
    });
  });

  group('EventParticipantRow — inline stars + city + flag '
      '(Events UI Consistency Step 1A)', () {
    testWidgets('stars render inline with the name, not on a secondary '
        'line', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventParticipantRow(
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
            EventParticipantRow(
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
          EventParticipantRow(
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
          EventParticipantRow(
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
          EventParticipantRow(
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
          EventParticipantRow(
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
          EventParticipantRow(
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
          EventParticipantRow(
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
          EventParticipantRow(
            restaurant: _restaurant(michelinStars: 1),
            onTap: () => calls++,
          ),
        ),
      );
      await tester.tap(find.byType(EventParticipantRow));
      expect(calls, 1);
    });

    testWidgets('accessibility: semantics combine name, city, country, and '
        'star count into one label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          EventParticipantRow(
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
          EventParticipantRow(
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
          EventParticipantRow(
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
            EventParticipantRow(
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
          EventParticipantRow(
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

  group('AtThisEventSection — Michelin-starred participants only '
      '(§12, §20)', () {
    testWidgets('shows only Michelin-starred restaurants, not unstarred '
        'participants', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
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
          AtThisEventSection(
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
      expect(find.text('AT THIS EVENT'), findsNothing);
      expect(find.textContaining('No Michelin'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders nothing for an empty restaurant list', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(restaurants: const [], onTapRestaurant: (_) {}),
        ),
      );
      expect(find.text('AT THIS EVENT'), findsNothing);
    });

    testWidgets('1-star, 2-star, and 3-star restaurants each show the '
        'correct star count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
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
      final result = recognizedEventParticipants([
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
          AtThisEventSection(
            restaurants: [starred],
            onTapRestaurant: (r) => tapped = r,
          ),
        ),
      );
      await tester.tap(find.byType(EventParticipantRow));
      expect(tapped, starred);
    });

    testWidgets('only StarRow uses gold — section title, chevron, and '
        'hairline spacing never do', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: [
              _restaurant(id: 'r1', name: 'Starred House', michelinStars: 2),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('AT THIS EVENT'));
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
          AtThisEventSection(
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
          AtThisEventSection(
            restaurants: [
              _restaurant(id: 'r1', name: 'First', michelinStars: 1),
              _restaurant(id: 'r2', name: 'Second', michelinStars: 2),
              _restaurant(id: 'r3', name: 'Third', michelinStars: 3),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.byType(EventParticipantRow), findsNWidgets(3));
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
          AtThisEventSection(
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
          AtThisEventSection(restaurants: restaurants, onTapRestaurant: (_) {}),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(EventParticipantRow), findsNWidgets(4));
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
                child: AtThisEventSection(
                  restaurants: restaurants,
                  onTapRestaurant: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(EventParticipantRow), findsNWidgets(12));
      expect(find.byType(Divider), findsNWidgets(11));
    });
  });

  group('isRecognizedEventParticipant — Events Recognition V2 eligibility', () {
    test('Michelin-starred is recognized', () {
      expect(
        isRecognizedEventParticipant(_restaurant(michelinStars: 1)),
        isTrue,
      );
    });

    test("World's 50 Best ranked (no Michelin star) is recognized", () {
      expect(
        isRecognizedEventParticipant(
          _restaurant(michelinStars: null, worlds50BestRank: 24),
        ),
        isTrue,
      );
    });

    test('Hall of Fame (no Michelin star) is recognized', () {
      expect(
        isRecognizedEventParticipant(
          _restaurant(michelinStars: null, isHallOfFame: true),
        ),
        isTrue,
      );
    });

    test('no qualifying recognition at all is not recognized', () {
      expect(
        isRecognizedEventParticipant(_restaurant(michelinStars: null)),
        isFalse,
      );
    });
  });

  group('recognizedEventParticipants — sorting, dedup (Recognition V2)', () {
    test('a World\'s 50 Best-only restaurant (no Michelin star) sorts after '
        'every Michelin-starred one — 0 stars, never a fabricated '
        'cross-guide prestige comparison', () {
      final result = recognizedEventParticipants([
        _restaurant(id: 'r1', name: 'One Star', michelinStars: 1),
        _restaurant(
          id: 'r2',
          name: 'W50B Only',
          michelinStars: null,
          worlds50BestRank: 5,
        ),
      ]);
      expect(result.map((r) => r.name).toList(), ['One Star', 'W50B Only']);
    });

    test('multiple recognition-only (no Michelin) restaurants fall back to '
        'alphabetical order among themselves', () {
      final result = recognizedEventParticipants([
        _restaurant(
          id: 'r1',
          name: 'Zebra House',
          michelinStars: null,
          isHallOfFame: true,
        ),
        _restaurant(
          id: 'r2',
          name: 'Alpha House',
          michelinStars: null,
          worlds50BestRank: 10,
        ),
      ]);
      expect(result.map((r) => r.name).toList(), [
        'Alpha House',
        'Zebra House',
      ]);
    });

    test('duplicate restaurant ids (defensive safety — should never occur '
        'through the real event_restaurants/restaurants_full path) collapse '
        'to a single row, never a duplicate', () {
      final result = recognizedEventParticipants([
        _restaurant(id: 'r1', name: 'Same Place', michelinStars: 2),
        _restaurant(id: 'r1', name: 'Same Place', michelinStars: 2),
      ]);
      expect(result.length, 1);
    });

    test('unrecognized restaurants are excluded entirely', () {
      final result = recognizedEventParticipants([
        _restaurant(id: 'r1', name: 'No Recognition', michelinStars: null),
      ]);
      expect(result, isEmpty);
    });
  });

  group('EventParticipantRow — World\'s 50 Best / Hall of Fame presentation '
      '(Recognition V2)', () {
    testWidgets(
      "World's 50 Best-only restaurant (no Michelin star): no StarRow, "
      'compact rank text on the secondary line',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            EventParticipantRow(
              restaurant: _restaurant(
                name: 'Rank Only House',
                michelinStars: null,
                worlds50BestRank: 24,
                cityName: 'Lima',
                countryCode: 'PE',
                countryName: 'Peru',
                flagEmoji: '🇵🇪',
              ),
              onTap: () {},
            ),
          ),
        );
        expect(find.byType(StarRow), findsNothing);
        expect(find.textContaining("World's 50 Best · #24"), findsOneWidget);
      },
    );

    testWidgets(
      'Hall of Fame restaurant (no Michelin star): no StarRow, "Hall of '
      'Fame" on the secondary line',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            EventParticipantRow(
              restaurant: _restaurant(
                name: 'Legend House',
                michelinStars: null,
                isHallOfFame: true,
              ),
              onTap: () {},
            ),
          ),
        );
        expect(find.byType(StarRow), findsNothing);
        expect(find.textContaining('Hall of Fame'), findsOneWidget);
      },
    );

    testWidgets(
      "Michelin + World's 50 Best (one restaurant, both recognitions): "
      'one row, stars inline with the name AND the rank text on the '
      'secondary line',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            EventParticipantRow(
              restaurant: _restaurant(
                name: 'Double Recognized',
                michelinStars: 3,
                worlds50BestRank: 7,
                cityName: 'Copenhagen',
                countryCode: 'DK',
                countryName: 'Denmark',
                flagEmoji: '🇩🇰',
              ),
              onTap: () {},
            ),
          ),
        );
        expect(find.byType(EventParticipantRow), findsOneWidget);
        final star = tester.widget<StarRow>(find.byType(StarRow));
        expect(star.count, 3);
        expect(find.textContaining("World's 50 Best · #7"), findsOneWidget);
        expect(find.textContaining('Copenhagen'), findsOneWidget);
      },
    );

    testWidgets(
      'Michelin-only restaurant (no W50B/Hall of Fame): no recognition '
      'text beyond stars — secondary line is exactly city + flag, '
      'unchanged from before Recognition V2',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            EventParticipantRow(
              restaurant: _restaurant(
                name: 'Plain Starred',
                michelinStars: 2,
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
        expect(find.textContaining("World's 50 Best"), findsNothing);
        expect(find.textContaining('Hall of Fame'), findsNothing);
      },
    );

    testWidgets(
      'accessibility: a World\'s 50 Best-only restaurant\'s semantic label '
      'includes the rank, never a fabricated Michelin phrase',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            EventParticipantRow(
              restaurant: _restaurant(
                name: 'Rank Only House',
                michelinStars: null,
                worlds50BestRank: 24,
                cityName: 'Lima',
                countryCode: 'PE',
                countryName: 'Peru',
                flagEmoji: '🇵🇪',
              ),
              onTap: () {},
            ),
          ),
        );
        expect(
          find.bySemanticsLabel(
            "Rank Only House, Lima, Peru, World's 50 Best · #24",
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );
  });

  group('AtThisEventSection — Recognition V2 multi-guide fixture matrix '
      '(§13)', () {
    testWidgets("World's 50 Best-only participant is visible", (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: [
              _restaurant(
                id: 'r1',
                name: 'W50B House',
                michelinStars: null,
                worlds50BestRank: 12,
              ),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.text('AT THIS EVENT'), findsOneWidget);
      expect(find.textContaining('W50B House'), findsOneWidget);
    });

    testWidgets('Hall of Fame-only participant is visible', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: [
              _restaurant(
                id: 'r1',
                name: 'Legend House',
                michelinStars: null,
                isHallOfFame: true,
              ),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.text('AT THIS EVENT'), findsOneWidget);
      expect(find.textContaining('Legend House'), findsOneWidget);
    });

    testWidgets(
      "Michelin + World's 50 Best participant renders as one row, both "
      'recognitions visible',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AtThisEventSection(
              restaurants: [
                _restaurant(
                  id: 'r1',
                  name: 'Double House',
                  michelinStars: 2,
                  worlds50BestRank: 30,
                ),
              ],
              onTapRestaurant: (_) {},
            ),
          ),
        );
        expect(find.byType(EventParticipantRow), findsOneWidget);
        expect(find.textContaining("World's 50 Best · #30"), findsOneWidget);
      },
    );

    testWidgets('Michelin + Hall of Fame participant renders as one row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: [
              _restaurant(
                id: 'r1',
                name: 'Starred Legend',
                michelinStars: 3,
                isHallOfFame: true,
              ),
            ],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.byType(EventParticipantRow), findsOneWidget);
      expect(find.textContaining('Hall of Fame'), findsOneWidget);
    });

    testWidgets(
      'a restaurant with zero qualifying recognition is excluded even '
      'when other participants are recognized',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AtThisEventSection(
              restaurants: [
                _restaurant(id: 'r1', name: 'Starred', michelinStars: 1),
                _restaurant(
                  id: 'r2',
                  name: 'Unrecognized',
                  michelinStars: null,
                ),
              ],
              onTapRestaurant: (_) {},
            ),
          ),
        );
        expect(find.textContaining('Starred'), findsOneWidget);
        expect(find.textContaining('Unrecognized'), findsNothing);
      },
    );

    testWidgets(
      'duplicate relationship/input safety: the same restaurant id linked '
      'twice renders exactly one row, never two',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AtThisEventSection(
              restaurants: [
                _restaurant(id: 'dup', name: 'Duplicated', michelinStars: 1),
                _restaurant(id: 'dup', name: 'Duplicated', michelinStars: 1),
              ],
              onTapRestaurant: (_) {},
            ),
          ),
        );
        expect(find.byType(EventParticipantRow), findsOneWidget);
      },
    );
  });

  group('Andorra Taste 2026 regression — Recognition V2 must not change this '
      'already-production, already-approved case (§12)', () {
    // Fixture profile mirrors Andorra Taste's real 6 linked restaurants
    // (name/star count only — never the live production UUIDs, per the
    // task's own explicit instruction) exactly as verified live in
    // production before this workstream began: 3+2+2+2+2+1 stars,
    // none with World's 50 Best/Hall of Fame recognition.
    List<Restaurant> andorraFixture() => [
      _restaurant(
        id: 'a1',
        name: 'Cocina Hermanos Torres',
        michelinStars: 3,
        cityName: 'Barcelona',
        countryCode: 'ES',
        countryName: 'Spain',
        flagEmoji: '🇪🇸',
      ),
      _restaurant(
        id: 'a2',
        name: "Rote Wand Chef's Table",
        michelinStars: 2,
        cityName: 'Lech am Arlberg',
        countryCode: 'AT',
        countryName: 'Austria',
        flagEmoji: '🇦🇹',
      ),
      _restaurant(
        id: 'a3',
        name: 'LÚ Cocina y Alma',
        michelinStars: 2,
        cityName: 'Jerez de la Frontera',
        countryCode: 'ES',
        countryName: 'Spain',
        flagEmoji: '🇪🇸',
      ),
      _restaurant(
        id: 'a4',
        name: 'Paco Roncero',
        michelinStars: 2,
        cityName: 'Madrid',
        countryCode: 'ES',
        countryName: 'Spain',
        flagEmoji: '🇪🇸',
      ),
      _restaurant(
        id: 'a5',
        name: 'Iván Cerdeño',
        michelinStars: 2,
        cityName: 'Toledo',
        countryCode: 'ES',
        countryName: 'Spain',
        flagEmoji: '🇪🇸',
      ),
      _restaurant(
        id: 'a6',
        name: 'Le Prince Noir - Vivien Durand',
        michelinStars: 1,
        cityName: 'Lormont',
        countryCode: 'FR',
        countryName: 'France',
        flagEmoji: '🇫🇷',
      ),
    ];

    testWidgets('all six restaurants remain visible, one row each', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: andorraFixture(),
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.byType(EventParticipantRow), findsNWidgets(6));
    });

    test('sort order unchanged: most-decorated first, alphabetical '
        'within the same star count', () {
      final result = recognizedEventParticipants(andorraFixture());
      expect(result.map((r) => r.name).toList(), [
        'Cocina Hermanos Torres',
        'Iván Cerdeño',
        'LÚ Cocina y Alma',
        'Paco Roncero',
        "Rote Wand Chef's Table",
        'Le Prince Noir - Vivien Durand',
      ]);
    });

    testWidgets('Michelin star counts render correctly for all six — '
        'no visual regression', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: andorraFixture(),
            onTapRestaurant: (_) {},
          ),
        ),
      );
      final stars = tester
          .widgetList<StarRow>(find.byType(StarRow))
          .map((s) => s.count)
          .toList();
      expect(stars, [3, 2, 2, 2, 2, 1]);
    });

    testWidgets('none of the six show any World\'s 50 Best/Hall of Fame text — '
        'none of Andorra\'s real restaurants currently hold that '
        'recognition', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: andorraFixture(),
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.textContaining("World's 50 Best"), findsNothing);
      expect(find.textContaining('Hall of Fame'), findsNothing);
    });

    testWidgets('5 hairlines separate the 6 rows, no visual regression', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: andorraFixture(),
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.byType(Divider), findsNWidgets(5));
    });

    testWidgets('tapping a row still navigates via the exact tapped '
        'Restaurant instance', (tester) async {
      Restaurant? tapped;
      final fixture = andorraFixture();
      await tester.pumpWidget(
        _wrap(
          AtThisEventSection(
            restaurants: fixture,
            onTapRestaurant: (r) => tapped = r,
          ),
        ),
      );
      await tester.tap(find.textContaining('Cocina Hermanos Torres'));
      expect(tapped?.name, 'Cocina Hermanos Torres');
    });
  });
}
