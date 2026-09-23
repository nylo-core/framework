import 'dart:io';

/// Flags shared by every `metro live:*` command and live custom command.
class LiveOptions {
  /// Creates [LiveOptions].
  const LiveOptions({
    this.device,
    this.all = false,
    this.json = false,
    this.uri,
    this.timeout = defaultTimeout,
  });

  /// How long discovery waits for each daemon and app by default.
  static const Duration defaultTimeout = Duration(seconds: 3);

  /// `-d/--device`: a 1-based index from `metro live:devices` or a device name.
  final String? device;

  /// `--all`: run on every running app of this project.
  final bool all;

  /// `--json`: print machine-readable output.
  final bool json;

  /// `--uri`: skip discovery and use this VM service address.
  final String? uri;

  /// `--timeout`: seconds to wait for each daemon and app while discovering.
  final Duration timeout;

  /// Usage lines for the shared flags.
  static const String usage =
      '-d, --device     Target an app by its number in `metro live:devices` or its device name\n'
      '    --all        Run on every running app of this project\n'
      '    --json       Print machine-readable JSON\n'
      '    --uri        Use this VM service address instead of discovering apps\n'
      '    --timeout    Seconds to wait for each app while discovering (default 3)';

  /// Removes the shared flags from [args], returning them with the remaining
  /// arguments in their original order.
  ///
  /// Arguments after `--` are passed through untouched. Throws a
  /// [FormatException] for a flag missing its value or a bad `--timeout`.
  static ({LiveOptions options, List<String> rest}) extract(List<String> args) {
    String? device;
    String? uri;
    bool all = false;
    bool json = false;
    Duration timeout = defaultTimeout;
    final List<String> rest = [];

    String valueFor(String flag, int index) {
      if (index + 1 >= args.length) {
        throw FormatException('Missing value for $flag.');
      }
      return args[index + 1];
    }

    for (int i = 0; i < args.length; i++) {
      final String arg = args[i];
      if (arg == '--') {
        rest.addAll(args.sublist(i));
        break;
      }

      if (arg == '-d' || arg == '--device') {
        device = valueFor(arg, i);
        i++;
      } else if (arg.startsWith('--device=')) {
        device = arg.substring('--device='.length);
      } else if (arg == '--uri') {
        uri = valueFor(arg, i);
        i++;
      } else if (arg.startsWith('--uri=')) {
        uri = arg.substring('--uri='.length);
      } else if (arg == '--timeout') {
        timeout = parseTimeout(valueFor(arg, i));
        i++;
      } else if (arg.startsWith('--timeout=')) {
        timeout = parseTimeout(arg.substring('--timeout='.length));
      } else if (arg == '--all') {
        all = true;
      } else if (arg == '--json') {
        json = true;
      } else {
        rest.add(arg);
      }
    }

    return (
      options: LiveOptions(
        device: device,
        all: all,
        json: json,
        uri: uri,
        timeout: timeout,
      ),
      rest: rest,
    );
  }

  /// Parses a `--timeout` value in seconds (fractions allowed).
  static Duration parseTimeout(String? value) {
    if (value == null || value.trim().isEmpty) return defaultTimeout;
    final double? seconds = double.tryParse(value.trim());
    if (seconds == null || seconds <= 0) {
      throw FormatException(
        '--timeout must be a positive number of seconds, got "$value".',
      );
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }
}

/// Replaces arguments written as `@path` with the contents of that file, so
/// an option can take a file: `--scenario @seeds/jane.json`.
///
/// Works for `--option=@path` too. Start a value with `@@` when it really
/// begins with `@`. Arguments after `--` are left alone. Trailing newlines
/// are dropped, as `$(cat path)` does. Throws a [FormatException] when the
/// file doesn't exist.
List<String> expandLiveFileArguments(List<String> arguments) {
  final List<String> expanded = [];
  for (int i = 0; i < arguments.length; i++) {
    final String argument = arguments[i];
    if (argument == '--') {
      expanded.addAll(arguments.sublist(i));
      break;
    }
    final int equals = argument.startsWith('--') ? argument.indexOf('=') : -1;
    expanded.add(
      equals == -1
          ? _fileValue(argument)
          : '${argument.substring(0, equals + 1)}'
                '${_fileValue(argument.substring(equals + 1))}',
    );
  }
  return expanded;
}

String _fileValue(String value) {
  if (value.startsWith('@@')) return value.substring(1);
  if (!value.startsWith('@') || value.length == 1) return value;
  final String path = value.substring(1);
  final File file = File(path);
  if (!file.existsSync()) {
    throw FormatException(
      'Couldn\'t find $path (from $value). Start the value with @@ if it '
      'really begins with @.',
    );
  }
  return file.readAsStringSync().replaceFirst(RegExp(r'[\r\n]+$'), '');
}
