// Only these names come from flutter_test, so every Flutter type below has to
// come from nylo_framework's own exports.
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:nylo_framework/nylo_framework.dart';

void main() {
  group('nylo_framework exports', () {
    test('Flutter\'s painting API, which apps use with only this import', () {
      // e.g. supportedLocales in the boilerplate's lib/config/localization.dart
      const List<Locale> locales = <Locale>[Locale('en'), Locale('es')];
      const Color color = Color(0xFF1F2937);
      const TextStyle style = TextStyle(fontSize: 14);
      const EdgeInsets padding = EdgeInsets.all(8);
      const BorderRadius radius = BorderRadius.all(Radius.circular(4));

      expect(locales.first.languageCode, 'en');
      expect(color.toARGB32(), 0xFF1F2937);
      expect(style.fontSize, 14);
      expect(padding.left, 8);
      expect(radius.topLeft.x, 4);
    });
  });
}
