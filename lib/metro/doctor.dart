import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import '/metro/playbook_routes.dart';

/// How one of `metro doctor`'s checks came out.
enum DoctorStatus {
  /// Everything the check looked at is wired up.
  ok,

  /// Something is wired wrong, so `metro doctor` exits non-zero.
  problem,

  /// Worth a look; it fails `metro doctor --strict` only.
  note,

  /// The project has nothing for the check to look at yet.
  skipped,
}

/// What one of `metro doctor`'s checks found.
class DoctorCheck {
  /// Creates a [DoctorCheck] labelled [label] that came out as [status].
  const DoctorCheck(
    this.label,
    this.status,
    this.summary, {
    this.details = const [],
    this.fixes = const [],
  });

  /// The check's name, e.g. `Routes`.
  final String label;

  /// How the check came out.
  final DoctorStatus status;

  /// One line on what the check found.
  final String summary;

  /// The files, keys or classes behind [summary], one per line.
  final List<String> details;

  /// What to change to fix it, one per line.
  final List<String> fixes;
}

/// Where Metro creates pages.
const String _pagesFolder = 'lib/resources/pages';

/// Where a Nylo project registers its decoders and controllers.
const String _decodersPath = 'lib/bootstrap/decoders.dart';

/// Runs every `metro doctor` check against the project in [projectRoot].
List<DoctorCheck> runDoctor({String projectRoot = '.'}) {
  return [
    checkRoutes(projectRoot: projectRoot),
    checkDecoders(projectRoot: projectRoot),
    checkLanguages(projectRoot: projectRoot),
    checkEnv(projectRoot: projectRoot),
    checkAssets(projectRoot: projectRoot),
  ];
}

/// The exit code for [checks]: 1 when one found a problem, or a note when
/// [strict], otherwise 0.
int doctorExitCode(List<DoctorCheck> checks, {bool strict = false}) =>
    checks.any(
      (DoctorCheck check) =>
          check.status == DoctorStatus.problem ||
          (strict && check.status == DoctorStatus.note),
    )
    ? 1
    : 0;

/// [checks] as `metro doctor` prints them, coloured when [ansi].
String formatDoctorReport(List<DoctorCheck> checks, {bool ansi = true}) {
  String paint(String code, String text) =>
      ansi ? '\x1B[${code}m$text\x1B[0m' : text;
  const int width = 12;

  final StringBuffer out = StringBuffer();
  for (final DoctorCheck check in checks) {
    final String colour = switch (check.status) {
      DoctorStatus.ok => '32',
      DoctorStatus.problem => '31',
      DoctorStatus.note => '33',
      DoctorStatus.skipped => '90',
    };
    out.writeln(
      '${paint(colour, check.label.padRight(width))}'
      '${check.status == DoctorStatus.skipped ? paint('90', check.summary) : check.summary}',
    );
    for (final String detail in check.details) {
      out.writeln('${' ' * width}${paint('90', detail)}');
    }
  }

  final List<String> fixes = [
    for (final DoctorCheck check in checks)
      if (check.status == DoctorStatus.problem) ...check.fixes,
  ];
  for (final String fix in fixes) {
    out.writeln(paint('32', 'Fix: $fix'));
  }
  if (doctorExitCode(checks) == 0) {
    out.writeln(paint('32', 'Everything is wired up.'));
  }
  return out.toString();
}

/// Pages that declare a route path but aren't added to a router.
DoctorCheck checkRoutes({String projectRoot = '.'}) {
  final _Project p = _Project(projectRoot);
  final Map<String, String> pages = {};
  p.dart(_pagesFolder).forEach((String path, String source) {
    for (final String page in _routableClasses(source)) {
      pages[page] = path;
    }
  });
  if (pages.isEmpty) {
    return const DoctorCheck('Routes', DoctorStatus.skipped, 'No pages yet');
  }

  final Set<String> routed = {
    for (final String source in p.dart('lib/routes').values)
      for (final RegExpMatch match in RegExp(
        r'\.add\s*\(\s*([A-Z]\w*)\s*\.\s*path\b',
      ).allMatches(source))
        match.group(1)!,
  };
  final List<String> unrouted = [
    for (final String page in pages.keys)
      if (!routed.contains(page)) page,
  ]..sort((String a, String b) => pages[a]!.compareTo(pages[b]!));

  if (unrouted.isEmpty) {
    return DoctorCheck(
      'Routes',
      DoctorStatus.ok,
      pages.length == 1
          ? 'The page has a route'
          : 'All ${pages.length} pages have a route',
    );
  }
  return DoctorCheck(
    'Routes',
    DoctorStatus.problem,
    unrouted.length == 1
        ? '1 page has no route: ${pages[unrouted.single]}'
        : '${unrouted.length} pages have no route',
    details: unrouted.length == 1
        ? const []
        : [for (final String page in unrouted) pages[page]!],
    fixes: [
      for (final String page in unrouted)
        'add router.add($page.path); to $routerPath',
    ],
  );
}

/// API services, controllers and models the app uses that
/// `lib/bootstrap/decoders.dart` doesn't register.
DoctorCheck checkDecoders({String projectRoot = '.'}) {
  final _Project p = _Project(projectRoot);
  final String? decoders = p.read(_decodersPath);
  if (decoders == null) {
    return const DoctorCheck(
      'Decoders',
      DoctorStatus.skipped,
      'No $_decodersPath',
    );
  }
  final String registry = withoutComments(decoders);
  final Map<String, String> lib = p.dart('lib')..remove(_decodersPath);

  // Only the project's own classes can be registered by the project.
  final Set<String> declared = {
    for (final String source in lib.values)
      for (final RegExpMatch match in _classDeclaration.allMatches(source))
        match.group(1)!,
  };
  final Set<String> models = {
    for (final MapEntry<String, String> entry in lib.entries)
      if (entry.key.startsWith('lib/app/models/'))
        for (final RegExpMatch match in _classDeclaration.allMatches(
          entry.value,
        ))
          match.group(1)!,
  };

  // Each missing class, with the map it belongs in and the first file that
  // uses it.
  final Map<String, (String, String)> missing = {};
  void find(RegExp usage, String map, {Set<String>? only}) {
    lib.forEach((String path, String source) {
      for (final RegExpMatch match in usage.allMatches(source)) {
        final String name = match.group(1)!;
        if (!declared.contains(name)) continue;
        if (only != null && !only.contains(name)) continue;
        if (RegExp('\\b$name\\b').hasMatch(registry)) continue;
        missing.putIfAbsent(name, () => (map, path));
      }
    });
  }

  find(RegExp(r'\bapi\s*<\s*([A-Z]\w*)\s*>\s*\('), 'apiDecoders');
  find(RegExp(r'\bNyStatefulWidget\s*<\s*([A-Z]\w*)\s*>'), 'controllers');
  find(
    RegExp(r'\bnetwork\s*<\s*(?:List\s*<\s*)?([A-Z]\w*)'),
    'modelDecoders',
    only: models,
  );

  if (missing.isEmpty) {
    return const DoctorCheck(
      'Decoders',
      DoctorStatus.ok,
      'Every API service, controller and model in use is registered',
    );
  }

  final bool decodersList = RegExp(r'modelDecoders\s*=\s*decoders\s*\(')
      .hasMatch(registry);
  String entry(String name, String map) => switch (map) {
    'modelDecoders' when decodersList => 'Decode($name.fromJson),',
    'modelDecoders' => '$name: (data) => $name.fromJson(data),',
    _ => '$name: () => $name(),',
  };

  final List<String> names = missing.keys.toList()
    ..sort((String a, String b) => missing[a]!.$2.compareTo(missing[b]!.$2));
  return DoctorCheck(
    'Decoders',
    DoctorStatus.problem,
    names.length == 1
        ? '${names.single} is used but not in ${missing[names.single]!.$1}'
        : '${names.length} classes are used but not registered',
    details: [
      for (final String name in names)
        names.length == 1
            ? 'used in ${missing[name]!.$2}'
            : '$name, not in ${missing[name]!.$1}: used in ${missing[name]!.$2}',
    ],
    fixes: [
      for (final String name in names)
        'add ${entry(name, missing[name]!.$1)} to '
            '${missing[name]!.$1} in $_decodersPath',
    ],
  );
}

/// Keys the default language file has that another language file doesn't.
DoctorCheck checkLanguages({String projectRoot = '.'}) {
  final _Project p = _Project(projectRoot);
  final List<String> files = p.files('lang', extension: '.json');
  if (files.isEmpty) {
    return const DoctorCheck(
      'Languages',
      DoctorStatus.skipped,
      'No lang/*.json files',
    );
  }

  final String? locale = _envValues(p.read('.env') ?? '')['DEFAULT_LOCALE'];
  final String base = files.contains('lang/$locale.json')
      ? 'lang/$locale.json'
      : files.contains('lang/en.json')
      ? 'lang/en.json'
      : files.first;
  final String baseName = base.substring('lang/'.length);

  final Map<String, Set<String>> keys = {};
  final List<String> invalid = [];
  for (final String file in files) {
    try {
      final Object? json = jsonDecode(p.read(file)!);
      if (json is! Map) throw const FormatException('not a JSON object');
      keys[file] = _flatKeys(json);
    } on FormatException {
      invalid.add(file);
    }
  }
  if (files.length == 1 && invalid.isEmpty) {
    return DoctorCheck(
      'Languages',
      DoctorStatus.ok,
      '$baseName is the only language file',
    );
  }

  final Map<String, List<String>> missing = {
    if (keys[base] case final Set<String> baseKeys)
      for (final String file in files)
        if (file != base && keys[file] != null)
          if (baseKeys.difference(keys[file]!).toList()..sort()
              case final List<String> gaps when gaps.isNotEmpty)
            file: gaps,
  };
  if (missing.isEmpty && invalid.isEmpty) {
    return DoctorCheck(
      'Languages',
      DoctorStatus.ok,
      files.length == 2
          ? '${files.firstWhere((String file) => file != base).substring('lang/'.length)} has every key $baseName has'
          : 'All ${files.length - 1} language files have every key $baseName has',
    );
  }

  const int shown = 10;
  final int count = missing.length + invalid.length;
  final String summary;
  if (count > 1) {
    summary = '$count language files need a look';
  } else if (invalid.isNotEmpty) {
    summary = '${invalid.single} isn\'t a valid JSON object';
  } else {
    final MapEntry<String, List<String>> only = missing.entries.single;
    summary =
        '${only.key.substring('lang/'.length)} is missing '
        '${_plural(only.value.length, 'key')} that $baseName has';
  }
  return DoctorCheck(
    'Languages',
    DoctorStatus.problem,
    summary,
    details: [
      for (final String file in invalid)
        if (count > 1) '$file isn\'t a valid JSON object',
      for (final MapEntry<String, List<String>> entry in missing.entries) ...[
        if (count > 1)
          '${entry.key} is missing ${_plural(entry.value.length, 'key')}:',
        for (final String key in entry.value.take(shown))
          count > 1 ? '  $key' : key,
        if (entry.value.length > shown)
          '${count > 1 ? '  ' : ''}and ${entry.value.length - shown} more',
      ],
    ],
  );
}

/// Keys in `.env` that `.env-example` doesn't have.
///
/// `APP_KEY` is left out: each copy of the app makes its own with
/// `metro make:key`.
DoctorCheck checkEnv({String projectRoot = '.'}) {
  final _Project p = _Project(projectRoot);
  final String? env = p.read('.env');
  final String? example = p.read('.env-example');
  if (env == null) {
    return const DoctorCheck('Env', DoctorStatus.skipped, 'No .env file');
  }
  if (example == null) {
    return const DoctorCheck(
      'Env',
      DoctorStatus.skipped,
      'No .env-example to compare .env with',
    );
  }

  final Set<String> shared = _envValues(example).keys.toSet();
  final List<String> missing = [
    for (final String key in _envValues(env).keys)
      if (key != 'APP_KEY' && !shared.contains(key)) key,
  ];
  if (missing.isEmpty) {
    return const DoctorCheck(
      'Env',
      DoctorStatus.ok,
      'Every key in .env is in .env-example',
    );
  }
  return DoctorCheck(
    'Env',
    DoctorStatus.problem,
    missing.length == 1
        ? '${missing.single} is in .env but not in .env-example'
        : '${missing.length} keys are in .env but not in .env-example',
    details: missing.length == 1 ? const [] : missing,
    fixes: [for (final String key in missing) 'add $key= to .env-example'],
  );
}

/// Images in `assets/images` (or `public/images`) that nothing refers to.
DoctorCheck checkAssets({String projectRoot = '.'}) {
  final _Project p = _Project(projectRoot);
  final String? folder = ['assets/images', 'public/images']
      .where((String path) => Directory('${p.root}/$path').existsSync())
      .firstOrNull;
  if (folder == null) {
    return const DoctorCheck(
      'Assets',
      DoctorStatus.skipped,
      'No assets/images folder',
    );
  }
  final List<String> images = p.files(folder);
  if (images.isEmpty) {
    return DoctorCheck('Assets', DoctorStatus.skipped, 'No images in $folder');
  }

  final String code = [
    ...p.dart('lib').values,
    p.read('pubspec.yaml') ?? '',
  ].join('\n');
  final List<String> unused = [
    for (final String image in images)
      if (!_mentions(code, _assetName(image.substring(folder.length + 1))))
        image,
  ];
  if (unused.isEmpty) {
    return DoctorCheck(
      'Assets',
      DoctorStatus.ok,
      images.length == 1
          ? 'The image in $folder is referenced'
          : 'All ${images.length} images in $folder are referenced',
    );
  }
  return DoctorCheck(
    'Assets',
    DoctorStatus.note,
    unused.length == 1
        ? '1 image in $folder is never referenced: ${unused.single}'
        : '${unused.length} images in $folder are never referenced',
    details: unused.length == 1 ? const [] : unused,
  );
}

/// Matches a class declaration, capturing the class name.
final RegExp _classDeclaration = RegExp(r'\bclass\s+([A-Z]\w*)');

/// The classes in [source] that declare a `static RouteView path`.
List<String> _routableClasses(String source) {
  final List<RegExpMatch> classes = _classDeclaration
      .allMatches(source)
      .toList();
  return [
    for (final RegExpMatch path in RegExp(
      r'\bstatic\s+(?:final\s+)?RouteView\s+path\b',
    ).allMatches(source))
      if (classes.lastWhereOrNull((RegExpMatch c) => c.start < path.start)
          case final RegExpMatch owner)
        owner.group(1)!,
  ];
}

/// The dotted keys of the leaves of [json], e.g. `nylo.journey.next`.
Set<String> _flatKeys(Map json, [String prefix = '']) => {
  for (final MapEntry entry in json.entries)
    if (entry.value is Map && (entry.value as Map).isNotEmpty)
      ..._flatKeys(entry.value as Map, '$prefix${entry.key}.')
    else
      '$prefix${entry.key}',
};

/// The keys and values of a `.env` file's [content], in order.
Map<String, String> _envValues(String content) => {
  for (final String raw in LineSplitter.split(content))
    if (raw.trim() case final String line
        when line.isNotEmpty && !line.startsWith('#') && line.contains('='))
      line.substring(0, line.indexOf('=')).trim(): line
          .substring(line.indexOf('=') + 1)
          .trim()
          .replaceAll(RegExp(r'''^["']|["']$'''), ''),
};

/// How code names the image at [path] in the images folder: without the
/// resolution folder Flutter picks variants from, e.g. `2.0x/logo.png`.
String _assetName(String path) => path.replaceFirstMapped(
  RegExp(r'(^|/)\d+(\.\d+)?x/'),
  (Match match) => match.group(1)!,
);

/// Whether [code] names [asset] as a whole path, not part of a longer name.
bool _mentions(String code, String asset) =>
    RegExp('(?<![\\w.-])${RegExp.escape(asset)}(?![\\w.-])').hasMatch(code);

/// [count] [noun]s, e.g. `1 key` or `14 keys`.
String _plural(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';

/// A Nylo project on disk, read with project-relative paths.
class _Project {
  _Project(this.root);

  /// The project's folder.
  final String root;

  /// The text of the file at [path], or null when there isn't one.
  String? read(String path) {
    final File file = File('$root/$path');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// The files under [folder], sorted, leaving out hidden ones.
  List<String> files(String folder, {String? extension}) {
    final Directory directory = Directory('$root/$folder');
    if (!directory.existsSync()) return const [];
    return [
      for (final FileSystemEntity entity in directory.listSync(recursive: true))
        if (entity is File)
          if ('$folder/${entity.path.substring(directory.path.length + 1).replaceAll(r'\', '/')}'
              case final String path
              when !path
                      .split('/')
                      .any((String part) => part.startsWith('.')) &&
                  (extension == null || path.endsWith(extension)))
            path,
    ]..sort();
  }

  /// The Dart files under [folder], with their comments blanked out.
  Map<String, String> dart(String folder) => {
    for (final String path in files(folder, extension: '.dart'))
      path: withoutComments(read(path)!),
  };
}
