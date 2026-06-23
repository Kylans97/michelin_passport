import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TablePassportApp());
    expect(find.text('Passport'), findsOneWidget);
  });
}
