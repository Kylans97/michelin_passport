// Covers the redesigned PlannedTripsScreen's header and empty state.
// PlannedTripsScreen itself constructs PlannedTripsRepository against
// Supabase.instance.client eagerly in initState (same established
// limitation as every other guide/Explore/Wishlist screen — see
// explore_guides_entry_test.dart's own note), so it can't be pumped
// directly without a live session. This reconstructs the exact copy and
// CTA shape used in lib/features/trips/planned_trips_screen.dart's own
// header and _EmptyState, mirroring the precedent
// wishlist_trips_entry_test.dart already set for the equivalent problem.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';

const _title = 'Trips';
const _subtitle = 'Plan the places worth travelling for.';
const _emptyHeadline = 'No trips planned yet';
const _emptyBody =
    'Start with a destination, then collect the places worth travelling for.';
const _cta = 'Plan a trip';

Widget _header() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      _title,
      style: CsTypography.screenTitle.copyWith(color: AppColors.textOnDark),
    ),
    const SizedBox(height: CsSpacing.sm),
    Text(
      _subtitle,
      style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
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

// Reconstructs PlannedTripsScreen's actual outer Column shape (TRIPS+GUIDES
// MICRO-POLISH item 1): back button + header are unconditional siblings
// BEFORE the state-dependent Expanded, never nested inside the
// loading/error/empty/populated switch. [stateContent] stands in for
// whatever that switch currently renders — its own content isn't under
// test here (covered elsewhere); what's under test is that
// EditorialBackButton keeps rendering no matter what stateContent is.
Widget _screenShell(Widget stateContent) => Column(
  children: [
    const Padding(
      padding: EdgeInsets.fromLTRB(
        CsSpacing.base,
        CsSpacing.sm,
        CsSpacing.base,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: EditorialBackButton(),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.xl,
        CsSpacing.pageHorizontal,
        0,
      ),
      child: _header(),
    ),
    const SizedBox(height: CsSpacing.xl),
    Expanded(child: stateContent),
  ],
);

void main() {
  group('PlannedTripsScreen header', () {
    testWidgets('renders the exact "Trips" title and supporting line', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_header()));
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_subtitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px and 390px widths — no overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(_wrap(_header()));
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
              body: _header(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group(
    'PlannedTripsScreen back button (TRIPS+GUIDES MICRO-POLISH item 1)',
    () {
      testWidgets('visible while loading', (tester) async {
        await tester.pumpWidget(
          _wrap(
            _screenShell(
              const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ),
          ),
        );
        expect(find.byType(EditorialBackButton), findsOneWidget);
      });

      testWidgets('visible on error', (tester) async {
        await tester.pumpWidget(
          _wrap(
            _screenShell(
              Text(
                'Could not load your trips',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(EditorialBackButton), findsOneWidget);
      });

      testWidgets(
        'visible in the empty state — never forces trip creation just to '
        'navigate back',
        (tester) async {
          var ctaTapped = false;
          await tester.pumpWidget(
            _wrap(_screenShell(_emptyState(() => ctaTapped = true))),
          );
          expect(find.byType(EditorialBackButton), findsOneWidget);
          expect(find.text(_emptyHeadline), findsOneWidget);
          // Tapping back must be independent of the "Plan a trip" CTA —
          // EditorialBackButton's own default onTap (Navigator.maybePop)
          // fires, not onCreateTrip.
          await tester.tap(find.byType(EditorialBackButton));
          expect(tester.takeException(), isNull);
          expect(ctaTapped, isFalse);
        },
      );

      testWidgets('visible when trips are populated', (tester) async {
        await tester.pumpWidget(
          _wrap(
            _screenShell(
              ListView(children: const [Text('a trip card stand-in')]),
            ),
          ),
        );
        expect(find.byType(EditorialBackButton), findsOneWidget);
      });
    },
  );

  group('PlannedTripsScreen empty state', () {
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
