import 'package:args/args.dart';

/// One option or flag a live command declares in its `builder()`.
class LiveCommandOption {
  /// Creates a [LiveCommandOption].
  const LiveCommandOption({
    required this.kind,
    required this.name,
    this.abbr,
    this.help,
    this.allowed,
    this.defaultValue,
  });

  /// Parses one schema entry reported by `ext.nylo.commands.list`.
  static LiveCommandOption? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final Object? abbr = json['abbr'];
    final Object? help = json['help'];
    final Object? allowed = json['allowed'];
    return LiveCommandOption(
      kind: json['kind'] == 'flag' ? 'flag' : 'option',
      name: name,
      abbr: abbr is String && abbr.length == 1 ? abbr : null,
      help: help is String ? help : null,
      allowed: allowed is List ? allowed.map((v) => '$v').toList() : null,
      defaultValue: json['defaultValue'],
    );
  }

  /// `option` or `flag`.
  final String kind;

  /// The long name, used as `--name`.
  final String name;

  /// The single-letter abbreviation, used as `-a`.
  final String? abbr;

  /// Help text shown in usage.
  final String? help;

  /// Allowed values for an option.
  final List<String>? allowed;

  /// The default value: a `String` for options, a `bool` for flags.
  final Object? defaultValue;

  /// Whether this entry is a boolean flag.
  bool get isFlag => kind == 'flag';
}

/// A live command as reported by the running app.
class LiveCommandSchema {
  /// Creates a [LiveCommandSchema].
  const LiveCommandSchema({
    required this.name,
    this.description,
    this.options = const [],
  });

  /// Parses one entry of `ext.nylo.commands.list`.
  static LiveCommandSchema? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final Object? description = json['description'];
    final Object? options = json['options'];
    return LiveCommandSchema(
      name: name,
      description: description is String && description.isNotEmpty
          ? description
          : null,
      options: options is List
          ? options
                .map(LiveCommandOption.fromJson)
                .whereType<LiveCommandOption>()
                .toList()
          : const [],
    );
  }

  /// Parses the `commands` list of an `ext.nylo.commands.list` result.
  static List<LiveCommandSchema> listFromResult(Object? result) {
    final Object? commands = result is Map ? result['commands'] : null;
    if (commands is! List) return const [];
    return commands
        .map(LiveCommandSchema.fromJson)
        .whereType<LiveCommandSchema>()
        .toList();
  }

  /// The full `category:name`.
  final String name;

  /// The one-line description, when the app provides one.
  final String? description;

  /// The declared options and flags.
  final List<LiveCommandOption> options;

  /// Builds the [ArgParser] Metro uses to validate terminal arguments.
  ///
  /// Abbreviations that are invalid or already taken are dropped rather
  /// than failing the whole command.
  ArgParser toArgParser() {
    final ArgParser parser = ArgParser();
    final Set<String> abbreviations = {};
    for (final LiveCommandOption option in options) {
      if (parser.options.containsKey(option.name)) continue;
      final String? abbr =
          option.abbr != null && abbreviations.add(option.abbr!)
          ? option.abbr
          : null;
      if (option.isFlag) {
        parser.addFlag(
          option.name,
          abbr: abbr,
          help: option.help,
          defaultsTo: option.defaultValue == true,
        );
      } else {
        final Object? defaultValue = option.defaultValue;
        parser.addOption(
          option.name,
          abbr: abbr,
          help: option.help,
          allowed: option.allowed,
          defaultsTo: defaultValue?.toString(),
        );
      }
    }
    return parser;
  }

  /// Parses terminal [arguments] against this schema.
  ///
  /// Returns the values for every declared option (defaults applied) and the
  /// positional arguments. Throws a [FormatException] for unknown options or
  /// values outside `allowed`.
  ({Map<String, Object?> values, List<String> rest}) parse(
    List<String> arguments,
  ) {
    final ArgParser parser = toArgParser();
    final ArgResults results = parser.parse(arguments);
    return (
      values: {
        for (final String name in parser.options.keys) name: results[name],
      },
      rest: results.rest,
    );
  }

  /// Usage text for `--help`.
  String get usage {
    final String optionsUsage = toArgParser().usage;
    return [
      'Usage: metro $name [options]',
      if (description != null) description!,
      if (optionsUsage.isNotEmpty) ...['', optionsUsage],
    ].join('\n');
  }

  /// Whether [arguments] ask for help without the command claiming `--help`
  /// or `-h` for itself.
  bool wantsHelp(List<String> arguments) {
    final bool ownsHelp = options.any((o) => o.name == 'help');
    final bool ownsH = options.any((o) => o.abbr == 'h');
    for (final String arg in arguments) {
      if (arg == '--') return false;
      if (arg == '--help' && !ownsHelp) return true;
      if (arg == '-h' && !ownsH) return true;
    }
    return false;
  }
}
