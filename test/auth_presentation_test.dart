// Covers the shared Login/Sign-up presentation pieces
// (lib/features/auth/widgets/auth_presentation.dart) — AuthBrandHeader,
// AuthErrorBanner, SecondaryAuthLink. Presentation-only, no Supabase.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart'
    show csMonogramAssetPath;
import 'package:michelin_passport/features/auth/widgets/auth_presentation.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SizedBox(
      width: width,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  group('AuthBrandHeader', () {
    testWidgets('renders the official monogram asset, the wordmark and '
        'the tagline', (tester) async {
      await tester.pumpWidget(
        _wrap(const AuthBrandHeader(tagline: 'A quiet line of copy.')),
      );
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (picture.bytesLoader as SvgAssetLoader).assetName,
        csMonogramAssetPath,
      );
      expect(find.text('MANTELIER'), findsOneWidget);
      expect(find.text('A quiet line of copy.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wordmark uses the Cormorant Garamond family, never '
        'Playfair Display', (tester) async {
      await tester.pumpWidget(_wrap(const AuthBrandHeader(tagline: 'Tagline')));
      final wordmark = tester.widget<Text>(find.text('MANTELIER'));
      final family = wordmark.style?.fontFamily ?? '';
      expect(family, contains('CormorantGaramond'));
      expect(family, isNot(contains('PlayfairDisplay')));
    });

    testWidgets('compact mode renders a smaller monogram and wordmark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AuthBrandHeader(tagline: 'Tagline', compact: true)),
      );
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(picture.width, 48);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long tagline at 320px does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthBrandHeader(
            tagline:
                'A deliberately long piece of supporting copy used to '
                'confirm the tagline never causes an overflow at a narrow '
                'device width.',
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale does not overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: const AuthBrandHeader(
                    tagline:
                        "Discover the world's most remarkable culinary "
                        'experiences.',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AuthErrorBanner', () {
    testWidgets('renders the given message and an icon, not color alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AuthErrorBanner(message: 'Invalid login credentials')),
      );
      expect(find.text('Invalid login credentials'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long message at 320px does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AuthErrorBanner(
            message:
                'Unable to sign in. Check your email and password and try '
                'again — this message is deliberately long to exercise '
                'wrapping at a narrow width.',
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SecondaryAuthLink', () {
    testWidgets('renders both lines and fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SecondaryAuthLink(
            question: 'New to Chasing Stars?',
            actionLabel: 'Create an account',
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('New to Chasing Stars?'), findsOneWidget);
      expect(find.text('Create an account →'), findsOneWidget);
      await tester.tap(find.byType(SecondaryAuthLink));
      expect(tapped, isTrue);
    });
  });
}
