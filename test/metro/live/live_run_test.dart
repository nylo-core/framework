import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/commands/built_in_commands.dart';
import 'package:nylo_framework/metro/commands/live/live_commands.dart';
import 'package:nylo_framework/metro/live/live_manifest.dart';
import 'package:nylo_framework/metro/live/live_runner.dart';

void main() {
  group('live commands', () {
    test('keeps the top level small', () {
      expect(builtInCommands.keys.where((name) => name.startsWith('live:')), [
        'live:devices',
        'live:status',
        'live:run',
      ]);
      expect(builtInCommands, contains('make:seeder'));
    });

    test('runs everything else through live:run', () {
      expect(liveRunActions.keys, [
        'data',
        'routes',
        'route',
        'back',
        'deeplink',
        'storage',
        'storage:clear',
        'backpack',
        'auth',
        'locale',
        'theme',
        'state',
        'event',
        'toast',
      ]);
      for (final LiveRunAction action in liveRunActions.values) {
        expect(action.description, isNotEmpty);
      }
    });
  });

  group('liveCommandMoved', () {
    test('names the command that took each one over', () {
      expect(
        liveCommandMoved('import'),
        '"import" is now seed <file> inside metro live',
      );
      expect(
        liveCommandMoved('import', runner: LiveRunner()),
        '"import" is now seed <file>',
      );
      expect(
        liveCommandMoved('login'),
        '"login" is now metro live:run auth login --data <json>',
      );
      expect(
        liveCommandMoved('storage:get'),
        '"storage:get" is now metro live:run storage <key>',
      );
      expect(
        liveCommandMoved('storage:set'),
        '"storage:set" is now metro live:run storage <key> <value>',
      );
      expect(
        liveCommandMoved('backpack:set'),
        '"backpack:set" is now metro live:run backpack <key> <value>',
      );
      expect(
        liveCommandMoved('backpack:delete'),
        '"backpack:delete" is now metro live:run backpack <key> --delete',
      );
    });

    test('leaves the shell-only commands out of the top level', () {
      // These only run inside metro live, so the top level doesn't know them.
      for (final String name in [
        'seed',
        'seed:rollback',
        'export',
        'reload',
        'restart',
      ]) {
        expect(liveCommandMoved(name), isNull);
        expect(liveCommandMoved(name, runner: LiveRunner()), isNull);
        expect(builtInCommands, isNot(contains('live:$name')));
        expect(liveRunActions, isNot(contains(name)));
      }
      // A command the top level still has is left alone.
      expect(liveCommandMoved('status'), isNull);
      expect(liveCommandMoved('devices'), isNull);
    });

    test('says nothing for a command that never existed', () {
      expect(liveCommandMoved('storage'), isNull);
      expect(liveCommandMoved('cart:seed_cart'), isNull);
    });

    test('only names commands that are really gone', () {
      for (final String name in liveCommandsMoved.keys) {
        expect(liveRunActions, isNot(contains(name)));
        expect(builtInCommands, isNot(contains('live:$name')));
      }
    });
  });

  group('liveShellArgumentsError', () {
    test('sends a shell-only command into the shell', () {
      expect(
        liveShellArgumentsError(['seed', 'demo_user']),
        'seed runs inside the shell. Open metro live and type seed demo_user',
      );
      expect(
        liveShellArgumentsError(['restart']),
        'restart runs inside the shell. Open metro live and type restart',
      );
    });

    test('names the one-shot form of every other command', () {
      expect(
        liveShellArgumentsError(['route', '/profile']),
        endsWith('To run one command, use metro live:run route /profile'),
      );
      expect(
        liveShellArgumentsError(['status']),
        endsWith('To run one command, use metro live:status'),
      );
      expect(
        liveShellArgumentsError(['app:seed_cart', '--count', '3']),
        endsWith('To run one command, use metro app:seed_cart --count 3'),
      );
      expect(
        liveShellArgumentsError(['use', '2']),
        endsWith('Open it and type use 2 there.'),
      );
    });

    test('quotes the words that have spaces', () {
      expect(
        liveShellArgumentsError(['route', '/profile', '--data', '{"id": 42}']),
        endsWith("metro live:run route /profile --data '{\"id\": 42}'"),
      );
    });
  });

  group('splitLiveRunArguments', () {
    test('takes the first argument as the command name', () {
      final split = splitLiveRunArguments([
        'route',
        '/profile',
        '--data',
        '{"id": 42}',
      ]);

      expect(split.name, 'route');
      expect(split.arguments, ['/profile', '--data', '{"id": 42}']);
      expect(split.stoppedAt, isNull);
    });

    test('keeps shared live flags that come before the name', () {
      final split = splitLiveRunArguments([
        '-d',
        '17 Pro',
        '--all',
        '--timeout=5',
        'storage:set',
        'coins',
        '10',
      ]);

      expect(split.name, 'storage:set');
      expect(split.arguments, [
        '-d',
        '17 Pro',
        '--all',
        '--timeout=5',
        'coins',
        '10',
      ]);
    });

    test('keeps app command names with a category', () {
      final split = splitLiveRunArguments([
        'cart:seed_cart',
        '--count',
        '5',
        '--json',
      ]);

      expect(split.name, 'cart:seed_cart');
      expect(split.arguments, ['--count', '5', '--json']);
    });

    test('never reads a flag value as the name', () {
      final split = splitLiveRunArguments(['--data', '{}', 'route']);

      expect(split.name, isNull);
      expect(split.stoppedAt, '--data');
    });

    test('reports help and a missing name', () {
      expect(splitLiveRunArguments([]).name, isNull);
      expect(splitLiveRunArguments([]).stoppedAt, isNull);
      expect(splitLiveRunArguments(['-d', '1']).stoppedAt, isNull);
      expect(splitLiveRunArguments(['--help']).stoppedAt, '--help');
    });
  });

  group('liveRunUsage', () {
    test('lists the built-in commands and a hint when the app has none', () {
      final String usage = liveRunUsage(const []);

      expect(usage, startsWith('Usage: metro live:run <command> [arguments]'));
      for (final String name in liveRunActions.keys) {
        expect(usage, contains('  $name '));
      }
      expect(usage, contains('metro make:command seed_cart --live'));
      expect(usage, contains('--device'));
    });

    test('lists the project\'s live commands with their descriptions', () {
      final String usage = liveRunUsage(const [
        LiveManifestEntry(
          name: 'seed_cart',
          category: 'cart',
          script: 'seed_cart.dart',
          description: 'Fill the cart with sample items',
        ),
        LiveManifestEntry(
          name: 'login_as',
          category: 'user',
          script: 'login_as.dart',
        ),
      ]);

      expect(
        usage,
        matches(RegExp(r'  cart:seed_cart +Fill the cart with sample items\n')),
      );
      expect(usage, contains('  user:login_as\n'));
      expect(usage, isNot(contains('None yet')));
    });
  });
}
