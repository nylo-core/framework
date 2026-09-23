import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_snapshot.dart';
import 'package:nylo_framework/metro/stubs/snapshot_seeder_stub.dart';
import 'package:recase/recase.dart';

void main() {
  final LiveSnapshot snapshot = LiveSnapshot(
    storage: {'Pro': true, 'user_name': 'Dummy User(s)'},
    backpack: {'SK_USER': null},
    app: 'Nylo',
    env: 'developing',
    device: 'iPhone 17e',
    route: '/home',
    exportedAt: DateTime(2026, 9, 15, 20, 41),
  );

  group('snapshotSeederStub', () {
    test('creates a seeder that imports the snapshot', () {
      final String stub = snapshotSeederStub(
        seeder: ReCase('demo_user'),
        snapshot: snapshot,
      );

      expect(stub, contains('class DemoUserSeeder extends Seeder'));
      expect(stub, contains('await importSnapshot(snapshot);'));
      expect(stub, contains('await restore();'));
      expect(
        stub,
        contains(
          "  static const Map<String, Object?> snapshot = {\n"
          "    'storage': {\n"
          "      'Pro': true,\n"
          "      'user_name': 'Dummy User(s)',\n"
          "    },\n"
          "    'backpack': {\n"
          "      'SK_USER': null,\n"
          "    },\n"
          "  };\n",
        ),
      );
      expect(stub, contains('/// 2 storage values and 1 Backpack value.'));
      expect(
        stub,
        contains(
          r"success('Demo User imported on ${Nylo.getCurrentRouteName()}');",
        ),
      );
      expect(stub, isNot(contains('class _')));
    });

    test('imports the framework and the live library', () {
      final String stub = snapshotSeederStub(
        seeder: ReCase('demo_user'),
        snapshot: snapshot,
      );

      expect(
        stub,
        contains("import 'package:nylo_framework/nylo_framework.dart';"),
      );
      expect(stub, contains("import 'package:nylo_framework/live.dart';"));
    });

    test('documents where it came from and how to run it', () {
      final String stub = snapshotSeederStub(
        seeder: ReCase('demo_user'),
        snapshot: snapshot,
      );

      expect(stub, contains('/// Demo User Seeder\n'));
      expect(
        stub,
        contains(
          '/// Exported from iPhone 17e (Nylo, developing) on 15 Sep 2026 at '
          '20:41 with\n/// export demo_user in metro live. Edit the snapshot '
          'below, or export again\n/// with --force to replace it.\n',
        ),
      );
      expect(stub, contains('/// Run it in metro live:  seed demo_user\n'));
      expect(
        stub,
        contains('/// Undo it in metro live: seed:rollback demo_user\n'),
      );
      // No metro live:<command>: these commands only run inside the shell.
      expect(stub, isNot(matches(r'metro live:\w')));
      expect(
        stub,
        contains("description => 'Storage from iPhone 17e, 15 Sep 20:41';"),
      );
      expect(stub, contains('/// Storage from iPhone 17e, 15 Sep 20:41\n'));
    });

    test('uses and escapes the description', () {
      final String stub = snapshotSeederStub(
        seeder: ReCase('demo_user'),
        snapshot: snapshot,
        description: r"Jane's account,  $5 credit",
      );

      expect(stub, contains(r"description => 'Jane\'s account, \$5 credit';"));
      expect(stub, contains("/// Jane's account, \$5 credit\n"));
    });

    test('copes without any context', () {
      final String stub = snapshotSeederStub(
        seeder: ReCase('bare'),
        snapshot: const LiveSnapshot(storage: {'a': 1}, backpack: {}),
        now: DateTime(2026, 1, 2, 3, 4),
      );

      expect(
        stub,
        contains('/// Exported from the app on 2 Jan 2026 at 03:04'),
      );
      expect(
        stub,
        contains("description => 'Storage from the app, 2 Jan 03:04';"),
      );
      expect(stub, contains("    'backpack': {},\n"));
      expect(stub, contains('/// 1 storage value and 0 Backpack values.'));
    });

    test('writes tagged and nested values as Dart', () {
      final String stub = snapshotSeederStub(
        seeder: ReCase('rich'),
        snapshot: LiveSnapshot(
          storage: {
            'user': {
              'type': 'model',
              'value': {'name': 'Anthony', 'email': 'anthony@example.com'},
            },
            'hint': {'type': 'string', 'value': 'abc', 'ttl': 3600},
          },
          backpack: {
            'me': {
              'type': 'model',
              'model': 'User',
              'value': {'name': 'Anthony'},
            },
          },
        ),
      );

      expect(
        stub,
        contains(
          "      'user': {\n"
          "        'type': 'model',\n"
          "        'value': {'name': 'Anthony', 'email': 'anthony@example.com'},\n"
          "      },\n"
          "      'hint': {'type': 'string', 'value': 'abc', 'ttl': 3600},\n",
        ),
      );
      expect(
        stub,
        contains(
          "      'me': {\n"
          "        'type': 'model',\n"
          "        'model': 'User',\n"
          "        'value': {'name': 'Anthony'},\n"
          "      },\n",
        ),
      );
    });
  });
}
