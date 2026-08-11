// PassportCollectionHeader now always renders the single, consistent
// "YOUR COLLECTION" title — no venue-type wording, no right-hand count (the
// count is already shown in the metric strip above; see passport_screen.dart
// for the metric-strip wiring). The overflow this widget was originally
// extracted to fix ('YOUR RESTAURANTS' + '11 RESTAURANTS' at 320px) can't
// recur: there's no longer a second Row child to overflow against, and
// 'YOUR COLLECTION' alone isn't inside a Flex at all, so it can only wrap
// (never RenderFlex-overflow) if it's ever too wide for its container.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/features/passport/widgets/passport_collection_header.dart';

Widget _wrap(Widget child, {double width = 320}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  group('PassportCollectionHeader', () {
    testWidgets('renders exactly "YOUR COLLECTION" and nothing else', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PassportCollectionHeader()));
      expect(find.text('YOUR COLLECTION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows no right-hand count of any kind', (tester) async {
      await tester.pumpWidget(_wrap(const PassportCollectionHeader()));
      expect(find.textContaining('RESTAURANTS'), findsNothing);
      expect(find.textContaining('HOTELS'), findsNothing);
      expect(find.textContaining('PLACES'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('no overflow at 320px', (tester) async {
      await tester.pumpWidget(
        _wrap(const PassportCollectionHeader(), width: 320),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 390px', (tester) async {
      await tester.pumpWidget(
        _wrap(const PassportCollectionHeader(), width: 390),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 1.6x text scale, narrow width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: const SizedBox(
                width: 320,
                child: PassportCollectionHeader(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
