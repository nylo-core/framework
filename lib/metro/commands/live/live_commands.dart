import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;

import 'package:recase/recase.dart';

import '/metro/live/live_app.dart';
import '/metro/live/live_discovery.dart';
import '/metro/live/live_manifest.dart';
import '/metro/live/live_options.dart';
import '/metro/live/live_platform_links.dart';
import '/metro/live/live_output.dart';
import '/metro/live/live_registry.dart';
import '/metro/live/live_runner.dart';
import '/metro/live/live_shell.dart';
import '/metro/live/live_snapshot.dart';
import '/metro/live/live_state_fields.dart';
import '/metro/ny_cli.dart';
import '/metro/stubs/snapshot_seeder_stub.dart';

/// The top-level `metro live:*` commands, keyed by command name.
///
/// Everything that acts on the app runs through `metro live:run <name>`.
final Map<String, Future<void> Function(List<String>)> liveBuiltInCommands = {
  'live': _runLiveShell,
  'live:devices': (args) => _LiveDevicesCommand(args).run(),
  'live:status': (args) => _LiveStatusCommand(args).run(),
  'live:run': _runLiveRunCommand,
};

/// A built-in action run with `metro live:run <name>`.
class LiveRunAction {
  /// Creates a [LiveRunAction] described by [description].
  const LiveRunAction(this.description, this.create);

  /// The one-line description shown by `metro live:run`.
  final String description;

  /// Creates the command with its arguments.
  final NyCustomCommand Function(List<String> arguments) create;

  /// Runs the action with its arguments, including any shared live flags.
  Future<void> run(List<String> arguments) => create(arguments).run();
}

/// The built-in actions of `metro live:run`, in the order they're listed.
///
/// A built-in action wins over an app command with the same name.
final Map<String, LiveRunAction> liveRunActions = {
  'data': LiveRunAction(
    'Show the data and fields of the page on screen',
    _LiveDataCommand.new,
  ),
  'routes': LiveRunAction('List the registered routes', _LiveRoutesCommand.new),
  'route': LiveRunAction(
    'Open a page, with optional --data',
    _LiveRouteCommand.new,
  ),
  'back': LiveRunAction(
    'Go back a page, or back to a route',
    _LiveBackCommand.new,
  ),
  'deeplink': LiveRunAction(
    'Open a deep link, or show how they are set up',
    _LiveDeepLinkCommand.new,
  ),
  'storage': LiveRunAction(
    'List local storage, or show, save or delete one value',
    _LiveStorageCommand.new,
  ),
  'storage:clear': LiveRunAction(
    'Clear local storage, with optional --keep',
    _LiveStorageClearCommand.new,
  ),
  'backpack': LiveRunAction(
    'List Backpack values, or show, save or delete one',
    _LiveBackpackCommand.new,
  ),
  'auth': LiveRunAction(
    'Show who is signed in, or sign in and out',
    _LiveAuthCommand.new,
  ),
  'locale': LiveRunAction('Switch the app\'s language', _LiveLocaleCommand.new),
  'theme': LiveRunAction('Switch the app\'s theme', _LiveThemeCommand.new),
  'state': LiveRunAction(
    'Send data to a state with updateState',
    _LiveStateCommand.new,
  ),
  'event': LiveRunAction('Fire one of your events', _LiveEventCommand.new),
  'toast': LiveRunAction('Show a toast notification', _LiveToastCommand.new),
};

/// Live commands another one took over, and what to type instead.
///
/// They were commands of their own until their argument told them apart, so a
/// developer's muscle memory - and any live script written before - still
/// reaches for them.
const Map<String, String> liveCommandsMoved = {
  'storage:get': 'storage <key>',
  'storage:set': 'storage <key> <value>',
  'storage:delete': 'storage <key> --delete',
  'backpack:get': 'backpack <key>',
  'backpack:set': 'backpack <key> <value>',
  'backpack:delete': 'backpack <key> --delete',
  'login': 'auth login --data <json>',
  'logout': 'auth logout',
  'import': 'seed <file>',
};

/// The message for [name] when it moved, or null when it didn't.
///
/// [runner] says where the replacement is typed from: `storage` and friends
/// run through `live:run`, while `seed` only runs inside `metro live`.
String? liveCommandMoved(String name, {LiveRunner? runner}) {
  final String? now = liveCommandsMoved[name];
  if (now == null) return null;
  final String head = now.split(' ').first;
  final String where;
  if (liveRunActions.containsKey(head)) {
    where = runner?.runActionName(now) ?? 'metro live:run $now';
  } else if (_isShellOnly(head)) {
    where = runner == null ? '$now inside metro live' : now;
  } else {
    where = runner?.commandName(now) ?? 'metro live:$now';
  }
  return '"$name" is now $where';
}

/// Whether [name] is a `metro live` command with no `live:<name>` of its own.
bool _isShellOnly(String name) =>
    _liveShellBuiltIns.containsKey(name) &&
    !liveBuiltInCommands.containsKey('live:$name');

/// Splits `metro live:run` arguments into the command [name] and everything/// Splits `metro live:run` arguments into the command [name] and everything
/// else, keeping the shared live flags (wherever they appear) in [arguments].
///
/// [name] is null when no command name comes before the first argument that
/// isn't a shared live flag; that argument (e.g. `--help`, or a command's own
/// option) is returned as [stoppedAt].
({String? name, List<String> arguments, String? stoppedAt})
splitLiveRunArguments(List<String> arguments) {
  const Set<String> flagsWithValues = {'-d', '--device', '--uri', '--timeout'};
  for (int i = 0; i < arguments.length; i++) {
    final String arg = arguments[i];
    if (flagsWithValues.contains(arg)) {
      i++;
      continue;
    }
    if (arg == '--all' ||
        arg == '--json' ||
        arg.startsWith('--device=') ||
        arg.startsWith('--uri=') ||
        arg.startsWith('--timeout=')) {
      continue;
    }
    if (arg.startsWith('-')) {
      return (name: null, arguments: arguments, stoppedAt: arg);
    }
    return (
      name: arg,
      arguments: [...arguments.sublist(0, i), ...arguments.sublist(i + 1)],
      stoppedAt: null,
    );
  }
  return (name: null, arguments: arguments, stoppedAt: null);
}

/// The `metro live:run` help: the built-in actions, then the project's live
/// commands from `commands.json`.
String liveRunUsage(List<LiveManifestEntry> projectCommands) {
  final List<LiveManifestEntry> sorted = List<LiveManifestEntry>.of(
    projectCommands,
  )..sort((a, b) => a.fullName.compareTo(b.fullName));
  final int width = [
    ...liveRunActions.keys,
    ...sorted.map((entry) => entry.fullName),
  ].map((name) => name.length).reduce((a, b) => a > b ? a : b);

  final StringBuffer buffer = StringBuffer()
    ..writeln('Usage: metro live:run <command> [arguments]')
    ..writeln()
    ..writeln('Built-in commands:');
  for (final MapEntry<String, LiveRunAction> action in liveRunActions.entries) {
    buffer.writeln(
      '  ${action.key.padRight(width + 2)}${action.value.description}',
    );
  }

  buffer
    ..writeln()
    ..writeln('Your commands (lib/app/commands):');
  if (sorted.isEmpty) {
    buffer.writeln(
      '  None yet. Create one with: metro make:command seed_cart --live',
    );
  }
  for (final LiveManifestEntry entry in sorted) {
    buffer.writeln(
      '  ${entry.fullName.padRight(width + 2)}${entry.description ?? ''}'
          .trimRight(),
    );
  }

  buffer
    ..writeln()
    ..writeln('Run metro live:run <command> --help for its options.')
    ..writeln()
    ..writeln('Options for every command:')
    ..write(LiveOptions.usage.split('\n').map((line) => '  $line').join('\n'));
  return buffer.toString();
}

/// Shared plumbing for the built-in live commands: the `-d/--device`,
/// `--all`, `--json`, `--uri` and `--timeout` flags, argument errors, and
/// exit codes.
abstract class _LiveBuiltInCommand extends NyCustomCommand {
  _LiveBuiltInCommand(super.arguments);

  /// An example invocation shown in `--help`, without the `metro` prefix.
  String get example;

  /// The `--help` line: [example] as it's typed.
  String get exampleHelp => 'e.g. metro $example';

  /// Adds the command's own options and flags.
  void options(CommandBuilder command) {}

  /// Runs the command with the parsed [result] and shared [options].
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  );

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag('help', abbr: 'h', help: exampleHelp);
    options(command);
    command.addOption(
      'device',
      abbr: 'd',
      help:
          'Target an app by its number in `metro live:devices` or its device '
          'name.',
    );
    command.addFlag('all', help: 'Run on every running app of this project.');
    command.addFlag('json', help: 'Print machine-readable JSON.');
    command.addOption(
      'uri',
      help: 'Use this VM service address instead of discovering apps.',
    );
    command.addOption(
      'timeout',
      help: 'Seconds to wait for each app while discovering.',
      defaultValue: '3',
    );
    return command;
  }

  @override
  Future<void> run() async {
    try {
      arguments = expandLiveFileArguments(arguments);
      await super.run();
    } on FormatException catch (e) {
      error(e.message);
      print('\nUsage:\n${builder(CommandBuilder()).usage}');
      exit(64);
    } on _LiveUsageError catch (e) {
      error(e.message);
      exit(e.exitCode);
    }
  }

  /// Runs the command on [runner]'s apps and returns its exit code.
  ///
  /// Unlike [run], mistakes in the arguments are printed rather than ending
  /// Metro, so `metro live` can carry on.
  Future<int> runWith(LiveRunner runner) async {
    final CommandBuilder command = builder(CommandBuilder());
    try {
      final List<String> expanded = expandLiveFileArguments(arguments);
      if (expanded.contains('--help') || expanded.contains('-h')) {
        runner.output.line('Usage:\n${command.usage}');
        return 0;
      }
      final CommandResult result = command.parse(expanded);
      return await execute(result, _options(result), runner);
    } on FormatException catch (e) {
      runner.output.error(e.message);
      runner.output.line('\nUsage:\n${command.usage}');
      return 64;
    } on _LiveUsageError catch (e) {
      runner.output.error(e.message);
      return e.exitCode;
    }
  }

  /// Ends the command with [message]; [run] exits with [exitCode] and
  /// [runWith] returns it.
  @override
  Never abort([String? message, int exitCode = 1]) => throw _LiveUsageError(
    message ?? 'The arguments aren\'t valid.',
    exitCode,
  );

  @override
  Future<void> handle(CommandResult result) async {
    final int code = await execute(result, _options(result), LiveRunner());
    if (code != 0) exit(code);
  }

  LiveOptions _options(CommandResult result) => LiveOptions(
    device: result.getString('device'),
    all: result.getBool('all') ?? false,
    json: result.getBool('json') ?? false,
    uri: result.getString('uri'),
    timeout: LiveOptions.parseTimeout(result.getString('timeout')),
  );

  /// The positional argument at [index], or null.
  String? positional(CommandResult result, int index) =>
      result.rest.length > index ? result.rest[index] : null;

  /// The positional argument at [index], or exits with [message].
  String requirePositional(CommandResult result, int index, String message) {
    final String? value = positional(result, index)?.trim();
    if (value == null || value.isEmpty) {
      abort('$message\n\nUsage:\n${builder(CommandBuilder()).usage}', 64);
    }
    return value;
  }
}

/// A live command that only runs inside `metro live`, with no `metro live:*`
/// of its own, so its [example] is typed as it is.
abstract class _LiveShellOnlyCommand extends _LiveBuiltInCommand {
  _LiveShellOnlyCommand(super.arguments);

  @override
  String get exampleHelp => 'e.g. $example';
}

/// A mistake in a live command's arguments.
class _LiveUsageError implements Exception {
  _LiveUsageError(this.message, this.exitCode);

  final String message;
  final int exitCode;
}

/// Decodes [text] as JSON, exiting with a clear message when it isn't.
Object? _decodeJsonArgument(String flag, String text) {
  try {
    return jsonDecode(text);
  } on FormatException catch (e) {
    throw FormatException('$flag must be valid JSON (${e.message}).');
  }
}

/// JSON when [text] is valid JSON, otherwise the text itself.
Object? _jsonOrString(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : <String, Object?>{};

String _stack(Object? stack) =>
    stack is List && stack.isNotEmpty ? stack.join(' → ') : '(empty)';

// ---------------------------------------------------------------------------
// Inspect
// ---------------------------------------------------------------------------

class _LiveDevicesCommand extends _LiveBuiltInCommand {
  _LiveDevicesCommand(super.arguments);

  @override
  String get example => 'live:devices';

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) async {
    final LiveDiscoveryResult discovered;
    try {
      discovered = await runner.discover(options);
    } on LiveDiscoveryException catch (e) {
      runner.output.error(e.message);
      return 1;
    } on LiveCommandException catch (e) {
      runner.output.error(e.message);
      return 1;
    }

    final List<LiveApp> apps = discovered.apps;
    if (options.json) {
      runner.output.json([
        for (int i = 0; i < apps.length; i++)
          {
            'index': i + 1,
            'device': apps[i].device,
            'package': apps[i].package,
            'uri': apps[i].uri.toString(),
            'status': apps[i].status,
          },
      ]);
    } else if (apps.isEmpty) {
      runner.output.note(
        'No running ${runner.project.packageName} app found. Start it with '
        '`flutter run` (a debug build) and try again.',
      );
      runner.printSkipped(discovered.skipped);
    } else {
      final LiveBlock block = LiveBlock()
        ..heading('Running apps for ${runner.project.packageName}:')
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
        );
      runner.output.block(block);
      runner.printSkipped(discovered.skipped);
    }

    await Future.wait(apps.map((app) => app.close()));
    return 0;
  }
}

class _LiveStatusCommand extends _LiveBuiltInCommand {
  _LiveStatusCommand(super.arguments);

  @override
  String get example => 'live:status';

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    return runner.run(options, (app, block) async {
      final Map<String, Object?> status = _map(await app.call('status'));
      app.status = status;
      renderStatus(block, app.device, status);
      return status;
    });
  }
}

/// Adds the `live:status` view of [status] for [device] to [block].
void renderStatus(LiveBlock block, String device, Map<String, Object?> status) {
  final Object? authenticated = status['authenticated'];
  final Object? commands = status['commands'];
  final String platform = [
    status['platform'],
    status['osVersion'],
  ].where((part) => part != null && '$part'.isNotEmpty).join(' · ');

  final List<List<String>> rows = [
    [
      'App',
      '${status['app'] ?? '-'}${status['env'] != null ? ' (${status['env']})' : ''}',
    ],
    ['Device', platform.isEmpty ? device : '$device · $platform'],
    ['Mode', '${status['mode'] ?? '-'}'],
    ['Route', '${status['route'] ?? '-'}'],
    ['Stack', _stack(status['stack'])],
    ['Locale', '${status['locale'] ?? '-'}'],
    ['Theme', '${status['theme'] ?? '-'}'],
    [
      'Authenticated',
      authenticated == null
          ? 'not configured'
          : (authenticated == true ? 'yes' : 'no'),
    ],
    [
      'Live commands',
      commands is List && commands.isNotEmpty ? commands.join(', ') : 'none',
    ],
    if (status['seeders'] case final Object? seeders?)
      [
        'Seeders',
        seeders is List && seeders.isNotEmpty ? seeders.join(', ') : 'none',
      ],
  ];
  final int width = rows
      .map((row) => row.first.length)
      .reduce((a, b) => a > b ? a : b);
  for (final List<String> row in rows) {
    block.plain('${row.first.padRight(width + 2)}${row.last}');
  }
}

class _LiveDataCommand extends _LiveBuiltInCommand {
  _LiveDataCommand(super.arguments);

  @override
  String get example => 'live:run data';

  @override
  void options(CommandBuilder command) {
    command.addFlag(
      'fields',
      help:
          'Read the fields the state class declares (use --no-fields to skip '
          'them).',
      defaultValue: true,
    );
    command.addFlag(
      'full',
      help: 'Print values in full instead of shortening them.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String? target = positional(result, 0);
    final bool wantsFields = result.getBool('fields') ?? true;
    final bool full = result.getBool('full') ?? false;

    return runner.run(options, (app, block) async {
      _requireProtocol(app, 3, 'reading a page\'s data');
      final Map<String, Object?> payload = _map(
        await app.call('state.data', {'target': ?target}),
      );

      List<LiveStateField>? fields;
      String? unavailable;
      if (wantsFields) {
        try {
          fields = await LiveStateFields.read(
            app,
            _map(payload['inspect']),
            timeout: LiveRunner.commandTimeout,
          );
        } on LiveStateFieldsUnavailable catch (e) {
          unavailable = e.message;
        }
      }

      renderStateData(
        block,
        payload,
        fields: fields,
        unavailable: unavailable,
        full: full,
        target: runner.runActionName('data'),
      );
      return {
        // `inspect` only tells Metro where to read the fields from.
        ...payload..remove('inspect'),
        if (fields != null)
          'fields': [for (final LiveStateField field in fields) field.toJson()],
      };
    });
  }
}

/// Adds the `data` view of a `state.data` [payload] to [block]: what the page
/// is, the data it was opened with, and the [fields] its state declares.
///
/// [unavailable] explains why [fields] is null when the app couldn't be read.
/// Values are shortened to one line unless [full]. [target] is how to run the
/// command again for another state.
void renderStateData(
  LiveBlock block,
  Map<String, Object?> payload, {
  List<LiveStateField>? fields,
  String? unavailable,
  bool full = false,
  String target = 'metro live:run data',
}) {
  final Map<String, Object?> state = _map(payload['state']);
  block.heading('${state['widget'] ?? 'The page'} · ${state['kind'] ?? '-'}');

  final Object? actions = state['actions'];
  final List<List<String>> rows = [
    if (state['name'] != null) ['state', '${state['name']}'],
    if (payload['route'] != null) ['route', '${payload['route']}'],
    if (state['controller'] != null) ['controller', '${state['controller']}'],
    if (actions is List && actions.isNotEmpty) ['actions', actions.join(', ')],
  ];
  final int width = rows
      .map((List<String> row) => row.first.length)
      .fold(0, (int a, int b) => a > b ? a : b);
  for (final List<String> row in rows) {
    block.plain('  ${row.first.padRight(width + 2)}${row.last}');
  }

  block
    ..plain('')
    ..heading('data');
  if (state['data'] != null) {
    block.json(state['data']);
  } else if (state['controller'] == null) {
    // data() reads the route arguments off a NyStatefulWidget's controller.
    block.note(
      'Nothing: only a NyStatefulWidget is given the data a route carries',
    );
  } else {
    block.note('No data was passed to this page');
  }

  if (state['queryParameters'] != null) {
    block
      ..plain('')
      ..heading('queryParameters')
      ..json(state['queryParameters']);
  }

  if (unavailable != null) {
    block
      ..plain('')
      ..heading('fields')
      ..note(unavailable);
  } else if (fields != null) {
    block.plain('');
    renderStateFields(block, fields, full: full);
  }

  renderOtherStates(block, payload, target: target);
}

/// Adds a `fields` section for the [fields] of a state to [block].
void renderStateFields(
  LiveBlock block,
  List<LiveStateField> fields, {
  bool full = false,
}) {
  block.heading('fields');
  if (fields.isEmpty) {
    block.note('This state declares no fields of its own');
    return;
  }

  if (full) {
    for (final LiveStateField field in fields) {
      block
        ..plain('')
        ..plain('  ${field.name}  ${_fieldSuffix(field)}'.trimRight());
      if (field.unread != null) {
        block.note(field.unread!);
      } else {
        block.json(field.value);
      }
    }
    return;
  }

  final int width = fields
      .map((LiveStateField field) => field.name.length)
      .fold(0, (int a, int b) => a > b ? a : b);
  for (final LiveStateField field in fields) {
    final String suffix = _fieldSuffix(field);
    block.plain(
      '  ${field.name.padRight(width + 2)}${_fieldValue(field)}'
              '${suffix.isEmpty ? '' : '  $suffix'}'
          .trimRight(),
    );
  }
}

/// Adds the other Nylo states on screen, and how to look at one, to [block].
void renderOtherStates(
  LiveBlock block,
  Map<String, Object?> payload, {
  String target = 'metro live:run data',
}) {
  final Object? listed = payload['states'];
  if (listed is! List) return;
  final Object? shown = _map(payload['state'])['state'];
  final List<Map<String, Object?>> others = [
    for (final Object? state in listed)
      if (state is Map && state['state'] != shown) _map(state),
  ];
  if (others.isEmpty) return;

  block
    ..plain('')
    ..heading('Also on screen')
    ..table(
      ['WIDGET', 'STATE', 'KIND'],
      [
        for (final Map<String, Object?> state in others)
          ['${state['widget']}', '${state['name'] ?? '-'}', '${state['kind']}'],
      ],
    )
    ..note('Look at one with $target ${others.first['widget']}');
}

/// The one-line rendering of a field's value.
String _fieldValue(LiveStateField field) {
  if (field.unread != null) return '(${field.unread})';
  // `Instance of 'ScrollController'` says no more than the type does.
  if (field.isOpaque) return field.type;
  return LiveFormat.value(field.value, max: 80);
}

/// The `· 12 items` note after a collection field's value.
String _fieldSuffix(LiveStateField field) {
  final int? count = field.count;
  if (count == null) return '';
  final String items = '$count ${count == 1 ? 'item' : 'items'}';
  return field.truncated ? '· $items, first shown' : '· $items';
}

class _LiveRoutesCommand extends _LiveBuiltInCommand {
  _LiveRoutesCommand(super.arguments);

  @override
  String get example => 'live:run routes';

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(await app.call('routes'));
      final Object? routes = payload['routes'];
      if (routes is! List || routes.isEmpty) {
        block.note('No routes are registered');
        return payload;
      }
      final List<String> paths = routes.map((route) => '$route').toList();
      final int width = paths
          .map((path) => path.length)
          .reduce((a, b) => a > b ? a : b);
      for (final String path in paths) {
        final List<String> markers = [
          if (payload['initial'] == path) 'initial',
          if (payload['auth'] == path) 'auth',
          if (payload['unknown'] == path) 'unknown',
        ];
        block.plain(
          markers.isEmpty
              ? path
              : '${path.padRight(width + 2)}${markers.join(', ')}',
        );
      }
      return payload;
    });
  }
}

class _LiveDeepLinkCommand extends _LiveBuiltInCommand {
  _LiveDeepLinkCommand(super.arguments);

  @override
  String get example => 'live:run deeplink myapp://product/42';

  @override
  void options(CommandBuilder command) {
    command.addFlag(
      'dry',
      help: 'Say where the link would go without going there.',
    );
    command.addFlag(
      'callback',
      help: 'Run onIncomingLink (use --no-callback to route straight past it).',
      defaultValue: true,
    );
    command.addFlag(
      'cold',
      help: 'Hot restart first, so the link arrives at a freshly started app.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String? link = positional(result, 0);
    final bool dry = result.getBool('dry') ?? false;
    final bool callback = result.getBool('callback') ?? true;
    final bool cold = result.getBool('cold') ?? false;

    if (link == null) {
      if (dry || cold || !callback) {
        abort('A link is required, e.g. metro $example', 64);
      }
      final PlatformLinks platform = PlatformLinks.read(runner.root);
      return runner.run(options, (app, block) async {
        _requireProtocol(app, 8, 'deep links');
        final Map<String, Object?> payload = _map(
          await app.call('deeplink.show'),
        );
        renderDeepLinkSetup(block, payload, platform);
        return {...payload, 'platform': platform.toJson()};
      });
    }

    // A path alone would skip the parsing that most often goes wrong, and
    // `route` already does that job.
    final Uri? uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme) {
      abort(
        '"$link" isn\'t a link. It needs a scheme, e.g. myapp://product/42.\n'
        'To go straight to a path, use ${runner.runActionName('route $link')}.',
        64,
      );
    }
    if (cold && dry) {
      abort('--cold restarts the app, so it can\'t be used with --dry.', 64);
    }

    final PlatformLinks platform = PlatformLinks.read(runner.root);
    return runner.run(options, (app, block) async {
      _requireProtocol(app, 8, 'deep links');
      if (cold) {
        final Duration took = await app.restart();
        block.note('Restarted in ${took.inMilliseconds}ms');
      }
      final Map<String, Object?> payload = _map(
        await app.call('deeplink.open', {
          'uri': link,
          if (dry) 'dry': true,
          if (!callback) 'callback': false,
        }, LiveRunner.commandTimeout),
      );
      renderDeepLink(block, payload, platform);
      return {...payload, 'platform': platform.toJson()};
    });
  }
}

/// Adds the outcome of a `deeplink.open` [payload] to [block], stage by
/// stage, so a link that goes nowhere says which step dropped it.
void renderDeepLink(
  LiveBlock block,
  Map<String, Object?> payload,
  PlatformLinks platform,
) {
  block.note('${payload['uri']} → ${payload['path']}');

  if (payload['registered'] != true) {
    block.warning(
      payload['usedFallback'] == true
          ? '${payload['path']} isn\'t registered — falling back to '
                '${payload['target']}'
          : '${payload['path']} isn\'t registered, and no fallbackRoute is '
                'set — the unknown route handles it',
    );
  }

  switch (payload['callback']) {
    case 'continued':
      block.note('onIncomingLink continued');
    case 'stopped':
      block.warning('onIncomingLink returned false, so nothing was routed');
    case 'skipped':
      block.note('onIncomingLink skipped');
  }

  final Object? query = payload['queryParameters'];
  final String parameters = query is Map && query.isNotEmpty
      ? '  ${query.entries.map((e) => '${e.key}=${e.value}').join(' ')}'
      : '';

  if (payload['dry'] == true) {
    block
      ..success('Would open ${payload['target']}$parameters')
      ..note('Nothing was sent to the app');
  } else if (payload['routed'] == true) {
    block.success(
      '${payload['from'] ?? '-'} → ${payload['current'] ?? payload['target']}'
      '$parameters',
    );
  } else {
    block.note('Stayed on ${payload['current'] ?? '-'}');
  }

  renderPlatformReach(block, payload['uri'], platform);
}

/// Warns when the platform wouldn't deliver a link the app just routed.
///
/// The app never sees the scheme, so this is the one half `deeplink` can
/// only answer from the project's own iOS and Android config.
void renderPlatformReach(
  LiveBlock block,
  Object? link,
  PlatformLinks platform,
) {
  final String? scheme = Uri.tryParse('$link')?.scheme;
  if (scheme == null || scheme.isEmpty || platform.isEmpty) return;
  if (platform.accepts(scheme)) return;
  block.warning(
    'Routed in the app, but "$scheme" isn\'t declared in this project. '
    'A real link with that scheme wouldn\'t reach it'
    '${platform.schemes.isEmpty ? '' : ' (declared: ${platform.schemes.join(', ')})'}.',
  );
}

/// Adds the `deeplink` setup view: what the app does with links, and what
/// the project's platform config lets in.
void renderDeepLinkSetup(
  LiveBlock block,
  Map<String, Object?> payload,
  PlatformLinks platform,
) {
  final Object? routes = payload['routes'];
  final int count = routes is List ? routes.length : 0;
  final List<List<String>> rows = [
    ['Deep links', payload['enabled'] == true ? 'on' : 'off'],
    ['Fallback route', '${payload['fallbackRoute'] ?? '-'}'],
    ['onIncomingLink', payload['hasCallback'] == true ? 'set' : 'not set'],
    if (platform.iosFound)
      [
        'iOS schemes',
        platform.iosSchemes.isEmpty ? '-' : platform.iosSchemes.join(', '),
      ],
    if (platform.iosDomains.isNotEmpty)
      ['iOS domains', platform.iosDomains.join(', ')],
    if (platform.androidFound)
      [
        'Android schemes',
        platform.androidSchemes.isEmpty
            ? '-'
            : platform.androidSchemes.join(', '),
      ],
    if (platform.androidHosts.isNotEmpty)
      ['Android hosts', platform.androidHosts.join(', ')],
    ['Routes', '$count registered'],
  ];
  final int width = rows
      .map((List<String> row) => row.first.length)
      .reduce((int a, int b) => a > b ? a : b);
  for (final List<String> row in rows) {
    block.plain('${row.first.padRight(width + 2)}${row.last}');
  }

  if (payload['enabled'] != true) {
    block.note(
      'Links still resolve here, but the app won\'t receive real ones until '
      'you call nylo.useDeepLinks() in a provider.',
    );
  }
}

class _LiveStorageCommand extends _LiveBuiltInCommand {
  _LiveStorageCommand(super.arguments);

  @override
  String get example => 'live:run storage SK_COINS 10';

  @override
  void options(CommandBuilder command) {
    command.addFlag(
      'delete',
      // -d is --device on every live command, so delete takes -D.
      abbr: 'D',
      help: 'Remove the key from local storage and the Backpack.',
    );
    command.addOption(
      'ttl',
      help: 'Saving: expire the value after this many seconds.',
    );
    command.addFlag(
      'backpack',
      help: 'Saving: also put the value in Backpack.',
    );
    command.addFlag(
      'string',
      help: 'Saving: keep the value as text, even if it looks like JSON.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String? key = positional(result, 0);
    final bool delete = result.getBool('delete') ?? false;
    // A second argument is the value to save; everything after it joins on.
    final bool saving = result.rest.length > 1;

    final String? ttlText = result.getString('ttl');
    final bool inBackpack = result.getBool('backpack') ?? false;
    final bool asString = result.getBool('string') ?? false;
    final List<String> savingOnly = [
      if (ttlText != null) '--ttl',
      if (inBackpack) '--backpack',
      if (asString) '--string',
    ];
    if (!saving && savingOnly.isNotEmpty) {
      abort(
        '${_andList(savingOnly)} '
        '${savingOnly.length == 1 ? 'only works' : 'only work'} when saving a '
        'value, e.g. ${runner.runActionName('storage SK_COINS 10')}',
        64,
      );
    }

    if (delete) {
      if (key == null) {
        abort(
          'A key is required to delete. To empty local storage, use '
          '${runner.runActionName('storage:clear')}.\n\n'
          'Usage:\n${builder(CommandBuilder()).usage}',
          64,
        );
      }
      if (saving) {
        abort('Use --delete with a key on its own, not with a value.', 64);
      }
      return runner.run(options, (app, block) async {
        final Map<String, Object?> payload = _map(
          await app.call('storage.delete', {'key': key}),
        );
        if (payload['existed'] == false) {
          block.note('$key wasn\'t set');
        } else {
          block.success('Deleted $key');
        }
        return payload;
      });
    }

    if (saving) {
      final String text = result.rest.sublist(1).join(' ');
      final Object? value = asString ? text : _jsonOrString(text);
      int? ttl;
      if (ttlText != null) {
        ttl = int.tryParse(ttlText);
        if (ttl == null || ttl <= 0) {
          abort('--ttl must be a positive number of seconds.', 64);
        }
      }
      return runner.run(options, (app, block) async {
        final Map<String, Object?> payload = _map(
          await app.call('storage.set', {
            'key': key,
            'value': value,
            'ttl': ?ttl,
            if (inBackpack) 'backpack': true,
          }),
        );
        final Object? expiresAt = payload['expiresAt'];
        block.success(
          'Saved $key (${payload['type'] ?? 'value'})'
          '${expiresAt != null ? ', expires $expiresAt' : ''}',
        );
        return payload;
      });
    }

    return runner.run(options, (app, block) async {
      if (key == null) {
        final Map<String, Object?> payload = _map(
          await app.call('storage.list'),
        );
        renderItems(block, payload['items'], empty: 'Storage is empty');
        return payload;
      }
      final Map<String, Object?> payload = _map(
        await app.call('storage.get', {'key': key}),
      );
      renderStoredValue(block, key, payload, missing: '$key isn\'t set');
      return payload;
    });
  }
}

/// [items] written out for a sentence: `a`, `a and b`, `a, b and c`.
String _andList(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

/// Adds a KEY / TYPE / VALUE (/ EXPIRES) table for storage-style [items].
void renderItems(LiveBlock block, Object? items, {required String empty}) {
  if (items is! List || items.isEmpty) {
    block.note(empty);
    return;
  }
  final List<Map<String, Object?>> rows = items.map(_map).toList()
    ..sort((a, b) => '${a['key']}'.compareTo('${b['key']}'));
  final bool expires = rows.any((row) => row['expiresAt'] != null);
  block.table(
    ['KEY', 'TYPE', 'VALUE', if (expires) 'EXPIRES'],
    [
      for (final Map<String, Object?> row in rows)
        [
          '${row['key']}',
          '${row['type'] ?? '-'}',
          LiveFormat.value(row['value']),
          if (expires) '${row['expiresAt'] ?? ''}',
        ],
    ],
  );
}

class _LiveStorageClearCommand extends _LiveBuiltInCommand {
  _LiveStorageClearCommand(super.arguments);

  @override
  String get example => 'live:run storage:clear --keep SK_USER';

  @override
  void options(CommandBuilder command) {
    command.addOption(
      'keep',
      help: 'Comma-separated keys to keep, e.g. --keep SK_USER,SK_BEARER_TOKEN',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final List<String> keep = (result.getString('keep') ?? '')
        .split(',')
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toList();
    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(
        await app.call('storage.clear', {if (keep.isNotEmpty) 'keep': keep}),
      );
      final Object? kept = payload['kept'];
      block.success(
        kept is List && kept.isNotEmpty
            ? 'Cleared storage (kept ${kept.join(', ')})'
            : 'Cleared storage',
      );
      return payload;
    });
  }
}

class _LiveBackpackCommand extends _LiveBuiltInCommand {
  _LiveBackpackCommand(super.arguments);

  @override
  String get example => 'live:run backpack auth_user';

  @override
  void options(CommandBuilder command) {
    command.addFlag(
      'delete',
      // -d is --device on every live command, so delete takes -D.
      abbr: 'D',
      help: 'Remove the key from the Backpack, leaving local storage alone.',
    );
    command.addFlag(
      'string',
      help: 'Saving: keep the value as text, even if it looks like JSON.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String? key = positional(result, 0);
    final bool delete = result.getBool('delete') ?? false;
    // A second argument is the value to save; everything after it joins on.
    final bool saving = result.rest.length > 1;
    final bool asString = result.getBool('string') ?? false;

    if (!saving && asString) {
      abort(
        '--string only works when saving a value, e.g. '
        '${runner.runActionName('backpack auth_user \'{"id": 1}\'')}',
        64,
      );
    }

    if (delete) {
      if (key == null) {
        abort(
          'A key is required to delete.\n\n'
          'Usage:\n${builder(CommandBuilder()).usage}',
          64,
        );
      }
      if (saving) {
        abort('Use --delete with a key on its own, not with a value.', 64);
      }
      return runner.run(options, (app, block) async {
        _requireProtocol(app, 5, 'deleting a Backpack value');
        final Map<String, Object?> payload = _map(
          await app.call('backpack.delete', {'key': key}),
        );
        if (payload['existed'] == false) {
          block.note('$key wasn\'t in the Backpack');
        } else {
          block.success('Deleted $key from the Backpack');
        }
        return payload;
      });
    }

    if (saving) {
      final String text = result.rest.sublist(1).join(' ');
      final Object? value = asString ? text : _jsonOrString(text);
      return runner.run(options, (app, block) async {
        _requireProtocol(app, 6, 'saving a Backpack value');
        final Map<String, Object?> payload = _map(
          await app.call('backpack.set', {'key': key, 'value': value}),
        );
        block.success(
          'Saved $key to the Backpack (${payload['type'] ?? 'value'})',
        );
        return payload;
      });
    }

    return runner.run(options, (app, block) async {
      if (key == null) {
        final Map<String, Object?> payload = _map(
          await app.call('backpack.list'),
        );
        renderItems(block, payload['items'], empty: 'Backpack is empty');
        return payload;
      }

      _requireProtocol(app, 4, 'showing one Backpack value');
      final Map<String, Object?> payload = _map(
        await app.call('backpack.get', {'key': key}),
      );
      renderStoredValue(
        block,
        key,
        payload,
        missing: '$key isn\'t in the Backpack',
      );
      return payload;
    });
  }
}

/// Adds the whole value the app holds for [key] to [block], untruncated.
///
/// [missing] is the note shown when the app holds no value for it.
void renderStoredValue(
  LiveBlock block,
  String key,
  Map<String, Object?> payload, {
  required String missing,
}) {
  if (payload['exists'] != true) {
    block.note(missing);
    return;
  }
  final Object? expiresAt = payload['expiresAt'];
  block.heading(
    '$key  ${payload['type'] ?? ''}'
            '${expiresAt != null ? '  expires $expiresAt' : ''}'
        .trimRight(),
  );
  final Object? value = payload['value'];
  if (value is Map || value is List) {
    block.json(value);
  } else {
    block.plain('$value');
  }
}

// ---------------------------------------------------------------------------
// Navigate
// ---------------------------------------------------------------------------

class _LiveRouteCommand extends _LiveBuiltInCommand {
  _LiveRouteCommand(super.arguments);

  @override
  String get example => 'live:run route /profile --data \'{"id": 42}\'';

  @override
  void options(CommandBuilder command) {
    command.addOption('data', help: 'JSON data passed to the page.');
    command.addFlag('replace', help: 'Replace the current route.');
    command.addFlag('clear', help: 'Remove every other route from the stack.');
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    String path = requirePositional(result, 0, 'A route path is required.');
    if (!path.startsWith('/')) path = '/$path';

    final bool replace = result.getBool('replace') ?? false;
    final bool clear = result.getBool('clear') ?? false;
    if (replace && clear) {
      abort('Use either --replace or --clear, not both.', 64);
    }

    final String? dataText = result.getString('data');
    final Object? data = dataText == null
        ? null
        : _decodeJsonArgument('--data', dataText);

    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(
        await app.call('route.push', {
          'path': path,
          'data': ?data,
          if (replace) 'navigation': 'replace',
          if (clear) 'navigation': 'clear',
        }),
      );
      renderRouteChange(block, path, payload);
      return payload;
    });
  }
}

/// Adds the outcome of a `route.push` to [path] to [block].
void renderRouteChange(
  LiveBlock block,
  String path,
  Map<String, Object?> payload,
) {
  final Object? from = payload['from'];
  final Object? current = payload['current'];
  if (payload['changed'] == false) {
    block.note(
      'Stayed on ${current ?? from ?? 'the current page'}. A route guard may '
      'have stopped the navigation to $path.',
    );
    return;
  }
  final String redirected = current != null && current != path
      ? ' (redirected from $path)'
      : '';
  block.success('${from ?? '-'} → ${current ?? path}$redirected');
}

class _LiveBackCommand extends _LiveBuiltInCommand {
  _LiveBackCommand(super.arguments);

  @override
  String get example => 'live:run back /home';

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String? path = positional(result, 0);
    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(
        await app.call('route.back', {'path': ?path}),
      );
      block.success('${payload['from'] ?? '-'} → ${payload['current'] ?? '-'}');
      return payload;
    });
  }
}

// ---------------------------------------------------------------------------
// Change state
// ---------------------------------------------------------------------------

class _LiveAuthCommand extends _LiveBuiltInCommand {
  _LiveAuthCommand(super.arguments);

  @override
  String get example => 'live:run auth login --data \'{"id": 42}\'';

  @override
  void options(CommandBuilder command) {
    command.addOption('data', help: 'Signing in: the user as a JSON object.');
    command.addOption('session', help: 'A named auth session, e.g. device.');
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String? verb = positional(result, 0);
    final String? session = result.getString('session');
    final String? dataText = result.getString('data');

    if (verb != null && verb != 'login' && verb != 'logout') {
      abort(
        '"$verb" isn\'t something auth does. Use '
        '${runner.runActionName('auth login')} or '
        '${runner.runActionName('auth logout')}, or auth on its own to see '
        'who is signed in.',
        64,
      );
    }
    if (verb != 'login' && dataText != null) {
      abort('--data only works when signing in, e.g. metro $example', 64);
    }

    if (verb == 'login') {
      final String? given = dataText ?? positional(result, 1);
      if (given == null) {
        abort(
          'The user data is required, e.g. metro $example\n\n'
          'Usage:\n${builder(CommandBuilder()).usage}',
          64,
        );
      }
      final String label = dataText == null ? 'The user data' : '--data';
      final Object? data = _decodeJsonArgument(label, given);
      if (data is! Map) {
        abort('$label must be a JSON object.', 64);
      }
      return runner.run(options, (app, block) async {
        final Map<String, Object?> payload = _map(
          await app.call('auth.login', {'data': data, 'session': ?session}),
        );
        block.success(
          payload['authenticated'] == false
              ? 'The app didn\'t keep the session'
              : 'Signed in${session != null ? ' ($session session)' : ''}',
        );
        final Object? user = payload['user'];
        if (user != null) block.note(LiveFormat.value(user, max: 100));
        return payload;
      });
    }

    if (verb == 'logout') {
      return runner.run(options, (app, block) async {
        final Map<String, Object?> payload = _map(
          await app.call('auth.logout', {'session': ?session}),
        );
        block.success(
          'Signed out${session != null ? ' ($session session)' : ''}',
        );
        return payload;
      });
    }

    return runner.run(options, (app, block) async {
      _requireProtocol(app, 7, 'showing who is signed in');
      final Map<String, Object?> payload = _map(
        await app.call('auth.show', {'session': ?session}),
      );
      renderAuth(block, payload, session: session);
      return payload;
    });
  }
}

/// Adds the signed-in sessions of an `auth.show` [payload] to [block].
void renderAuth(
  LiveBlock block,
  Map<String, Object?> payload, {
  String? session,
}) {
  final Object? key = payload['key'];
  if (key == null) {
    block.note(
      'No auth key is set. Pass authKey to nylo.configure(...) in your '
      'AppProvider.',
    );
    return;
  }

  final Object? sessions = payload['sessions'];
  final List<Map<String, Object?>> found = [
    if (sessions is List)
      for (final Object? entry in sessions)
        if (entry is Map) _map(entry),
  ];
  if (found.isEmpty) {
    block.note(
      session == null
          ? 'Nobody is signed in (auth key $key)'
          : 'Nobody is signed in to the $session session',
    );
    return;
  }

  for (final Map<String, Object?> entry in found) {
    block
      ..heading('${entry['session']}')
      ..json(entry['user']);
  }
}

class _LiveLocaleCommand extends _LiveBuiltInCommand {
  _LiveLocaleCommand(super.arguments);

  @override
  String get example => 'live:run locale es';

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String language = requirePositional(
      result,
      0,
      'A language code is required.',
    );
    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(
        await app.call('locale.set', {'language': language}),
      );
      block.success('Locale set to ${payload['locale'] ?? language}');
      return payload;
    });
  }
}

class _LiveThemeCommand extends _LiveBuiltInCommand {
  _LiveThemeCommand(super.arguments);

  @override
  String get example => 'live:run theme dark_theme';

  @override
  void options(CommandBuilder command) {
    command.addFlag('remember', help: 'Keep the theme after the app restarts.');
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String id = requirePositional(result, 0, 'A theme id is required.');
    final bool remember = result.getBool('remember') ?? false;
    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(
        await app.call('theme.set', {'id': id, if (remember) 'remember': true}),
      );
      block.success('Theme set to ${payload['theme'] ?? id}');
      return payload;
    });
  }
}

class _LiveStateCommand extends _LiveBuiltInCommand {
  _LiveStateCommand(super.arguments);

  @override
  String get example => 'live:run state HomePage --data \'{"count": 2}\'';

  @override
  void options(CommandBuilder command) {
    command.addOption('data', help: 'The data to send (JSON or text).');
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String state = requirePositional(
      result,
      0,
      'A state name is required.',
    );
    final String? dataText = result.getString('data');
    final Object? data = dataText == null ? null : _jsonOrString(dataText);
    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(
        await app.call('state.update', {
          'state': state,
          if (dataText != null) 'data': data,
        }),
      );
      block.success('Updated $state');
      return payload;
    });
  }
}

class _LiveEventCommand extends _LiveBuiltInCommand {
  _LiveEventCommand(super.arguments);

  @override
  String get example =>
      'live:run event LogoutEvent --data \'{"reason": "test"}\'';

  @override
  void options(CommandBuilder command) {
    command.addOption('data', help: 'The event data as a JSON object.');
    command.addFlag(
      'broadcast',
      help: 'Broadcast the event to every listener.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final String event = requirePositional(
      result,
      0,
      'An event class name is required.',
    );
    final String? dataText = result.getString('data');
    final Object? data = dataText == null
        ? null
        : _decodeJsonArgument('--data', dataText);
    if (data != null && data is! Map) {
      abort('--data must be a JSON object.', 64);
    }
    final bool broadcast = result.getBool('broadcast') ?? false;

    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(
        await app.call('event.fire', {
          'event': event,
          'data': ?data,
          if (broadcast) 'broadcast': true,
        }),
      );
      block.success('Fired ${payload['event'] ?? event}');
      return payload;
    });
  }
}

class _LiveToastCommand extends _LiveBuiltInCommand {
  _LiveToastCommand(super.arguments);

  @override
  String get example => 'live:run toast "Item saved" --title Success';

  @override
  void options(CommandBuilder command) {
    command.addOption('title', help: 'The toast title.');
    command.addOption(
      'style',
      help: 'A toast style id registered in your app, e.g. success.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    if (result.rest.isEmpty) {
      abort(
        'A message is required, e.g. metro $example\n\n'
        'Usage:\n${builder(CommandBuilder()).usage}',
        64,
      );
    }
    final String description = result.rest.join(' ');
    final String? title = result.getString('title');
    final String? style = result.getString('style');
    return runner.run(options, (app, block) async {
      final Map<String, Object?> payload = _map(
        await app.call('toast.show', {
          'description': description,
          'title': ?title,
          'style': ?style,
        }),
      );
      block.success('Toast shown');
      return payload;
    });
  }
}

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

class _LiveSeedCommand extends _LiveShellOnlyCommand {
  _LiveSeedCommand(super.arguments);

  @override
  String get example => 'seed demo_user';

  @override
  void options(CommandBuilder command) {
    command.addOption(
      'as',
      help:
          'Loading a file: record it under this name, for seed:rollback. '
          'Defaults to the file name.',
    );
    command.addFlag(
      'fresh',
      help:
          'Clear storage and Backpack before seeding. seed:rollback brings '
          'them back.',
    );
    command.addFlag(
      'restart',
      help: 'Hot restart the app afterwards, so it starts up seeded.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final List<String> names = [
      for (final String name in result.rest)
        if (name.trim().isNotEmpty) name.trim(),
    ];
    final bool fresh = result.getBool('fresh') ?? false;
    final bool restart = result.getBool('restart') ?? false;
    final String? asName = result.getString('as');

    if (names.isEmpty) {
      if (fresh || restart || asName != null) {
        abort('Name the seeders to run, e.g. seed demo_user', 64);
      }
      final List<String> registered = runner.registered(registeredSeeders);
      return runner.run(options, (app, block) async {
        _requireSeeders(app);
        final Object? payload = await app.call('seeders.list');
        renderSeederList(
          block,
          app.device,
          payload,
          registered: registered,
          restart: runner.restartCommand,
          seed: runner.commandName('seed'),
          rollback: runner.commandName('seed:rollback'),
        );
        return payload;
      });
    }

    // A snapshot from `export --to` is sent over as it is; a seeder is
    // already in the app and runs by name.
    final String? source = _snapshotSource(names.first, runner);
    if (source != null) {
      if (names.length > 1) {
        abort(
          'A snapshot loads on its own, e.g. '
          '${runner.commandName('seed')} ${names.first}',
          64,
        );
      }
      return _loadSnapshot(
        runner,
        options,
        source,
        typed: names.first,
        asName: asName,
        fresh: fresh,
        restart: restart,
      );
    }

    // A path or a .json names a file and nothing else, so say it's missing
    // rather than sending it to the app as a seeder name.
    final String first = names.first;
    if (first.toLowerCase().endsWith('.json') ||
        first.contains('/') ||
        first.contains(r'\')) {
      abort(
        'Couldn\'t find a snapshot file called "$first". Write one with '
        '${runner.commandName('export')} --to $first',
        64,
      );
    }
    if (asName != null) {
      abort('--as only works when loading a snapshot file.', 64);
    }
    return _runSeeders(
      runner,
      options,
      names,
      direction: 'up',
      fresh: fresh,
      restart: restart,
    );
  }

  /// The snapshot text [name] points at - inline JSON, or a file - or null
  /// when it names a seeder instead.
  ///
  /// A registered seeder always wins, so a project with both a `demo_user`
  /// seeder and `snapshots/demo_user.json` runs the seeder.
  String? _snapshotSource(String name, LiveRunner runner) {
    final String trimmed = name.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return name;
    if (runner.registered(registeredSeeders).contains(name)) return null;
    final File? file = findSnapshotFile(name, root: runner.root);
    return file?.readAsStringSync();
  }
}

/// Sends a snapshot [source] to the app as a recorded run, the way a seeder
/// is recorded, so `seed:rollback` undoes it.
///
/// [typed] is what the developer wrote, used in messages and to name the run.
Future<int> _loadSnapshot(
  LiveRunner runner,
  LiveOptions options,
  String source, {
  required String typed,
  String? asName,
  bool fresh = false,
  bool restart = false,
}) async {
  final bool inline =
      typed.trimLeft().startsWith('{') || typed.trimLeft().startsWith('[');
  final String? fileName = inline
      ? null
      : findSnapshotFile(typed, root: runner.root)?.uri.pathSegments.last;

  final LiveSnapshot snapshot;
  try {
    snapshot = LiveSnapshot.decode(source);
  } on FormatException catch (e) {
    runner.output.error('${fileName ?? 'The snapshot'} ${e.message}.');
    return 64;
  }

  final String? name = asName != null
      ? seederNameFrom(asName)
      : fileName != null
      ? snapshotNameFor(fileName)
      : 'snapshot';
  if (name == null) {
    runner.output.error(
      '"$asName" can\'t be a seeder name. Use letters, numbers and '
      'underscores, e.g. demo_user.',
    );
    return 64;
  }
  if (snapshot.isEmpty) {
    runner.output.error(
      '${fileName ?? 'The snapshot'} holds no storage or Backpack values.',
    );
    return 64;
  }

  return runner.run(options, (app, block) async {
    _requireSnapshots(app);
    final Object? payload = await app.call('snapshot.import', {
      'name': name,
      'snapshot': snapshot.toImportJson(),
      'source': ?fileName,
      if (fresh) 'fresh': true,
    }, LiveRunner.commandTimeout);
    final String? failure = renderSeedRuns(
      block,
      payload,
      rollback: runner.commandName('seed:rollback'),
      verbs: (running: 'Loading', done: 'Loaded'),
    );
    if (failure != null) throw LiveReportedFailure(failure, payload);
    if (restart) {
      final Duration took = await app.restart();
      block.success('Hot restarted in ${took.inMilliseconds}ms');
    }
    return payload;
  });
}

class _LiveSeedRollbackCommand extends _LiveShellOnlyCommand {
  _LiveSeedRollbackCommand(super.arguments);

  @override
  String get example => 'seed:rollback demo_user';

  @override
  void options(CommandBuilder command) {
    command.addFlag(
      'restart',
      help: 'Hot restart the app afterwards, so it starts up without the data.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    final List<String> names = [
      for (final String name in result.rest)
        if (name.trim().isNotEmpty) name.trim(),
    ];
    if (names.isEmpty) {
      abort('Name the seeders to roll back, e.g. seed:rollback demo_user', 64);
    }
    return _runSeeders(
      runner,
      options,
      names,
      direction: 'down',
      restart: result.getBool('restart') ?? false,
    );
  }
}

/// Runs the seeders [names] `up` or `down` on [runner]'s apps, then hot
/// restarts them when [restart].
Future<int> _runSeeders(
  LiveRunner runner,
  LiveOptions options,
  List<String> names, {
  required String direction,
  bool fresh = false,
  bool restart = false,
}) {
  return runner.run(options, (app, block) async {
    _requireSeeders(app);
    final Object? payload = await app.call('seeders.run', {
      'names': names,
      'direction': direction,
      if (fresh) 'fresh': true,
    }, LiveRunner.commandTimeout);
    final String? failure = renderSeedRuns(
      block,
      payload,
      rollback: runner.commandName('seed:rollback'),
    );
    if (failure != null) throw LiveReportedFailure(failure, payload);
    if (restart) {
      final Duration took = await app.restart();
      block.success('Hot restarted in ${took.inMilliseconds}ms');
    }
    return payload;
  });
}

void _requireSeeders(LiveApp app) {
  if (!app.status.containsKey('seeders')) {
    throw LiveCommandException(
      'This app\'s Nylo version doesn\'t support seeders yet. Update '
      'nylo_framework, then restart the app.',
    );
  }
}

/// Adds each run in a `seeders.run` [payload] to [block]: its changes, its
/// messages and how it ended. After seeding, it ends with how to undo it
/// with [rollback].
///
/// [verbs] name what an `up` run did: `Seeding` and `Seeded` for seeders,
/// `Importing` and `Imported` for snapshots.
///
/// Returns why a run failed, or null when every run succeeded.
String? renderSeedRuns(
  LiveBlock block,
  Object? payload, {
  String rollback = 'seed:rollback',
  ({String running, String done}) verbs = (running: 'Seeding', done: 'Seeded'),
}) {
  final Object? runs = payload is Map ? payload['runs'] : null;
  if (runs is! List || runs.isEmpty) {
    block.note('Nothing ran');
    return null;
  }

  String? failure;
  final List<String> seeded = [];
  for (final Object? run in runs) {
    if (run is! Map) continue;
    final String name = '${run['name']}';
    final bool down = run['direction'] == 'down';
    final List<Map<Object?, Object?>> log = [
      if (run['log'] case final List entries)
        for (final Object? entry in entries)
          if (entry is Map) entry,
    ];
    final Iterable<Map<Object?, Object?>> changes = log.where(
      (entry) => entry['level'] == 'change',
    );
    final int storeWidth = changes.fold(
      0,
      (width, entry) => max(width, '${entry['store']}'.length),
    );
    final int keyWidth = changes.fold(
      0,
      (width, entry) => max(width, '${entry['key']}'.length),
    );

    block.plain(down ? 'Rolling back $name' : '${verbs.running} $name');
    for (final Map<Object?, Object?> entry in log) {
      final String message = '${entry['message'] ?? ''}';
      switch (entry['level']) {
        case 'change':
          final String change = '${entry['change']}';
          final (String symbol, LiveTone tone) = switch (change) {
            'added' => ('+', LiveTone.success),
            'removed' => ('-', LiveTone.failure),
            _ => ('~', LiveTone.warning),
          };
          block.add(
            '  $symbol ${'${entry['store']}'.padRight(storeWidth + 2)}'
            '${'${entry['key']}'.padRight(keyWidth + 2)}'
            '${change == 'restored' ? 'put back' : change}',
            tone,
          );
        case 'success':
          block.add('  ✓ $message', LiveTone.success);
        case 'error':
          block.add('  ✗ $message', LiveTone.failure);
        case 'warning':
          block.add('  ! $message', LiveTone.warning);
        default:
          block.plain('  $message');
      }
    }

    if (run['failed'] == true) {
      failure = '$name failed: ${run['error'] ?? 'unknown error'}';
      block.failure('$name failed');
    } else {
      if (!down) seeded.add(name);
      block.success(
        '${down ? 'Rolled back' : verbs.done} $name in ${run['ms'] ?? 0}ms',
      );
    }
  }
  if (seeded.isNotEmpty && failure == null) {
    block.note('Undo with $rollback ${seeded.join(' ')}');
  }
  return failure;
}

/// Adds the seeders in a `seeders.list` [payload] to [block].
///
/// Seeders in [registered] (from `lib/bootstrap/seeders.dart`) that the app
/// didn't list were usually added after it started, so [block] ends by
/// saying to hot restart with [restart]. [seed] and [rollback] are how to run
/// and undo a seeder from where the list was shown.
void renderSeederList(
  LiveBlock block,
  String device,
  Object? payload, {
  List<String> registered = const [],
  String restart = 'restart',
  String seed = 'seed',
  String rollback = 'seed:rollback',
}) {
  final Object? list = payload is Map ? payload['seeders'] : null;
  final List<Map<Object?, Object?>> seeders = [
    if (list is List)
      for (final Object? seeder in list)
        if (seeder is Map) seeder,
  ];
  final List<String> notLoaded = _notLoaded(registered, [
    for (final Map<Object?, Object?> seeder in seeders)
      if (seeder['registered'] != false) '${seeder['name']}',
  ]);
  if (seeders.isEmpty) {
    if (notLoaded.isEmpty) {
      block.note(
        'This app has no seeders yet. Create one with: '
        'metro make:seeder demo_user',
      );
    }
    _warnNotLoaded(block, notLoaded, restart);
    return;
  }
  block.heading('Seeders on $device:');
  block.table(
    ['NAME', 'DESCRIPTION', 'STATUS'],
    [
      for (final Map<Object?, Object?> seeder in seeders)
        [
          '${seeder['name']}',
          seeder['source'] != null
              ? '(imported from ${seeder['source']})'
              : seeder['registered'] == false
              ? '(no longer registered)'
              : '${seeder['description'] ?? ''}',
          describeSeededAt(seeder['seededAt']),
        ],
    ],
  );
  block.note('Run one with $seed <name>, and undo it with $rollback <name>');
  _warnNotLoaded(block, notLoaded, restart);
}

/// `seeded 10:42` for a time today, `seeded 12 Sep 10:42` for an earlier
/// day, or `not seeded`.
String describeSeededAt(Object? seededAt, {DateTime? now}) {
  final DateTime? time = seededAt is String
      ? DateTime.tryParse(seededAt)?.toLocal()
      : null;
  if (time == null) return 'not seeded';
  final DateTime today = now ?? DateTime.now();
  final String clock = LiveFormat.clock(time).substring(0, 5);
  if (time.year == today.year &&
      time.month == today.month &&
      time.day == today.day) {
    return 'seeded $clock';
  }
  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'seeded ${time.day} ${months[time.month - 1]} $clock';
}

// ---------------------------------------------------------------------------
// Snapshots
// ---------------------------------------------------------------------------

class _LiveExportCommand extends _LiveShellOnlyCommand {
  _LiveExportCommand(super.arguments);

  @override
  String get example => 'export demo_user';

  @override
  void options(CommandBuilder command) {
    command.addOption(
      'to',
      help:
          'Write the snapshot to this JSON file, e.g. --to snapshots/demo.json',
    );
    command.addOption(
      'description',
      help: 'A one-line description for the seeder, shown when seed lists it.',
    );
    command.addOption(
      'only',
      help:
          'Comma-separated keys to export; * matches anything, '
          'e.g. --only SK_USER,onboarding_*',
    );
    command.addOption(
      'except',
      help: 'Comma-separated keys to leave out, e.g. --except \'cache_*\'',
    );
    command.addFlag(
      'backpack',
      help: 'Include Backpack values (use --no-backpack to leave them out).',
      defaultValue: true,
    );
    command.addFlag(
      'force',
      abbr: 'f',
      help: 'Replace a seeder or file that already exists.',
    );
  }

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    if (options.all) {
      abort('export works on one app at a time. Pick it with -d <#>.', 64);
    }
    final String? rawName = positional(result, 0);
    final String? to = result.getString('to')?.trim();
    final bool force = result.getBool('force') ?? false;
    final String? description = result.getString('description');
    final List<String> only = _csv(result.getString('only'));
    final List<String> except = _csv(result.getString('except'));
    final bool backpack = result.getBool('backpack') ?? true;

    String? name;
    String? creationPath;
    String? seederPath;
    if (rawName != null) {
      final MetroProjectFile projectFile = MetroService.createMetroProjectFile(
        rawName,
        prefix: RegExp(r'_?seeder$', caseSensitive: false),
      );
      name = seederNameFrom(
        projectFile.name.replaceAll(RegExp(r'_?seeder$'), ''),
      );
      if (name == null) {
        abort(
          '"$rawName" can\'t be a seeder name. Use letters, numbers and '
          'underscores, e.g. demo_user.',
          64,
        );
      }
      creationPath = projectFile.creationPath;
      seederPath = MetroService.createPathForDartFile(
        folderPath: seedersFolder,
        className: name,
        prefix: 'seeder',
        creationPath: creationPath,
      );
      // Checked here because MetroService.makeSeeder ends the process when
      // the file exists, which would close metro live.
      if (!force && File(seederPath).existsSync()) {
        abort('$seederPath already exists. Pass --force to replace it.');
      }
    }
    if (to != null && to.isEmpty) {
      abort('--to needs a file path, e.g. --to snapshots/demo.json', 64);
    }
    if (to != null && !force && File(to).existsSync()) {
      abort('$to already exists. Pass --force to replace it.');
    }

    return runner.run(options, (app, block) async {
      _requireSnapshots(app);
      final Object? payload = await app.call('storage.export', {
        if (only.isNotEmpty) 'only': only,
        if (except.isNotEmpty) 'except': except,
        if (!backpack) 'backpack': false,
      }, LiveRunner.commandTimeout);
      final LiveSnapshot snapshot = LiveSnapshot.fromPayload(
        payload,
        device: app.device,
      );

      if (name == null && to == null) {
        renderSnapshotPreview(
          block,
          app.device,
          snapshot,
          export: runner.commandName('export'),
        );
        return payload;
      }
      if (snapshot.isEmpty) {
        block.warning(
          'Nothing to export: storage and Backpack are empty'
          '${only.isNotEmpty || except.isNotEmpty ? ' after filtering' : ''}.',
        );
        return payload;
      }
      if (name != null) {
        await _writeSnapshotSeeder(
          block,
          runner: runner,
          name: name,
          creationPath: creationPath,
          snapshot: snapshot,
          description: description,
          force: force,
        );
      }
      if (to != null) {
        final File file = File(to);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(snapshot.encode());
        block.success('Wrote $to (${snapshot.summary})');
        block.note(
          'Load it into an app with ${runner.commandName('seed')} $to',
        );
      }
      renderSnapshotWarnings(block, snapshot);
      return payload;
    });
  }
}

/// Creates the seeder [name] holding [snapshot], registers it in
/// `lib/bootstrap/seeders.dart` and wires the app provider, like
/// `make:seeder` does.
///
/// Metro's own `[Seeder] ... created` line is all a successful run prints;
/// [block] only gets what needs attention.
Future<void> _writeSnapshotSeeder(
  LiveBlock block, {
  required LiveRunner runner,
  required String name,
  required String? creationPath,
  required LiveSnapshot snapshot,
  required String? description,
  required bool force,
}) async {
  final ReCase seeder = ReCase(name);
  await MetroService.makeSeeder(
    name,
    snapshotSeederStub(
      seeder: seeder,
      snapshot: snapshot,
      description: description,
    ),
    forceCreate: force,
    creationPath: creationPath,
  );

  final String className = '${seeder.pascalCase}Seeder';
  final LiveRegistration registration = await registerSeeder(
    name: name,
    className: className,
    importPath:
        'app/seeders/${creationPath != null ? '$creationPath/' : ''}${name}_seeder.dart',
  );
  if (registration == LiveRegistration.mapNotFound) {
    block.warning(
      'Couldn\'t find the seeders map in $seedersRegistryPath. Add this '
      'entry to it:\n  \'$name\': $className.new,',
    );
  }

  block.note(
    'Load it with ${runner.restartCommand}, then run it with '
    '${runner.commandName('seed')} $name',
  );

  final String providerPath = '$providerFolder/app_provider.dart';
  switch (await wireSeeders(File(providerPath))) {
    case LiveWiring.added:
      block.note('$providerPath now passes seeders to Nylo');
    case LiveWiring.alreadyWired:
      break;
    case LiveWiring.configureNotFound:
    case LiveWiring.providerMissing:
      block.warning(
        'One more step: pass your seeders to Nylo in $providerPath\n'
        '  $seedersImport\n'
        '  await nylo.configure(..., seeders: seeders);',
      );
  }
}

/// Adds the storage and Backpack tables of [snapshot] from [device] to
/// [block], ending with how to save it with [export].
void renderSnapshotPreview(
  LiveBlock block,
  String device,
  LiveSnapshot snapshot, {
  String export = 'export',
}) {
  List<List<String>> rows(Map<String, Object?> values) => [
    for (final MapEntry<String, Object?> entry in values.entries)
      [
        entry.key,
        LiveSnapshot.describeEntry(entry.value).type,
        LiveFormat.value(LiveSnapshot.describeEntry(entry.value).value),
      ],
  ];

  block.heading(
    'Storage on $device (${snapshot.storage.length} '
    '${snapshot.storage.length == 1 ? 'value' : 'values'}, '
    '${_describeSize(snapshot.sizeInBytes)})',
  );
  if (snapshot.storage.isEmpty) {
    block.note('Storage is empty');
  } else {
    block.table(['KEY', 'TYPE', 'VALUE'], rows(snapshot.storage));
  }
  block.plain('');
  block.heading(
    'Backpack (${snapshot.backpack.length} '
    '${snapshot.backpack.length == 1 ? 'value' : 'values'})',
  );
  if (snapshot.backpack.isEmpty) {
    block.note('Backpack is empty');
  } else {
    block.table(['KEY', 'TYPE', 'VALUE'], rows(snapshot.backpack));
  }
  renderSnapshotWarnings(block, snapshot);
  block.note(
    'Save it as a seeder with $export <name>, or as a file with '
    '$export --to <path>.json',
  );
}

/// Adds what the app left out of [snapshot], keys that look like
/// credentials, and a size warning to [block].
void renderSnapshotWarnings(LiveBlock block, LiveSnapshot snapshot) {
  for (final Map<String, Object?> skip in snapshot.skipped) {
    block.note('Left out ${skip['store']} ${skip['key']}: ${skip['reason']}');
  }
  final List<String> secrets = snapshot.secretKeys;
  if (secrets.isNotEmpty) {
    block.warning(
      'The snapshot includes ${secrets.join(', ')}. Don\'t commit real '
      'credentials; leave them out with --except ${secrets.join(',')}',
    );
  }
  if (snapshot.sizeInBytes > LiveSnapshot.largeSize) {
    block.warning(
      'The snapshot is ${_describeSize(snapshot.sizeInBytes)}. Leave caches '
      'out with --except, e.g. --except \'cache_*\'',
    );
  }
}

void _requireSnapshots(LiveApp app) =>
    _requireProtocol(app, 2, 'storage snapshots');

/// Stops a command the running app is too old to answer.
///
/// [feature] names what it can't do, e.g. `storage snapshots`.
void _requireProtocol(LiveApp app, int version, String feature) {
  final Object? protocol = app.status['protocol'];
  if (protocol is! num || protocol < version) {
    throw LiveCommandException(
      'This app\'s Nylo version doesn\'t support $feature yet. '
      'Update nylo_framework, then restart the app.',
    );
  }
}

List<String> _csv(String? text) => [
  for (final String part in (text ?? '').split(','))
    if (part.trim().isNotEmpty) part.trim(),
];

String _describeSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ---------------------------------------------------------------------------
// Develop
// ---------------------------------------------------------------------------

class _LiveReloadCommand extends _LiveShellOnlyCommand {
  _LiveReloadCommand(super.arguments);

  @override
  String get example => 'reload --all';

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    return runner.run(options, (app, block) async {
      final Duration took = await app.reload();
      block.success('Hot reloaded in ${took.inMilliseconds}ms');
      return {'reloaded': true, 'ms': took.inMilliseconds};
    });
  }
}

class _LiveRestartCommand extends _LiveShellOnlyCommand {
  _LiveRestartCommand(super.arguments);

  @override
  String get example => 'restart --all';

  @override
  Future<int> execute(
    CommandResult result,
    LiveOptions options,
    LiveRunner runner,
  ) {
    return runner.run(options, (app, block) async {
      final Duration took = await app.restart();
      block.success('Hot restarted in ${took.inMilliseconds}ms');
      return {'restarted': true, 'ms': took.inMilliseconds};
    });
  }
}

/// The names in [registered] that aren't in [loaded].
List<String> _notLoaded(List<String> registered, List<String> loaded) => [
  for (final String name in registered)
    if (!loaded.contains(name)) name,
];

/// Warns that the app hasn't loaded [names] and that [restart] loads them.
void _warnNotLoaded(LiveBlock block, List<String> names, String restart) {
  if (names.isEmpty) return;
  block.warning(
    names.length == 1
        ? '${names.single} isn\'t loaded in the running app yet. '
              'Load it with $restart.'
        : '${names.join(', ')} aren\'t loaded in the running app yet. '
              'Load them with $restart.',
  );
}

/// `metro live:run <command>`: a built-in action (route, storage, ...) or a
/// command the app registered (e.g. cart:seed_cart).
Future<void> _runLiveRunCommand(List<String> arguments) async {
  final ({String? name, List<String> arguments, String? stoppedAt}) split =
      splitLiveRunArguments(arguments);
  final String? name = split.name;

  if (name == null) {
    final String? stoppedAt = split.stoppedAt;
    if (stoppedAt == null || stoppedAt == '--help' || stoppedAt == '-h') {
      print(liveRunUsage(LiveManifest.load()));
      return;
    }
    MetroConsole.writeInRed(
      'Put the command name first, e.g. metro live:run route /profile',
    );
    exit(64);
  }

  final LiveRunAction? action = liveRunActions[name];
  if (action != null) {
    await action.run(split.arguments);
    return;
  }

  final String? moved = liveCommandMoved(name);
  if (moved != null) {
    MetroConsole.writeInRed(moved);
    exit(64);
  }

  final ({LiveOptions options, List<String> rest}) extracted;
  try {
    extracted = LiveOptions.extract(split.arguments);
  } on FormatException catch (e) {
    MetroConsole.writeInRed(e.message);
    exit(64);
  }
  final int code = await runLiveCustomCommand(
    name,
    extracted.rest,
    options: extracted.options,
  );
  if (code != 0) exit(code);
}

// ---------------------------------------------------------------------------
// metro live
// ---------------------------------------------------------------------------

/// The commands `metro live` runs itself: `devices` and `status`, which also
/// run as `metro live:devices` and `metro live:status`, and the commands that
/// only run inside the shell.
final Map<String, NyCustomCommand Function(List<String> arguments)>
_liveShellBuiltIns = {
  'devices': _LiveDevicesCommand.new,
  'status': _LiveStatusCommand.new,
  'seed': _LiveSeedCommand.new,
  'seed:rollback': _LiveSeedRollbackCommand.new,
  'export': _LiveExportCommand.new,
  'reload': _LiveReloadCommand.new,
  'restart': _LiveRestartCommand.new,
};

/// The commands `metro live` lists in `help` and completes with Tab.
List<LiveShellCommand> get liveShellCommands {
  List<String> optionsOf(NyCustomCommand Function(List<String>) create) {
    final String usage = create(const []).builder(CommandBuilder()).usage;
    return {
      for (final RegExpMatch match in RegExp(
        r'--(?:\[no-\])?([a-z][a-z0-9-]*)',
      ).allMatches(usage))
        '--${match.group(1)}',
    }.toList();
  }

  LiveShellCommand builtIn(String name, String usage, String description) => (
    name: name,
    usage: usage,
    description: description,
    options: optionsOf(_liveShellBuiltIns[name]!),
  );

  return [
    (
      name: 'devices',
      usage: 'devices',
      description: 'List the running apps, numbered for use',
      options: const [],
    ),
    (
      name: 'use',
      usage: 'use <#|name|all>',
      description: 'Run commands on one app, or on all of them',
      options: const [],
    ),
    builtIn('status', 'status', 'Show the page, stack, locale and session'),
    builtIn(
      'seed',
      'seed [name|file]',
      'Run seeders or load a snapshot, or list them',
    ),
    builtIn(
      'seed:rollback',
      'seed:rollback <name>',
      'Roll seeders back with down()',
    ),
    builtIn(
      'export',
      'export [name]',
      'Save the app\'s storage as a seeder, or with --to as a file',
    ),
    builtIn('reload', 'reload', 'Hot reload the app'),
    builtIn('restart', 'restart', 'Hot restart the app'),
    for (final MapEntry<String, LiveRunAction> action in liveRunActions.entries)
      (
        name: action.key,
        usage: action.key,
        description: action.value.description,
        options: optionsOf(action.value.create),
      ),
    (
      name: 'help',
      usage: 'help [command]',
      description: 'List the commands, or show one command\'s options',
      options: const [],
    ),
    (
      name: 'exit',
      usage: 'exit',
      description: 'Leave the shell (Ctrl+D does too)',
      options: const [],
    ),
  ];
}

/// Runs the `metro live` command [name] with [arguments] on [runner]'s
/// session and returns its exit code.
///
/// [name] is a live command without its prefix (`status`, `seed`), a
/// `live:run` action (`route`), or one of the project's live commands
/// (`app:seed_demo`, or `seed_demo` when only one command has that name).
/// Returns null when nothing has that name.
Future<int?> runLiveShellCommand(
  String name,
  List<String> arguments,
  LiveRunner runner,
) async {
  String command = name.startsWith('live:') ? name.substring(5) : name;
  List<String> rest = arguments;
  if (command == 'run') {
    if (arguments.isEmpty) return null;
    command = arguments.first;
    rest = arguments.sublist(1);
  }

  final NyCustomCommand Function(List<String>)? create =
      _liveShellBuiltIns[command] ?? liveRunActions[command]?.create;
  if (create != null) {
    return (create(rest) as _LiveBuiltInCommand).runWith(runner);
  }

  final String? moved = liveCommandMoved(command, runner: runner);
  if (moved != null) {
    runner.output.error(moved);
    return 64;
  }

  final String? appCommand = resolveLiveAppCommand(
    command,
    LiveManifest.load(),
  );
  if (appCommand == null) return null;
  return runLiveCustomCommand(appCommand, rest, runner: runner);
}

/// The full name of the project live command [name] refers to: an exact
/// `category:name`, or a bare name that only one command in [entries] has.
///
/// Names with a category are returned as they are, since the app may have
/// commands `commands.json` doesn't list.
String? resolveLiveAppCommand(String name, List<LiveManifestEntry> entries) {
  if (name.contains(':')) return name;
  final List<LiveManifestEntry> matches = entries
      .where((entry) => entry.name == name)
      .toList();
  return matches.length == 1 ? matches.single.fullName : null;
}

/// `metro live`: opens the shell.
Future<void> _runLiveShell(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    print(liveShellUsage);
    return;
  }

  final ({LiveOptions options, List<String> rest}) extracted;
  try {
    extracted = LiveOptions.extract(arguments);
  } on FormatException catch (e) {
    MetroConsole.writeInRed(e.message);
    exit(64);
  }
  if (extracted.rest.isNotEmpty) {
    MetroConsole.writeInRed(liveShellArgumentsError(extracted.rest));
    exit(64);
  }

  final LiveShell shell;
  try {
    shell = LiveShell.forProject(
      options: extracted.options,
      dispatch: runLiveShellCommand,
      commands: liveShellCommands,
    );
  } on LiveCommandException catch (e) {
    MetroConsole.writeInRed(e.message);
    exit(1);
  }
  exit(await shell.start());
}

/// Why `metro live` won't take the command in [rest], and where that command
/// runs instead.
String liveShellArgumentsError(List<String> rest) {
  final String name = rest.first;
  final String typed = [
    for (final String word in rest)
      !word.contains(RegExp(r'\s'))
          ? word
          : word.contains("'")
          ? '"$word"'
          : "'$word'",
  ].join(' ');
  if (_isShellOnly(name)) {
    return '$name runs inside the shell. Open metro live and type $typed';
  }

  final String? oneShot = liveRunActions.containsKey(name)
      ? 'metro live:run $typed'
      : liveBuiltInCommands.containsKey('live:$name')
      ? 'metro live:$typed'
      : name.contains(':')
      ? 'metro $typed'
      : null;
  return 'metro live opens a shell and only takes -d, --all, --uri and '
      '--timeout. ${oneShot == null ? 'Open it and type $typed there.' : 'To run one command, use $oneShot'}';
}

/// The `metro live --help` text.
const String liveShellUsage = """Usage: metro live [options]

Opens a shell connected to your running app. Inside it, live commands drop
their prefix (status, route /profile), and seed, seed:rollback, export,
reload and restart only run there. Type help inside the shell to see them
all.

Pipe a file in to run it as a script, one command per line:
  metro live < seeds/demo.live

Options:
  -d, --device     Start on the app with this number or device name
      --all        Start with commands running on every app
      --uri        Connect to this VM service address instead of finding apps
      --timeout    Seconds to wait for each app while finding apps (default 3)""";
