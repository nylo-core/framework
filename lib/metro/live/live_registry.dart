import 'dart:io';

import 'package:nylo_support/metro/ny_metro.dart';

/// Where apps register their live commands.
const String liveCommandsRegistryPath = 'lib/bootstrap/live_commands.dart';

/// The contents of a new `lib/bootstrap/live_commands.dart`.
const String liveCommandsRegistryTemplate =
    '''import 'package:flutter/foundation.dart';
import 'package:nylo_framework/live.dart';

/* Live Commands
|--------------------------------------------------------------------------
| Commands that run inside your app while it's running in debug mode.
| Metro adds them here, so there's no need to edit this file. Create one:
|   metro make:command seed_cart --live
| Then run it from your terminal: metro app:seed_cart
|
| Release builds get an empty map, so live commands are left out of the app
| you ship.
|
| Learn more: https://nylo.dev/docs/7.x/metro
|-------------------------------------------------------------------------- */

final Map<String, LiveCommand Function()> liveCommands = kReleaseMode
    ? const {}
    : {};
''';

/// Where apps register their seeders.
const String seedersRegistryPath = 'lib/bootstrap/seeders.dart';

/// The contents of a new `lib/bootstrap/seeders.dart`.
const String seedersRegistryTemplate =
    '''import 'package:flutter/foundation.dart';
import 'package:nylo_framework/live.dart';

/* Seeders
|--------------------------------------------------------------------------
| Seeders put your running app into a known state, like a signed-in user
| with sample data, and take it back out again.
| Metro adds them here, so there's no need to edit this file. 
| Create one:
|   metro make:seeder demo_user
| Then, while your app is running, open metro live and seed it:
|   seed demo_user
|
| Learn more: https://nylo.dev/docs/7.x/metro
|-------------------------------------------------------------------------- */

final Map<String, Seeder Function()> seeders = kReleaseMode ? const {} : {};
''';

/// Adds `'<fullName>': () => <className>(),` to the `liveCommands` map in
/// [file].
///
/// Returns the updated file, or null when the command is already registered
/// or the `liveCommands` map can't be found.
String? insertLiveCommandRegistration(
  String file, {
  required String fullName,
  required String className,
}) => insertRegistryEntry(
  file,
  variable: 'liveCommands',
  type: 'LiveCommand Function()',
  key: fullName,
  value: '() => $className()',
);

/// Adds `'<name>': <className>.new,` to the `seeders` map in [file].
///
/// Returns the updated file, or null when the seeder is already registered
/// or the `seeders` map can't be found.
String? insertSeederRegistration(
  String file, {
  required String name,
  required String className,
}) => insertRegistryEntry(
  file,
  variable: 'seeders',
  type: 'Seeder Function()',
  key: name,
  value: '$className.new',
);

/// Adds `'<key>': <value>,` to the `Map<String, <type>> <variable>`
/// declared in [file].
///
/// Handles the release-guarded form Metro generates
/// (`kReleaseMode ? const {} : {...}`) as well as a plain map literal.
/// Returns null when [key] is already in [file] or there is no such map.
String? insertRegistryEntry(
  String file, {
  required String variable,
  required String type,
  required String key,
  required String value,
}) {
  if (file.contains("'$key'") || file.contains('"$key"')) return null;
  final String declaration = 'final Map<String, $type> $variable = ';

  final RegExpMatch? guarded = _guardedMap(variable, type).firstMatch(file);
  if (guarded != null) {
    final String entries = _entries(
      guarded.group(1)!,
    ).map((String line) => '        $line\n').join();
    return file.replaceRange(
      guarded.start,
      guarded.end,
      '${declaration}kReleaseMode\n'
      '    ? const {}\n'
      '    : {\n'
      '$entries'
      "        '$key': $value,\n"
      '      };',
    );
  }

  final RegExpMatch? plain = _plainMap(variable, type).firstMatch(file);
  if (plain == null) return null;
  String entries = plain.group(1)!.trimRight();
  if (entries.trim().isNotEmpty && !entries.endsWith(',')) entries += ',';
  return file.replaceRange(
    plain.start,
    plain.end,
    '$declaration{'
    '$entries\n'
    "  '$key': $value,\n"
    '};',
  );
}

/// Whether [file] declares the `Map<String, <type>> <variable>` registry.
bool hasRegistryMap(
  String file, {
  required String variable,
  required String type,
}) =>
    _guardedMap(variable, type).hasMatch(file) ||
    _plainMap(variable, type).hasMatch(file);

/// The keys of the `Map<String, <type>> <variable>` registry declared in
/// [file], skipping commented-out entries.
///
/// Returns an empty list when [file] has no such map.
List<String> registryKeys(
  String file, {
  required String variable,
  required String type,
}) {
  final RegExpMatch? map =
      _guardedMap(variable, type).firstMatch(file) ??
      _plainMap(variable, type).firstMatch(file);
  if (map == null) return const [];
  // Strings and comments are matched whole, left to right, so a quote inside
  // a comment or a value is never read as the start of a key.
  return [
    for (final RegExpMatch token in RegExp(
      r'''\'([^'\n]*)'(\s*:)?|"([^"\n]*)"(\s*:)?|//[^\n]*|/\*[\s\S]*?\*/''',
    ).allMatches(map.group(1)!))
      if (token.group(2) != null)
        token.group(1)!
      else if (token.group(4) != null)
        token.group(3)!,
  ];
}

/// The live command names `lib/bootstrap/live_commands.dart` registers in
/// the project at [projectRoot].
List<String> registeredLiveCommands({String projectRoot = '.'}) => _readKeys(
  '$projectRoot/$liveCommandsRegistryPath',
  variable: 'liveCommands',
  type: 'LiveCommand Function()',
);

/// The seeder names `lib/bootstrap/seeders.dart` registers in the project at
/// [projectRoot].
List<String> registeredSeeders({String projectRoot = '.'}) => _readKeys(
  '$projectRoot/$seedersRegistryPath',
  variable: 'seeders',
  type: 'Seeder Function()',
);

List<String> _readKeys(
  String path, {
  required String variable,
  required String type,
}) {
  try {
    final File file = File(path);
    if (!file.existsSync()) return const [];
    return registryKeys(
      file.readAsStringSync(),
      variable: variable,
      type: type,
    );
  } on FileSystemException {
    return const [];
  }
}

RegExp _guardedMap(String variable, String type) => RegExp(
  'final Map<String, ${RegExp.escape(type)}> $variable = kReleaseMode'
  r'\s*\?\s*const\s*\{\s*\}\s*:\s*\{([\s\S]*?)\};',
);

RegExp _plainMap(String variable, String type) => RegExp(
  'final Map<String, ${RegExp.escape(type)}> $variable = '
  r'\{([\s\S]*?)\};',
);

/// The entries between a map's braces, one trimmed line each, the last one
/// ending with a comma.
List<String> _entries(String body) {
  final List<String> lines = body
      .split('\n')
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();
  if (lines.isNotEmpty && !lines.last.endsWith(',')) {
    lines[lines.length - 1] = '${lines.last},';
  }
  return lines;
}

/// The result of registering a live command or seeder in the app.
enum LiveRegistration {
  /// It was added to the registry.
  added,

  /// The registry already imports or lists it.
  alreadyRegistered,

  /// The registry has no map to add it to.
  mapNotFound,
}

/// Registers the command class [className] (from [importPath], relative to
/// `lib/`) under [fullName] in `lib/bootstrap/live_commands.dart`, creating
/// the file when it doesn't exist.
Future<LiveRegistration> registerLiveCommand({
  required String fullName,
  required String className,
  required String importPath,
}) => _register(
  path: liveCommandsRegistryPath,
  template: liveCommandsRegistryTemplate,
  configName: 'live_commands',
  label: 'Live Command',
  importPath: importPath,
  insert: (String file) => insertLiveCommandRegistration(
    file,
    fullName: fullName,
    className: className,
  ),
  hasMap: (String file) => hasRegistryMap(
    file,
    variable: 'liveCommands',
    type: 'LiveCommand Function()',
  ),
);

/// Registers the seeder class [className] (from [importPath], relative to
/// `lib/`) under [name] in `lib/bootstrap/seeders.dart`, creating the file
/// when it doesn't exist.
Future<LiveRegistration> registerSeeder({
  required String name,
  required String className,
  required String importPath,
}) => _register(
  path: seedersRegistryPath,
  template: seedersRegistryTemplate,
  configName: 'seeders',
  label: 'Seeder',
  importPath: importPath,
  insert: (String file) =>
      insertSeederRegistration(file, name: name, className: className),
  hasMap: (String file) =>
      hasRegistryMap(file, variable: 'seeders', type: 'Seeder Function()'),
);

Future<LiveRegistration> _register({
  required String path,
  required String template,
  required String configName,
  required String label,
  required String importPath,
  required String? Function(String file) insert,
  required bool Function(String file) hasMap,
}) async {
  final File registry = File(path);
  if (!registry.existsSync()) {
    await registry.parent.create(recursive: true);
    await registry.writeAsString(template);
    MetroConsole.writeInGreen(
      '[$label] ${MetroConsole.hyperlink(configName, path)} created',
    );
  }

  final String classImport = "import '/$importPath';";
  final String before = await registry.readAsString();
  if (before.contains(classImport)) return LiveRegistration.alreadyRegistered;

  bool mapFound = true;
  await MetroService.addToConfig(
    configName: configName,
    classImport: classImport,
    createTemplate: (String file) {
      final String? updated = insert(file);
      if (updated == null) {
        mapFound = hasMap(file);
        return '';
      }
      return updated;
    },
  );

  if (!mapFound) return LiveRegistration.mapNotFound;
  final String after = await registry.readAsString();
  return after == before
      ? LiveRegistration.alreadyRegistered
      : LiveRegistration.added;
}

/// The import that makes `liveCommands` available to the app provider.
const String liveCommandsImport = "import '/bootstrap/live_commands.dart';";

/// The import that makes `seeders` available to the app provider.
const String seedersImport = "import '/bootstrap/seeders.dart';";

/// The result of wiring a registry into the app provider.
enum LiveWiring {
  /// The import and the `nylo.configure` argument were added.
  added,

  /// The app provider already passes it.
  alreadyWired,

  /// No `nylo.configure(...)` call was found to add it to.
  configureNotFound,

  /// There is no app provider file.
  providerMissing,
}

/// Passes the app's live commands to Nylo in [appProvider] by adding
/// [liveCommandsImport] and `liveCommands: liveCommands` to its
/// `nylo.configure(...)` call.
Future<LiveWiring> wireLiveCommands(File appProvider) =>
    _wire(appProvider, addLiveCommandsToProvider, _passesLiveCommands);

/// Passes the app's seeders to Nylo in [appProvider] by adding
/// [seedersImport] and `seeders: seeders` to its `nylo.configure(...)` call.
Future<LiveWiring> wireSeeders(File appProvider) =>
    _wire(appProvider, addSeedersToProvider, _passesSeeders);

Future<LiveWiring> _wire(
  File appProvider,
  String? Function(String source) add,
  bool Function(String source) isWired,
) async {
  if (!appProvider.existsSync()) return LiveWiring.providerMissing;
  final String source = await appProvider.readAsString();
  if (isWired(source)) return LiveWiring.alreadyWired;

  final String? updated = add(source);
  if (updated == null) return LiveWiring.configureNotFound;
  await appProvider.writeAsString(updated);
  return LiveWiring.added;
}

bool _passesLiveCommands(String source) => source.contains('liveCommands');

bool _passesSeeders(String source) =>
    RegExp(r'\bseeders\s*:|\baddSeeders\s*\(').hasMatch(source);

/// Returns [source] with `liveCommands: liveCommands` added as the last
/// argument of its first `nylo.configure(...)` call and [liveCommandsImport]
/// added after the last import.
///
/// Returns [source] unchanged when it already mentions `liveCommands`, and
/// null when it has no `nylo.configure(...)` call.
String? addLiveCommandsToProvider(String source) {
  if (_passesLiveCommands(source)) return source;
  return _addConfigureArgument(
    source,
    argument: 'liveCommands: liveCommands',
    import: liveCommandsImport,
  );
}

/// Returns [source] with `seeders: seeders` added as the last argument of
/// its first `nylo.configure(...)` call and [seedersImport] added after the
/// last import.
///
/// Returns [source] unchanged when it already passes seeders, and null when
/// it has no `nylo.configure(...)` call.
String? addSeedersToProvider(String source) {
  if (_passesSeeders(source)) return source;
  return _addConfigureArgument(
    source,
    argument: 'seeders: seeders',
    import: seedersImport,
  );
}

String? _addConfigureArgument(
  String source, {
  required String argument,
  required String import,
}) {
  final RegExpMatch? call = RegExp(
    r'\bnylo\s*\.\s*configure\s*\(',
  ).firstMatch(source);
  if (call == null) return null;
  final int open = call.end - 1;
  final ({int close, int lastSignificant})? arguments = _scanArguments(
    source,
    open,
  );
  if (arguments == null) return null;

  final int close = arguments.close;
  final int last = arguments.lastSignificant;
  String updated;

  if (last == open) {
    // configure() without arguments
    updated = source.replaceRange(open + 1, close, argument);
  } else {
    final bool hasComma = source[last] == ',';
    final int lineEnd = source.indexOf('\n', last);
    if (lineEnd != -1 && lineEnd < close) {
      // One argument per line: add ours on a new line with the same indent,
      // after anything (such as a comment) that ends the last argument's line.
      final int lineStart = source.lastIndexOf('\n', last) + 1;
      final String indent = RegExp(
        r'^[ \t]*',
      ).firstMatch(source.substring(lineStart))!.group(0)!;
      updated = source.replaceRange(lineEnd, lineEnd, '\n$indent$argument,');
      if (!hasComma) updated = updated.replaceRange(last + 1, last + 1, ',');
    } else {
      updated = source.replaceRange(
        last + 1,
        last + 1,
        hasComma ? ' $argument' : ', $argument',
      );
    }
  }

  return _addImport(updated, import);
}

/// Scans the argument list opened at [open], skipping strings and comments.
///
/// Returns the index of the matching `)` and of the last character before it
/// that isn't whitespace or a comment ([open] itself when there are no
/// arguments), or null when the parenthesis is never closed.
({int close, int lastSignificant})? _scanArguments(String source, int open) {
  int depth = 0;
  int lastSignificant = open;
  int i = open;
  while (i < source.length) {
    final String char = source[i];

    if (char == '/' && i + 1 < source.length) {
      if (source[i + 1] == '/') {
        final int end = source.indexOf('\n', i);
        i = end == -1 ? source.length : end;
        continue;
      }
      if (source[i + 1] == '*') {
        final int end = source.indexOf('*/', i + 2);
        i = end == -1 ? source.length : end + 2;
        continue;
      }
    }

    if (char == "'" || char == '"') {
      final String quote = source.startsWith(char * 3, i) ? char * 3 : char;
      final bool raw = i > 0 && source[i - 1] == 'r';
      int j = i + quote.length;
      while (j < source.length) {
        if (!raw && source[j] == r'\') {
          j += 2;
          continue;
        }
        if (source.startsWith(quote, j)) {
          j += quote.length;
          break;
        }
        j++;
      }
      lastSignificant = j - 1;
      i = j;
      continue;
    }

    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return (close: i, lastSignificant: lastSignificant);
    }
    if (char.trim().isNotEmpty && i != open) lastSignificant = i;
    i++;
  }
  return null;
}

/// Adds [line] after the last import directive in [source].
String _addImport(String source, String line) {
  if (source.contains(line)) return source;
  final List<RegExpMatch> imports = RegExp(
    r'^import\s[^;]*;[^\n]*$',
    multiLine: true,
  ).allMatches(source).toList();
  if (imports.isEmpty) return '$line\n$source';
  final int end = imports.last.end;
  return source.replaceRange(end, end, '\n$line');
}
