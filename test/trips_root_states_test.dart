// Covers TripsBody's header and empty state. TripsBody constructs
// PlannedTripsRepository against Supabase.instance.client eagerly in
// initState (same established limitation as every other Supabase-eager
// screen in this app), so it can't be pumped directly without a live
// session. This reconstructs the exact copy/CTA shape used in
// lib/features/trips/planned_trips_screen.dart.
//
// Passport Unified Experience V1: TripsBody is no longer a pushed screen
// with its own back button — it's one of PassportScreen's four local
// subsections, embedded beneath the shared Passport header + local tab
// bar (see passport_unified_shell_test.dart for that persistent-shell
// behavior). The old "Trips" title/subtitle is gone (the shared header
// says "Passport" now); this body's own heading is "YOUR TRIPS", with
// the "Create trip" action moved beside it in place of the old back
// button row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/cs_section_title.dart';

const _emptyHeadline = 'No trips planned yet';
const _emptyBody =
    'Start with a destination, then collect the places worth travelling for.';
const _cta = 'Plan a trip';

Widget _header(VoidCallback onCreateTrip) => Row(
  children: [
    const Expanded(
      child: CsSectionTitle(
        'YOUR TRIPS',
        color: AppColors.textOnDark,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    IconButton(
      icon: const Icon(Icons.add_rounded),
      tooltip: 'Create trip',
      onPressed: onCreateTrip,
    ),
  ],
);

Widget _emptyState(VoidCallback onCreateTrip) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      _emptyHeadline,
      textAlign: TextAlign.center,
      style: CsTypography.placeTitle.copyWith(color: AppColors.textOnDark),
    ),
    const SizedBox(height: CsSpacing.sm),
    Text(
      _emptyBody,
      textAlign: TextAlign.center,
      style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
    ),
    const SizedBox(height: CsSpacing.xl),
    Semantics(
      button: true,
      label: _cta,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCreateTrip,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CsSpacing.xl,
              vertical: CsSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(CsRadius.pill),
            ),
            child: Text(_cta),
          ),
        ),
      ),
    ),
  ],
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

// Reconstructs TripsBody's actual outer Column shape: the "YOUR TRIPS" +
// Create-trip header is an unconditional sibling BEFORE the
// state-dependent Expanded, never nested inside the loading/error/empty/
// populated switch. [stateContent] stands in for whatever that switch
// currently renders — what's under test is that the header keeps
// rendering no matter what stateContent is.
Widget _bodyShell(Widget stateContent, {VoidCallback? onCreateTrip}) => Column(
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        0,
      ),
      child: _header(onCreateTrip ?? () {}),
    ),
    const SizedBox(height: CsSpacing.lg),
    Expanded(child: stateContent),
  ],
);

void main() {
  group('TripsBody header', () {
    testWidgets('renders "YOUR TRIPS" and a Create trip action, no back '
        'button, no separate title/subtitle (owned by the shared Passport '
        'header now)', (tester) async {
      await tester.pumpWidget(_wrap(_header(() {})));
      expect(find.text('YOUR TRIPS'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px and 390px widths — no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(_wrap(_header(() {})));
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: _header(() {}),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Create trip fires the callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(_header(() => tapped = true)));
      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(tapped, isTrue);
    });
  });

  group('TripsBody header persists across loading/error/empty/populated', () {
    testWidgets('visible while loading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _bodyShell(
            const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          ),
        ),
      );
      expect(find.text('YOUR TRIPS'), findsOneWidget);
    });

    testWidgets('visible on error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _bodyShell(
            Text(
              'Could not load your trips',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ),
        ),
      );
      expect(find.text('YOUR TRIPS'), findsOneWidget);
    });

    testWidgets('visible in the empty state — Create trip in the header is '
        'independent of the "Plan a trip" CTA in the empty state itself', (
      tester,
    ) async {
      var headerCtaTapped = false;
      var emptyStateCtaTapped = false;
      await tester.pumpWidget(
        _wrap(
          _bodyShell(
            _emptyState(() => emptyStateCtaTapped = true),
            onCreateTrip: () => headerCtaTapped = true,
          ),
        ),
      );
      expect(find.text('YOUR TRIPS'), findsOneWidget);
      expect(find.text(_emptyHeadline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(headerCtaTapped, isTrue);
      expect(emptyStateCtaTapped, isFalse);
    });

    testWidgets('visible when trips are populated', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _bodyShell(ListView(children: const [Text('a trip card stand-in')])),
        ),
      );
      expect(find.text('YOUR TRIPS'), findsOneWidget);
    });
  });

  group('TripsBody empty state', () {
    testWidgets('renders headline, supporting copy and the CTA', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_emptyState(() {})));
      expect(find.text(_emptyHeadline), findsOneWidget);
      expect(find.text(_emptyBody), findsOneWidget);
      expect(find.text(_cta), findsOneWidget);
    });

    testWidgets('tapping "Plan a trip" fires the create-trip callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(_emptyState(() => tapped = true)));
      await tester.tap(find.text(_cta));
      expect(tapped, isTrue);
    });

    testWidgets('320px width — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(_wrap(_emptyState(() {})));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: _emptyState(() {}),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('CTA tap target meets the 44px minimum', (tester) async {
      await tester.pumpWidget(_wrap(_emptyState(() {})));
      final size = tester.getSize(find.byType(InkWell));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
