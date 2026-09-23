import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/commands/live/live_commands.dart';
import 'package:nylo_framework/metro/live/live_app.dart';
import 'package:nylo_framework/metro/live/live_discovery.dart';
import 'package:nylo_framework/metro/live/live_options.dart';
import 'package:nylo_framework/metro/live/live_output.dart';
import 'package:nylo_framework/metro/live/live_runner.dart';

import 'fake_servers.dart';

void main() {
  final List<Future<void> Function()> cleanup = [];
  late StringBuffer printed;

  tearDown(() async {
    for (final Future<void> Function() close in cleanup.reversed) {
      await close();
    }
    cleanup.clear();
  });

  Future<FakeNyloApp> app({
    Map<String, Future<Object?> Function(Map<String, Object?> args)> commands =
        const {},
  }) async {
    final FakeNyloApp fake = await FakeNyloApp.start(commands: commands);
    cleanup.add(fake.close);
    return fake;
  }

  /// A runner whose discovery finds [devices] (device name → fake app), for
  /// the project at [root].
  Future<LiveRunner> runnerFor(
    Map<String, FakeNyloApp> devices, {
    String? root,
  }) async {
    final FakeJsonRpcServer dtd = await startFakeDaemon([
      for (final MapEntry<String, FakeNyloApp> entry in devices.entries)
        (
          uri: entry.value.wsUri,
          name: 'Kind: Flutter - Device: ${entry.key} - Package: shop',
        ),
    ]);
    cleanup.add(dtd.close);
    printed = StringBuffer();
    return LiveRunner(
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
  }

  Future<Object?> seeded(LiveApp app, LiveBlock block) async {
    final Object? result = await app.call('cart.seed', {'count': 2});
    block.success('Seeded 2 cart items');
    return result;
  }

  group('LiveRunner.run', () {
    test('runs on the only app and prints without a prefix', () async {
      final FakeNyloApp phone = await app(
        commands: {
          'cart.seed': (args) async => {'seeded': args['count']},
        },
      );
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      final int code = await runner.run(const LiveOptions(), seeded);

      expect(code, 0);
      expect(printed.toString(), '✓ Seeded 2 cart items\n');
      expect(phone.calls['cart.seed'], [
        {'count': 2},
      ]);
    });

    test('--all runs everywhere with [device] prefixes', () async {
      final LiveRunner runner = await runnerFor({
        'iPhone 17e': await app(
          commands: {
            'cart.seed': (args) async => {'seeded': 2},
          },
        ),
        'iPhone 17 Pro': await app(
          commands: {
            'cart.seed': (args) async => {'seeded': 2},
          },
        ),
      });

      final int code = await runner.run(const LiveOptions(all: true), seeded);

      expect(code, 0);
      expect(
        printed.toString(),
        '[iPhone 17 Pro]  ✓ Seeded 2 cart items\n'
        '[iPhone 17e]     ✓ Seeded 2 cart items\n',
      );
    });

    test('several apps and no target exits 2 and lists them', () async {
      final FakeNyloApp a = await app();
      final FakeNyloApp b = await app();
      final LiveRunner runner = await runnerFor({
        'iPhone 17e': a,
        'Pixel 9': b,
      });

      final int code = await runner.run(const LiveOptions(), seeded);

      expect(code, 2);
      expect(printed.toString(), contains('2 apps are running'));
      expect(printed.toString(), contains('  1  iPhone 17e'));
      expect(printed.toString(), contains('  2  Pixel 9'));
      expect(a.calls['cart.seed'], isNull);
      expect(b.calls['cart.seed'], isNull);
    });

    test('-d runs only on the matching app', () async {
      final FakeNyloApp phone = await app(
        commands: {
          'cart.seed': (args) async => {'seeded': 2},
        },
      );
      final FakeNyloApp tablet = await app(
        commands: {
          'cart.seed': (args) async => {'seeded': 2},
        },
      );
      final LiveRunner runner = await runnerFor({
        'iPhone 17e': phone,
        'iPad Pro': tablet,
      });

      final int code = await runner.run(
        const LiveOptions(device: '17e'),
        seeded,
      );

      expect(code, 0);
      expect(phone.calls.keys, contains('cart.seed'));
      expect(tablet.calls.keys, isNot(contains('cart.seed')));
    });

    test('a failing app makes the exit code 1 and shows the details', () async {
      final LiveRunner runner = await runnerFor({
        'iPhone 17e': await app(
          commands: {
            'cart.seed': (args) async => throw FakeRpcError(
              -32000,
              'Server error',
              {'details': 'cart.seed is only available in debug builds'},
            ),
          },
        ),
      });

      final int code = await runner.run(const LiveOptions(), seeded);

      expect(code, 1);
      expect(
        printed.toString(),
        '✗ cart.seed is only available in debug builds\n',
      );
    });

    test('--json prints one document with every outcome', () async {
      final LiveRunner runner = await runnerFor({
        'iPhone 17e': await app(
          commands: {
            'cart.seed': (args) async => {'seeded': 2},
          },
        ),
      });

      final int code = await runner.run(const LiveOptions(json: true), seeded);
      final List<dynamic> document = jsonDecode(printed.toString());

      expect(code, 0);
      expect(document.single['device'], 'iPhone 17e');
      expect(document.single['ok'], isTrue);
      expect(document.single['result'], {'seeded': 2});
    });

    test('--uri connects straight to the app', () async {
      final FakeNyloApp phone = await app(
        commands: {
          'cart.seed': (args) async => {'seeded': 2},
        },
      );
      printed = StringBuffer();
      final LiveRunner runner = LiveRunner(
        output: LivePrinter(sink: printed, ansi: false),
        project: LiveProject(Directory.systemTemp.path, 'shop'),
        discovery: (project, timeout) => throw StateError('no discovery'),
      );

      final int code = await runner.run(
        LiveOptions(uri: 'http://127.0.0.1:${phone.wsUri.port}/secret=/'),
        seeded,
      );

      expect(code, 0);
      expect(phone.calls.keys, contains('cart.seed'));
    });

    test('no running app exits 1 with a hint', () async {
      final LiveRunner runner = await runnerFor({});

      final int code = await runner.run(const LiveOptions(), seeded);

      expect(code, 1);
      expect(printed.toString(), contains('No running shop app found'));
    });
  });

  group('runLiveCustomCommand', () {
    Map<String, Future<Object?> Function(Map<String, Object?>)> seedCommand({
      bool failed = false,
    }) => {
      'commands.list': (args) async => {
        'commands': [
          {
            'name': 'cart:seed',
            'description': 'Fill the cart',
            'options': [
              {
                'kind': 'option',
                'name': 'count',
                'abbr': 'c',
                'defaultValue': '3',
              },
              {'kind': 'flag', 'name': 'open', 'defaultValue': false},
            ],
          },
        ],
      },
      'commands.run': (args) async => {
        'name': args['name'],
        'output': [
          {'level': 'info', 'message': 'Seeding…'},
          if (failed)
            {'level': 'error', 'message': 'The cart API is down'}
          else
            {
              'level': 'success',
              'message': 'Seeded ${(args['args'] as Map)['count']} items',
            },
        ],
        'result': failed ? null : {'count': (args['args'] as Map)['count']},
        'failed': failed,
      },
    };

    test('parses arguments against the app schema and runs it', () async {
      final FakeNyloApp phone = await app(commands: seedCommand());
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      final int code = await runLiveCustomCommand('cart:seed', [
        '-c',
        '5',
        '--open',
        'extra',
      ], runner: runner);

      expect(code, 0);
      expect(phone.calls['commands.run']!.single, {
        'name': 'cart:seed',
        'args': {'count': '5', 'open': true},
        'rest': ['extra'],
      });
      expect(printed.toString(), contains('Seeding…\n✓ Seeded 5 items\n'));
      expect(printed.toString(), contains('"count": "5"'));
    });

    test('shared flags can sit among the command arguments', () async {
      final FakeNyloApp phone = await app(commands: seedCommand());
      final FakeNyloApp tablet = await app(commands: seedCommand());
      final LiveRunner runner = await runnerFor({
        'iPhone 17e': phone,
        'iPad Pro': tablet,
      });

      final int code = await runLiveCustomCommand('cart:seed', [
        '--count',
        '2',
        '--all',
      ], runner: runner);

      expect(code, 0);
      expect(phone.calls['commands.run'], hasLength(1));
      expect(tablet.calls['commands.run'], hasLength(1));
    });

    test(
      'a command that reports failure exits 1 without a duplicate error',
      () async {
        final LiveRunner runner = await runnerFor({
          'iPhone 17e': await app(commands: seedCommand(failed: true)),
        });

        final int code = await runLiveCustomCommand(
          'cart:seed',
          [],
          runner: runner,
        );

        expect(code, 1);
        expect(
          '✗ The cart API is down'.allMatches(printed.toString()),
          hasLength(1),
        );
      },
    );

    test('an unknown option fails with the command usage', () async {
      final FakeNyloApp phone = await app(commands: seedCommand());
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      final int code = await runLiveCustomCommand('cart:seed', [
        '--colour',
        'red',
      ], runner: runner);

      expect(code, 1);
      expect(printed.toString(), contains('Usage: metro cart:seed'));
      expect(phone.calls['commands.run'], isNull);
    });

    test(
      'a command missing from the build explains how to register it',
      () async {
        final LiveRunner runner = await runnerFor({
          'iPhone 17e': await app(commands: seedCommand()),
        });

        final int code = await runLiveCustomCommand(
          'user:login_as',
          [],
          runner: runner,
        );

        expect(code, 1);
        expect(printed.toString(), contains('isn\'t in this build yet'));
        expect(
          printed.toString(),
          contains('lib/bootstrap/live_commands.dart'),
        );
      },
    );

    test(
      'a registered command the app hasn\'t loaded says to hot restart',
      () async {
        final Directory project = Directory.systemTemp.createTempSync(
          'nylo_live_project_',
        );
        addTearDown(() => project.deleteSync(recursive: true));
        File('${project.path}/lib/bootstrap/live_commands.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync(
            "final Map<String, LiveCommand Function()> liveCommands = {\n"
            "  'user:login_as': () => LoginAsCommand(),\n"
            "};\n",
          );
        final LiveRunner runner = await runnerFor({
          'iPhone 17e': await app(commands: seedCommand()),
        }, root: project.path);

        final int code = await runLiveCustomCommand(
          'user:login_as',
          [],
          runner: runner,
        );

        expect(code, 1);
        expect(
          printed.toString(),
          '✗ "user:login_as" isn\'t loaded in the running app yet. '
          'Load it with a hot restart.\n',
        );
      },
    );

    test('--help prints the usage from the app without running it', () async {
      final FakeNyloApp phone = await app(commands: seedCommand());
      final FakeNyloApp tablet = await app(commands: seedCommand());
      final LiveRunner runner = await runnerFor({
        'iPhone 17e': phone,
        'iPad Pro': tablet,
      });

      final int code = await runLiveCustomCommand('cart:seed', [
        '--help',
      ], runner: runner);

      expect(code, 0);
      expect(printed.toString(), contains('Usage: metro cart:seed [options]'));
      expect(printed.toString(), contains('--count'));
      expect(phone.calls['commands.run'], isNull);
      expect(tablet.calls['commands.run'], isNull);
    });

    test('a bad shared flag exits 64', () async {
      final LiveRunner runner = await runnerFor({});

      final int code = await runLiveCustomCommand('cart:seed', [
        '--timeout',
        'soon',
      ], runner: runner);

      expect(code, 64);
    });
  });

  group('renderRunResult', () {
    test('maps output levels and prints unknown levels as plain text', () {
      final LiveBlock block = LiveBlock();

      renderRunResult(block, {
        'output': [
          {'level': 'line', 'message': 'plain'},
          {'level': 'warning', 'message': 'careful'},
          {'level': 'shiny', 'message': 'unknown'},
        ],
        'result': null,
      });

      expect(block.lines.map((line) => line.$2), [
        'plain',
        '! careful',
        'unknown',
      ]);
    });

    test('says Done when the command printed nothing', () {
      final LiveBlock block = LiveBlock();

      renderRunResult(block, {'output': [], 'result': null});

      expect(block.lines.single.$2, '✓ Done');
    });
  });

  group('seed renderers', () {
    String render(void Function(LiveBlock block) draw) {
      final LiveBlock block = LiveBlock();
      draw(block);
      return block.lines.map((line) => line.$2).join('\n');
    }

    test('renderSeedRuns aligns changes and shows messages in order', () {
      final LiveBlock block = LiveBlock();
      final String? failure = renderSeedRuns(block, {
        'runs': [
          {
            'name': 'demo_user',
            'direction': 'up',
            'ms': 84,
            'failed': false,
            'log': [
              {
                'level': 'change',
                'store': 'backpack',
                'key': 'SK_USER',
                'change': 'added',
              },
              {
                'level': 'change',
                'store': 'storage',
                'key': 'preferred_language',
                'change': 'changed',
              },
              {'level': 'success', 'message': 'Signed in as Jane Doe'},
            ],
          },
        ],
        'failed': false,
      });

      expect(failure, isNull);
      expect(block.lines.map((line) => line.$2), [
        'Seeding demo_user',
        '  + backpack  SK_USER             added',
        '  ~ storage   preferred_language  changed',
        '  ✓ Signed in as Jane Doe',
        '✓ Seeded demo_user in 84ms',
        '· Undo with seed:rollback demo_user',
      ]);
      expect(block.lines[1].$1, LiveTone.success);
      expect(block.lines[2].$1, LiveTone.warning);
    });

    test('renderSeedRuns shows rollbacks and failures', () {
      final LiveBlock block = LiveBlock();
      final String? failure = renderSeedRuns(block, {
        'runs': [
          {
            'name': 'demo_user',
            'direction': 'down',
            'ms': 31,
            'failed': false,
            'log': [
              {
                'level': 'change',
                'store': 'storage',
                'key': 'preferred_language',
                'change': 'restored',
              },
              {
                'level': 'change',
                'store': 'storage',
                'key': 'SK_USER',
                'change': 'removed',
              },
            ],
          },
          {
            'name': 'broken',
            'direction': 'up',
            'ms': 5,
            'failed': true,
            'error': 'Bad state: API unavailable',
            'log': [
              {'level': 'error', 'message': 'Bad state: API unavailable'},
              {
                'level': 'info',
                'message': 'Put back the change made before the error',
              },
            ],
          },
        ],
        'failed': true,
      });

      expect(failure, 'broken failed: Bad state: API unavailable');
      final String text = block.lines.map((line) => line.$2).join('\n');
      expect(
        text,
        contains(
          'Rolling back demo_user\n'
          '  ~ storage  preferred_language  put back\n'
          '  - storage  SK_USER             removed\n'
          '✓ Rolled back demo_user in 31ms',
        ),
      );
      expect(text, contains('  ✗ Bad state: API unavailable'));
      expect(text, contains('✗ broken failed'));
      expect(text, isNot(contains('Undo with')));
    });

    test('renderSeederList shows each seeder and when it ran', () {
      final String today = DateTime.now().toUtc().toIso8601String();
      final String text = render(
        (block) => renderSeederList(block, 'iPhone 17 Pro', {
          'seeders': [
            {
              'name': 'demo_user',
              'description': 'Jane Doe, signed in',
              'seededAt': today,
              'registered': true,
            },
            {'name': 'favourites', 'description': null, 'registered': true},
            {'name': 'old_seeder', 'registered': false, 'seededAt': today},
          ],
        }),
      );

      expect(text, startsWith('Seeders on iPhone 17 Pro:'));
      expect(text, contains('NAME'));
      expect(
        text,
        matches(RegExp(r'demo_user\s+Jane Doe, signed in\s+seeded \d\d:\d\d')),
      );
      expect(text, matches(RegExp(r'favourites\s+not seeded')));
      expect(text, contains('(no longer registered)'));
      expect(
        render((block) => renderSeederList(block, 'Pixel 9', {'seeders': []})),
        contains('metro make:seeder demo_user'),
      );
    });

    test('renderSeederList says to hot restart for seeders not loaded yet', () {
      expect(
        render(
          (block) => renderSeederList(
            block,
            'Pixel 9',
            {'seeders': []},
            registered: ['demo_user'],
          ),
        ),
        '! demo_user isn\'t loaded in the running app yet. '
        'Load it with restart.',
      );

      final String text = render(
        (block) => renderSeederList(
          block,
          'Pixel 9',
          {
            'seeders': [
              {'name': 'favourites', 'registered': true},
              {'name': 'demo_user', 'registered': false},
            ],
          },
          registered: ['favourites', 'demo_user', 'orders'],
          restart: 'restart',
        ),
      );
      expect(text, contains('(no longer registered)'));
      expect(
        text,
        endsWith(
          '! demo_user, orders aren\'t loaded in the running app yet. '
          'Load them with restart.',
        ),
      );
    });

    test(
      'describeSeededAt shows the time, and the day when it isn\'t today',
      () {
        final DateTime now = DateTime(2026, 9, 14, 18);
        expect(describeSeededAt(null), 'not seeded');
        expect(
          describeSeededAt(
            DateTime(2026, 9, 14, 10, 42).toIso8601String(),
            now: now,
          ),
          'seeded 10:42',
        );
        expect(
          describeSeededAt(
            DateTime(2026, 9, 12, 9, 5).toIso8601String(),
            now: now,
          ),
          'seeded 12 Sep 09:05',
        );
      },
    );

    test('renderStatus lists seeders only when the app reports them', () {
      final String withSeeders = render(
        (block) => renderStatus(block, 'iPhone 17 Pro', {
          'seeders': ['demo_user', 'favourites'],
        }),
      );
      final String older = render(
        (block) => renderStatus(block, 'iPhone 17 Pro', {'app': 'Nylo'}),
      );

      expect(withSeeders, contains(RegExp(r'Seeders\s+demo_user, favourites')));
      expect(older, isNot(contains('Seeders')));
    });
  });

  group('render helpers', () {
    test('renderStatus shows the app summary', () {
      final LiveBlock block = LiveBlock();

      renderStatus(block, 'iPhone 17e', {
        'app': 'Nylo',
        'env': 'developing',
        'mode': 'debug',
        'platform': 'ios',
        'osVersion': 'Version 26.4',
        'route': '/profile',
        'stack': ['/home', '/profile'],
        'locale': 'en',
        'theme': 'light_theme',
        'authenticated': null,
        'commands': ['cart:seed'],
      });
      final String text = block.lines.map((line) => line.$2).join('\n');

      expect(text, contains('Nylo (developing)'));
      expect(text, contains('iPhone 17e · ios · Version 26.4'));
      expect(text, contains('/home → /profile'));
      expect(text, contains('not configured'));
      expect(text, contains('cart:seed'));
    });

    test('renderItems sorts keys and adds EXPIRES only when needed', () {
      final LiveBlock plain = LiveBlock();
      renderItems(plain, [
        {'key': 'b', 'type': 'int', 'value': 1},
        {
          'key': 'a',
          'type': 'json',
          'value': {'id': 42},
        },
      ], empty: 'Storage is empty');

      expect(plain.lines.map((line) => line.$2), [
        'KEY  TYPE  VALUE',
        'a    json  {"id":42}',
        'b    int   1',
      ]);

      final LiveBlock expiring = LiveBlock();
      renderItems(expiring, [
        {
          'key': 'otp',
          'type': 'string',
          'value': '1234',
          'expiresAt': '2026-09-13T10:00:00Z',
        },
      ], empty: 'Storage is empty');
      expect(expiring.lines.first.$2, contains('EXPIRES'));

      final LiveBlock empty = LiveBlock();
      renderItems(empty, [], empty: 'Storage is empty');
      expect(empty.lines.single.$2, '· Storage is empty');
    });

    test('renderRouteChange covers moves, redirects and guards', () {
      final LiveBlock moved = LiveBlock();
      renderRouteChange(moved, '/profile', {
        'from': '/home',
        'current': '/profile',
        'changed': true,
      });
      expect(moved.lines.single.$2, '✓ /home → /profile');

      final LiveBlock redirected = LiveBlock();
      renderRouteChange(redirected, '/orders', {
        'from': '/home',
        'current': '/login',
        'changed': true,
      });
      expect(
        redirected.lines.single.$2,
        '✓ /home → /login (redirected from /orders)',
      );

      final LiveBlock guarded = LiveBlock();
      renderRouteChange(guarded, '/admin', {
        'from': '/home',
        'current': '/home',
        'changed': false,
      });
      expect(guarded.lines.single.$2, contains('Stayed on /home'));
      expect(guarded.lines.single.$2, contains('route guard'));
    });
  });
}
