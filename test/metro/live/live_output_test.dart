import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_output.dart';

void main() {
  group('LiveBlock', () {
    test('prefixes actions with symbols and splits multi-line text', () {
      final LiveBlock block = LiveBlock()
        ..success('Saved')
        ..failure('Nope')
        ..warning('Careful')
        ..note('FYI')
        ..plain('one\ntwo');

      expect(block.lines.map((line) => line.$2), [
        '✓ Saved',
        '✗ Nope',
        '! Careful',
        '· FYI',
        'one',
        'two',
      ]);
      expect(block.lines.first.$1, LiveTone.success);
    });

    test('table aligns columns and dims the header', () {
      final LiveBlock block = LiveBlock()
        ..table(
          ['KEY', 'TYPE', 'VALUE'],
          [
            ['SK_USER', 'json', '{"id":42}'],
            ['coins', 'int', '10'],
          ],
        );

      expect(block.lines.map((line) => line.$2), [
        'KEY      TYPE  VALUE',
        'SK_USER  json  {"id":42}',
        'coins    int   10',
      ]);
      expect(block.lines.first.$1, LiveTone.note);
    });

    test('json adds indented JSON', () {
      final LiveBlock block = LiveBlock()..json({'a': 1});

      expect(block.lines.map((line) => line.$2), ['{', '  "a": 1', '}']);
    });
  });

  group('LivePrinter', () {
    test('a single block is printed without a device prefix', () {
      final StringBuffer buffer = StringBuffer();
      final LivePrinter output = LivePrinter(sink: buffer, ansi: false);

      output.blocks([
        (label: 'iPhone 17e', block: LiveBlock()..success('Done')),
      ]);

      expect(buffer.toString(), '✓ Done\n');
    });

    test('several blocks get aligned [device] prefixes', () {
      final StringBuffer buffer = StringBuffer();
      final LivePrinter output = LivePrinter(sink: buffer, ansi: false);

      output.blocks([
        (label: 'iPhone 17 Pro', block: LiveBlock()..success('Seeded 2')),
        (
          label: 'Pixel 9',
          block: LiveBlock()
            ..success('Seeded 2')
            ..plain('Opened /profile'),
        ),
      ]);

      expect(
        buffer.toString(),
        '[iPhone 17 Pro]  ✓ Seeded 2\n'
        '[Pixel 9]        ✓ Seeded 2\n'
        '[Pixel 9]        Opened /profile\n',
      );
    });

    test('colors lines only when ansi is enabled', () {
      final StringBuffer plain = StringBuffer();
      final StringBuffer colored = StringBuffer();

      LivePrinter(sink: plain, ansi: false).error('Failed');
      LivePrinter(sink: colored, ansi: true).error('Failed');

      expect(plain.toString(), '✗ Failed\n');
      expect(colored.toString(), '\x1B[91m✗ Failed\x1B[0m\n');
    });

    test('json writes indented JSON', () {
      final StringBuffer buffer = StringBuffer();

      LivePrinter(sink: buffer, ansi: false).json([
        {'ok': true},
      ]);

      expect(buffer.toString(), '[\n  {\n    "ok": true\n  }\n]\n');
    });
  });

  group('LiveFormat', () {
    test('value keeps short strings and encodes other values', () {
      expect(LiveFormat.value('hello'), 'hello');
      expect(LiveFormat.value(10), '10');
      expect(LiveFormat.value({'id': 42}), '{"id":42}');
      expect(LiveFormat.value(null), 'null');
    });

    test('value cuts long text to the limit', () {
      final String value = LiveFormat.value('x' * 100, max: 10);

      expect(value, '${'x' * 9}…');
      expect(value.length, 10);
    });

    test('clock formats local time as HH:mm:ss', () {
      expect(LiveFormat.clock(DateTime(2026, 9, 13, 9, 5, 7)), '09:05:07');
    });
  });
}
