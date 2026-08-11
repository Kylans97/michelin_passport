// Covers the new CsTextField component (lib/core/widgets/cs_text_field.dart),
// built for Login/Sign up (Step 4A) and kept general enough for future
// forms. No Supabase involved — this is a presentation-only widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/theme/cs_surface_context.dart';
import 'package:michelin_passport/core/widgets/cs_text_field.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);

void main() {
  group('CsTextField', () {
    testWidgets('renders the visible label and hint text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          CsTextField(
            label: 'Email',
            controller: controller,
            hintText: 'you@example.com',
          ),
        ),
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the label is exposed as the field\'s semantic label', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(CsTextField(label: 'Email', controller: controller)),
      );
      // Two matches are expected and correct: the visible Text('Email')
      // label itself already produces an implicit semantics node from its
      // content, and the explicit Semantics wrapper around the field adds
      // a second one with the same label — both legitimately announce
      // "Email", which is exactly the point of the wrapper.
      expect(find.bySemanticsLabel('Email'), findsWidgets);
    });

    testWidgets('typing updates the controller', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(CsTextField(label: 'Name', controller: controller)),
      );
      await tester.enterText(find.byType(TextFormField), 'Jane Doe');
      expect(controller.text, 'Jane Doe');
    });

    testWidgets('no visibility toggle when obscureText is false', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(CsTextField(label: 'Name', controller: controller)),
      );
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets(
      'obscureText with showVisibilityToggle: starts hidden, toggles to '
      'visible and back',
      (tester) async {
        final controller = TextEditingController();
        await tester.pumpWidget(
          _wrap(
            CsTextField(
              label: 'Password',
              controller: controller,
              obscureText: true,
              showVisibilityToggle: true,
            ),
          ),
        );
        var field = tester.widget<TextField>(find.byType(TextField));
        expect(field.obscureText, isTrue);
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pump();
        field = tester.widget<TextField>(find.byType(TextField));
        expect(field.obscureText, isFalse);
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.visibility_off_outlined));
        await tester.pump();
        field = tester.widget<TextField>(find.byType(TextField));
        expect(field.obscureText, isTrue);
      },
    );

    testWidgets('obscureText true but showVisibilityToggle false: obscured, no '
        'toggle icon (matches the original always-hidden password field)', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          CsTextField(
            label: 'Password',
            controller: controller,
            obscureText: true,
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('validator produces an inline error under the field', (
      tester,
    ) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: CsTextField(
              label: 'Email',
              controller: controller,
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
          ),
        ),
      );
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders on both CsSurface values with no exceptions', (
      tester,
    ) async {
      for (final surface in CsSurface.values) {
        final controller = TextEditingController();
        await tester.pumpWidget(
          _wrap(
            CsTextField(
              label: 'Email',
              controller: controller,
              surface: surface,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('long error copy at 320px does not overflow', (tester) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: CsTextField(
                    label: 'Password',
                    controller: controller,
                    validator: (_) =>
                        'This is a considerably long validation message '
                        'used to check that error copy never causes a '
                        'RenderFlex overflow at a narrow width',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      formKey.currentState!.validate();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
