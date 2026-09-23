import 'dart:async';
import 'dart:io';

import 'live_app.dart';
import 'live_command_schema.dart';
import 'live_discovery.dart';
import 'live_line_editor.dart';
import 'live_manifest.dart';
import 'live_options.dart';
import 'live_platform_links.dart';
import 'live_output.dart';
import 'live_runner.dart';
import 'live_session.dart';

/// Runs one command inside `metro live` and returns its exit code, or null
/// when no command has that name.
typedef LiveShellDispatch =
    Future<int?> Function(
      String name,
      List<String> arguments,
      LiveRunner runner,
    );

/// A command `metro live` lists in `help` and completes with Tab.
typedef LiveShellCommand = ({
  String name,
  String usage,
  String description,
  List<String> options,
});

/// `metro live`: a prompt connected to the running app.
///
/// Live commands drop their `metro live:` prefix inside the shell, and run
/// on connections that stay open between commands. When its input isn't a
/// terminal, the shell runs each line as a script instead.
class LiveShell {
  /// Creates a shell that runs commands with [dispatch] on [session]'s apps.
  LiveShell({
    required this.runner,
    required this.session,
    required this.dispatch,
    required this.commands,
    required Stream<List<int>> input,
    required StringSink output,
    this.options = const LiveOptions(),
    this.appCommands = const [],
    this.terminal = const StdioLiveTerminal(),
    this.historyPath,
    Stream<ProcessSignal>? interrupts,
  }) : _input = input,
       _output = output,
       _interrupts = interrupts;

  /// A shell for the Flutter project in the current directory.
  ///
  /// Throws a [LiveCommandException] outside a Flutter project.
  factory LiveShell.forProject({
    required LiveOptions options,
    required LiveShellDispatch dispatch,
    required List<LiveShellCommand> commands,
  }) {
    final LiveRunner runner = LiveRunner();
    final String root = runner.project.root;
    final String? address = options.uri;
    final Uri? uri = address == null
        ? null
        : LiveDiscovery.normalizeVmServiceUri(address);
    if (address != null && uri == null) {
      throw LiveCommandException('Not a VM service address: $address');
    }
    final LiveSession session = LiveSession(
      runner,
      timeout: options.timeout,
      uri: uri,
    );
    runner.session = session;
    return LiveShell(
      runner: runner,
      session: session,
      dispatch: dispatch,
      commands: commands,
      options: options,
      appCommands: LiveManifest.load(),
      input: stdin,
      output: stdout,
      historyPath: '$root/.dart_tool/nylo/live_history',
      interrupts: _sigint(),
    );
  }

  /// Runs commands and prints their output.
  final LiveRunner runner;

  /// The apps commands run on.
  final LiveSession session;

  /// Runs a command that isn't one of the shell's own.
  final LiveShellDispatch dispatch;

  /// The live commands, for `help` and Tab.
  final List<LiveShellCommand> commands;

  /// The project's live commands from `commands.json`.
  final List<LiveManifestEntry> appCommands;

  /// `-d` and `--all` given to `metro live`.
  final LiveOptions options;

  /// The terminal the prompt is drawn on.
  final LiveTerminal terminal;

  /// Where earlier commands are saved, or null to not save them.
  final String? historyPath;

  final Stream<List<int>> _input;
  final StringSink _output;
  final Stream<ProcessSignal>? _interrupts;

  late final LiveLineEditor _editor;
  StreamSubscription<ProcessSignal>? _interruptSubscription;
  void Function()? _onInterrupt;
  final Map<String, List<String>> _completionCache = {};

  static const int _historyLimit = 500;

  /// Runs the shell until `exit`, Ctrl+D or the end of the input, and
  /// returns the exit code.
  Future<int> start() async {
    _editor = LiveLineEditor(
      input: _input,
      output: _output,
      terminal: terminal,
      history: _loadHistory(),
      historyLimit: _historyLimit,
      complete: _complete,
    );
    _interruptSubscription = _interrupts?.listen((_) {
      final void Function()? onInterrupt = _onInterrupt;
      if (onInterrupt != null) {
        onInterrupt();
      } else if (_editor.isReading) {
        _editor.cancelLine();
      }
    });

    try {
      return terminal.hasTerminal ? await _interactive() : await _script();
    } finally {
      await _interruptSubscription?.cancel();
      await session.close();
      await _editor.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Modes
  // ---------------------------------------------------------------------------

  Future<int> _interactive() async {
    session.onNotice = (message) => _editor.printAbove(_dim('· $message'));
    session.onChange = () {
      if (_editor.isReading) _editor.updatePrompt(_prompt());
    };

    _output.writeln(_bold('Nylo Live · ${runner.project.packageName}'));
    if (!await _connect()) return 0;
    _output.writeln(_dim('Type help to see commands, and exit to leave.'));

    while (true) {
      final String? line = await _editor.readLine(_prompt());
      if (line == null) {
        _output.writeln();
        return 0;
      }
      final int? code = await _execute(line);
      _saveHistory();
      if (code == null) return 0;
    }
  }

  Future<int> _script() async {
    if (options.all) await session.use('all');
    final String? device = options.device;
    if (device != null) {
      final ({String error, List<LiveApp> candidates})? failure = await session
          .use(device);
      if (failure != null) {
        _printPickError(failure);
        return 1;
      }
    }

    while (true) {
      final String? line = await _editor.readLine('');
      if (line == null) return 0;
      final String command = line.trim();
      if (command.isEmpty || command.startsWith('#')) continue;
      _output.writeln('${_dim('›')} $command');
      final int? code = await _execute(command);
      if (code == null) return 0;
      if (code != 0) return code;
    }
  }

  /// Connects to the running apps and picks one. Returns false when the
  /// user left while picking.
  Future<bool> _connect() async {
    try {
      await session.refresh();
    } on LiveDiscoveryException catch (e) {
      runner.output.error(e.message);
    } on LiveCommandException catch (e) {
      runner.output.error(e.message);
    }

    if (options.all) {
      await session.use('all');
    } else if (options.device != null) {
      final ({String error, List<LiveApp> candidates})? failure = await session
          .use(options.device!);
      if (failure != null) _printPickError(failure);
    }

    final List<LiveApp> apps = session.apps;
    if (apps.isEmpty) {
      runner.output.note(
        'Waiting for ${runner.project.packageName} to start. Run it with '
        'flutter run, and the shell connects on its own.',
      );
      return true;
    }
    if (session.all || session.current != null) {
      final LiveApp? app = session.current;
      runner.output.success(
        app == null
            ? 'Connected to ${apps.length} apps'
            : 'Connected to ${app.device} (${app.status['mode'] ?? 'debug'})',
      );
      return true;
    }

    _printApps(apps);
    while (true) {
      final String? answer = await _editor.readLine(
        'Which one? Enter 1-${apps.length} or all ${_dim('›')} ',
      );
      if (answer == null) return false;
      if (answer.trim().isEmpty) continue;
      final ({String error, List<LiveApp> candidates})? failure = await session
          .use(answer.trim());
      if (failure == null) return true;
      runner.output.error(failure.error);
    }
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// Runs [line] and returns its exit code, or null to leave the shell.
  Future<int?> _execute(String line) async {
    final List<String> words;
    try {
      words = splitLiveShellLine(line);
    } on FormatException catch (e) {
      runner.output.error(e.message);
      return 64;
    }
    if (words.isEmpty) return 0;
    final String name = words.first;
    final List<String> arguments = words.sublist(1);

    switch (name) {
      case 'exit' || 'quit':
        return null;
      case 'help' || '?':
        if (arguments.isNotEmpty) {
          return await _execute('${arguments.first} --help') ?? 0;
        }
        return _help();
      case 'use':
        return _use(arguments);
      case 'devices' when arguments.isEmpty:
        return _devices();
      case 'clear':
        if (terminal.supportsAnsi) _output.write('\x1B[2J\x1B[H');
        return 0;
    }

    session.busy = true;
    try {
      final int? code = await _whileInterruptible(
        () => dispatch(name, arguments, runner),
      );
      if (code == null) {
        runner.output.error(
          'There\'s no command named "$name". Type help to see commands.',
        );
        return 64;
      }
      if (name == 'restart' || name == 'reload') _completionCache.clear();
      return code;
    } catch (e) {
      runner.output.error(describeLiveError(e));
      return 1;
    } finally {
      session.busy = false;
    }
  }

  /// Runs [action], returning early when Ctrl+C is pressed and the action
  /// doesn't stop on its own soon after.
  Future<int?> _whileInterruptible(Future<int?> Function() action) async {
    final Completer<int?> interrupted = Completer<int?>();
    _onInterrupt = () {
      Timer(const Duration(milliseconds: 300), () {
        if (!interrupted.isCompleted) interrupted.complete(130);
      });
    };
    try {
      final Future<int?> running = action();
      final int? code = await Future.any([running, interrupted.future]);
      if (interrupted.isCompleted && code == 130) {
        runner.output.note(
          'Stopped waiting. The app may still finish the command.',
        );
        unawaited(running.then((_) {}, onError: (Object _) {}));
      }
      return code;
    } finally {
      _onInterrupt = null;
    }
  }

  int _help() {
    final int width = [
      ...commands.map((command) => command.usage.length),
      ...appCommands.map((entry) => entry.fullName.length),
    ].fold(0, (a, b) => a > b ? a : b);

    final LiveBlock block = LiveBlock()..heading('Commands:');
    for (final LiveShellCommand command in commands) {
      block.plain(
        '  ${command.usage.padRight(width + 2)}${command.description}',
      );
    }
    block
      ..plain('')
      ..heading('Your commands:');
    if (appCommands.isEmpty) {
      block.note(
        'None yet. Create one with: metro make:command seed_cart --live',
      );
    }
    for (final LiveManifestEntry entry in appCommands) {
      block.plain(
        '  ${entry.fullName.padRight(width + 2)}${entry.description ?? ''}'
            .trimRight(),
      );
    }
    block
      ..plain('')
      ..note(
        'Add -d <#>, --all or --json to run one command on another app, or '
        'as JSON. Values starting with @ are read from a file.',
      );
    runner.output.block(block);
    return 0;
  }

  Future<int> _use(List<String> arguments) async {
    if (arguments.isEmpty) {
      final LiveApp? app = session.current;
      runner.output.note(
        session.all
            ? 'Commands run on every app (${session.apps.length})'
            : app != null
            ? 'Commands run on ${app.device}'
            : 'No app is picked. Pick one with use <#|name>, or use all',
      );
      return 0;
    }
    final ({String error, List<LiveApp> candidates})? failure = await session
        .use(arguments.join(' '));
    if (failure != null) {
      _printPickError(failure);
      return 1;
    }
    final LiveApp? app = session.current;
    runner.output.success(
      session.all
          ? 'Commands now run on every app (${session.apps.length})'
          : 'Commands now run on ${app?.device ?? 'the only running app'}',
    );
    return 0;
  }

  Future<int> _devices() async {
    try {
      final List<LiveSkippedApp> skipped = await session.refresh();
      final List<LiveApp> apps = session.apps;
      if (apps.isEmpty) {
        runner.output.note(
          'No running ${runner.project.packageName} app found. Start it with '
          'flutter run.',
        );
      } else {
        _printApps(apps);
        final LiveApp? current = session.current;
        if (current != null && apps.length > 1) {
          runner.output.note(
            'Commands run on ${current.device}. Pick another with use <#>.',
          );
        }
      }
      for (final LiveSkippedApp app in skipped) {
        runner.output.note('Skipped ${app.device}: ${app.reason}');
      }
      return 0;
    } on LiveDiscoveryException catch (e) {
      runner.output.error(e.message);
      return 1;
    } on LiveCommandException catch (e) {
      runner.output.error(e.message);
      return 1;
    }
  }

  void _printApps(List<LiveApp> apps) {
    runner.output.block(
      LiveBlock()
        ..heading(
          '${apps.length} ${apps.length == 1 ? 'app is' : 'apps are'} running:',
        )
        ..table(
          ['#', 'DEVICE', 'PLATFORM', 'MODE', 'ROUTE', 'APP'],
          [
            for (int i = 0; i < apps.length; i++)
              [
                '${i + 1}',
                apps[i].device,
                '${apps[i].status['platform'] ?? '-'}',
                '${apps[i].status['mode'] ?? '-'}',
                '${apps[i].status['route'] ?? '-'}',
                '${apps[i].status['app'] ?? '-'}',
              ],
          ],
        ),
    );
  }

  void _printPickError(({String error, List<LiveApp> candidates}) failure) {
    runner.output.error(failure.error);
    final List<LiveApp> apps = session.apps;
    for (final LiveApp app in failure.candidates) {
      runner.output.line('  ${apps.indexOf(app) + 1}  ${app.device}');
    }
  }

  // ---------------------------------------------------------------------------
  // Prompt
  // ---------------------------------------------------------------------------

  String _prompt() {
    final List<LiveApp> apps = session.apps;
    final LiveApp? app = session.current;
    final String label;
    if (session.all && apps.isNotEmpty) {
      label = _cyan('${apps.length} ${apps.length == 1 ? 'app' : 'devices'}');
    } else if (app != null) {
      final Object? route = app.status['route'];
      label = route == null
          ? _cyan(app.device)
          : '${_cyan(app.device)} ${_yellow('$route')}';
    } else if (session.missingDevice != null) {
      label = '${_cyan(session.missingDevice!)} ${_dim('(not running)')}';
    } else if (apps.isEmpty) {
      label = _dim('waiting for the app');
    } else {
      label = _dim('pick an app with use');
    }
    return '$label ${_dim('›')} ';
  }

  // ---------------------------------------------------------------------------
  // Completion
  // ---------------------------------------------------------------------------

  Future<List<String>> _complete(String line) async {
    final ({List<String> words, String current}) parts = splitForCompletion(
      line,
    );
    final String current = parts.current;
    if (parts.words.isEmpty) return _matching(_commandNames(), current);

    final String command = parts.words.first;
    if (current.startsWith('-')) {
      return _matching(await _optionsFor(command), current);
    }
    final List<String> candidates = switch (command) {
      'route' || 'back' => await _cached('routes', _routes),
      'storage' when parts.words.length == 1 => await _storageKeys(),
      'backpack' when parts.words.length == 1 => await _backpackKeys(),
      'auth' when parts.words.length == 1 => const ['login', 'logout'],
      'deeplink' when parts.words.length == 1 => _linkSchemes(),
      'data' when parts.words.length == 1 => await _statesOnScreen(),
      'seed' when parts.words.length == 1 => [
        ...await _cached('seeders', _seeders),
        ..._snapshotPaths(current),
      ],
      'seed' || 'seed:rollback' => await _cached('seeders', _seeders),
      'use' => [
        for (int i = 0; i < session.apps.length; i++) '${i + 1}',
        'all',
        'auto',
      ],
      'help' => _commandNames(),
      _ => const <String>[],
    };
    return _matching(candidates, current);
  }

  List<String> _matching(Iterable<String> candidates, String prefix) => [
    for (final String candidate in candidates)
      if (candidate.startsWith(prefix)) candidate,
  ];

  List<String> _commandNames() => {
    for (final LiveShellCommand command in commands) command.name,
    for (final LiveManifestEntry entry in appCommands) entry.fullName,
  }.toList();

  Future<List<String>> _optionsFor(String command) async {
    for (final LiveShellCommand known in commands) {
      if (known.name == command) return known.options;
    }
    final LiveApp? app = _completionApp;
    if (app == null) return const [];
    try {
      for (final LiveCommandSchema schema in LiveCommandSchema.listFromResult(
        await app.call('commands.list', null, _completionTimeout),
      )) {
        if (schema.name == command ||
            schema.name.endsWith(':$command') && !command.contains(':')) {
          return [
            for (final String option in schema.toArgParser().options.keys)
              '--$option',
          ];
        }
      }
    } catch (_) {
      // No suggestions when the app doesn't answer.
    }
    return const [];
  }

  Future<List<String>> _cached(
    String key,
    Future<List<String>> Function(LiveApp app) load,
  ) async {
    final LiveApp? app = _completionApp;
    if (app == null) return const [];
    final String cacheKey = '$key ${app.uri} ${app.isolateId}';
    final List<String>? known = _completionCache[cacheKey];
    if (known != null) return known;
    try {
      return _completionCache[cacheKey] = await load(app);
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _routes(LiveApp app) async {
    final Object? payload = await app.call('routes', null, _completionTimeout);
    final Object? routes = payload is Map ? payload['routes'] : null;
    return routes is List ? routes.map((route) => '$route').toList() : [];
  }

  Future<List<String>> _seeders(LiveApp app) async {
    final Object? payload = await app.call(
      'seeders.list',
      null,
      _completionTimeout,
    );
    final Object? seeders = payload is Map ? payload['seeders'] : null;
    return seeders is List
        ? [
            for (final Object? seeder in seeders)
              if (seeder is Map) '${seeder['name']}',
          ]
        : [];
  }

  /// The widget classes of the Nylo states on the page, for `data`.
  ///
  /// Never cached: the states on screen change with every navigation.
  Future<List<String>> _statesOnScreen() async {
    final LiveApp? app = _completionApp;
    if (app == null) return const [];
    try {
      final Object? payload = await app.call(
        'state.data',
        null,
        _completionTimeout,
      );
      final Object? states = payload is Map ? payload['states'] : null;
      return states is List
          ? [
              for (final Object? state in states)
                if (state is Map) '${state['widget']}',
            ]
          : const [];
    } catch (_) {
      // No suggestions when nothing on screen is a Nylo state.
      return const [];
    }
  }

  /// The link prefixes this project declares, for `deeplink`.
  ///
  /// Read from the project rather than the app, so they are there before the
  /// app has said anything.
  List<String> _linkSchemes() {
    try {
      return [
        for (final String scheme in PlatformLinks.read(runner.root).schemes)
          '$scheme://',
      ];
    } on LiveCommandException {
      return const [];
    }
  }

  /// The Backpack keys the app holds, for `backpack`.
  Future<List<String>> _backpackKeys() => _keysFrom('backpack.list');

  /// The local storage keys the app holds, for `storage`.
  Future<List<String>> _storageKeys() => _keysFrom('storage.list');

  /// The keys in the `items` [command] lists.
  ///
  /// Never cached: storage and the Backpack change as the app runs.
  Future<List<String>> _keysFrom(String command) async {
    final LiveApp? app = _completionApp;
    if (app == null) return const [];
    try {
      final Object? payload = await app.call(command, null, _completionTimeout);
      final Object? items = payload is Map ? payload['items'] : null;
      return items is List
          ? [
              for (final Object? item in items)
                if (item is Map) '${item['key']}',
            ]
          : const [];
    } catch (_) {
      // No suggestions when the app doesn't answer.
      return const [];
    }
  }

  /// The `.json` files and folders under the project that [prefix] could
  /// start, as paths relative to the project.
  List<String> _snapshotPaths(String prefix) {
    final int slash = prefix.lastIndexOf('/');
    final String directory = slash == -1 ? '' : prefix.substring(0, slash + 1);
    try {
      final String root = runner.project.root;
      final Directory folder = Directory(
        directory.isEmpty ? root : '$root/$directory',
      );
      final List<String> found = [];
      for (final FileSystemEntity entity in folder.listSync()) {
        final String name = entity.path.substring(
          entity.path.lastIndexOf(Platform.pathSeparator) + 1,
        );
        if (name.startsWith('.')) continue;
        if (entity is Directory) {
          found.add('$directory$name/');
        } else if (name.endsWith('.json')) {
          found.add('$directory$name');
        }
      }
      return found..sort();
    } catch (_) {
      return const [];
    }
  }

  LiveApp? get _completionApp {
    final LiveApp? current = session.current;
    if (current != null) return current;
    final List<LiveApp> apps = session.apps;
    return apps.isEmpty ? null : apps.first;
  }

  static const Duration _completionTimeout = Duration(seconds: 1);

  // ---------------------------------------------------------------------------
  // History and styling
  // ---------------------------------------------------------------------------

  List<String> _loadHistory() {
    final String? path = historyPath;
    if (path == null) return const [];
    try {
      final File file = File(path);
      if (!file.existsSync()) return const [];
      final List<String> lines = file
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .toList();
      return lines.length > _historyLimit
          ? lines.sublist(lines.length - _historyLimit)
          : lines;
    } on FileSystemException {
      return const [];
    }
  }

  void _saveHistory() {
    final String? path = historyPath;
    if (path == null || !terminal.hasTerminal) return;
    try {
      final File file = File(path);
      file.parent.createSync(recursive: true);
      final List<String> history = _editor.history;
      final List<String> kept = history.length > _historyLimit
          ? history.sublist(history.length - _historyLimit)
          : history;
      file.writeAsStringSync(kept.isEmpty ? '' : '${kept.join('\n')}\n');
    } on FileSystemException {
      // History is a convenience; carry on without it.
    }
  }

  String _style(String code, String text) =>
      terminal.supportsAnsi ? '\x1B[${code}m$text\x1B[0m' : text;

  String _bold(String text) => _style('1', text);

  String _dim(String text) => _style('90', text);

  String _cyan(String text) => _style('36', text);

  String _yellow(String text) => _style('33', text);

  static Stream<ProcessSignal>? _sigint() {
    try {
      return ProcessSignal.sigint.watch();
    } catch (_) {
      return null;
    }
  }
}

/// Splits a shell [line] into words the way a POSIX shell does: whitespace
/// separates words, quotes group them, a backslash escapes the next
/// character, and `#` at the start of a word begins a comment.
///
/// Throws a [FormatException] when a quote isn't closed.
List<String> splitLiveShellLine(String line) {
  final List<String> words = [];
  final StringBuffer word = StringBuffer();
  bool inWord = false;
  String? quote;

  for (int i = 0; i < line.length; i++) {
    final String char = line[i];
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else if (quote == '"' &&
          char == r'\' &&
          i + 1 < line.length &&
          r'"\$`'.contains(line[i + 1])) {
        word.write(line[++i]);
      } else {
        word.write(char);
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      inWord = true;
    } else if (char == r'\' && i + 1 < line.length) {
      word.write(line[++i]);
      inWord = true;
    } else if (char.trim().isEmpty) {
      if (inWord) {
        words.add(word.toString());
        word.clear();
        inWord = false;
      }
    } else if (char == '#' && !inWord) {
      break;
    } else {
      word.write(char);
      inWord = true;
    }
  }

  if (quote != null) {
    throw FormatException('Missing a closing $quote.');
  }
  if (inWord) words.add(word.toString());
  return words;
}

/// Splits the text before the cursor into the complete [words] and the
/// [current] word being typed, for Tab completion.
({List<String> words, String current}) splitForCompletion(String line) {
  int start = 0;
  String? quote;
  for (int i = 0; i < line.length; i++) {
    final String char = line[i];
    if (quote != null) {
      if (char == quote) quote = null;
    } else if (char == "'" || char == '"') {
      quote = char;
    } else if (char == r'\') {
      i++;
    } else if (char.trim().isEmpty) {
      start = i + 1;
    }
  }
  List<String> words;
  try {
    words = splitLiveShellLine(line.substring(0, start));
  } on FormatException {
    words = const [];
  }
  return (words: words, current: line.substring(start));
}
