import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_registry.dart';

void main() {
  group('insertLiveCommandRegistration', () {
    test('adds to the release-guarded map in the generated template', () {
      final String? updated = insertLiveCommandRegistration(
        liveCommandsRegistryTemplate,
        fullName: 'app:seed_cart',
        className: 'SeedCartCommand',
      );

      expect(
        updated,
        endsWith(
          "final Map<String, LiveCommand Function()> liveCommands = kReleaseMode\n"
          "    ? const {}\n"
          "    : {\n"
          "        'app:seed_cart': () => SeedCartCommand(),\n"
          "      };\n",
        ),
      );
      expect(updated, contains("import 'package:nylo_framework/live.dart';"));
      expect(updated, contains("import 'package:flutter/foundation.dart';"));
    });

    test('appends to a guarded map, including one formatted on one line', () {
      const String file =
          "final Map<String, LiveCommand Function()> liveCommands = kReleaseMode\n"
          "    ? const {}\n"
          "    : {'app:a': () => ACommand()};\n";

      final String? once = insertLiveCommandRegistration(
        file,
        fullName: 'app:b',
        className: 'BCommand',
      );
      final String? twice = insertLiveCommandRegistration(
        once!,
        fullName: 'app:c',
        className: 'CCommand',
      );

      expect(
        twice,
        "final Map<String, LiveCommand Function()> liveCommands = kReleaseMode\n"
        "    ? const {}\n"
        "    : {\n"
        "        'app:a': () => ACommand(),\n"
        "        'app:b': () => BCommand(),\n"
        "        'app:c': () => CCommand(),\n"
        "      };\n",
      );
    });

    test('appends to a multi-line map', () {
      const String file = '''
final Map<String, LiveCommand Function()> liveCommands = {
  'app:seed_cart': () => SeedCartCommand(),
};
''';

      final String? updated = insertLiveCommandRegistration(
        file,
        fullName: 'user:login_as',
        className: 'LoginAsCommand',
      );

      expect(
        updated,
        "final Map<String, LiveCommand Function()> liveCommands = {\n"
        "  'app:seed_cart': () => SeedCartCommand(),\n"
        "  'user:login_as': () => LoginAsCommand(),\n"
        "};\n",
      );
    });

    test('adds a missing trailing comma before appending', () {
      const String file =
          "final Map<String, LiveCommand Function()> liveCommands = {\n"
          "  'app:a': () => ACommand()\n"
          "};";

      final String? updated = insertLiveCommandRegistration(
        file,
        fullName: 'app:b',
        className: 'BCommand',
      );

      expect(
        updated,
        contains("() => ACommand(),\n  'app:b': () => BCommand(),"),
      );
    });

    test('returns null when the command is already registered', () {
      const String file =
          "final Map<String, LiveCommand Function()> liveCommands = {\n"
          "  'app:seed_cart': () => SeedCartCommand(),\n"
          "};";

      expect(
        insertLiveCommandRegistration(
          file,
          fullName: 'app:seed_cart',
          className: 'SeedCartCommand',
        ),
        isNull,
      );
    });

    test('returns null when there is no liveCommands map', () {
      expect(
        insertLiveCommandRegistration(
          'final Map<Type, NyEvent> events = {};',
          fullName: 'app:a',
          className: 'ACommand',
        ),
        isNull,
      );
    });
  });

  group('insertSeederRegistration', () {
    test('adds to the release-guarded map in the generated template', () {
      final String? updated = insertSeederRegistration(
        seedersRegistryTemplate,
        name: 'demo_user',
        className: 'DemoUserSeeder',
      );

      expect(
        updated,
        endsWith(
          "final Map<String, Seeder Function()> seeders = kReleaseMode\n"
          "    ? const {}\n"
          "    : {\n"
          "        'demo_user': DemoUserSeeder.new,\n"
          "      };\n",
        ),
      );
      expect(
        insertSeederRegistration(
          updated!,
          name: 'demo_user',
          className: 'DemoUserSeeder',
        ),
        isNull,
      );
    });

    test('finds the map in either form', () {
      expect(
        hasRegistryMap(
          seedersRegistryTemplate,
          variable: 'seeders',
          type: 'Seeder Function()',
        ),
        isTrue,
      );
      expect(
        hasRegistryMap(
          'final Map<String, Seeder Function()> seeders = {};',
          variable: 'seeders',
          type: 'Seeder Function()',
        ),
        isTrue,
      );
      expect(
        hasRegistryMap(
          liveCommandsRegistryTemplate,
          variable: 'seeders',
          type: 'Seeder Function()',
        ),
        isFalse,
      );
    });
  });

  group('registryKeys', () {
    test('reads the keys of either map form, skipping comments', () {
      const String commands =
          "final Map<String, LiveCommand Function()> liveCommands = kReleaseMode\n"
          "    ? const {}\n"
          "    : {\n"
          "        'app:seed_cart': () => SeedCartCommand(),\n"
          "        // 'app:old': () => OldCommand(),\n"
          "        \"cart:clear\": () => ClearCommand(label: 'Clear: all'),\n"
          "      };\n";
      expect(
        registryKeys(
          commands,
          variable: 'liveCommands',
          type: 'LiveCommand Function()',
        ),
        ['app:seed_cart', 'cart:clear'],
      );

      expect(
        registryKeys(
          "final Map<String, Seeder Function()> seeders = kReleaseMode ? "
          "const {} : {'demo_user': DemoUserSeeder.new, /* 'b': B.new */};",
          variable: 'seeders',
          type: 'Seeder Function()',
        ),
        ['demo_user'],
      );
      expect(
        registryKeys(
          "final Map<String, Seeder Function()> seeders = {\n"
          "  'a': A.new, // it's a demo: really\n"
          "  'b': B.new,\n"
          "};",
          variable: 'seeders',
          type: 'Seeder Function()',
        ),
        ['a', 'b'],
      );
    });

    test('is empty for an empty or missing map', () {
      expect(
        registryKeys(
          liveCommandsRegistryTemplate,
          variable: 'liveCommands',
          type: 'LiveCommand Function()',
        ),
        isEmpty,
      );
      expect(
        registryKeys(
          liveCommandsRegistryTemplate,
          variable: 'seeders',
          type: 'Seeder Function()',
        ),
        isEmpty,
      );
    });

    test('reads a project\'s registries from disk', () {
      final Directory project = Directory.systemTemp.createTempSync(
        'nylo_live_registry_',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      expect(registeredLiveCommands(projectRoot: project.path), isEmpty);
      expect(registeredSeeders(projectRoot: project.path), isEmpty);

      File('${project.path}/$liveCommandsRegistryPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          insertLiveCommandRegistration(
            liveCommandsRegistryTemplate,
            fullName: 'app:seed_cart',
            className: 'SeedCartCommand',
          )!,
        );
      File('${project.path}/$seedersRegistryPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          insertSeederRegistration(
            seedersRegistryTemplate,
            name: 'demo_user',
            className: 'DemoUserSeeder',
          )!,
        );

      expect(registeredLiveCommands(projectRoot: project.path), [
        'app:seed_cart',
      ]);
      expect(registeredSeeders(projectRoot: project.path), ['demo_user']);
    });
  });

  group('addSeedersToProvider', () {
    test('adds the argument and import next to live commands', () {
      const String source =
          "import 'package:nylo_framework/nylo_framework.dart';\n"
          "import '/bootstrap/live_commands.dart';\n"
          "\n"
          "setup(Nylo nylo) async {\n"
          "  await nylo.configure(\n"
          "    useErrorStack: true,\n"
          "    liveCommands: liveCommands,\n"
          "  );\n"
          "}\n";

      final String? updated = addSeedersToProvider(source);

      expect(
        updated,
        contains(
          "    liveCommands: liveCommands,\n"
          "    seeders: seeders,\n"
          "  );",
        ),
      );
      expect(
        updated,
        contains(
          "import '/bootstrap/live_commands.dart';\n"
          "import '/bootstrap/seeders.dart';\n",
        ),
      );
      expect(addSeedersToProvider(updated!), updated);
    });

    test('treats addSeeders as already wired', () {
      const String source =
          "nylo.addSeeders(seeders);\nawait nylo.configure();";

      expect(addSeedersToProvider(source), source);
    });

    test('isn\'t fooled by the word seeders elsewhere', () {
      const String source =
          "// seeders live in lib/app/seeders\nawait nylo.configure();";

      expect(
        addSeedersToProvider(source),
        endsWith('await nylo.configure(seeders: seeders);'),
      );
    });
  });

  group('addLiveCommandsToProvider', () {
    const String boilerplateProvider = """import '/config/storage_keys.dart';
import '/bootstrap/decoders.dart';
import 'package:nylo_framework/nylo_framework.dart';

class AppProvider implements NyProvider {

  @override
  setup(Nylo nylo) async {
    await nylo.configure(
      localization: NyLocalizationConfig(
          languageCode: LocalizationConfig.languageCode,
          assetsDirectory: LocalizationConfig.assetsDirectory
      ),
      initialThemeId: 'light_theme',
      authKey: StorageKeysConfig.auth,
      useErrorStack: true,
    );

    return nylo;
  }
}
""";

    test('adds the argument and import to the boilerplate provider', () {
      final String? updated = addLiveCommandsToProvider(boilerplateProvider);

      expect(
        updated,
        contains(
          "      useErrorStack: true,\n"
          "      liveCommands: liveCommands,\n"
          "    );",
        ),
      );
      expect(
        updated,
        contains(
          "import 'package:nylo_framework/nylo_framework.dart';\n"
          "import '/bootstrap/live_commands.dart';\n",
        ),
      );
      expect('liveCommands: liveCommands'.allMatches(updated!), hasLength(1));
    });

    test('leaves an already wired provider unchanged', () {
      final String wired = addLiveCommandsToProvider(boilerplateProvider)!;

      expect(addLiveCommandsToProvider(wired), wired);
    });

    test('returns null without a nylo.configure call', () {
      expect(
        addLiveCommandsToProvider(
          "import 'package:nylo_framework/nylo_framework.dart';\n"
          "setup(Nylo nylo) async {\n  nylo.addLoader(loader);\n}\n",
        ),
        isNull,
      );
    });

    test('adds a trailing comma when the last argument has none', () {
      const String source =
          "await nylo.configure(\n"
          "  authKey: 'SK_USER',\n"
          "  useErrorStack: true\n"
          ");";

      expect(
        addLiveCommandsToProvider(source),
        endsWith(
          "  useErrorStack: true,\n"
          "  liveCommands: liveCommands,\n"
          ");",
        ),
      );
    });

    test('keeps a comment that ends the last argument line', () {
      const String source =
          "await nylo.configure(\n"
          "  useErrorStack: true, // (see docs)\n"
          ");";

      expect(
        addLiveCommandsToProvider(source),
        endsWith(
          "  useErrorStack: true, // (see docs)\n"
          "  liveCommands: liveCommands,\n"
          ");",
        ),
      );
    });

    test('handles single-line and empty calls', () {
      expect(
        addLiveCommandsToProvider("await nylo.configure(authKey: 'k');"),
        endsWith(
          "await nylo.configure(authKey: 'k', liveCommands: liveCommands);",
        ),
      );
      expect(
        addLiveCommandsToProvider('await nylo.configure();'),
        endsWith('await nylo.configure(liveCommands: liveCommands);'),
      );
    });

    test('ignores parentheses inside strings and nested calls', () {
      const String source =
          "await nylo.configure(\n"
          "  loader: Text(')('),\n"
          "  logo: Logo(size: max(1, 2)),\n"
          ");";

      expect(
        addLiveCommandsToProvider(source),
        endsWith(
          "  logo: Logo(size: max(1, 2)),\n"
          "  liveCommands: liveCommands,\n"
          ");",
        ),
      );
    });
  });

  group('wireLiveCommands', () {
    late Directory temp;

    setUp(
      () => temp = Directory.systemTemp.createTempSync('nylo_live_wiring_'),
    );
    tearDown(() => temp.deleteSync(recursive: true));

    test('writes the wiring once', () async {
      final File file = File('${temp.path}/app_provider.dart')
        ..writeAsStringSync('await nylo.configure(useErrorStack: true);');

      expect(await wireLiveCommands(file), LiveWiring.added);
      expect(file.readAsStringSync(), contains('liveCommands: liveCommands'));
      expect(await wireLiveCommands(file), LiveWiring.alreadyWired);
    });

    test('reports when it can\'t wire the provider', () async {
      final File plain = File('${temp.path}/app_provider.dart')
        ..writeAsStringSync('nylo.addLoader(loader);');

      expect(await wireLiveCommands(plain), LiveWiring.configureNotFound);
      expect(plain.readAsStringSync(), 'nylo.addLoader(loader);');
      expect(
        await wireLiveCommands(File('${temp.path}/missing.dart')),
        LiveWiring.providerMissing,
      );
    });

    test('wires seeders once, alongside live commands', () async {
      final File file = File('${temp.path}/app_provider.dart')
        ..writeAsStringSync('await nylo.configure(useErrorStack: true);');

      expect(await wireLiveCommands(file), LiveWiring.added);
      expect(await wireSeeders(file), LiveWiring.added);
      expect(await wireSeeders(file), LiveWiring.alreadyWired);
      expect(
        file.readAsStringSync(),
        endsWith(
          'await nylo.configure(useErrorStack: true, '
          'liveCommands: liveCommands, seeders: seeders);',
        ),
      );
    });
  });
}
