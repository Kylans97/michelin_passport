import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/visits/widgets/rating_meter.dart';

/// Holds the value the way the visit sheets do, so a drag sees each
/// change it made.
class _Harness extends StatefulWidget {
  final ValueChanged<int?> onValue;
  const _Harness({required this.onValue});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int? _value;

  @override
  Widget build(BuildContext context) => RatingMeter(
    label: 'Overall',
    value: _value,
    onChanged: (v) {
      setState(() => _value = v);
      widget.onValue(v);
    },
  );
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  ),
);

void main() {
  group('RatingMeter.valueAt', () {
    test('over the pill is Not rated', () {
      expect(RatingMeter.valueAt(0, 360), isNull);
      expect(RatingMeter.valueAt(39, 360), isNull);
    });

    test('the meter maps to 1–10, clamped at both ends', () {
      // meter runs from 40 to 360: 32 per segment.
      expect(RatingMeter.valueAt(40, 360), 1);
      expect(RatingMeter.valueAt(71, 360), 1);
      expect(RatingMeter.valueAt(72, 360), 2);
      expect(RatingMeter.valueAt(359, 360), 10);
      expect(RatingMeter.valueAt(500, 360), 10);
    });
  });

  testWidgets('swiping from "—" to the right gives a score, and back '
      'over the pill clears it', (tester) async {
    int? last = -1;
    await _pump(tester, _Harness(onValue: (v) => last = v));

    final pill = tester.getCenter(find.text('—'));
    final gesture = await tester.startGesture(pill);
    // From the pill's centre (x 16) to x 356 of the 360-wide row:
    // segment 10.
    await gesture.moveBy(const Offset(340, 0));
    await tester.pump();
    expect(last, 10);
    expect(find.text('10/10'), findsOneWidget);

    // Back to x 196: segment 5.
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(last, 5);

    // Back over the pill.
    await gesture.moveTo(pill);
    await tester.pump();
    await gesture.up();
    expect(last, isNull);
    expect(find.text('Not rated'), findsOneWidget);
  });

  testWidgets('tapping a segment still works', (tester) async {
    int? last = -1;
    await _pump(tester, _Harness(onValue: (v) => last = v));
    final left = tester.getTopLeft(find.byType(RatingMeter)).dx;
    final rowY = tester.getCenter(find.text('—')).dy;
    // Segment 3 centre: row left + 40 + 2.5 × 32.
    await tester.tapAt(Offset(left + 40 + 80, rowY));
    await tester.pump();
    expect(last, 3);
  });
}
