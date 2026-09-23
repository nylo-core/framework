import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_app.dart';
import 'package:nylo_framework/metro/live/live_snapshot.dart';

void main() {
  group('dartLiteral', () {
    test('writes scalars as Dart literals', () {
      expect(dartLiteral(null), 'null');
      expect(dartLiteral(true), 'true');
      expect(dartLiteral(7), '7');
      expect(dartLiteral(1.5), '1.5');
      expect(dartLiteral(2.0), '2.0');
      expect(dartLiteral(double.nan), 'double.nan');
      expect(dartLiteral(double.negativeInfinity), 'double.negativeInfinity');
      expect(dartLiteral('Jane'), "'Jane'");
    });

    test('escapes what a single-quoted string needs', () {
      expect(dartLiteral(r"it's $5 \ done"), r"'it\'s \$5 \\ done'");
      expect(dartLiteral('a\nb\tc\r'), r"'a\nb\tc\r'");
      expect(dartLiteral('bell\x07'), r"'bell\u{7}'");
      expect(dartLiteral('héllo 😀'), "'héllo 😀'");
    });

    test('keeps short maps and lists on one line', () {
      expect(
        dartLiteral({'id': 1, 'name': 'Jane'}),
        "{'id': 1, 'name': 'Jane'}",
      );
      expect(dartLiteral([1, 2, 'x']), "[1, 2, 'x']");
      expect(dartLiteral({}), '{}');
      expect(dartLiteral([]), '[]');
      expect(dartLiteral({}, expand: true), '{}');
    });

    test('splits long maps one entry per line with trailing commas', () {
      final String literal = dartLiteral({
        'storage': {
          'user_name':
              'A fairly long value that pushes this map past the width',
          'flag': true,
        },
        'backpack': {},
      }, indent: '  ');

      expect(
        literal,
        "{\n"
        "    'storage': {\n"
        "      'user_name': 'A fairly long value that pushes this map past the width',\n"
        "      'flag': true,\n"
        "    },\n"
        "    'backpack': {},\n"
        "  }",
      );
    });

    test('splits a collection that holds another, as dart format does', () {
      expect(
        dartLiteral({
          'a': {'b': 1},
        }),
        "{\n  'a': {'b': 1},\n}",
      );
      expect(
        dartLiteral([
          {'id': 1},
          {'id': 2},
        ]),
        "[\n  {'id': 1},\n  {'id': 2},\n]",
      );
      expect(
        dartLiteral({
          'orders': [
            {'id': 1},
          ],
        }, indent: '  '),
        "{\n    'orders': [\n      {'id': 1},\n    ],\n  }",
      );
      expect(dartLiteral({'a': [], 'c': {}}), "{'a': [], 'c': {}}");
    });

    test('counts the key and the comma when checking the width', () {
      final String value = 'x' * 60;
      // 4 + 'key': (7) + quoted value (62) + comma = 74, fits in 80.
      expect(
        dartLiteral({'key': value}, indent: '  ', expand: true),
        "{\n    'key': '$value',\n  }",
      );
      // A list that would fit alone no longer fits after a long key.
      final Map<String, Object?> map = {
        'a_rather_long_key_name_here': [1, 2],
      };
      expect(
        dartLiteral(map, indent: '  ', width: 40),
        "{\n    'a_rather_long_key_name_here': [\n      1,\n      2,\n    ],\n  }",
      );
    });

    test('expands the top level on request, but not nested values', () {
      expect(
        dartLiteral({
          'Pro': true,
          'cart': [1, 2],
        }, expand: true),
        "{\n  'Pro': true,\n  'cart': [1, 2],\n}",
      );
      expect(dartLiteral(['a', 'b'], expand: true), "[\n  'a',\n  'b',\n]");
    });
  });

  group('LiveSnapshot.decode', () {
    test('reads the file export --to writes', () {
      final LiveSnapshot snapshot = LiveSnapshot.decode('''
{
  "nylo": 1,
  "exportedAt": "2026-09-15T19:41:09Z",
  "app": "Nylo",
  "env": "developing",
  "device": "iPhone 17e",
  "route": "/home",
  "storage": {"Pro": true, "user": {"type": "model", "value": {"id": 1}}},
  "backpack": {"cart": [1]}
}
''');

      expect(snapshot.storage, {
        'Pro': true,
        'user': {
          'type': 'model',
          'value': {'id': 1},
        },
      });
      expect(snapshot.backpack, {
        'cart': [1],
      });
      expect(snapshot.app, 'Nylo');
      expect(snapshot.env, 'developing');
      expect(snapshot.device, 'iPhone 17e');
      expect(snapshot.route, '/home');
      expect(snapshot.exportedAt, DateTime.utc(2026, 9, 15, 19, 41, 9));
      expect(snapshot.length, 3);
    });

    test('reads what export --json prints', () {
      const String result =
          '{"storage": {"Pro": true}, "backpack": {}, "route": "/home"}';

      final LiveSnapshot fromList = LiveSnapshot.decode(
        '[{"device": "iPhone 17e", "ok": true, "result": $result}]',
      );
      expect(fromList.storage, {'Pro': true});
      expect(fromList.route, '/home');

      final LiveSnapshot fromObject = LiveSnapshot.decode(
        '{"result": $result}',
      );
      expect(fromObject.storage, {'Pro': true});

      final LiveSnapshot bare = LiveSnapshot.decode('{"storage": {"a": 1}}');
      expect(bare.storage, {'a': 1});
      expect(bare.backpack, isEmpty);
    });

    test('says what is wrong', () {
      Matcher formatError(Object message) => throwsA(
        isA<FormatException>().having((e) => e.message, 'message', message),
      );

      expect(
        () => LiveSnapshot.decode('nope'),
        formatError(contains('isn\'t valid JSON')),
      );
      expect(
        () => LiveSnapshot.decode('[]'),
        formatError(contains('one app at a time')),
      );
      expect(
        () => LiveSnapshot.decode('{"a": 1}'),
        formatError(contains('"storage" and "backpack"')),
      );
      expect(
        () => LiveSnapshot.decode('{"storage": []}'),
        formatError(contains('"storage" isn\'t a JSON object')),
      );
      expect(
        () => LiveSnapshot.decode('{"nylo": 9, "storage": {}}'),
        formatError(contains('newer than this Metro')),
      );
    });

    test('encode round-trips through decode', () {
      final LiveSnapshot snapshot = LiveSnapshot(
        storage: {
          'Pro': true,
          'user': {
            'type': 'model',
            'value': {'id': 1},
          },
        },
        backpack: {
          'cart': [1],
        },
        app: 'Nylo',
        env: 'developing',
        device: 'iPhone 17e',
        route: '/home',
        exportedAt: DateTime.utc(2026, 9, 15, 19, 41, 9),
      );

      final String text = snapshot.encode();

      expect(
        text,
        startsWith(
          '{\n  "nylo": 1,\n  "exportedAt": "2026-09-15T19:41:09.000Z",\n'
          '  "app": "Nylo",\n',
        ),
      );
      expect(text, endsWith('}\n'));
      final LiveSnapshot back = LiveSnapshot.decode(text);
      expect(back.storage, snapshot.storage);
      expect(back.backpack, snapshot.backpack);
      expect(back.device, 'iPhone 17e');
      expect(back.exportedAt, snapshot.exportedAt);
    });
  });

  group('LiveSnapshot.fromPayload', () {
    test('reads the storage.export payload with its context', () {
      final LiveSnapshot snapshot = LiveSnapshot.fromPayload({
        'nylo': 1,
        'storage': {'Pro': true},
        'backpack': {'SK_USER': null},
        'skipped': [
          {'store': 'backpack', 'key': 'callback', 'reason': 'not JSON'},
        ],
        'app': 'Nylo',
        'env': '',
        'route': '/home',
        'exportedAt': '2026-09-15T19:41:09Z',
      }, device: 'iPhone 17e');

      expect(snapshot.storage, {'Pro': true});
      expect(snapshot.backpack, {'SK_USER': null});
      expect(snapshot.backpack.containsKey('SK_USER'), isTrue);
      expect(snapshot.skipped, [
        {'store': 'backpack', 'key': 'callback', 'reason': 'not JSON'},
      ]);
      expect(snapshot.app, 'Nylo');
      expect(snapshot.env, isNull);
      expect(snapshot.device, 'iPhone 17e');
      expect(snapshot.exportedAt, DateTime.utc(2026, 9, 15, 19, 41, 9));
    });

    test('rejects payloads that aren\'t snapshots', () {
      expect(
        () => LiveSnapshot.fromPayload('nope'),
        throwsA(isA<LiveCommandException>()),
      );
      expect(
        () => LiveSnapshot.fromPayload({'storage': 'x'}),
        throwsA(
          isA<LiveCommandException>().having(
            (e) => e.message,
            'message',
            contains('"storage" isn\'t a JSON object'),
          ),
        ),
      );
    });
  });

  group('LiveSnapshot', () {
    test('summarises and sizes itself', () {
      final LiveSnapshot snapshot = LiveSnapshot(
        storage: {'Pro': true},
        backpack: {'a': 1, 'b': 2},
      );

      expect(snapshot.summary, '1 storage value, 2 Backpack values');
      expect(snapshot.isEmpty, isFalse);
      expect(
        snapshot.sizeInBytes,
        utf8.encode(jsonEncode(snapshot.toImportJson())).length,
      );
      expect(const LiveSnapshot(storage: {}, backpack: {}).isEmpty, isTrue);
      expect(
        const LiveSnapshot(storage: {}, backpack: {}).summary,
        '0 storage values, 0 Backpack values',
      );
    });

    test('spots keys that look like credentials', () {
      final LiveSnapshot snapshot = LiveSnapshot(
        storage: {
          'SK_BEARER_TOKEN': 'x',
          'api_key': 1,
          'name': 'Jane',
          'session': 'aaaaaaaaaaaa.bbbbbbbbbbbb.cccccccccccc',
          'SK_USER': {'id': 1, 'token': 'demo-token'},
          'orders': [
            {'id': 1, 'secret_code': 'x'},
          ],
          'prefs': {'dark': true},
        },
        backpack: {'SK_BEARER_TOKEN': null, 'password_hint': 'x', 'cart': []},
      );

      expect(snapshot.secretKeys, [
        'SK_BEARER_TOKEN',
        'api_key',
        'session',
        'SK_USER',
        'orders',
        'password_hint',
      ]);
      expect(const LiveSnapshot(storage: {}, backpack: {}).secretKeys, isEmpty);
    });

    test('describes entries for a table', () {
      expect(LiveSnapshot.describeEntry(7), (type: 'int', value: 7));
      expect(LiveSnapshot.describeEntry(1.5), (type: 'double', value: 1.5));
      expect(LiveSnapshot.describeEntry('x'), (type: 'string', value: 'x'));
      expect(LiveSnapshot.describeEntry(null), (type: 'null', value: null));

      void describes(Object? entry, String type, Object? value) {
        final ({String type, Object? value}) described =
            LiveSnapshot.describeEntry(entry);
        expect(described.type, type);
        expect(described.value, value);
      }

      describes([1], 'json', [1]);
      describes(
        {
          'type': 'model',
          'value': {'id': 1},
        },
        'model',
        {'id': 1},
      );
      describes(
        {'type': 'string', 'value': 'a', 'ttl': 60},
        'string · ttl 60s',
        'a',
      );
      describes(
        {
          'type': 'model',
          'model': 'User',
          'value': {'id': 1},
        },
        'User',
        {'id': 1},
      );
      describes(
        {'type': 'models', 'model': 'Order', 'value': []},
        'List<Order>',
        [],
      );
      final Map<String, Object?> plain = {'type': 'car', 'value': 3, 'x': 1};
      describes(plain, 'json', plain);
    });
  });

  group('findSnapshotFile', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('nylo_find_snapshot_');
      File('${project.path}/snapshots/demo.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      File('${project.path}/exports/tone.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      File('${project.path}/loose.json').writeAsStringSync('{}');
      Directory('${project.path}/notafile.json').createSync();
    });

    tearDown(() => project.deleteSync(recursive: true));

    String? found(String source) =>
        findSnapshotFile(source, root: project.path)?.path;

    test('finds a bare name in the folders snapshots are kept in', () {
      expect(found('demo'), '${project.path}/snapshots/demo.json');
      expect(found('tone'), '${project.path}/exports/tone.json');
    });

    test('finds a bare name that already ends in .json', () {
      expect(found('demo.json'), '${project.path}/snapshots/demo.json');
    });

    test('takes a path as written, without searching', () {
      final String previous = Directory.current.path;
      Directory.current = project;
      try {
        expect(findSnapshotFile('loose.json'), isNotNull);
        expect(findSnapshotFile('loose'), isNotNull);
        expect(findSnapshotFile('snapshots/demo.json'), isNotNull);
        // A path that names a folder isn't found somewhere else.
        expect(findSnapshotFile('other/demo.json', root: project.path), isNull);
      } finally {
        Directory.current = previous;
      }
    });

    test('is null for a name nothing matches, and for a folder', () {
      expect(found('missing'), isNull);
      expect(found('notafile'), isNull);
    });
  });

  group('names', () {
    test('snapshotNameFor uses the file stem in snake case', () {
      expect(snapshotNameFor('snapshots/pro_user.json'), 'pro_user');
      expect(snapshotNameFor('Pro-User.json'), 'pro_user');
      expect(snapshotNameFor(r'C:\snaps\Demo User.json'), 'demo_user');
      expect(snapshotNameFor('demo.snapshot.json'), 'demo_snapshot');
      expect(snapshotNameFor('.json'), 'snapshot');
      expect(snapshotNameFor('123.json'), 'snapshot');
    });

    test('seederNameFrom accepts seeder-style names only', () {
      expect(seederNameFrom('DemoUser'), 'demo_user');
      expect(seederNameFrom('demo user'), 'demo_user');
      expect(seederNameFrom(' demo__user '), 'demo_user');
      expect(seederNameFrom('demo_user2'), 'demo_user2');
      expect(seederNameFrom(''), isNull);
      expect(seederNameFrom('9lives'), isNull);
      expect(seederNameFrom('---'), isNull);
    });
  });
}
