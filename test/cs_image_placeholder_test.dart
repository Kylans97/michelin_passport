// Covers CsImagePlaceholder — the branded fallback introduced for
// restaurant/hotel/event cards and the Event Detail hero — across the
// three size regimes it needs to support: small thumbnails, normal cards,
// and hero areas stretched via a Stack with no explicit width/height.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';

void main() {
  testWidgets('renders at a small thumbnail size with no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 24,
            height: 24,
            child: CsImagePlaceholder(width: 24, height: 24),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders at normal card size and shows the monogram image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CsImagePlaceholder(width: 84, height: 84)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets(
    'fills a stretched Stack with no explicit size (hero usage) without '
    'overflow',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 208,
              child: Stack(
                fit: StackFit.expand,
                children: [CsImagePlaceholder(logoScale: 0.22)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('applies the given BorderRadius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CsImagePlaceholder(
            width: 60,
            height: 60,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
    await tester.pump();
    final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clipRRect.borderRadius, BorderRadius.circular(12));
  });
}
