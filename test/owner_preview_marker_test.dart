// Covers the "PREVIEW" pill's own typography resolving correctly — not
// just the widget's own `style:` property (which was never wrong), but
// the RESOLVED style Text.build() actually hands to RichText/
// RenderParagraph after merging against the ambient DefaultTextStyle.
// Before the Material(type: MaterialType.transparency, ...) fix, the
// pill's Text had no Material ancestor (it sits as a Stack sibling of
// the whole Scaffold it wraps, deliberately — see OwnerPreviewMarker's
// own doc comment), so that ambient style was MaterialApp's own glaring
// fallback (_errorTextStyle in material/app.dart) — and since Text.style
// MERGES rather than replaces, its decoration/decorationColor/
// decorationStyle leaked straight through: a double yellow underline
// under otherwise-correct-looking text.
//
// Confirmed regression-catching, not vacuous, by reverting the fix
// locally and re-running this file: it failed exactly as expected before
// the Material wrapper was added back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/profile/widgets/owner_preview_marker.dart';

// Finds the RichText Text.build() actually produces for [text] and
// returns its RESOLVED style — the one DefaultTextStyle.of(context).style
// .merge(...) already applied, i.e. what RenderParagraph actually paints
// with. Reading Text.style directly (the widget's own input) would not
// catch this bug: that field was never wrong, only what it merged
// against was.
TextStyle _resolvedStyle(WidgetTester tester, String text) {
  final matches = tester
      .widgetList<RichText>(find.byType(RichText))
      .where((rt) => (rt.text as TextSpan).toPlainText() == text);
  return (matches.single.text as TextSpan).style!;
}

void main() {
  testWidgets(
    'the PREVIEW text resolves with no leaked decoration — proves it has '
    "a real Material ancestor, not MaterialApp's own glaring "
    'no-Material-ancestor fallback style',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OwnerPreviewMarker(child: SizedBox())),
      );

      final resolvedStyle = _resolvedStyle(tester, 'PREVIEW');
      expect(resolvedStyle.decoration, isNot(TextDecoration.underline));
      expect(resolvedStyle.decorationStyle, isNot(TextDecorationStyle.double));
      expect(resolvedStyle.decorationColor, isNot(const Color(0xFFFFFF00)));
    },
  );

  testWidgets(
    'the staleness subtitle line has the same fix — it sits under the '
    'same Material ancestor as PREVIEW, added in the same place, and was '
    'vulnerable to the identical leak',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerPreviewMarker(
            subtitle: 'Showing your last saved details',
            child: SizedBox(),
          ),
        ),
      );

      final resolvedStyle = _resolvedStyle(
        tester,
        'Showing your last saved details',
      );
      expect(resolvedStyle.decoration, isNot(TextDecoration.underline));
      expect(resolvedStyle.decorationStyle, isNot(TextDecorationStyle.double));
      expect(resolvedStyle.decorationColor, isNot(const Color(0xFFFFFF00)));
    },
  );
}
