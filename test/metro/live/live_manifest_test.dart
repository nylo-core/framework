import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_manifest.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('nylo_live_manifest_');
    Directory('${project.path}/lib/app/commands').createSync(recursive: true);
  });

  tearDown(() => project.deleteSync(recursive: true));

  File commandsJson() => File('${project.path}/${LiveManifest.path}');

  void writeCommands(List<Map<String, Object?>> commands) =>
      commandsJson().writeAsStringSync(jsonEncode(commands));

  group('LiveManifest.load', () {
    test('returns only "type": "live" entries', () {
      writeCommands([
        {
          'name': 'current_time',
          'category': 'app',
          'script': 'current_time.dart',
        },
        {
          'name': 'seed',
          'category': 'cart',
          'script': 'seed_cart.dart',
          'type': 'live',
          'description': 'Fill the cart with sample items',
        },
        {'name': 'hello', 'script': 'hello.dart', 'type': 'live'},
      ]);

      final List<LiveManifestEntry> entries = LiveManifest.load(
        projectRoot: project.path,
      );

      expect(entries.map((e) => e.fullName), ['cart:seed', 'app:hello']);
      expect(entries.first.description, 'Fill the cart with sample items');
      expect(entries.first.script, 'seed_cart.dart');
    });

    test('is empty when commands.json is missing or invalid', () {
      expect(LiveManifest.load(projectRoot: project.path), isEmpty);

      commandsJson().writeAsStringSync('{not json');
      expect(LiveManifest.load(projectRoot: project.path), isEmpty);

      commandsJson().writeAsStringSync('{"name": "not a list"}');
      expect(LiveManifest.load(projectRoot: project.path), isEmpty);
    });

    test('find matches the full category:name', () {
      writeCommands([
        {
          'name': 'seed',
          'category': 'cart',
          'script': 's.dart',
          'type': 'live',
        },
        {'name': 'current_time', 'category': 'app', 'script': 'c.dart'},
      ]);

      expect(
        LiveManifest.find('cart:seed', projectRoot: project.path)?.name,
        'seed',
      );
      expect(
        LiveManifest.find('app:current_time', projectRoot: project.path),
        isNull,
      );
      expect(LiveManifest.find('seed', projectRoot: project.path), isNull);
    });
  });

  group('LiveManifest.menuLines', () {
    test('aligns descriptions like the custom commands menu', () {
      final String lines = LiveManifest.menuLines(const [
        LiveManifestEntry(
          name: 'seed',
          category: 'cart',
          description: 'Fill the cart',
        ),
        LiveManifestEntry(name: 'login_as', category: 'user'),
        LiveManifestEntry(name: 'x', category: 'app', description: 'Short'),
      ]);

      expect(
        lines,
        '  app:x            Short\n'
        '  cart:seed        Fill the cart\n'
        '  user:login_as\n',
      );
    });

    test('is empty without entries', () {
      expect(LiveManifest.menuLines(const []), '');
    });
  });

  group('LiveManifest.markLive', () {
    test('marks the matching entry as live with a description', () {
      writeCommands([
        {'name': 'seed_cart', 'category': 'app', 'script': 'seed_cart.dart'},
      ]);

      final bool marked = LiveManifest.markLive(
        commandsJson(),
        name: 'seed_cart',
        category: 'app',
        script: 'seed_cart.dart',
        description: ' Fill the cart ',
      );

      expect(marked, isTrue);
      expect(jsonDecode(commandsJson().readAsStringSync()), [
        {
          'name': 'seed_cart',
          'category': 'app',
          'script': 'seed_cart.dart',
          'type': 'live',
          'description': 'Fill the cart',
        },
      ]);
      expect(commandsJson().readAsStringSync(), contains('\n  {'));
    });

    test('adds a live entry instead of changing another category', () {
      writeCommands([
        {'name': 'seed', 'category': 'db', 'script': 'seed.dart'},
      ]);

      LiveManifest.markLive(
        commandsJson(),
        name: 'seed',
        category: 'cart',
        script: 'seed.dart',
      );

      final List<dynamic> commands = jsonDecode(
        commandsJson().readAsStringSync(),
      );
      expect(commands, hasLength(2));
      expect(commands.first, {
        'name': 'seed',
        'category': 'db',
        'script': 'seed.dart',
      });
      expect(commands.last['category'], 'cart');
      expect(commands.last['type'], 'live');
    });

    test('returns false for a missing or invalid file', () {
      expect(
        LiveManifest.markLive(
          commandsJson(),
          name: 'a',
          category: 'app',
          script: 'a.dart',
        ),
        isFalse,
      );
      commandsJson().writeAsStringSync('nope');
      expect(
        LiveManifest.markLive(
          commandsJson(),
          name: 'a',
          category: 'app',
          script: 'a.dart',
        ),
        isFalse,
      );
    });
  });
}
