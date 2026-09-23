import 'dart:async';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'json_rpc_client.dart';
import 'live_app.dart';
import 'live_command_schema.dart';
import 'live_discovery.dart';
import 'live_options.dart';
import 'live_output.dart';
import 'live_registry.dart';
import 'live_session.dart';
import 'live_targets.dart';

/// The Flutter project Metro is running in.
class LiveProject {
  /// Creates a [LiveProject] rooted at [root] with pubspec name [packageName].
  const LiveProject(this.root, this.packageName);

  /// Loads the project from the `pubspec.yaml` in [root] (the current
  /// directory by default).
  ///
  /// Throws a [LiveCommandException] when there is no readable pubspec.
  static LiveProject load([String? root]) {
    final String directory = root ?? Directory.current.path;
    final File pubspec = File('$directory/pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw LiveCommandException(
        'No pubspec.yaml in $directory. Run metro from your Flutter project '
        'root.',
      );
    }
    try {
      final Object? yaml = loadYaml(pubspec.readAsStringSync());
      final Object? name = yaml is YamlMap ? yaml['name'] : null;
      if (name is String && name.isNotEmpty) {
        return LiveProject(directory, name);
      }
    } catch (_) {
      // Fall through to the error below.
    }
    throw LiveCommandException(
      'Couldn\'t read the package name from ${pubspec.path}.',
    );
  }

  /// The project root directory.
  final String root;

  /// The pubspec `name`.
  final String packageName;
}

/// The outcome of a live command on one app.
class LiveOutcome {
  /// Creates a [LiveOutcome] for [app].
  const LiveOutcome(this.app, this.block, {this.result, this.error});

  /// The app the command ran on.
  final LiveApp app;

  /// The human-readable output.
  final LiveBlock block;

  /// The command's result payload.
  final Object? result;

  /// Why the command failed, or null when it succeeded.
  final String? error;

  /// Whether the command succeeded.
  bool get isSuccess => error == null;

  /// The `--json` representation.
  Map<String, Object?> toJson() => {
    'device': app.device,
    'uri': app.uri.toString(),
    'ok': isSuccess,
    if (error != null) 'error': error,
    if (isSuccess || result != null) 'result': result,
  };
}

/// Creates the [LiveDiscovery] a [LiveRunner] uses.
typedef LiveDiscoveryFactory =
    LiveDiscovery Function(LiveProject project, Duration timeout);

/// Finds the target apps for a live command and runs it on them.
class LiveRunner {
  /// Creates a [LiveRunner].
  ///
  /// [project] defaults to the project in the current directory, and
  /// [discovery] to discovery through the running Dart Tooling Daemons.
  LiveRunner({
    LivePrinter? output,
    LiveProject? project,
    LiveDiscoveryFactory? discovery,
    this.session,
  }) : output = output ?? LivePrinter(),
       _project = project,
       _discovery = discovery;

  /// Where output is printed.
  final LivePrinter output;

  /// The `metro live` session whose open connections commands run on.
  ///
  /// Without one, each command finds the apps itself and closes the
  /// connections when it's done.
  LiveSession? session;

  LiveProject? _project;
  final LiveDiscoveryFactory? _discovery;

  /// How long an app gets to run a command before Metro gives up.
  static const Duration commandTimeout = Duration(seconds: 30);

  /// The project Metro is running in.
  LiveProject get project => _project ??= LiveProject.load();

  /// The project directory, or the current one outside a Flutter project.
  String get root {
    try {
      return project.root;
    } on LiveCommandException {
      return Directory.current.path;
    }
  }

  /// How to run the live command [name] from where this runner is used:
  /// `name` inside `metro live`, otherwise `metro live:name`.
  String commandName(String name) =>
      session == null ? 'metro live:$name' : name;

  /// How to run the `live:run` action [name] from where this runner is used:
  /// `name` inside `metro live`, otherwise `metro live:run name`.
  ///
  /// Not [commandName], which would give `run storage:clear` in the shell.
  String runActionName(String name) =>
      session == null ? 'metro live:run $name' : name;

  /// How the app gets hot restarted from where this runner is used:
  /// `restart` inside `metro live`, and the developer's own hot restart
  /// outside it, where `flutter run` and the IDE both offer one.
  ///
  /// Written to read after "Load it with ...".
  String get restartCommand => session == null ? 'a hot restart' : 'restart';

  /// The names [read] finds in the project's registry (e.g.
  /// [registeredLiveCommands]), or none when Metro isn't running in a Flutter
  /// project.
  List<String> registered(List<String> Function({String projectRoot}) read) {
    try {
      return read(projectRoot: project.root);
    } on LiveCommandException {
      return const [];
    }
  }

  /// Discovers this project's running apps.
  Future<LiveDiscoveryResult> discover(LiveOptions options) {
    final LiveDiscovery discovery =
        _discovery?.call(project, options.timeout) ??
        LiveDiscovery(
          projectRoot: project.root,
          packageName: project.packageName,
          timeout: options.timeout,
        );
    return discovery.discover();
  }

  /// Resolves the apps a command runs on, printing why when there are none.
  ///
  /// Returns the targets and the exit code to use when the list is empty.
  Future<({List<LiveApp> targets, int exitCode})> resolveTargets(
    LiveOptions options,
  ) async {
    final LiveSession? session = this.session;
    if (session != null) return session.resolve(options, output);

    final String? address = options.uri;
    if (address != null) {
      final Uri? uri = LiveDiscovery.normalizeVmServiceUri(address);
      if (uri == null) {
        _error(options, 'Not a VM service address: $address');
        return (targets: <LiveApp>[], exitCode: 1);
      }
      String packageName = 'app';
      try {
        packageName = project.packageName;
      } on LiveCommandException {
        // --uri works outside a project too.
      }
      try {
        final LiveApp app = await LiveApp.connect(
          uri,
          device: uri.hasPort ? '${uri.host}:${uri.port}' : uri.host,
          package: packageName,
          timeout: options.timeout,
        );
        return (targets: [app], exitCode: 0);
      } on LiveCommandException catch (e) {
        _error(options, e.message);
        return (targets: <LiveApp>[], exitCode: 1);
      }
    }

    final LiveDiscoveryResult discovered;
    try {
      discovered = await discover(options);
    } on LiveDiscoveryException catch (e) {
      _error(options, e.message);
      return (targets: <LiveApp>[], exitCode: 1);
    } on LiveCommandException catch (e) {
      _error(options, e.message);
      return (targets: <LiveApp>[], exitCode: 1);
    }

    final LiveTargetSelection<LiveApp> selection = selectLiveTargets(
      discovered.apps,
      deviceOf: (app) => app.device,
      device: options.device,
      all: options.all,
      packageName: project.packageName,
    );

    if (!selection.isSuccess) {
      if (options.json) {
        output.json({
          'error': selection.error,
          'apps': [
            for (final LiveApp app in selection.candidates)
              {'index': discovered.apps.indexOf(app) + 1, 'device': app.device},
          ],
        });
      } else {
        output.error(selection.error!);
        for (final LiveApp app in selection.candidates) {
          output.line('  ${discovered.apps.indexOf(app) + 1}  ${app.device}');
        }
        printSkipped(discovered.skipped);
      }
      await Future.wait(discovered.apps.map((app) => app.close()));
      return (targets: <LiveApp>[], exitCode: selection.exitCode);
    }

    await Future.wait(
      discovered.apps
          .where((app) => !selection.targets.contains(app))
          .map((app) => app.close()),
    );
    return (targets: selection.targets, exitCode: 0);
  }

  /// Runs [action] on every target app in parallel, then prints each app's
  /// output (or the `--json` document) and returns the exit code: `0` when
  /// every app succeeded, `1` when any failed.
  Future<int> run(
    LiveOptions options,
    Future<Object?> Function(LiveApp app, LiveBlock block) action,
  ) async {
    final ({List<LiveApp> targets, int exitCode}) resolved =
        await resolveTargets(options);
    if (resolved.targets.isEmpty) return resolved.exitCode;

    final List<LiveOutcome> outcomes = await Future.wait(
      resolved.targets.map((app) async {
        final LiveBlock block = LiveBlock();
        try {
          final Object? result = await action(app, block);
          return LiveOutcome(app, block, result: result);
        } on LiveReportedFailure catch (e) {
          // The app already explained the failure in the output lines.
          return LiveOutcome(app, block, result: e.result, error: e.message);
        } catch (e) {
          final String message = describeLiveError(e);
          block.failure(message);
          return LiveOutcome(app, block, error: message);
        }
      }),
    );

    if (options.json) {
      output.json([
        for (final LiveOutcome outcome in outcomes) outcome.toJson(),
      ]);
    } else {
      output.blocks([
        for (final LiveOutcome outcome in outcomes)
          (label: outcome.app.device, block: outcome.block),
      ]);
    }

    await _release(resolved.targets);
    return outcomes.every((outcome) => outcome.isSuccess) ? 0 : 1;
  }

  /// Closes [apps] unless they belong to the [session].
  Future<void> _release(List<LiveApp> apps) async {
    if (session != null) return;
    await Future.wait(apps.map((app) => app.close()));
  }

  /// Prints the apps discovery had to skip.
  void printSkipped(List<LiveSkippedApp> skipped) {
    for (final LiveSkippedApp app in skipped) {
      output.note('Skipped ${app.device}: ${app.reason}');
    }
  }

  void _error(LiveOptions options, String message) {
    if (options.json) {
      output.json({'error': message});
    } else {
      output.error(message);
    }
  }
}

/// Runs an app-defined live command named [name] with terminal [arguments].
///
/// The command's options come from the running app (`commands.list`), are
/// parsed by Metro, and the validated values are sent with `commands.run`.
Future<int> runLiveCustomCommand(
  String name,
  List<String> arguments, {
  LiveRunner? runner,
  LiveOptions? options,
}) async {
  final LiveRunner live = runner ?? LiveRunner();

  // Shared flags can sit anywhere among the command's own arguments.
  final ({LiveOptions options, List<String> rest}) extracted;
  try {
    extracted = LiveOptions.extract(expandLiveFileArguments(arguments));
  } on FormatException catch (e) {
    live.output.error(e.message);
    return 64;
  }
  final LiveOptions resolvedOptions = options ?? extracted.options;

  if (_asksForHelp(extracted.rest)) {
    return _printCustomCommandHelp(name, extracted.rest, resolvedOptions, live);
  }

  return live.run(resolvedOptions, (app, block) async {
    final LiveCommandSchema schema = await _schemaFor(app, name, live);
    final ({Map<String, Object?> values, List<String> rest}) parsed;
    try {
      parsed = schema.parse(extracted.rest);
    } on FormatException catch (e) {
      throw LiveCommandException('${e.message}\n\n${schema.usage}');
    }
    return _runParsed(app, block, name, parsed);
  });
}

/// A command that ran but reported failure through its own output lines.
class LiveReportedFailure implements Exception {
  /// Creates a [LiveReportedFailure] with a summary [message] and the
  /// app's [result] payload.
  LiveReportedFailure(this.message, this.result);

  /// A one-line summary of the failure.
  final String message;

  /// The `commands.run` payload, including the output lines.
  final Object? result;

  @override
  String toString() => message;
}

String? _lastError(Map result) {
  final Object? output = result['output'];
  if (output is! List) return null;
  for (final Object? line in output.reversed) {
    if (line is Map && line['level'] == 'error') return '${line['message']}';
  }
  return null;
}

/// Runs [name] for a command that declares `-h`/`--help` itself.
Future<int> _runWithoutHelp(
  String name,
  List<String> rest,
  LiveOptions options,
  LiveRunner live,
) {
  return live.run(options, (app, block) async {
    final LiveCommandSchema schema = await _schemaFor(app, name, live);
    final ({Map<String, Object?> values, List<String> rest}) parsed;
    try {
      parsed = schema.parse(rest);
    } on FormatException catch (e) {
      throw LiveCommandException('${e.message}\n\n${schema.usage}');
    }
    return _runParsed(app, block, name, parsed);
  });
}

Future<Object?> _runParsed(
  LiveApp app,
  LiveBlock block,
  String name,
  ({Map<String, Object?> values, List<String> rest}) parsed,
) async {
  final Object? result = await app.call('commands.run', {
    'name': name,
    'args': parsed.values,
    'rest': parsed.rest,
  }, LiveRunner.commandTimeout);
  renderRunResult(block, result);
  if (result is Map && result['failed'] == true) {
    throw LiveReportedFailure(_lastError(result) ?? '$name failed', result);
  }
  return result;
}

bool _asksForHelp(List<String> arguments) {
  for (final String arg in arguments) {
    if (arg == '--') return false;
    if (arg == '--help' || arg == '-h') return true;
  }
  return false;
}

Future<int> _printCustomCommandHelp(
  String name,
  List<String> rest,
  LiveOptions options,
  LiveRunner live,
) async {
  // Help only needs one app; don't make the user pick a device for it.
  final LiveOptions anyApp = LiveOptions(
    all: true,
    json: options.json,
    uri: options.uri,
    timeout: options.timeout,
  );
  final ({List<LiveApp> targets, int exitCode}) resolved = await live
      .resolveTargets(anyApp);
  if (resolved.targets.isEmpty) {
    live.output.note(
      'Start your app with `flutter run` to see the options for $name.',
    );
    return resolved.exitCode;
  }

  try {
    final LiveCommandSchema schema = await _schemaFor(
      resolved.targets.first,
      name,
      live,
    );
    if (!schema.wantsHelp(rest)) {
      // The command declares -h/--help itself; run it normally.
      await live._release(resolved.targets);
      return await _runWithoutHelp(name, rest, options, live);
    }
    live.output.line(schema.usage);
    return 0;
  } catch (e) {
    live.output.error(describeLiveError(e));
    return 1;
  } finally {
    await live._release(resolved.targets);
  }
}

Future<LiveCommandSchema> _schemaFor(
  LiveApp app,
  String name,
  LiveRunner live,
) async {
  final List<LiveCommandSchema> schemas = LiveCommandSchema.listFromResult(
    await app.call('commands.list'),
  );
  for (final LiveCommandSchema schema in schemas) {
    if (schema.name == name) return schema;
  }
  if (live.registered(registeredLiveCommands).contains(name)) {
    throw LiveCommandException(
      '"$name" isn\'t loaded in the running app yet. Load it with '
      '${live.restartCommand}.',
    );
  }
  throw LiveCommandException(
    '"$name" isn\'t in this build yet. Register it in '
    'lib/bootstrap/live_commands.dart, pass liveCommands to nylo.configure(), '
    'then hot restart.',
  );
}

/// Adds the output lines and result of a `commands.run` [result] to [block].
void renderRunResult(LiveBlock block, Object? result) {
  final Object? output = result is Map ? result['output'] : null;
  if (output is List) {
    for (final Object? line in output) {
      if (line is! Map) continue;
      final String message = '${line['message'] ?? ''}';
      switch (line['level']) {
        case 'success':
          block.success(message);
        case 'error':
          block.failure(message);
        case 'warning':
          block.warning(message);
        default:
          block.plain(message);
      }
    }
  }
  final Object? value = result is Map ? result['result'] : null;
  if (value != null) block.json(value);
  if (block.isEmpty) block.success('Done');
}

/// A user-facing message for an error raised while running a live command.
String describeLiveError(Object error) {
  if (error is JsonRpcException) return error.details;
  if (error is LiveCommandException) return error.message;
  if (error is LiveDiscoveryException) return error.message;
  if (error is TimeoutException) {
    return 'The app didn\'t respond in time. It may be paused in a debugger '
        'or in the background.';
  }
  if (error is JsonRpcConnectionClosed) {
    return 'Lost the connection to the app. Did it stop running?';
  }
  if (error is FormatException) return error.message;
  return '$error';
}
