import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/commands/live/live_commands.dart';
import 'package:nylo_framework/metro/live/live_discovery.dart';
import 'package:nylo_framework/metro/live/live_line_editor.dart';
import 'package:nylo_framework/metro/live/live_manifest.dart';
import 'package:nylo_framework/metro/live/live_options.dart';
import 'package:nylo_framework/metro/live/live_output.dart';
import 'package:nylo_framework/metro/live/live_runner.dart';
import 'package:nylo_framework/metro/live/live_session.dart';
import 'package:nylo_framework/metro/live/live_shell.dart';
import 'package:nylo_framework/metro/live/live_snapshot.dart';

import 'fake_servers.dart';

class FakeTerminal implements LiveTerminal {
  FakeTerminal({this.hasTerminal = true});

  @override
  final bool hasTerminal;

  @override
  bool get supportsAnsi => false;

  @override
  int get columns => 120;

  @override
  void enableRawMode() {}

  @override
  void restoreMode() {}
}

/// Pushes a VM service stream event to every client of [app].
void notify(FakeNyloApp app, String streamId, Map<String, Object?> event) {
  for (final FakeConnection client in app.server.clients) {
    try {
      client.streamNotify(streamId, event);
    } catch (_) {
      // A closed connection from an earlier refresh.
    }
  }
}

Future<void> settle([int milliseconds = 50]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

Future<void> eventually(bool Function() condition) async {
  for (int i = 0; i < 100 && !condition(); i++) {
    await settle(10);
  }
  expect(condition(), isTrue);
}

void main() {
  final List<Future<void> Function()> cleanup = [];

  tearDown(() async {
    for (final Future<void> Function() close in cleanup.reversed) {
      await close();
    }
    cleanup.clear();
  });

  Future<FakeNyloApp> app({
    Map<String, Future<Object?> Function(Map<String, Object?> args)> commands =
        const {},
    Map<String, Object?>? status,
    FakeStateObject? inspected,
  }) async {
    final FakeNyloApp fake = await FakeNyloApp.start(
      commands: commands,
      status: status,
      inspected: inspected,
    );
    cleanup.add(fake.close);
    return fake;
  }

  /// A runner and session whose discovery finds [devices], for the project
  /// at [root].
  Future<({LiveRunner runner, LiveSession session, StringBuffer printed})>
  sessionFor(Map<String, FakeNyloApp> devices, {String? root}) async {
    final FakeJsonRpcServer dtd = await startFakeDaemon([
      for (final MapEntry<String, FakeNyloApp> entry in devices.entries)
        (
          uri: entry.value.wsUri,
          name: 'Kind: Flutter - Device: ${entry.key} - Package: shop',
        ),
    ]);
    cleanup.add(dtd.close);
    final StringBuffer printed = StringBuffer();
    final LiveRunner runner = LiveRunner(
      output: LivePrinter(sink: printed, ansi: false),
      project: LiveProject(root ?? Directory.systemTemp.path, 'shop'),
      discovery: (project, timeout) => LiveDiscovery(
        projectRoot: project.root,
        packageName: project.packageName,
        timeout: timeout,
        listDaemons: () async => [
          LiveDaemon(wsUri: dtd.wsUri, workspaceRoot: project.root),
        ],
      ),
    );
    final LiveSession session = LiveSession(
      runner,
      pollInterval: const Duration(milliseconds: 20),
    );
    runner.session = session;
    cleanup.add(session.close);
    return (runner: runner, session: session, printed: printed);
  }

  group('LiveSession', () {
    test('keeps connections open across commands and refreshes', () async {
      final FakeNyloApp phone = await app(
        commands: {
          'cart.seed': (args) async => {'seeded': 2},
        },
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      await live.session.refresh();
      await live.session.refresh();
      for (int i = 0; i < 3; i++) {
        final int code = await live.runner.run(
          const LiveOptions(),
          (app, block) => app.call('cart.seed'),
        );
        expect(code, 0);
      }

      expect(live.session.apps, hasLength(1));
      expect(live.session.apps.single.client.isClosed, isFalse);
      expect(phone.calls['cart.seed'], hasLength(3));
    });

    test(
      'uses the only app, and asks for use when there are several',
      () async {
        final live = await sessionFor({
          'iPhone 17 Pro': await app(),
          'Pixel 9': await app(),
        });
        await live.session.refresh();

        final resolved = await live.session.resolve(
          const LiveOptions(),
          live.runner.output,
        );

        expect(resolved.exitCode, 2);
        expect(
          live.printed.toString(),
          contains(
            '2 apps are running. Pick one with use <#|name>, or use all:',
          ),
        );
        expect(live.printed.toString(), contains('  1  iPhone 17 Pro'));
      },
    );

    test('use picks an app by number or name, or all of them', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(),
        'Pixel 9': await app(),
      });
      await live.session.refresh();

      expect(await live.session.use('2'), isNull);
      expect(live.session.current?.device, 'Pixel 9');
      expect(
        (await live.session.resolve(
          const LiveOptions(),
          live.runner.output,
        )).targets.single.device,
        'Pixel 9',
      );

      expect(await live.session.use('iphone'), isNull);
      expect(live.session.current?.device, 'iPhone 17 Pro');

      expect(await live.session.use('all'), isNull);
      expect(
        (await live.session.resolve(
          const LiveOptions(),
          live.runner.output,
        )).targets,
        hasLength(2),
      );

      final failure = await live.session.use('7');
      expect(failure?.error, contains('There is no app #7'));
    });

    test('-d and --all on one command win over use', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(),
        'Pixel 9': await app(),
      });
      await live.session.refresh();
      await live.session.use('1');

      final resolved = await live.session.resolve(
        const LiveOptions(device: 'Pixel'),
        live.runner.output,
      );

      expect(resolved.targets.single.device, 'Pixel 9');
      expect(live.session.current?.device, 'iPhone 17 Pro');
    });

    test('follows page changes for the prompt', () async {
      final FakeNyloApp phone = await app();
      final live = await sessionFor({'iPhone 17 Pro': phone});
      int changes = 0;
      live.session.onChange = () => changes++;
      await live.session.refresh();
      await settle();

      notify(phone, 'nylo', {
        'extensionKind': 'nylo.route',
        'extensionData': {
          'action': 'push',
          'name': '/profile',
          'previous': '/home',
        },
      });
      await eventually(
        () => live.session.current?.status['route'] == '/profile',
      );

      notify(phone, 'nylo', {
        'extensionKind': 'nylo.route',
        'extensionData': {
          'action': 'pop',
          'name': '/profile',
          'previous': '/home',
        },
      });
      await eventually(() => live.session.current?.status['route'] == '/home');
      expect(changes, greaterThanOrEqualTo(2));
    });

    test('notices a hot restart and follows the new isolate', () async {
      final FakeNyloApp phone = await app();
      final live = await sessionFor({'iPhone 17 Pro': phone});
      final List<String> notices = [];
      live.session.onNotice = notices.add;
      await live.session.refresh();
      await settle();

      phone.state.isolateId = 'isolates/200';
      notify(phone, 'Extension', {
        'kind': 'ServiceExtensionAdded',
        'extensionRPC': 'ext.nylo.status',
        'isolate': {'type': '@Isolate', 'id': 'isolates/200'},
      });

      await eventually(() => notices.isNotEmpty);
      expect(notices.single, 'iPhone 17 Pro hot restarted, reconnected');
      expect(live.session.current?.isolateId, 'isolates/200');
    });

    test('says when an app disconnects, and waits for it', () async {
      final FakeNyloApp phone = await app();
      final live = await sessionFor({'iPhone 17 Pro': phone});
      final List<String> notices = [];
      live.session.onNotice = notices.add;
      await live.session.refresh();

      await phone.close();

      await eventually(() => notices.contains('iPhone 17 Pro disconnected'));
      expect(live.session.apps, isEmpty);
    });
  });

  group('runLiveShellCommand', () {
    /// A fake `seeders.run` that reports each named seeder as done.
    Future<Object?> seedersRun(Map<String, Object?> args) async => {
      'runs': [
        for (final Object? name in args['names'] as List)
          {
            'name': name,
            'direction': args['direction'],
            'ms': 3,
            'failed': false,
            'log': [],
          },
      ],
      'failed': false,
    };

    test('runs built-in commands without their prefix', () async {
      final live = await sessionFor({'iPhone 17 Pro': await app()});

      final int? code = await runLiveShellCommand(
        'status',
        const [],
        live.runner,
      );

      expect(code, 0);
      expect(live.printed.toString(), contains('Route'));
      expect(live.session.apps.single.client.isClosed, isFalse);
    });

    test('seed runs up and says how to roll back', () async {
      final FakeNyloApp phone = await app(
        status: {'route': '/home', 'seeders': []},
        commands: {'seeders.run': seedersRun},
      );
      final live = await sessionFor({'iPhone 17e': phone});

      final int? code = await runLiveShellCommand('seed', [
        'demo_user',
        'favourites',
      ], live.runner);

      expect(code, 0);
      expect(phone.calls['seeders.run']!.single, {
        'names': ['demo_user', 'favourites'],
        'direction': 'up',
      });
      expect(
        live.printed.toString(),
        endsWith('· Undo with seed:rollback demo_user favourites\n'),
      );
    });

    test('seed:rollback runs down, and needs a name', () async {
      final FakeNyloApp phone = await app(
        status: {'route': '/home', 'seeders': []},
        commands: {'seeders.run': seedersRun},
      );
      final live = await sessionFor({'iPhone 17e': phone});

      expect(
        await runLiveShellCommand('seed:rollback', ['demo_user'], live.runner),
        0,
      );
      expect(phone.calls['seeders.run']!.single, {
        'names': ['demo_user'],
        'direction': 'down',
      });
      expect(live.printed.toString(), contains('✓ Rolled back demo_user'));
      expect(live.printed.toString(), isNot(contains('Undo with')));

      expect(
        await runLiveShellCommand('seed:rollback', const [], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('Name the seeders to roll back, e.g. seed:rollback demo_user'),
      );
    });

    test('shell-only commands show examples as typed in the shell', () async {
      final live = await sessionFor({'iPhone 17e': await app()});

      for (final (String name, String example) in [
        ('seed', 'e.g. seed demo_user'),
        ('seed:rollback', 'e.g. seed:rollback demo_user'),
        ('export', 'e.g. export demo_user'),
        ('reload', 'e.g. reload --all'),
        ('restart', 'e.g. restart --all'),
      ]) {
        expect(await runLiveShellCommand(name, ['--help'], live.runner), 0);
        expect(live.printed.toString(), contains(example));
      }
      expect(live.printed.toString(), isNot(contains('e.g. metro live:')));

      // A command with a metro live:* of its own still shows that.
      expect(await runLiveShellCommand('status', ['--help'], live.runner), 0);
      expect(live.printed.toString(), contains('e.g. metro live:status'));
    });

    test(
      'running a command the app hasn\'t loaded says to hot restart',
      () async {
        final Directory project = Directory.systemTemp.createTempSync(
          'nylo_live_project_',
        );
        addTearDown(() => project.deleteSync(recursive: true));
        File('${project.path}/lib/bootstrap/live_commands.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync(
            "final Map<String, LiveCommand Function()> liveCommands = {\n"
            "  'app:seed_cart': () => SeedCartCommand(),\n"
            "};\n",
          );
        final live = await sessionFor({
          'iPhone 17e': await app(
            commands: {
              'commands.list': (args) async => {'commands': []},
            },
          ),
        }, root: project.path);

        final int? code = await runLiveShellCommand(
          'app:seed_cart',
          const [],
          live.runner,
        );

        expect(code, 1);
        expect(
          live.printed.toString(),
          contains(
            '"app:seed_cart" isn\'t loaded in the running app yet. '
            'Load it with restart.',
          ),
        );
      },
    );

    /// A fake app holding one storage value that expires.
    Future<FakeNyloApp> storageApp() => app(
      commands: {
        'storage.list': (args) async => {
          'items': [
            {'key': 'SK_USER', 'type': 'json', 'value': {}},
          ],
        },
        'storage.get': (args) async => {
          'key': args['key'],
          'exists': true,
          'type': 'json',
          'value': {
            'name': 'Jane',
            'roles': ['admin'],
          },
          'expiresAt': '2026-10-01T00:00:00.000Z',
        },
        'storage.delete': (args) async => {
          'key': args['key'],
          'deleted': true,
          'existed': true,
        },
        'storage.set': (args) async => {
          'key': args['key'],
          'type': args['value'] is Map || args['value'] is List
              ? 'json'
              : '${args['value'].runtimeType}',
          if (args['ttl'] != null) 'expiresAt': '2026-10-01T00:00:00.000Z',
        },
      },
    );

    test('the commands storage took over say what to type now', () async {
      final live = await sessionFor({'iPhone 17 Pro': await app()});

      expect(
        await runLiveShellCommand('storage:get', ['SK_USER'], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('"storage:get" is now storage <key>'),
      );

      expect(
        await runLiveShellCommand('storage:delete', ['SK_USER'], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('"storage:delete" is now storage <key> --delete'),
      );
    });

    test('storage lists, shows one key, and deletes one key', () async {
      final FakeNyloApp phone = await storageApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(await runLiveShellCommand('storage', const [], live.runner), 0);
      expect(live.printed.toString(), contains('KEY'));
      expect(phone.calls['storage.get'], isNull);

      expect(await runLiveShellCommand('storage', ['SK_USER'], live.runner), 0);
      expect(phone.calls['storage.get']!.single, {'key': 'SK_USER'});
      final String shown = live.printed.toString();
      expect(shown, contains('SK_USER  json  expires 2026-10-01'));
      expect(shown, contains('"name": "Jane"'));

      expect(
        await runLiveShellCommand('storage', ['SK_USER', '-D'], live.runner),
        0,
      );
      expect(phone.calls['storage.delete']!.single, {'key': 'SK_USER'});
      expect(live.printed.toString(), contains('Deleted SK_USER'));
    });

    test('storage saves a value given after the key', () async {
      final FakeNyloApp phone = await storageApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('storage', ['SK_COINS', '10'], live.runner),
        0,
      );
      expect(phone.calls['storage.set']!.single, {
        'key': 'SK_COINS',
        'value': 10,
      });
      expect(live.printed.toString(), contains('Saved SK_COINS (int)'));
      expect(
        phone.calls['storage.get'],
        isNull,
        reason: 'a second argument means save, not show',
      );
    });

    test('storage reads the value as JSON, or as text with --string', () async {
      final FakeNyloApp phone = await storageApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      await runLiveShellCommand('storage', [
        'profile',
        '{"name":"Jane"}',
      ], live.runner);
      expect(phone.calls['storage.set']!.last['value'], {'name': 'Jane'});

      await runLiveShellCommand('storage', [
        'version',
        '1.0',
        '--string',
      ], live.runner);
      expect(phone.calls['storage.set']!.last['value'], '1.0');

      await runLiveShellCommand('storage', [
        'greeting',
        'hello',
        'there',
      ], live.runner);
      expect(phone.calls['storage.set']!.last['value'], 'hello there');
    });

    test('storage passes --ttl and --backpack when saving', () async {
      final FakeNyloApp phone = await storageApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('storage', [
          'coins',
          '10',
          '--ttl',
          '60',
          '--backpack',
        ], live.runner),
        0,
      );
      expect(phone.calls['storage.set']!.single, {
        'key': 'coins',
        'value': 10,
        'ttl': 60,
        'backpack': true,
      });
      expect(live.printed.toString(), contains('expires 2026-10-01'));

      expect(
        await runLiveShellCommand('storage', [
          'coins',
          '10',
          '--ttl',
          '0',
        ], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('--ttl must be a positive number of seconds'),
      );
    });

    test('the saving flags are refused when nothing is being saved', () async {
      final FakeNyloApp phone = await storageApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('storage', [
          'coins',
          '--ttl',
          '60',
        ], live.runner),
        64,
      );
      expect(live.printed.toString(), contains('--ttl only work'));
      expect(phone.calls['storage.get'], isNull);

      expect(
        await runLiveShellCommand('storage', [
          '--backpack',
          '--string',
        ], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('--backpack and --string only work when saving'),
      );
      expect(phone.calls['storage.list'], isNull);
    });

    test('--delete refuses a value, so a save is never a delete', () async {
      final FakeNyloApp phone = await storageApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('storage', [
          'coins',
          '10',
          '-D',
        ], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('Use --delete with a key on its own'),
      );
      expect(phone.calls['storage.delete'], isNull);
      expect(phone.calls['storage.set'], isNull);
    });

    test('storage says when a key is not set', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          commands: {
            'storage.get': (args) async => {
              'key': args['key'],
              'exists': false,
              'type': null,
              'value': null,
            },
            'storage.delete': (args) async => {
              'key': args['key'],
              'deleted': true,
              'existed': false,
            },
          },
        ),
      });

      expect(await runLiveShellCommand('storage', ['nope'], live.runner), 0);
      expect(live.printed.toString(), contains('nope isn\'t set'));

      expect(
        await runLiveShellCommand('storage', ['gone', '--delete'], live.runner),
        0,
      );
      expect(live.printed.toString(), contains('gone wasn\'t set'));
    });

    test('storage --delete needs a key, and points at clear', () async {
      final FakeNyloApp phone = await storageApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('storage', ['--delete'], live.runner),
        64,
      );
      final String printed = live.printed.toString();
      expect(printed, contains('A key is required to delete'));
      expect(printed, contains('storage:clear'));
      expect(phone.calls['storage.list'], isNull);
      expect(phone.calls['storage.delete'], isNull);
    });

    test('backpack lists every value, and one in full with a key', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 6, 'route': '/home'},
        commands: {
          'backpack.list': (args) async => {
            'items': [
              {
                'key': 'auth_user',
                'type': '_Map<String, dynamic>',
                'value': {},
              },
            ],
          },
          'backpack.get': (args) async => {
            'key': args['key'],
            'exists': true,
            'type': '_Map<String, dynamic>',
            'value': {
              'name': 'Jane',
              'roles': ['admin'],
            },
          },
        },
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(await runLiveShellCommand('backpack', const [], live.runner), 0);
      expect(live.printed.toString(), contains('KEY'));
      expect(phone.calls['backpack.get'], isNull);

      expect(
        await runLiveShellCommand('backpack', ['auth_user'], live.runner),
        0,
      );
      expect(phone.calls['backpack.get']!.single, {'key': 'auth_user'});
      final String printed = live.printed.toString();
      expect(printed, contains('auth_user  _Map<String, dynamic>'));
      expect(printed, contains('"name": "Jane"'));
      expect(printed, contains('"admin"'));
    });

    test('backpack saves a value given after the key', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 6, 'route': '/home'},
        commands: {
          'backpack.set': (args) async => {
            'key': args['key'],
            'type': args['value'] is Map
                ? '_Map<String, dynamic>'
                : '${args['value'].runtimeType}',
          },
          'backpack.get': (args) async => {
            'key': args['key'],
            'exists': true,
            'type': 'int',
            'value': 1,
          },
        },
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('backpack', ['coins', '10'], live.runner),
        0,
      );
      expect(phone.calls['backpack.set']!.single, {
        'key': 'coins',
        'value': 10,
      });
      expect(
        live.printed.toString(),
        contains('Saved coins to the Backpack (int)'),
      );
      expect(
        phone.calls['backpack.get'],
        isNull,
        reason: 'a second argument means save, not show',
      );

      await runLiveShellCommand('backpack', ['user', '{"id":1}'], live.runner);
      expect(phone.calls['backpack.set']!.last['value'], {'id': 1});

      await runLiveShellCommand('backpack', [
        'version',
        '1.0',
        '--string',
      ], live.runner);
      expect(phone.calls['backpack.set']!.last['value'], '1.0');
    });

    test('backpack refuses --string and --delete misuse', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 6, 'route': '/home'},
        commands: {
          'backpack.list': (args) async => {'items': []},
        },
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('backpack', [
          'coins',
          '--string',
        ], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('--string only works when saving a value'),
      );

      expect(
        await runLiveShellCommand('backpack', [
          'coins',
          '10',
          '-D',
        ], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('Use --delete with a key on its own'),
      );
      expect(phone.calls['backpack.set'], isNull);
      expect(phone.calls['backpack.delete'], isNull);
      expect(phone.calls['backpack.list'], isNull);
    });

    test('backpack says when the app is too old to save', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          status: {'protocol': 5, 'route': '/home'},
          commands: {
            'backpack.set': (args) async => {'key': args['key']},
          },
        ),
      });

      expect(
        await runLiveShellCommand('backpack', ['coins', '10'], live.runner),
        1,
      );
      expect(
        live.printed.toString(),
        contains('doesn\'t support saving a Backpack value yet'),
      );
    });

    test('backpack --delete removes one key', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 5, 'route': '/home'},
        commands: {
          'backpack.delete': (args) async => {
            'key': args['key'],
            'deleted': true,
            'existed': true,
          },
        },
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('backpack', [
          'cached_user_resource',
          '-D',
        ], live.runner),
        0,
      );
      expect(phone.calls['backpack.delete']!.single, {
        'key': 'cached_user_resource',
      });
      expect(
        live.printed.toString(),
        contains('Deleted cached_user_resource from the Backpack'),
      );
      expect(phone.calls['backpack.get'], isNull);
    });

    test('backpack --delete says when the key was not there', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          status: {'protocol': 5, 'route': '/home'},
          commands: {
            'backpack.delete': (args) async => {
              'key': args['key'],
              'deleted': true,
              'existed': false,
            },
          },
        ),
      });

      expect(
        await runLiveShellCommand('backpack', [
          'gone',
          '--delete',
        ], live.runner),
        0,
      );
      expect(live.printed.toString(), contains('gone wasn\'t in the Backpack'));
    });

    test('backpack --delete needs a key', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 6, 'route': '/home'},
        commands: {
          'backpack.list': (args) async => {'items': []},
        },
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('backpack', ['--delete'], live.runner),
        64,
      );
      expect(live.printed.toString(), contains('A key is required to delete'));
      expect(phone.calls['backpack.list'], isNull);
    });

    test('backpack --delete says when the app is too old', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          status: {'protocol': 4, 'route': '/home'},
          commands: {
            'backpack.delete': (args) async => {'deleted': true},
          },
        ),
      });

      expect(
        await runLiveShellCommand('backpack', ['cart', '-D'], live.runner),
        1,
      );
      expect(
        live.printed.toString(),
        contains('doesn\'t support deleting a Backpack value yet'),
      );
    });

    test('backpack says when a key was never saved', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          status: {'protocol': 4, 'route': '/home'},
          commands: {
            'backpack.get': (args) async => {
              'key': args['key'],
              'exists': false,
              'type': null,
              'value': null,
            },
          },
        ),
      });

      expect(await runLiveShellCommand('backpack', ['nope'], live.runner), 0);
      expect(live.printed.toString(), contains('nope isn\'t in the Backpack'));
    });

    test('backpack says when the app is too old for one value', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          status: {'protocol': 3, 'route': '/home'},
          commands: {
            'backpack.list': (args) async => {'items': []},
          },
        ),
      });

      expect(await runLiveShellCommand('backpack', ['cart'], live.runner), 1);
      expect(
        live.printed.toString(),
        contains('doesn\'t support showing one Backpack value yet'),
      );
      expect(
        await runLiveShellCommand('backpack', const [], live.runner),
        0,
        reason: 'listing still works on an older app',
      );
    });

    test('auth signs in, signs out, and shows who is signed in', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 7, 'route': '/home'},
        commands: {
          'auth.login': (args) async => {
            'authenticated': true,
            'session': args['session'] ?? 'default',
            'user': args['data'],
          },
          'auth.logout': (args) async => {'session': 'default'},
          'auth.show': (args) async => {
            'key': 'SK_USER',
            'sessions': [
              {
                'session': 'default',
                'user': {'id': 42, 'name': 'Jane'},
              },
            ],
          },
        },
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('auth', [
          'login',
          '--data',
          '{"id": 42}',
        ], live.runner),
        0,
      );
      expect(phone.calls['auth.login']!.single, {
        'data': {'id': 42},
      });
      expect(live.printed.toString(), contains('✓ Signed in'));

      // The JSON can come after login, without --data.
      expect(
        await runLiveShellCommand('auth', [
          'login',
          '{"id": 7}',
          '--session',
          'device',
        ], live.runner),
        0,
      );
      expect(phone.calls['auth.login']!.last, {
        'data': {'id': 7},
        'session': 'device',
      });
      expect(live.printed.toString(), contains('Signed in (device session)'));

      expect(await runLiveShellCommand('auth', ['logout'], live.runner), 0);
      expect(live.printed.toString(), contains('✓ Signed out'));

      expect(await runLiveShellCommand('auth', const [], live.runner), 0);
      final String shown = live.printed.toString();
      expect(shown, contains('default'));
      expect(shown, contains('"name": "Jane"'));
    });

    test('auth explains a verb it does not have, and stray --data', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 7, 'route': '/home'},
        commands: {
          'auth.show': (args) async => {'key': 'SK_USER', 'sessions': []},
        },
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(await runLiveShellCommand('auth', ['signin'], live.runner), 64);
      expect(
        live.printed.toString(),
        contains(
          '"signin" isn\'t something auth does. Use auth login or '
          'auth logout',
        ),
      );

      expect(
        await runLiveShellCommand('auth', [
          'logout',
          '--data',
          '{}',
        ], live.runner),
        64,
      );
      expect(
        live.printed.toString(),
        contains('--data only works when signing in'),
      );

      expect(await runLiveShellCommand('auth', ['login'], live.runner), 64);
      expect(live.printed.toString(), contains('The user data is required'));
      expect(phone.calls['auth.login'], isNull);
    });

    test('auth says when nobody is signed in, or no key is set', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          status: {'protocol': 7, 'route': '/home'},
          commands: {
            'auth.show': (args) async => {
              'key': args['session'] == 'none' ? null : 'SK_USER',
              'sessions': <Object?>[],
            },
          },
        ),
      });

      expect(await runLiveShellCommand('auth', const [], live.runner), 0);
      expect(
        live.printed.toString(),
        contains('Nobody is signed in (auth key SK_USER)'),
      );

      expect(
        await runLiveShellCommand('auth', ['--session', 'none'], live.runner),
        0,
      );
      expect(live.printed.toString(), contains('No auth key is set'));
    });

    /// A fake app that resolves a link to a registered route.
    Future<FakeNyloApp> linkApp({bool registered = true}) => app(
      status: {'protocol': 8, 'route': '/home'},
      commands: {
        'deeplink.show': (args) async => {
          'enabled': true,
          'fallbackRoute': '/home',
          'hasCallback': true,
          'routes': ['/home', '/product/42'],
        },
        'deeplink.open': (args) async => {
          'uri': args['uri'],
          'path': '/product/42',
          'registered': registered,
          'target': registered ? '/product/42' : '/home',
          'queryParameters': {'ref': 'email'},
          'usedFallback': !registered,
          'dry': args['dry'] == true,
          'callback': args['callback'] == false ? 'skipped' : 'continued',
          'routed': args['dry'] != true,
          'from': '/home',
          'current': args['dry'] == true
              ? '/home'
              : (registered ? '/product/42' : '/home'),
        },
      },
    );

    test('deeplink reports each stage of the link', () async {
      final FakeNyloApp phone = await linkApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('deeplink', [
          'myapp://product/42?ref=email',
        ], live.runner),
        0,
      );

      expect(phone.calls['deeplink.open']!.single, {
        'uri': 'myapp://product/42?ref=email',
      });
      final String printed = live.printed.toString();
      expect(printed, contains('myapp://product/42?ref=email → /product/42'));
      expect(printed, contains('onIncomingLink continued'));
      expect(printed, contains('/home → /product/42  ref=email'));
    });

    test('deeplink --dry resolves without sending anything', () async {
      final FakeNyloApp phone = await linkApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('deeplink', [
          'myapp://product/42',
          '--dry',
        ], live.runner),
        0,
      );

      expect(phone.calls['deeplink.open']!.single['dry'], true);
      final String printed = live.printed.toString();
      expect(printed, contains('Would open /product/42'));
      expect(printed, contains('Nothing was sent to the app'));
    });

    test('deeplink says when the path falls back', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await linkApp(registered: false),
      });

      expect(
        await runLiveShellCommand('deeplink', [
          'myapp://promo/summer',
        ], live.runner),
        0,
      );

      expect(
        live.printed.toString(),
        contains('/product/42 isn\'t registered — falling back to /home'),
      );
    });

    test('deeplink refuses a bare path and points at route', () async {
      final FakeNyloApp phone = await linkApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('deeplink', ['/product/42'], live.runner),
        64,
      );

      final String printed = live.printed.toString();
      expect(printed, contains('It needs a scheme'));
      expect(printed, contains('use route /product/42'));
      expect(phone.calls['deeplink.open'], isNull);
    });

    test('deeplink --no-callback skips onIncomingLink', () async {
      final FakeNyloApp phone = await linkApp();
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('deeplink', [
          'myapp://product/42',
          '--no-callback',
        ], live.runner),
        0,
      );

      expect(phone.calls['deeplink.open']!.single['callback'], false);
      expect(live.printed.toString(), contains('onIncomingLink skipped'));
    });

    test('deeplink on its own shows how links are set up', () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'nylo_live_deeplink_',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      File('${project.path}/ios/Runner/Info.plist')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<plist><dict><key>CFBundleURLTypes</key><array><dict>'
          '<key>CFBundleURLSchemes</key><array><string>myapp</string></array>'
          '</dict></array></dict></plist>',
        );
      final FakeNyloApp phone = await linkApp();
      final live = await sessionFor({
        'iPhone 17 Pro': phone,
      }, root: project.path);

      expect(await runLiveShellCommand('deeplink', const [], live.runner), 0);

      final String printed = live.printed.toString();
      expect(printed, contains('Deep links      on'));
      expect(printed, contains('Fallback route  /home'));
      expect(printed, contains('iOS schemes     myapp'));
      expect(printed, contains('2 registered'));
      expect(phone.calls['deeplink.open'], isNull);
    });

    test('deeplink warns when the project declares no such scheme', () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'nylo_live_deeplink_warn_',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      File('${project.path}/ios/Runner/Info.plist')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<plist><dict><key>CFBundleURLTypes</key><array><dict>'
          '<key>CFBundleURLSchemes</key><array><string>myapp</string></array>'
          '</dict></array></dict></plist>',
        );
      final live = await sessionFor({
        'iPhone 17 Pro': await linkApp(),
      }, root: project.path);

      expect(
        await runLiveShellCommand('deeplink', [
          'other://product/42',
        ], live.runner),
        0,
      );

      expect(
        live.printed.toString(),
        contains('"other" isn\'t declared in this project'),
      );
    });

    /// A `state.data` reply for a page holding one field.
    Future<Object?> stateData(Map<String, Object?> args) async => {
      'route': '/conversation-detail',
      'state': {
        'name': 'Closure: () => _ConversationDetailPageState',
        'state': '_ConversationDetailPageState',
        'widget': 'ConversationDetailPage',
        'kind': 'NyPage',
        'controller': 'NyController',
        'data': {'id': 42},
        'queryParameters': null,
        'actions': <String>[],
      },
      'states': [
        {
          'name': null,
          'state': '_ConversationDetailPageState',
          'widget': 'ConversationDetailPage',
          'kind': 'NyPage',
        },
      ],
      'inspect': {
        'library': 'package:nylo_support/live/src/live_state_inspector.dart',
        'variable': 'nyLiveInspectedState',
        'encoder': 'nyLiveInspectJson',
        'skip': const ['State', 'NyBaseState', 'NyPage', 'NyState'],
      },
    };

    test('data shows the page, its data and the fields it declares', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 3, 'route': '/conversation-detail'},
        commands: {'state.data': stateData},
        inspected: FakeStateObject(
          fields: const [
            FakeField.framework('stateName'),
            FakeField.own('isTyping', value: true, className: 'bool'),
          ],
        ),
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      final int? code = await runLiveShellCommand(
        'data',
        const [],
        live.runner,
      );

      expect(code, 0);
      expect(phone.calls['state.data']!.single, isEmpty);
      final String printed = live.printed.toString();
      expect(printed, contains('ConversationDetailPage · NyPage'));
      expect(printed, contains('"id": 42'));
      expect(printed, contains('isTyping  true'));
      expect(printed, isNot(contains('stateName')));
    });

    test('data passes a target through to the app', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 3, 'route': '/conversation-detail'},
        commands: {'state.data': stateData},
      );
      final live = await sessionFor({'iPhone 17 Pro': phone});

      expect(
        await runLiveShellCommand('data', [
          'MessageList',
          '--no-fields',
        ], live.runner),
        0,
      );
      expect(phone.calls['state.data']!.single, {'target': 'MessageList'});
    });

    test('data says when the app is too old to answer', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          status: {'protocol': 2, 'route': '/home'},
          commands: {'state.data': stateData},
        ),
      });

      expect(await runLiveShellCommand('data', const [], live.runner), 1);
      expect(
        live.printed.toString(),
        contains('doesn\'t support reading a page\'s data yet'),
      );
    });

    test('data explains a build whose fields cannot be read', () async {
      final live = await sessionFor({
        'iPhone 17 Pro': await app(
          status: {'protocol': 3, 'route': '/conversation-detail'},
          commands: {'state.data': stateData},
          inspected: FakeStateObject(
            evaluates: false,
            fields: const [
              FakeField.own('isTyping', value: true, className: 'bool'),
            ],
          ),
        ),
      });

      final int? code = await runLiveShellCommand(
        'data',
        const [],
        live.runner,
      );

      expect(code, 0, reason: 'the page itself was still shown');
      final String printed = live.printed.toString();
      expect(printed, contains('ConversationDetailPage · NyPage'));
      expect(printed, contains('debug mode'));
    });

    test(
      'runs live:run actions and reports mistakes without exiting',
      () async {
        final FakeNyloApp phone = await app(
          commands: {
            'route.push': (args) async => {
              'from': '/home',
              'current': args['path'],
              'changed': true,
            },
          },
        );
        final live = await sessionFor({'iPhone 17 Pro': phone});

        expect(
          await runLiveShellCommand('route', ['/profile'], live.runner),
          0,
        );
        expect(live.printed.toString(), contains('/home → /profile'));

        expect(await runLiveShellCommand('route', const [], live.runner), 64);
        expect(live.printed.toString(), contains('A route path is required.'));

        expect(
          await runLiveShellCommand('run', ['route', '/cart'], live.runner),
          0,
        );
        expect(
          await runLiveShellCommand('nonsense', const [], live.runner),
          isNull,
        );
      },
    );

    test('resolves bare names of project commands', () {
      const List<LiveManifestEntry> entries = [
        LiveManifestEntry(name: 'seed_demo', category: 'app', script: 'a.dart'),
        LiveManifestEntry(name: 'reset', category: 'cart', script: 'b.dart'),
        LiveManifestEntry(name: 'reset', category: 'user', script: 'c.dart'),
      ];

      expect(resolveLiveAppCommand('seed_demo', entries), 'app:seed_demo');
      expect(resolveLiveAppCommand('reset', entries), isNull);
      expect(resolveLiveAppCommand('cart:reset', entries), 'cart:reset');
      expect(resolveLiveAppCommand('missing', entries), isNull);
    });

    test('lists every command with options for Tab', () {
      final List<LiveShellCommand> commands = liveShellCommands;
      final List<String> names = commands
          .map((command) => command.name)
          .toList();

      expect(names, containsAll(['devices', 'use', 'seed', 'route', 'toast']));
      expect(names.last, 'exit');
      List<String> optionsOf(String name) =>
          commands.firstWhere((command) => command.name == name).options;
      expect(optionsOf('seed'), containsAll(['--fresh', '--restart', '--all']));
      expect(optionsOf('seed'), isNot(contains('--down')));
      expect(optionsOf('seed:rollback'), containsAll(['--restart', '--all']));
    });
  });

  group('export and import', () {
    const Map<String, Object?> snapshotStatus = {
      'protocol': 2,
      'route': '/home',
      'seeders': [],
    };

    Map<String, Object?> exportPayload() => {
      'nylo': 1,
      'storage': {
        'Pro': true,
        'user_name': 'Dummy User(s)',
        'SK_BEARER_TOKEN': 'abc',
      },
      'backpack': {'SK_USER': null},
      'skipped': [
        {
          'store': 'backpack',
          'key': 'callback',
          'reason': 'Closure can\'t be written as JSON',
        },
      ],
      'exportedAt': '2026-09-15T19:41:09Z',
      'app': 'Nylo',
      'env': 'developing',
      'route': '/home',
    };

    /// A fake `snapshot.import` that reports one change.
    Future<Object?> snapshotImport(Map<String, Object?> args) async => {
      'runs': [
        {
          'name': args['name'],
          'direction': 'up',
          'ms': 11,
          'failed': false,
          'log': [
            {
              'level': 'change',
              'store': 'storage',
              'key': 'Pro',
              'change': 'added',
              'message': 'storage Pro added',
            },
            {'level': 'success', 'message': 'Imported 1 value'},
          ],
        },
      ],
      'failed': false,
    };

    Directory tempProject(String prefix) {
      final Directory project = Directory.systemTemp.createTempSync(prefix);
      cleanup.add(() async => project.deleteSync(recursive: true));
      return project;
    }

    /// A `seeders.run` that reports each named seeder as done.
    Future<Object?> runSeeders(Map<String, Object?> args) async => {
      'runs': [
        for (final Object? name in args['names'] as List)
          {
            'name': name,
            'direction': args['direction'],
            'ms': 3,
            'failed': false,
            'log': [],
          },
      ],
      'failed': false,
    };

    test('export previews the storage without writing anything', () async {
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {'storage.export': (args) async => exportPayload()},
      );
      final live = await sessionFor({'iPhone 17e': phone});

      final int? code = await runLiveShellCommand(
        'export',
        const [],
        live.runner,
      );

      expect(code, 0);
      final String printed = live.printed.toString();
      expect(printed, contains('Storage on iPhone 17e (3 values'));
      expect(printed, contains(RegExp(r'Pro +bool +true')));
      expect(printed, contains(RegExp(r'user_name +string +Dummy User\(s\)')));
      expect(printed, contains('Backpack (1 value)'));
      expect(printed, contains(RegExp(r'SK_USER +null +null')));
      expect(
        printed,
        contains(
          '· Left out backpack callback: Closure can\'t be written as JSON',
        ),
      );
      expect(printed, contains('! The snapshot includes SK_BEARER_TOKEN.'));
      expect(printed, contains('--except SK_BEARER_TOKEN'));
      expect(
        printed,
        contains(
          'Save it as a seeder with export <name>, or as a file with '
          'export --to <path>.json',
        ),
      );
      expect(phone.calls['storage.export']!.single, isEmpty);
    });

    test('export sends its filters, and refuses --all', () async {
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {'storage.export': (args) async => exportPayload()},
      );
      final live = await sessionFor({'iPhone 17e': phone});

      expect(
        await runLiveShellCommand('export', [
          '--only',
          'SK_*, Pro',
          '--except',
          'cache_*',
          '--no-backpack',
        ], live.runner),
        0,
      );
      expect(phone.calls['storage.export']!.single, {
        'only': ['SK_*', 'Pro'],
        'except': ['cache_*'],
        'backpack': false,
      });

      expect(await runLiveShellCommand('export', ['--all'], live.runner), 64);
      expect(live.printed.toString(), contains('one app at a time'));
    });

    test('export writes a seeder and registers it', () async {
      final Directory project = tempProject('nylo_live_export_');
      File('${project.path}/lib/app/providers/app_provider.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "import 'package:nylo_framework/nylo_framework.dart';\n\n"
          'class AppProvider {\n'
          '  Future<void> setup(Nylo nylo) async {\n'
          '    await nylo.configure(\n'
          "      authKey: 'SK_USER',\n"
          '    );\n'
          '  }\n'
          '}\n',
        );
      final Directory previous = Directory.current;
      Directory.current = project;
      try {
        final FakeNyloApp phone = await app(
          status: snapshotStatus,
          commands: {'storage.export': (args) async => exportPayload()},
        );
        final live = await sessionFor({
          'iPhone 17e': phone,
        }, root: project.path);

        final int? code = await runLiveShellCommand('export', [
          'demo_user',
          '--description',
          'Onboarded Pro user',
        ], live.runner);

        expect(code, 0);
        final File seeder = File(
          '${project.path}/lib/app/seeders/demo_user_seeder.dart',
        );
        expect(seeder.existsSync(), isTrue);
        final String source = seeder.readAsStringSync();
        expect(source, contains('class DemoUserSeeder extends Seeder'));
        expect(source, contains("      'user_name': 'Dummy User(s)',\n"));
        expect(source, contains("      'SK_USER': null,\n"));
        expect(source, contains("description => 'Onboarded Pro user';"));
        expect(source, contains('Exported from iPhone 17e (Nylo, developing)'));
        final String registry = File(
          '${project.path}/lib/bootstrap/seeders.dart',
        ).readAsStringSync();
        expect(registry, contains("'demo_user': DemoUserSeeder.new,"));
        expect(
          registry,
          contains("import '/app/seeders/demo_user_seeder.dart';"),
        );
        expect(
          File(
            '${project.path}/lib/app/providers/app_provider.dart',
          ).readAsStringSync(),
          contains('seeders: seeders'),
        );
        // Metro's own "[Seeder] demo_user_seeder created" line goes to the
        // console; the block only carries what needs attention.
        final String printed = live.printed.toString();
        expect(printed, contains('! The snapshot includes SK_BEARER_TOKEN.'));
        expect(printed, contains('now passes seeders to Nylo'));
        expect(printed, isNot(contains('created')));
        expect(printed, isNot(contains('registered in')));
        expect(
          printed,
          contains('Load it with restart, then run it with seed demo_user'),
        );

        // Exporting again keeps the shell open and asks for --force.
        expect(
          await runLiveShellCommand('export', ['demo_user'], live.runner),
          1,
        );
        expect(
          live.printed.toString(),
          contains(
            'lib/app/seeders/demo_user_seeder.dart already exists. '
            'Pass --force to replace it.',
          ),
        );
        expect(
          await runLiveShellCommand('export', [
            'demo_user',
            '--force',
          ], live.runner),
          0,
        );
        expect(
          seeder.readAsStringSync(),
          contains("description => 'Storage from iPhone 17e, "),
        );
      } finally {
        Directory.current = previous;
      }
    });

    test('export writes a JSON file with --to', () async {
      final Directory project = tempProject('nylo_live_export_json_');
      final String path = '${project.path}/snapshots/pro_user.json';
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {'storage.export': (args) async => exportPayload()},
      );
      final live = await sessionFor({'iPhone 17e': phone});

      final int? code = await runLiveShellCommand('export', [
        '--to',
        path,
      ], live.runner);

      expect(code, 0);
      final LiveSnapshot written = LiveSnapshot.decode(
        File(path).readAsStringSync(),
      );
      expect(written.storage, exportPayload()['storage']);
      expect(written.backpack, {'SK_USER': null});
      expect(written.device, 'iPhone 17e');
      expect(written.app, 'Nylo');
      expect(written.exportedAt, DateTime.utc(2026, 9, 15, 19, 41, 9));
      final String printed = live.printed.toString();
      expect(
        printed,
        contains('✓ Wrote $path (3 storage values, 1 Backpack value)'),
      );
      expect(printed, contains('· Load it into an app with seed $path'));

      expect(
        await runLiveShellCommand('export', ['--to', path], live.runner),
        1,
      );
      expect(
        live.printed.toString(),
        contains('$path already exists. Pass --force to replace it.'),
      );
    });

    test('seed finds a snapshot by a bare name', () async {
      final Directory project = tempProject('nylo_live_import_bare_');
      File('${project.path}/snapshots/tone.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"nylo": 1, "storage": {"Pro": true}}');
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {'snapshot.import': snapshotImport},
      );
      final live = await sessionFor({'Pixel 9': phone}, root: project.path);

      expect(await runLiveShellCommand('seed', ['tone'], live.runner), 0);

      expect(phone.calls['snapshot.import']!.single, {
        'name': 'tone',
        'snapshot': {
          'storage': {'Pro': true},
          'backpack': <String, Object?>{},
        },
        'source': 'tone.json',
      });
    });

    test('a registered seeder wins over a file of the same name', () async {
      final Directory project = tempProject('nylo_live_seed_wins_');
      File('${project.path}/snapshots/tone.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"nylo": 1, "storage": {"Pro": true}}');
      File('${project.path}/lib/bootstrap/seeders.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'final Map<String, Seeder Function()> seeders = kReleaseMode\n'
          '    ? const {}\n'
          '    : {\n'
          "        'tone': ToneSeeder.new,\n"
          '      };\n',
        );
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {'seeders.run': runSeeders},
      );
      final live = await sessionFor({'Pixel 9': phone}, root: project.path);

      expect(await runLiveShellCommand('seed', ['tone'], live.runner), 0);

      expect(phone.calls['seeders.run']!.single, {
        'names': ['tone'],
        'direction': 'up',
      });
      expect(phone.calls['snapshot.import'], isNull);
    });

    test('a name that is neither is sent on as a seeder name', () async {
      final Directory project = tempProject('nylo_live_seed_unknown_');
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {'seeders.run': runSeeders},
      );
      final live = await sessionFor({'Pixel 9': phone}, root: project.path);

      // The app owns the list of seeders, so it explains an unknown name.
      expect(await runLiveShellCommand('seed', ['nope'], live.runner), 0);
      expect(phone.calls['seeders.run']!.single['names'], ['nope']);
    });

    test('seed sends a snapshot file as a named, recorded run', () async {
      final Directory project = tempProject('nylo_live_import_');
      final File file = File('${project.path}/pro_user.json')
        ..writeAsStringSync(
          '{"nylo": 1, "device": "iPhone 17e", '
          '"storage": {"Pro": true}, "backpack": {"cart": [1]}}',
        );
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {'snapshot.import': snapshotImport},
      );
      final live = await sessionFor({'Pixel 9': phone});

      final int? code = await runLiveShellCommand('seed', [
        file.path,
      ], live.runner);

      expect(code, 0);
      expect(phone.calls['snapshot.import']!.single, {
        'name': 'pro_user',
        'snapshot': {
          'storage': {'Pro': true},
          'backpack': {
            'cart': [1],
          },
        },
        'source': 'pro_user.json',
      });
      final String printed = live.printed.toString();
      expect(printed, contains('Loading pro_user'));
      expect(printed, contains(RegExp(r'\+ storage +Pro +added')));
      expect(printed, contains('✓ Imported 1 value'));
      expect(printed, contains('✓ Loaded pro_user in 11ms'));
      expect(printed, contains('· Undo with seed:rollback pro_user'));

      expect(
        await runLiveShellCommand('seed', [
          '--as',
          'clean slate',
          '--fresh',
          file.path,
        ], live.runner),
        0,
      );
      expect(phone.calls['snapshot.import']!.last, {
        'name': 'clean_slate',
        'snapshot': {
          'storage': {'Pro': true},
          'backpack': {
            'cart': [1],
          },
        },
        'source': 'pro_user.json',
        'fresh': true,
      });
    });

    test('seed accepts inline JSON and explains bad files', () async {
      final Directory project = tempProject('nylo_live_import_bad_');
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {'snapshot.import': snapshotImport},
      );
      final live = await sessionFor({'Pixel 9': phone});

      expect(
        await runLiveShellCommand('seed', [
          '{"storage": {"Pro": true}}',
        ], live.runner),
        0,
      );
      expect(phone.calls['snapshot.import']!.single, {
        'name': 'snapshot',
        'snapshot': {
          'storage': {'Pro': true},
          'backpack': {},
        },
      });

      // A .json that isn't there names a file, not a seeder.
      expect(await runLiveShellCommand('seed', ['nope.json'], live.runner), 64);
      expect(
        live.printed.toString(),
        contains(
          'Couldn\'t find a snapshot file called "nope.json". Write '
          'one with export --to nope.json',
        ),
      );

      expect(await runLiveShellCommand('seed', ['--as', 'x'], live.runner), 64);
      expect(live.printed.toString(), contains('Name the seeders to run'));

      final File bad = File('${project.path}/bad.json')
        ..writeAsStringSync('not json');
      expect(await runLiveShellCommand('seed', [bad.path], live.runner), 64);
      expect(live.printed.toString(), contains('bad.json isn\'t valid JSON'));

      final File empty = File('${project.path}/empty.json')
        ..writeAsStringSync('{"storage": {}, "backpack": {}}');
      expect(await runLiveShellCommand('seed', [empty.path], live.runner), 64);
      expect(
        live.printed.toString(),
        contains('empty.json holds no storage or Backpack values.'),
      );
      expect(phone.calls['snapshot.import'], hasLength(1));
    });

    test('export and snapshots need an app that knows them', () async {
      final FakeNyloApp phone = await app(
        status: {'protocol': 1, 'route': '/home', 'seeders': []},
        commands: {'storage.export': (args) async => exportPayload()},
      );
      final live = await sessionFor({'iPhone 17e': phone});

      expect(await runLiveShellCommand('export', const [], live.runner), 1);
      expect(
        live.printed.toString(),
        contains('doesn\'t support storage snapshots yet'),
      );
      expect(
        await runLiveShellCommand('seed', [
          '{"storage": {"Pro": true}}',
        ], live.runner),
        1,
      );
      expect(phone.calls['storage.export'], isNull);
    });

    test('seed lists imports with where they came from', () async {
      final FakeNyloApp phone = await app(
        status: snapshotStatus,
        commands: {
          'seeders.list': (args) async => {
            'seeders': [
              {
                'name': 'demo_user',
                'description': 'Onboarded Pro user',
                'seededAt': null,
                'registered': true,
              },
              {
                'name': 'pro_user',
                'description': null,
                'seededAt': DateTime.now().toUtc().toIso8601String(),
                'registered': false,
                'source': 'pro_user.json',
              },
            ],
          },
        },
      );
      final live = await sessionFor({'Pixel 9': phone});

      expect(await runLiveShellCommand('seed', const [], live.runner), 0);
      expect(
        live.printed.toString(),
        contains(RegExp(r'pro_user +\(imported from pro_user\.json\) +seeded')),
      );
      expect(
        live.printed.toString(),
        contains(RegExp(r'demo_user +Onboarded Pro user +not seeded')),
      );
    });

    test('lists export and seed with their options for Tab', () {
      final List<LiveShellCommand> commands = liveShellCommands;
      List<String> optionsOf(String name) =>
          commands.firstWhere((command) => command.name == name).options;

      expect(
        commands.map((command) => command.name),
        containsAllInOrder(['seed:rollback', 'export', 'reload']),
      );
      expect(
        optionsOf('export'),
        containsAll([
          '--to',
          '--description',
          '--only',
          '--except',
          '--backpack',
          '--force',
        ]),
      );
      expect(optionsOf('seed'), containsAll(['--as', '--fresh', '--restart']));
    });
  });

  group('LiveShell', () {
    Future<({LiveShell shell, StringBuffer output, List<String> dispatched})>
    shellFor(
      Map<String, FakeNyloApp> devices, {
      required Stream<List<int>> input,
      bool terminal = false,
      LiveOptions options = const LiveOptions(),
      Future<int?> Function(String name, List<String> args)? handler,
      String? root,
    }) async {
      final live = await sessionFor(devices, root: root);
      final List<String> dispatched = [];
      final LiveShell shell = LiveShell(
        runner: live.runner,
        session: live.session,
        commands: liveShellCommands,
        options: options,
        dispatch: (name, args, runner) async {
          dispatched.add([name, ...args].join(' '));
          return handler == null ? 0 : handler(name, args);
        },
        input: input,
        output: live.printed,
        terminal: FakeTerminal(hasTerminal: terminal),
      );
      return (shell: shell, output: live.printed, dispatched: dispatched);
    }

    Stream<List<int>> lines(String text) =>
        Stream<List<int>>.fromIterable([utf8.encode(text)]);

    test('runs a piped script line by line', () async {
      final shell = await shellFor(
        {'iPhone 17 Pro': await app()},
        input: lines(
          '# Put the simulator into the demo state\n'
          '\n'
          'seed demo --fresh\n'
          'route /home --data \'{"tab": "orders"}\'\n',
        ),
      );

      expect(await shell.shell.start(), 0);
      expect(shell.dispatched, [
        'seed demo --fresh',
        'route /home --data {"tab": "orders"}',
      ]);
      expect(shell.output.toString(), contains('› seed demo --fresh'));
    });

    test('stops a script at the first failure with its exit code', () async {
      final shell = await shellFor(
        {'iPhone 17 Pro': await app()},
        input: lines('status\nseed broken\nroute /never\n'),
        handler: (name, args) async => name == 'seed' ? 1 : 0,
      );

      expect(await shell.shell.start(), 1);
      expect(shell.dispatched, ['status', 'seed broken']);
    });

    test('reports unknown commands and unclosed quotes', () async {
      final unknown = await shellFor(
        {'iPhone 17 Pro': await app()},
        input: lines('dance\n'),
        handler: (name, args) async => null,
      );
      expect(await unknown.shell.start(), 64);
      expect(
        unknown.output.toString(),
        contains('There\'s no command named "dance"'),
      );

      final quote = await shellFor({
        'iPhone 17 Pro': await app(),
      }, input: lines('toast "unfinished\n'));
      expect(await quote.shell.start(), 64);
      expect(quote.output.toString(), contains('Missing a closing "'));
    });

    test('use and exit are handled by the shell itself', () async {
      final shell = await shellFor({
        'iPhone 17 Pro': await app(),
        'Pixel 9': await app(),
      }, input: lines('use 2\nstatus\nexit\nstatus\n'));

      expect(await shell.shell.start(), 0);
      expect(shell.dispatched, ['status']);
      expect(shell.output.toString(), contains('Commands now run on Pixel 9'));
    });

    test(
      'shows the device and page in the prompt, and completes with Tab',
      () async {
        final StreamController<List<int>> input = StreamController<List<int>>();
        final shell = await shellFor(
          {
            'iPhone 17 Pro': await app(
              commands: {
                'routes': (args) async => {
                  'routes': ['/home', '/profile', '/products'],
                },
              },
            ),
          },
          input: input.stream,
          terminal: true,
        );

        final Future<int> running = shell.shell.start();
        await eventually(
          () => shell.output.toString().contains('iPhone 17 Pro /home › '),
        );
        // "rou" matches route and routes, so Tab stops at the shared prefix.
        input.add(utf8.encode('rou\t'));
        await settle();
        input.add(utf8.encode(' /prof\t'));
        await settle();
        input.add(utf8.encode('\r'));
        await eventually(() => shell.dispatched.isNotEmpty);
        input.add(utf8.encode('exit\r'));

        expect(await running, 0);
        expect(shell.dispatched, ['route /profile']);
        expect(shell.output.toString(), contains('Connected to iPhone 17 Pro'));
      },
    );

    test('completes the Backpack keys after backpack', () async {
      final StreamController<List<int>> input = StreamController<List<int>>();
      final shell = await shellFor(
        {
          'iPhone 17 Pro': await app(
            commands: {
              'backpack.list': (args) async => {
                'items': [
                  {'key': 'auth_user'},
                  {'key': 'translate_page_translate_from'},
                ],
              },
            },
          ),
        },
        input: input.stream,
        terminal: true,
      );

      final Future<int> running = shell.shell.start();
      await eventually(
        () => shell.output.toString().contains('iPhone 17 Pro /home › '),
      );
      input.add(utf8.encode('backpack trans\t'));
      await settle();
      input.add(utf8.encode('\r'));
      await eventually(() => shell.dispatched.isNotEmpty);
      input.add(utf8.encode('exit\r'));

      expect(await running, 0);
      expect(shell.dispatched, ['backpack translate_page_translate_from']);
    });

    test('completes the states on screen after data', () async {
      final StreamController<List<int>> input = StreamController<List<int>>();
      final shell = await shellFor(
        {
          'iPhone 17 Pro': await app(
            commands: {
              'state.data': (args) async => {
                'states': [
                  {'widget': 'ConversationDetailPage'},
                  {'widget': 'MessageListWidget'},
                ],
              },
            },
          ),
        },
        input: input.stream,
        terminal: true,
      );

      final Future<int> running = shell.shell.start();
      await eventually(
        () => shell.output.toString().contains('iPhone 17 Pro /home › '),
      );
      input.add(utf8.encode('data Mess\t'));
      await settle();
      input.add(utf8.encode('\r'));
      await eventually(() => shell.dispatched.isNotEmpty);
      input.add(utf8.encode('exit\r'));

      expect(await running, 0);
      expect(shell.dispatched, ['data MessageListWidget']);
    });

    test('completes seeders and snapshot files after seed', () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'nylo_live_complete_',
      );
      cleanup.add(() async => project.deleteSync(recursive: true));
      File('${project.path}/snapshots/pro_user.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      File('${project.path}/snapshots/notes.txt').writeAsStringSync('');
      File('${project.path}/README.md').writeAsStringSync('');
      final StreamController<List<int>> input = StreamController<List<int>>();
      final shell = await shellFor(
        {'iPhone 17 Pro': await app()},
        input: input.stream,
        terminal: true,
        root: project.path,
      );

      final Future<int> running = shell.shell.start();
      await eventually(
        () => shell.output.toString().contains('iPhone 17 Pro /home › '),
      );
      input.add(utf8.encode('seed snap\t'));
      await settle();
      input.add(utf8.encode('pro\t'));
      await settle();
      input.add(utf8.encode('\r'));
      await eventually(() => shell.dispatched.isNotEmpty);
      input.add(utf8.encode('exit\r'));

      expect(await running, 0);
      expect(shell.dispatched, ['seed snapshots/pro_user.json']);
    });

    test('asks which app to use when several are running', () async {
      final StreamController<List<int>> input = StreamController<List<int>>();
      final shell = await shellFor(
        {'iPhone 17 Pro': await app(), 'Pixel 9': await app()},
        input: input.stream,
        terminal: true,
      );

      final Future<int> running = shell.shell.start();
      await eventually(() => shell.output.toString().contains('Which one?'));
      input.add(utf8.encode('2\r'));
      await eventually(
        () => shell.output.toString().contains('Pixel 9 /home › '),
      );
      input.add(utf8.encode('\x04'));

      expect(await running, 0);
      expect(shell.output.toString(), contains('2 apps are running:'));
    });
  });

  group('splitLiveShellLine', () {
    test('splits on spaces and keeps quoted text together', () {
      expect(splitLiveShellLine('  route /profile  --data \'{"id": 7}\' '), [
        'route',
        '/profile',
        '--data',
        '{"id": 7}',
      ]);
      expect(splitLiveShellLine('toast "It\'s done" --title \\"Hi\\"'), [
        'toast',
        'It\'s done',
        '--title',
        '"Hi"',
      ]);
      expect(splitLiveShellLine('use iPhone\\ 17\\ Pro'), [
        'use',
        'iPhone 17 Pro',
      ]);
      expect(splitLiveShellLine('storage:set empty ""'), [
        'storage:set',
        'empty',
        '',
      ]);
    });

    test('ignores comments and rejects unclosed quotes', () {
      expect(splitLiveShellLine('status # where am I?'), ['status']);
      expect(splitLiveShellLine('toast #1'), ['toast']);
      expect(splitLiveShellLine('toast a#1'), ['toast', 'a#1']);
      expect(() => splitLiveShellLine('toast "oops'), throwsFormatException);
    });
  });

  group('splitForCompletion', () {
    test('separates finished words from the word being typed', () {
      void expectSplit(String line, List<String> words, String current) {
        final ({List<String> words, String current}) split = splitForCompletion(
          line,
        );
        expect(split.words, words, reason: line);
        expect(split.current, current, reason: line);
      }

      expectSplit('rou', [], 'rou');
      expectSplit('route /pro', ['route'], '/pro');
      expectSplit('seed ', ['seed'], '');
      expectSplit('toast "a b', ['toast'], '"a b');
    });
  });
}
