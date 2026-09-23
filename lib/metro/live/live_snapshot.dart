import 'dart:convert';
import 'dart:io';

import 'package:recase/recase.dart';

import 'live_app.dart';

/// A storage snapshot on Metro's side: what `storage.export` returns, what
/// `export --to` writes in `metro live`, and the map an exported seeder holds.
///
/// Storage values are plain literals where Dart's type says enough, and
/// `{'type': ..., 'value': ...}` tags for models, raw values, values with a
/// `ttl`, and JSON objects with a `type` key of their own. Backpack models
/// carry their class name so the app can rebuild them. The app owns the
/// format; Metro only carries it.
class LiveSnapshot {
  /// Creates a snapshot of [storage] and [backpack] values.
  const LiveSnapshot({
    required this.storage,
    required this.backpack,
    this.skipped = const [],
    this.app,
    this.env,
    this.device,
    this.route,
    this.exportedAt,
  });

  /// The `nylo` value written to snapshot files.
  static const int formatVersion = 1;

  /// Above this many bytes, export suggests leaving caches out.
  static const int largeSize = 256 * 1024;

  /// The storage values, by key.
  final Map<String, Object?> storage;

  /// The Backpack values, by key.
  final Map<String, Object?> backpack;

  /// What the app left out, each as `{store, key, reason}`.
  final List<Map<String, Object?>> skipped;

  /// The app's `APP_NAME`, when known.
  final String? app;

  /// The app's `APP_ENV`, when known.
  final String? env;

  /// The device the snapshot was taken from, when known.
  final String? device;

  /// The route the app was on, when known.
  final String? route;

  /// When the snapshot was taken, when known.
  final DateTime? exportedAt;

  /// How many values the snapshot holds.
  int get length => storage.length + backpack.length;

  /// Whether the snapshot holds nothing.
  bool get isEmpty => storage.isEmpty && backpack.isEmpty;

  /// `3 storage values, 2 Backpack values`.
  String get summary =>
      '${_count(storage.length, 'storage value')}, '
      '${_count(backpack.length, 'Backpack value')}';

  /// The size of the values as JSON, in bytes.
  int get sizeInBytes => utf8.encode(jsonEncode(toImportJson())).length;

  /// Keys whose name, or a name inside their value, looks like a credential,
  /// or whose text value looks like a JWT.
  List<String> get secretKeys {
    final List<String> keys = [];
    void scan(Map<String, Object?> values) {
      for (final MapEntry<String, Object?> entry in values.entries) {
        if (keys.contains(entry.key)) continue;
        if (_secretName.hasMatch(entry.key) || _holdsSecret(entry.value)) {
          keys.add(entry.key);
        }
      }
    }

    scan(storage);
    scan(backpack);
    return keys;
  }

  static bool _holdsSecret(Object? value, [int depth = 0]) {
    if (value is String) return _jwt.hasMatch(value);
    if (depth > 6) return false;
    if (value is Map) {
      return value.entries.any(
        (MapEntry<Object?, Object?> entry) =>
            _secretName.hasMatch('${entry.key}') ||
            _holdsSecret(entry.value, depth + 1),
      );
    }
    if (value is List) {
      return value.any((Object? item) => _holdsSecret(item, depth + 1));
    }
    return false;
  }

  static final RegExp _secretName = RegExp(
    r'token|secret|password|passwd|bearer|api[_-]?key|private[_-]?key',
    caseSensitive: false,
  );
  static final RegExp _jwt = RegExp(
    r'^[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}$',
  );

  /// Reads the payload `storage.export` returned from [device].
  ///
  /// Throws a [LiveCommandException] when it isn't a snapshot.
  factory LiveSnapshot.fromPayload(Object? payload, {String? device}) {
    if (payload is! Map) {
      throw LiveCommandException('The app didn\'t return a snapshot.');
    }
    try {
      return LiveSnapshot(
        storage: _stringKeyed(payload['storage'], 'storage'),
        backpack: _stringKeyed(payload['backpack'], 'backpack'),
        skipped: [
          if (payload['skipped'] case final List items)
            for (final Object? item in items)
              if (item is Map) Map<String, Object?>.from(item),
        ],
        app: _text(payload['app']),
        env: _text(payload['env']),
        device: device ?? _text(payload['device']),
        route: _text(payload['route']),
        exportedAt: DateTime.tryParse(_text(payload['exportedAt']) ?? ''),
      );
    } on FormatException catch (e) {
      throw LiveCommandException('The app returned a snapshot ${e.message}.');
    }
  }

  /// Reads [text]: a file written by `export --to`, the output of
  /// `export --json`, or a bare `{"storage": ..., "backpack": ...}` object.
  ///
  /// Throws a [FormatException] saying what's wrong.
  static LiveSnapshot decode(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('isn\'t valid JSON (${e.message})');
    }
    // export --json prints [{device, ok, result}].
    if (decoded is List) {
      if (decoded.length != 1 || decoded.single is! Map) {
        throw FormatException(
          'holds ${decoded.length} apps\' results; export one app at a time',
        );
      }
      decoded = (decoded.single as Map)['result'];
    }
    if (decoded is Map &&
        decoded['result'] is Map &&
        !decoded.containsKey('storage')) {
      decoded = decoded['result'];
    }
    if (decoded is! Map ||
        !decoded.containsKey('storage') && !decoded.containsKey('backpack')) {
      throw const FormatException(
        'should be a JSON object with "storage" and "backpack"',
      );
    }
    final Object? version = decoded['nylo'];
    if (version is num && version > formatVersion) {
      throw FormatException(
        'uses snapshot format $version, newer than this Metro '
        '(format $formatVersion). Update nylo_framework',
      );
    }
    return LiveSnapshot(
      storage: _stringKeyed(decoded['storage'], 'storage'),
      backpack: _stringKeyed(decoded['backpack'], 'backpack'),
      app: _text(decoded['app']),
      env: _text(decoded['env']),
      device: _text(decoded['device']),
      route: _text(decoded['route']),
      exportedAt: DateTime.tryParse(_text(decoded['exportedAt']) ?? ''),
    );
  }

  /// The file `export --to` writes.
  String encode() {
    final Map<String, Object?> document = {
      'nylo': formatVersion,
      if (exportedAt != null)
        'exportedAt': exportedAt!.toUtc().toIso8601String(),
      if (app != null) 'app': app,
      if (env != null) 'env': env,
      if (device != null) 'device': device,
      if (route != null) 'route': route,
      'storage': storage,
      'backpack': backpack,
    };
    return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
  }

  /// What `snapshot.import` is sent.
  Map<String, Object?> toImportJson() => {
    'storage': storage,
    'backpack': backpack,
  };

  /// The type and value shown for a storage or Backpack [entry] in a table.
  ///
  /// Tagged entries show their tag (`model`, `raw`, `string · ttl 60s`, or
  /// the Backpack model's class); plain entries show Dart's type.
  static ({String type, Object? value}) describeEntry(Object? entry) {
    if (entry is Map && entry['type'] is String) {
      final Set<Object?> keys = entry.keys.toSet();
      if (keys.every(
        (Object? key) => key == 'type' || key == 'value' || key == 'ttl',
      )) {
        final Object? ttl = entry['ttl'];
        return (
          type: '${entry['type']}${ttl == null ? '' : ' · ttl ${ttl}s'}',
          value: entry['value'],
        );
      }
      if ((entry['type'] == 'model' || entry['type'] == 'models') &&
          entry['model'] is String &&
          keys.every(
            (Object? key) => key == 'type' || key == 'model' || key == 'value',
          )) {
        final String model = '${entry['model']}';
        return (
          type: entry['type'] == 'models' ? 'List<$model>' : model,
          value: entry['value'],
        );
      }
    }
    return (
      type: switch (entry) {
        int() => 'int',
        double() => 'double',
        bool() => 'bool',
        String() => 'string',
        null => 'null',
        _ => 'json',
      },
      value: entry,
    );
  }

  static Map<String, Object?> _stringKeyed(Object? value, String store) {
    if (value == null) return {};
    if (value is! Map) {
      throw FormatException('whose "$store" isn\'t a JSON object');
    }
    return {
      for (final MapEntry<Object?, Object?> entry in value.entries)
        '${entry.key}': entry.value,
    };
  }

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static String _count(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 's'}';
}

/// Folders a bare name is looked for in, after where it was typed.
const List<String> snapshotFolders = ['snapshots', 'exports'];

/// The snapshot file [source] names, or null when nothing matches.
///
/// A path is taken as written. A bare name also matches `<name>.json`, and is
/// looked for in [snapshotFolders] under [root], so `import demo` finds
/// `snapshots/demo.json`.
File? findSnapshotFile(String source, {String root = '.'}) {
  final List<String> names = [
    source,
    if (!source.toLowerCase().endsWith('.json')) '$source.json',
  ];
  for (final String name in names) {
    final File file = File(name);
    if (file.existsSync()) return file;
  }
  // Only a bare name is looked for elsewhere; a path means where it says.
  if (source.contains('/') || source.contains(r'\')) return null;
  for (final String folder in snapshotFolders) {
    for (final String name in names) {
      final File file = File('$root/$folder/$name');
      if (file.existsSync()) return file;
    }
  }
  return null;
}

/// The seeder name for a snapshot file at [path]:
/// `snapshots/Pro-User.json` becomes `pro_user`.
String snapshotNameFor(String path) {
  final String base = path.split(RegExp(r'[\\/]')).last;
  final int dot = base.lastIndexOf('.');
  final String stem = dot >= 0 ? base.substring(0, dot) : base;
  return seederNameFrom(stem) ?? 'snapshot';
}

/// [input] as a seeder name (`demo_user`), or null when it can't be one.
String? seederNameFrom(String input) {
  final String name = ReCase(input.trim()).snakeCase
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name) ? name : null;
}

/// [value] as a Dart literal that can sit in a `const` map.
///
/// Maps and lists are laid out the way `dart format` lays them out: one
/// entry per line, indented by [step] with trailing commas, when the literal
/// holds another non-empty map or list, or when it wouldn't fit within
/// [width] columns after [indent] and [prefix] (the text already on the
/// line, such as the key); otherwise on one line. [expand] writes [value]
/// itself one entry per line even when it would fit.
String dartLiteral(
  Object? value, {
  String indent = '',
  String step = '  ',
  int width = 80,
  bool expand = false,
  int prefix = 0,
}) {
  final String inline = _inlineLiteral(value);
  if (value is! Map && value is! List) return inline;
  final bool fits = indent.length + prefix + inline.length + 1 <= width;
  if (!expand && fits && !_holdsCollection(value)) return inline;

  final String inner = '$indent$step';
  final StringBuffer buffer = StringBuffer();
  if (value is Map) {
    if (value.isEmpty) return '{}';
    buffer.writeln('{');
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final String key = _stringLiteral('${entry.key}');
      buffer
        ..write(inner)
        ..write(key)
        ..write(': ')
        ..write(
          dartLiteral(
            entry.value,
            indent: inner,
            step: step,
            width: width,
            prefix: key.length + 2,
          ),
        )
        ..writeln(',');
    }
    buffer.write('$indent}');
  } else {
    final List<Object?> items = value as List;
    if (items.isEmpty) return '[]';
    buffer.writeln('[');
    for (final Object? item in items) {
      buffer
        ..write(inner)
        ..write(dartLiteral(item, indent: inner, step: step, width: width))
        ..writeln(',');
    }
    buffer.write('$indent]');
  }
  return buffer.toString();
}

/// Whether a map or list [value] holds a non-empty map or list, which makes
/// `dart format` split it one entry per line.
bool _holdsCollection(Object? value) {
  final Iterable<Object?> elements = value is Map
      ? value.values
      : value as List;
  return elements.any(
    (Object? element) =>
        (element is Map && element.isNotEmpty) ||
        (element is List && element.isNotEmpty),
  );
}

String _inlineLiteral(Object? value) {
  if (value is Map) {
    if (value.isEmpty) return '{}';
    return '{${value.entries.map((MapEntry<Object?, Object?> entry) => '${_stringLiteral('${entry.key}')}: ${_inlineLiteral(entry.value)}').join(', ')}}';
  }
  if (value is List) {
    if (value.isEmpty) return '[]';
    return '[${value.map(_inlineLiteral).join(', ')}]';
  }
  if (value == null) return 'null';
  if (value is bool || value is int) return '$value';
  if (value is double) {
    if (value.isNaN) return 'double.nan';
    if (value.isInfinite) {
      return value.isNegative ? 'double.negativeInfinity' : 'double.infinity';
    }
    return '$value';
  }
  return _stringLiteral('$value');
}

/// [text] as a single-quoted Dart string.
String _stringLiteral(String text) {
  final StringBuffer buffer = StringBuffer("'");
  for (final int rune in text.runes) {
    switch (rune) {
      case 0x5C: // \
        buffer.write(r'\\');
      case 0x27: // '
        buffer.write(r"\'");
      case 0x24: // $
        buffer.write(r'\$');
      case 0x0A:
        buffer.write(r'\n');
      case 0x0D:
        buffer.write(r'\r');
      case 0x09:
        buffer.write(r'\t');
      case < 0x20 || 0x7F:
        buffer.write('\\u{${rune.toRadixString(16)}}');
      default:
        buffer.writeCharCode(rune);
    }
  }
  buffer.write("'");
  return buffer.toString();
}
