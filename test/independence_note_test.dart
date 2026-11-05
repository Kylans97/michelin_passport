import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/profile/widgets/independence_note.dart';

void main() {
  testWidgets('says Mantelier is independent of the guides it names', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IndependenceNote())),
    );
    expect(find.textContaining('Mantelier is independent.'), findsOneWidget);
  });

  test('uses the same words as the terms', () {
    final terms = File('site/terms.html').readAsStringSync();
    expect(terms.replaceAll('&amp;', '&'), contains(IndependenceNote.text));
  });
}
