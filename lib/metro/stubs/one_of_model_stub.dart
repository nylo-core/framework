import 'package:recase/recase.dart';

/// Parses the `--one-of` value into the subtype names.
///
/// Names are comma separated, e.g. "login_success,two_factor_required".
/// Blank entries and duplicates are dropped.
List<ReCase> parseOneOfTypes(String input) {
  final Set<String> seen = {};
  final List<ReCase> types = [];
  for (final String raw in input.split(',')) {
    final String name = raw.trim();
    if (name.isEmpty) continue;
    final ReCase reCase = ReCase(name);
    if (!seen.add(reCase.pascalCase)) continue;
    types.add(reCase);
  }
  return types;
}

/// Whether the app's [pubspec] allows primary constructors, which need a
/// minimum SDK of 3.13.
///
/// Reads the lower bound of `environment: sdk:`, written as `^3.13.0` or
/// `>=3.13.0 <4.0.0`. Returns false when it can't be read.
bool supportsPrimaryConstructors(String pubspec) {
  final RegExpMatch? match = RegExp(
    r'''^\s+sdk:\s*['"]?(?:\^|>=)\s*(\d+)\.(\d+)''',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) return false;
  final int major = int.parse(match.group(1)!);
  final int minor = int.parse(match.group(2)!);
  return major > 3 || (major == 3 && minor >= 13);
}

/// This stub is used to create a new OneOf model: a sealed parent class and
/// its subtypes, all in one file.
///
/// With [primaryConstructors], each subtype uses Dart 3.13's primary
/// constructor syntax.
String oneOfModelStub({
  required ReCase modelName,
  required List<ReCase> types,
  bool primaryConstructors = false,
}) {
  final String parent = modelName.pascalCase;
  final StringBuffer subtypes = StringBuffer();
  for (final ReCase type in types) {
    final String name = type.pascalCase;
    if (primaryConstructors) {
      subtypes.write('''

class $name() extends $parent {
  // TODO: add fields to the primary constructor and read them from [json].
  $name.fromJson(dynamic json) : this();
}
''');
    } else {
      subtypes.write('''

class $name extends $parent {
  // TODO: add fields and read them from [json].
  $name.fromJson(dynamic json);
}
''');
    }
  }

  return '''
/// Every response shape a [$parent] can be.
///
/// The OneOf entry for [$parent] in lib/bootstrap/decoders.dart picks
/// which subtype to build.
sealed class $parent {}
$subtypes''';
}

/// Adds a `OneOf.byKey` entry for a OneOf model to `modelDecoders` in
/// [decodersFile]. Each subtype's name is its value for the `'type'` field.
/// Also imports nylo_framework if decoders.dart doesn't yet.
///
/// Works with both shapes of decoders.dart: the `decoders([...])` list,
/// where the entry needs no key, and the older `{...}` map.
///
/// Returns [decodersFile] unchanged if neither can be found.
String addOneOfDecoders(
  String decodersFile, {
  required ReCase modelName,
  required List<ReCase> types,
}) {
  final String parent = modelName.pascalCase;
  final String? result =
      _addToList(decodersFile, _oneOfEntry(parent, types, keyed: false)) ??
      _addToMap(decodersFile, _oneOfEntry(parent, types, keyed: true));
  return result == null ? decodersFile : _withFrameworkImport(result);
}

/// The `OneOf.byKey` entry for [parent], with a `Parent:` key when [keyed].
String _oneOfEntry(String parent, List<ReCase> types, {required bool keyed}) {
  final StringBuffer entry = StringBuffer()
    ..write(
      "  // TODO: change 'type' to the field your API uses, or use OneOf.byStatus / OneOf.byJson\n",
    )
    ..write("  ${keyed ? '$parent: ' : ''}OneOf<$parent>.byKey('type', {\n");
  for (final ReCase type in types) {
    entry.write("    '${type.snakeCase}': ${type.pascalCase}.fromJson,\n");
  }
  entry.write('  }),\n');
  return entry.toString();
}

/// Matches `modelDecoders = decoders([`, the list form of decoders.dart.
final RegExp _decodersList = RegExp(r'modelDecoders\s*=\s*decoders\(\s*\[');

/// Adds [entry] to the end of the `decoders([...])` list, or returns null.
String? _addToList(String file, String entry) {
  final RegExpMatch? match = _decodersList.firstMatch(file);
  if (match == null) return null;
  final int open = match.end - 1;
  final int? close = _closingBrace(file, open, openChar: '[', closeChar: ']');
  if (close == null) return null;

  final String body = file.substring(open + 1, close).trimRight();
  // The last line of code, skipping comments, decides whether a comma is
  // needed. It goes on its own line so it can't land inside a comment.
  final String lastCode =
      body
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('//'))
          .lastOrNull ??
      '';
  final String separator = lastCode.isEmpty || lastCode.endsWith(',')
      ? ''
      : '\n,';
  final int insertAt = open + 1 + body.length;
  return file.replaceRange(insertAt, close, '$separator\n$entry');
}

/// Adds [entry] to the end of the `modelDecoders` map, or returns null.
String? _addToMap(String file, String entry) {
  const String declaration = 'final Map<Type, dynamic> modelDecoders = {';
  final int start = file.indexOf(declaration);
  if (start == -1) return null;
  final int? close = _closingBrace(file, start + declaration.length - 1);
  if (close == null) return null;
  return file.replaceRange(close, close, '\n$entry');
}

/// The import that brings `OneOf` into decoders.dart.
const String _frameworkImport =
    "import 'package:nylo_framework/nylo_framework.dart';";

/// Adds [_frameworkImport] to the top of [file] if it isn't there already.
/// The default decoders.dart doesn't import nylo_framework.
String _withFrameworkImport(String file) {
  if (file.contains(_frameworkImport)) return file;
  return '$_frameworkImport\n$file';
}

/// The index of the `}` that closes the `{` at [open] in [source], or null.
/// Pass [openChar] and [closeChar] to match other brackets, such as `[`.
///
/// Brackets inside strings and `//` comments are ignored, so entries that
/// contain their own brackets don't cut the map or list short.
int? _closingBrace(
  String source,
  int open, {
  String openChar = '{',
  String closeChar = '}',
}) {
  int depth = 0;
  for (int i = open; i < source.length; i++) {
    final String char = source[i];
    if (char == '/' && source.startsWith('//', i)) {
      final int end = source.indexOf('\n', i);
      if (end == -1) return null;
      i = end;
    } else if (char == "'" || char == '"') {
      int j = i + 1;
      while (j < source.length && source[j] != char) {
        if (source[j] == '\\') j++;
        j++;
      }
      i = j;
    } else if (char == openChar) {
      depth++;
    } else if (char == closeChar) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}
