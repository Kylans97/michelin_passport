import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

/// Loads the app's two bundled typefaces (pubspec.yaml's `fonts:`) before
/// every test file, so layout and overflow assertions measure the real
/// Spectral and Hanken Grotesk glyphs. Without this, `flutter test` sets
/// every family in its own "FlutterTest" font, whose glyphs are all one
/// em wide — far wider than real text, so width checks would describe a
/// font no user ever sees.
///
/// Read straight from disk with dart:ui rather than through FontLoader/
/// rootBundle, which would need a test binding initialised here for every
/// file — and that binding stubs all HTTP to 400, breaking the live-view
/// tests that deliberately query production.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const files = {
    'Spectral': [
      'Spectral-Light',
      'Spectral-Regular',
      'Spectral-Italic',
      'Spectral-Medium',
    ],
    'HankenGrotesk': [
      'HankenGrotesk-Regular',
      'HankenGrotesk-Medium',
      'HankenGrotesk-SemiBold',
    ],
  };
  for (final MapEntry(key: family, value: names) in files.entries) {
    for (final name in names) {
      final bytes = File('assets/fonts/$name.ttf').readAsBytesSync();
      await ui.loadFontFromList(bytes, fontFamily: family);
    }
  }
  await testMain();
}
