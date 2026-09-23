import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_options.dart';

void main() {
  group('LiveOptions.extract', () {
    test('leaves command arguments alone when there are no shared flags', () {
      final result = LiveOptions.extract(['--count', '5', '--open']);

      expect(result.rest, ['--count', '5', '--open']);
      expect(result.options.device, isNull);
      expect(result.options.all, isFalse);
      expect(result.options.json, isFalse);
      expect(result.options.uri, isNull);
      expect(result.options.timeout, LiveOptions.defaultTimeout);
    });

    test('pulls shared flags out from anywhere in the arguments', () {
      final result = LiveOptions.extract([
        '--count',
        '5',
        '-d',
        'iPhone 17e',
        '--json',
        '--open',
        '--timeout',
        '1.5',
        '--all',
        '--uri',
        'ws://127.0.0.1:5000/abc=/ws',
      ]);

      expect(result.rest, ['--count', '5', '--open']);
      expect(result.options.device, 'iPhone 17e');
      expect(result.options.json, isTrue);
      expect(result.options.all, isTrue);
      expect(result.options.uri, 'ws://127.0.0.1:5000/abc=/ws');
      expect(result.options.timeout, const Duration(milliseconds: 1500));
    });

    test('supports --flag=value forms', () {
      final result = LiveOptions.extract([
        '--device=Pixel 9',
        '--uri=ws://h:1/x=/ws',
        '--timeout=2',
      ]);

      expect(result.rest, isEmpty);
      expect(result.options.device, 'Pixel 9');
      expect(result.options.uri, 'ws://h:1/x=/ws');
      expect(result.options.timeout, const Duration(seconds: 2));
    });

    test('passes everything after -- through untouched', () {
      final result = LiveOptions.extract(['--count', '5', '--', '-d', '--all']);

      expect(result.rest, ['--count', '5', '--', '-d', '--all']);
      expect(result.options.device, isNull);
      expect(result.options.all, isFalse);
    });

    test('throws for a flag missing its value', () {
      expect(() => LiveOptions.extract(['-d']), throwsFormatException);
      expect(() => LiveOptions.extract(['--uri']), throwsFormatException);
      expect(() => LiveOptions.extract(['--timeout']), throwsFormatException);
    });
  });

  group('LiveOptions.parseTimeout', () {
    test('parses whole and fractional seconds', () {
      expect(LiveOptions.parseTimeout('3'), const Duration(seconds: 3));
      expect(
        LiveOptions.parseTimeout('0.25'),
        const Duration(milliseconds: 250),
      );
    });

    test('defaults when empty', () {
      expect(LiveOptions.parseTimeout(null), LiveOptions.defaultTimeout);
      expect(LiveOptions.parseTimeout(' '), LiveOptions.defaultTimeout);
    });

    test('rejects zero, negative and non-numeric values', () {
      expect(() => LiveOptions.parseTimeout('0'), throwsFormatException);
      expect(() => LiveOptions.parseTimeout('-1'), throwsFormatException);
      expect(() => LiveOptions.parseTimeout('abc'), throwsFormatException);
    });
  });

  group('expandLiveFileArguments', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('nylo_live_files_'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('reads @path values, including --option=@path', () {
      final File scenario = File('${temp.path}/jane.json')
        ..writeAsStringSync('{"user": "Jane"}\n\n');

      expect(
        expandLiveFileArguments([
          '--scenario',
          '@${scenario.path}',
          '--data=@${scenario.path}',
          'plain',
        ]),
        ['--scenario', '{"user": "Jane"}', '--data={"user": "Jane"}', 'plain'],
      );
    });

    test('@@ keeps a leading @, and arguments after -- are untouched', () {
      expect(
        expandLiveFileArguments(['@@everyone', '@', '--', '@not/a/file']),
        ['@everyone', '@', '--', '@not/a/file'],
      );
    });

    test('explains a missing file', () {
      expect(
        () => expandLiveFileArguments(['@missing/file.json']),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Couldn\'t find missing/file.json'),
          ),
        ),
      );
    });
  });
}
