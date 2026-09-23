import 'dart:convert';
import 'dart:io';

/// A `"type": "live"` entry in `lib/app/commands/commands.json`.
class LiveManifestEntry {
  /// Creates a [LiveManifestEntry].
  const LiveManifestEntry({
    required this.name,
    required this.category,
    this.script,
    this.description,
  });

  /// The command name, used after the category.
  final String name;

  /// The command category, used as the prefix.
  final String category;

  /// The Dart file holding the command class.
  final String? script;

  /// The one-line description shown in the Metro menu.
  final String? description;

  /// The full `category:name` used to run the command.
  String get fullName => '$category:$name';
}

/// Reads and updates the live entries of a project's `commands.json`.
class LiveManifest {
  /// The manifest path, relative to the project root.
  static const String path = 'lib/app/commands/commands.json';

  /// The `type` value that marks a command as a live command.
  static const String liveType = 'live';

  /// Loads the live entries from the project at [projectRoot].
  ///
  /// Returns an empty list when the file is missing or isn't valid JSON;
  /// Metro's regular custom-command discovery reports those problems.
  static List<LiveManifestEntry> load({String projectRoot = '.'}) {
    final File file = File('$projectRoot/$path');
    if (!file.existsSync()) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException {
      return const [];
    }
    return parse(decoded);
  }

  /// Parses the live entries from a decoded `commands.json` document.
  static List<LiveManifestEntry> parse(Object? decoded) {
    if (decoded is! List) return const [];
    final List<LiveManifestEntry> entries = [];
    for (final Object? entry in decoded) {
      if (entry is! Map || entry['type'] != liveType) continue;
      final Object? name = entry['name'];
      if (name is! String || name.isEmpty) continue;
      final Object? category = entry['category'];
      final Object? script = entry['script'];
      final Object? description = entry['description'];
      entries.add(
        LiveManifestEntry(
          name: name,
          category: category is String && category.isNotEmpty
              ? category
              : 'app',
          script: script is String ? script : null,
          description: description is String && description.isNotEmpty
              ? description
              : null,
        ),
      );
    }
    return entries;
  }

  /// Finds the live entry for [fullName] (`category:name`), or null.
  static LiveManifestEntry? find(String fullName, {String projectRoot = '.'}) {
    for (final LiveManifestEntry entry in load(projectRoot: projectRoot)) {
      if (entry.fullName == fullName) return entry;
    }
    return null;
  }

  /// Menu lines for [entries], aligned like Metro's custom commands section.
  static String menuLines(List<LiveManifestEntry> entries) {
    if (entries.isEmpty) return '';
    final List<LiveManifestEntry> sorted = List<LiveManifestEntry>.of(entries)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final int width = sorted
        .map((entry) => entry.fullName.length)
        .reduce((a, b) => a > b ? a : b);
    final StringBuffer buffer = StringBuffer();
    for (final LiveManifestEntry entry in sorted) {
      buffer.write('  ${entry.fullName}');
      final String? description = entry.description;
      if (description != null) {
        buffer.write(' ' * (width - entry.fullName.length + 4));
        buffer.write(description);
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Marks the `commands.json` entry for [category]:[name] as a live command,
  /// setting [description] when given. When no entry has that exact
  /// category and name, a live entry is added instead, so an existing command
  /// with the same name in another category is never changed.
  ///
  /// Returns false when the file is missing or isn't a JSON list.
  static bool markLive(
    File file, {
    required String name,
    required String category,
    required String script,
    String? description,
  }) {
    if (!file.existsSync()) return false;
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException {
      return false;
    }
    if (decoded is! List) return false;

    Map? entry;
    for (final Object? candidate in decoded) {
      if (candidate is Map &&
          candidate['name'] == name &&
          (candidate['category'] ?? 'app') == category) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) {
      entry = <String, Object?>{
        'name': name,
        'category': category,
        'script': script,
      };
      decoded.add(entry);
    }

    entry['type'] = liveType;
    if (description != null && description.trim().isNotEmpty) {
      entry['description'] = description.trim();
    }
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(decoded));
    return true;
  }
}
