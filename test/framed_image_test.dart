// Covers FramedImage: the alignment it hands its image, and that zoom
// scales around that same point.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/framed_image.dart';
import 'package:michelin_passport/models/photo_framing.dart';

Widget _host(PhotoFraming framing, void Function(Alignment) seen) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 100,
        child: FramedImage(
          framing: framing,
          builder: (alignment) {
            seen(alignment);
            return const ColoredBox(color: Color(0xFF000000));
          },
        ),
      ),
    );

void main() {
  testWidgets('centred and unzoomed: centre alignment, no transform', (
    tester,
  ) async {
    Alignment? alignment;
    await tester.pumpWidget(_host(PhotoFraming.center, (a) => alignment = a));
    expect(alignment, Alignment.center);
    expect(find.byType(Transform), findsNothing);
    expect(find.byType(ClipRect), findsOneWidget);
  });

  testWidgets('zoomed: scales around the focus point, clipped to the box', (
    tester,
  ) async {
    Alignment? alignment;
    const framing = PhotoFraming(focusX: 0.25, focusY: 0.75, zoom: 2);
    await tester.pumpWidget(_host(framing, (a) => alignment = a));
    expect(alignment, const Alignment(-0.5, 0.5));
    final transform = tester.widget<Transform>(find.byType(Transform));
    expect(transform.alignment, const Alignment(-0.5, 0.5));
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(2, 1e-9));
    expect(find.byType(ClipRect), findsOneWidget);
  });
}
