// Covers CsComingSoon (Navigation & Information Architecture V2) — the one
// restrained, reusable "not built yet" placeholder used by NewsScreen and
// CommunityScreen. Pure StatelessWidget, no Supabase dependency, so it's
// pumped directly rather than mirrored.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_coming_soon.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('CsComingSoon', () {
    testWidgets('renders the title, ivory, never gold', (tester) async {
      await tester.pumpWidget(_wrap(const CsComingSoon(title: 'Coming soon')));
      final title = tester.widget<Text>(find.text('Coming soon'));
      expect(title.style?.color, AppColors.ivory);
      expect(title.style?.color, isNot(AppColors.gold));
    });

    testWidgets('description is optional — omitted renders no extra text', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CsComingSoon(title: 'Coming soon')));
      expect(find.text('Coming soon'), findsOneWidget);
      // Only the title Text should be present — no description.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('description, when provided, renders on-dark secondary, '
        'never gold', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CsComingSoon(
            title: 'Coming soon',
            description: 'Launch stories are on the way.',
          ),
        ),
      );
      final description = tester.widget<Text>(
        find.text('Launch stories are on the way.'),
      );
      expect(description.style?.color, AppColors.secondaryOnDark);
      expect(description.style?.color, isNot(AppColors.gold));
    });

    testWidgets('defaults to the hourglass icon, secondary on-dark, never '
        'gold', (tester) async {
      await tester.pumpWidget(_wrap(const CsComingSoon(title: 'Coming soon')));
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.hourglass_top_rounded),
      );
      expect(icon.color, AppColors.secondaryOnDark);
      expect(icon.color, isNot(AppColors.gold));
    });

    testWidgets('accepts a custom icon override', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CsComingSoon(
            title: 'Coming soon',
            icon: Icons.article_outlined,
          ),
        ),
      );
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
    });

    testWidgets(
      'compact defaults to false — full-page callers (News) are unaffected',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const CsComingSoon(title: 'Coming soon')),
        );
        final widget = tester.widget<CsComingSoon>(find.byType(CsComingSoon));
        expect(widget.compact, isFalse);
        final icon = tester.widget<Icon>(
          find.byIcon(Icons.hourglass_top_rounded),
        );
        expect(icon.size, 32);
      },
    );

    testWidgets('compact: true renders a smaller icon and tighter padding '
        '— for stacking several sections on one page', (tester) async {
      await tester.pumpWidget(
        _wrap(const CsComingSoon(title: 'Coming soon', compact: true)),
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.hourglass_top_rounded),
      );
      expect(icon.size, 24);
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.text('Coming soon'),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect((padding.padding as EdgeInsets).vertical, lessThan(112));
    });

    testWidgets('never renders a construction/fake-control affordance — no '
        'buttons, no gold anywhere', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CsComingSoon(title: 'Coming soon', description: 'On the way.'),
        ),
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });
  });
}
