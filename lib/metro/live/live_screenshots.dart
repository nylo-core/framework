import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'live_app.dart';
import 'live_output.dart';
import 'live_recorder.dart';
import 'live_runner.dart';

/// The `screenshots` modes `playbooks.run` takes, from most to least saved.
///
/// `marked` saves the `screenshot()` steps. `auto` saves them too, and every
/// step of a playbook that has none. `all` saves every step and the
/// `screenshot()` steps. `failures` saves only the screen of a failing step,
/// which every mode but `off` saves. `off` saves nothing.
const List<String> liveScreenshotModes = [
  'all',
  'auto',
  'marked',
  'failures',
  'off',
];

/// [text] as a file name: lowercase letters and digits, with a `-` for
/// everything in between, at most [max] characters long.
///
/// `Type "demo@nylo.dev" into Email` becomes `type-demo-nylo-dev-into-email`.
String liveSlug(String text, {int max = 48}) {
  final String slug = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length <= max) return slug;
  return slug.substring(0, max).replaceAll(RegExp(r'-+$'), '');
}

/// [name] (a playbook, a `screenshot()` name or a store) with only the
/// letters, digits, `_`, `-` and `.` a file name keeps everywhere, starting
/// with a letter or digit.
String _fileName(String name) => name
    .replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '-')
    .replaceAll(RegExp(r'^[-.]+|-+$'), '');

/// [path] relative to [root] when it's inside it, otherwise [path].
String liveRelativePath(String path, String root) {
  final String prefix = '$root${Platform.pathSeparator}';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

/// Whether the `--out` value [requested] names a folder rather than a file:
/// it ends with a path separator, or is a folder already.
bool liveOutIsFolder(String requested, {required String root}) =>
    requested.endsWith('/') ||
    requested.endsWith(Platform.pathSeparator) ||
    Directory(_resolve(requested, root)).existsSync();

String _resolve(String path, String root) =>
    File(path).isAbsolute ? path : '$root${Platform.pathSeparator}$path';

/// Where `screenshot` saves the capture of [device], running in [mode],
/// taken [at].
///
/// By default that's `screenshots/<mode>-<device>-<yyyyMMdd-HHmm>.png` in
/// [root], with [suffix] (e.g. `-native`) before the extension. When that
/// file is there already, the seconds are added, then `-2`, `-3` and so on,
/// so every capture keeps its own file. With an empty [extension] it's a
/// folder, named the same way.
///
/// [requested] is the `--out` value, relative to [root]: a `.png` is saved
/// as named, and a folder gets the default name inside it. When [several]
/// apps are captured, each named `.png` gets its device name added.
String liveScreenshotPath({
  required String root,
  required String device,
  required String mode,
  required DateTime at,
  String? requested,
  bool several = false,
  String suffix = '',
  String extension = '.png',
  bool Function(String path)? exists,
}) {
  final bool Function(String path) taken =
      exists ??
      ((String path) =>
          FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound);
  final String separator = Platform.pathSeparator;
  final String slug = liveSlug(device);

  String folder = '$root${separator}screenshots';
  if (requested != null) {
    final String path = _resolve(requested, root);
    if (!liveOutIsFolder(requested, root: root)) {
      if (!several) return path;
      final int dot = path.lastIndexOf('.');
      return '${path.substring(0, dot)}-$slug${path.substring(dot)}';
    }
    folder = path.replaceAll(RegExp(r'[\\/]+$'), '');
  }

  String two(int n) => n.toString().padLeft(2, '0');
  final String minute =
      '${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}'
      '${two(at.minute)}';
  final String name = [
    liveSlug(mode),
    slug,
    minute,
  ].where((String part) => part.isNotEmpty).join('-');
  final String path = '$folder$separator$name$suffix$extension';
  if (!taken(path)) return path;
  final String seconds = '$folder$separator$name${two(at.second)}';
  if (!taken('$seconds$suffix$extension')) return '$seconds$suffix$extension';
  for (int n = 2; ; n++) {
    if (!taken('$seconds-$n$suffix$extension')) {
      return '$seconds-$n$suffix$extension';
    }
  }
}

/// A locale and theme to capture the app in, from `--locales` and
/// `--themes`.
class LiveCell {
  /// Creates a [LiveCell] for [locale] and [theme], either of which may be
  /// left as it is.
  const LiveCell({this.locale, this.theme});

  /// The language code, e.g. `es`.
  final String? locale;

  /// The theme id, e.g. `dark`.
  final String? theme;

  /// Whether it leaves both the locale and the theme as they are.
  bool get isEmpty => locale == null && theme == null;

  /// Its folder or file name: `es`, `dark` or `es-dark`.
  String get name => [?locale, ?theme].map(_fileName).join('-');

  /// How it's shown in the terminal: `es · dark`.
  String get label => [?locale, ?theme].join(' · ');

  /// The `matrix` sent with `playbooks.run`.
  Map<String, Object?> toJson() => {'locale': ?locale, 'theme': ?theme};
}

/// Every [LiveCell] for the `--locales` [locales] and `--themes` [themes],
/// locales outer and themes inner, checked against the `locales` and
/// `themes` the app lists in its [status].
///
/// `all` stands for everything the app lists. A null list leaves that side
/// as it is. Throws a [LiveCommandException] naming the app's locales or
/// themes when one asked for isn't among them.
List<LiveCell> liveCells(
  Map<String, Object?> status, {
  List<String>? locales,
  List<String>? themes,
}) {
  final List<String?> languages = locales == null
      ? const [null]
      : _chooseFrom('locale', status['locales'], locales);
  final List<String?> ids = themes == null
      ? const [null]
      : _chooseFrom('theme', status['themes'], themes);
  return [
    for (final String? locale in languages)
      for (final String? theme in ids) LiveCell(locale: locale, theme: theme),
  ];
}

List<String> _chooseFrom(String kind, Object? listed, List<String> wanted) {
  final List<String> available = [
    if (listed is List)
      for (final Object? value in listed)
        if (value != null) '$value',
  ];
  if (available.isEmpty) {
    throw LiveCommandException(
      kind == 'locale'
          ? 'This app lists no locales. They come from the lang/*.json files '
                'it bundles.'
          : 'This app lists no themes. Register them in '
                'lib/bootstrap/theme.dart.',
    );
  }
  if (wanted.contains('all')) return available;
  final List<String> chosen = [];
  for (final String value in wanted) {
    if (!available.contains(value)) {
      throw LiveCommandException(
        'No $kind "$value" in this app. Its ${kind}s: '
        '${available.join(', ')}.',
      );
    }
    if (!chosen.contains(value)) chosen.add(value);
  }
  return chosen;
}

/// Where `screenshot --locales/--themes` saves the capture of each of
/// [cells], in the same order.
///
/// By default they're `<cell>.png` files in a folder named like
/// [liveScreenshotPath] names a file: `screenshots/<mode>-<device>-<time>/`.
/// An `--out` folder ([requested]) holds them instead, in a folder per device
/// when [several] apps are captured. An `--out` `.png` gets each cell's name
/// added, after the device's when there are several. [suffix] (e.g.
/// `-ios-6.9`) follows each cell's name.
List<String> liveCellScreenshotPaths({
  required String root,
  required String device,
  required String mode,
  required DateTime at,
  required List<LiveCell> cells,
  String? requested,
  bool several = false,
  String suffix = '',
  bool Function(String path)? exists,
}) {
  final String separator = Platform.pathSeparator;
  if (requested != null && !liveOutIsFolder(requested, root: root)) {
    final String path = _resolve(requested, root);
    final int dot = path.lastIndexOf('.');
    final String stem =
        '${path.substring(0, dot)}${several ? '-${liveSlug(device)}' : ''}';
    return [
      for (final LiveCell cell in cells)
        '$stem-${cell.name}$suffix${path.substring(dot)}',
    ];
  }
  final String folder = requested != null
      ? [
          _resolve(requested, root).replaceAll(RegExp(r'[\\/]+$'), ''),
          if (several) liveSlug(device),
        ].join(separator)
      : liveScreenshotPath(
          root: root,
          device: device,
          mode: mode,
          at: at,
          extension: '',
          exists: exists,
        );
  return [
    for (final LiveCell cell in cells)
      '$folder$separator${cell.name}$suffix.png',
  ];
}

/// An app store's screenshot size, as the app lists it in `status.stores`.
class LiveStore {
  /// Creates a [LiveStore] called [id], [width] by [height] pixels.
  const LiveStore({
    required this.id,
    required this.width,
    required this.height,
    this.label,
  });

  /// The id `--store` takes, e.g. `ios-6.9`.
  final String id;

  /// The width in pixels.
  final int width;

  /// The height in pixels.
  final int height;

  /// What the store calls the size, e.g. `iPhone 6.9"`.
  final String? label;

  /// `1320×2868`.
  String get size => '$width×$height';

  /// The stores listed in an app's [status].
  static List<LiveStore> listIn(Map<String, Object?> status) {
    final Object? stores = status['stores'];
    return [
      if (stores is List)
        for (final Object? store in stores)
          if (store is Map && store['id'] is String)
            LiveStore(
              id: store['id'] as String,
              width: _int(store['width']) ?? 0,
              height: _int(store['height']) ?? 0,
              label: store['label'] is String ? store['label'] as String : null,
            ),
    ];
  }
}

/// The store [id] among those the app lists in its [status].
///
/// Throws a [LiveCommandException] naming the app's stores when it isn't one
/// of them.
LiveStore liveStore(Map<String, Object?> status, String id) {
  final List<LiveStore> stores = LiveStore.listIn(status);
  for (final LiveStore store in stores) {
    if (store.id == id) return store;
  }
  throw LiveCommandException(
    'No store "$id" in this app. Its stores: '
    '${stores.map((LiveStore store) => '${store.id} (${store.size})').join(', ')}.',
  );
}

/// Adds the stores the app lists in its [status] to [block], with [use] as
/// how to capture at one, e.g. `screenshot --store`.
void renderStoreList(
  LiveBlock block,
  Map<String, Object?> status, {
  String use = 'screenshot --store',
}) {
  final List<LiveStore> stores = LiveStore.listIn(status);
  block
    ..table(
      ['STORE', 'SIZE', 'NAME'],
      [
        for (final LiveStore store in stores)
          [store.id, store.size, store.label ?? ''],
      ],
    )
    ..note(
      'Capture at one with $use ${stores.isEmpty ? 'ios-6.9' : stores.first.id}',
    );
}

/// The width and height in the header of [png], or null when it isn't a
/// PNG.
({int width, int height})? livePngSize(List<int> png) {
  const List<int> signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (png.length < 24) return null;
  for (int i = 0; i < signature.length; i++) {
    if (png[i] != signature[i]) return null;
  }
  // The IHDR chunk comes first, with the width and height as 4-byte ints.
  int read(int at) =>
      (png[at] << 24) | (png[at + 1] << 16) | (png[at + 2] << 8) | png[at + 3];
  return (width: read(16), height: read(20));
}

/// A screenshot a playbook step reported, and where Metro saves it.
class PlaybookScreenshotFile {
  /// Creates a [PlaybookScreenshotFile].
  const PlaybookScreenshotFile({
    required this.id,
    required this.kind,
    required this.path,
    required this.file,
    required this.step,
    this.name,
    this.locale,
    this.theme,
    this.store,
    this.native = false,
    this.nativeFallback,
    this.width,
    this.height,
  });

  /// The id the app holds the capture under, e.g. `s3`.
  final String id;

  /// Why it was taken: `step`, `marked` or `failure`.
  final String kind;

  /// The name given to `screenshot()`, for a `marked` capture.
  final String? name;

  /// Where it's saved.
  final String path;

  /// [path] as it's printed: relative to the project.
  final String file;

  /// The title of the step it was taken after.
  final String step;

  /// The locale it was taken in, when the run captures several.
  final String? locale;

  /// The theme it was taken in, when the run captures several.
  final String? theme;

  /// The app store size it was drawn at, e.g. `ios-6.9`, or null for the
  /// screen as it is.
  final String? store;

  /// Whether Metro took it with the iOS Simulator or adb, for
  /// a `screenshot('name')` step, rather than the app.
  final bool native;

  /// Why Metro couldn't capture a `screenshot()` step, so the app took it,
  /// or null.
  final String? nativeFallback;

  /// The size in pixels the app reported.
  final int? width;

  /// The height in pixels the app reported.
  final int? height;

  /// Whether it shows the screen of a failing step.
  bool get isFailure => kind == 'failure';

  /// How it's named on its step's line: the file, after its store and its
  /// locale and theme folders when it has them, e.g. `ios-6.9/es/cart.png`.
  String get shown {
    final String name = path.split(Platform.pathSeparator).last;
    if (isFailure) return name;
    final LiveCell cell = LiveCell(locale: locale, theme: theme);
    return [
      ?store,
      if (!cell.isEmpty) cell.name,
      name,
    ].join(Platform.pathSeparator);
  }

  /// The `--json` representation.
  Map<String, Object?> toJson() => {
    'file': path,
    'kind': kind,
    'name': ?name,
    'step': step,
    'locale': ?locale,
    'theme': ?theme,
    'store': ?store,
    if (native) 'native': true,
    'nativeFallback': ?nativeFallback,
    'width': ?width,
    'height': ?height,
  };
}

/// Decides where the screenshots of one playbook run are saved, one
/// `nylo.playbook` event at a time, as they arrive.
///
/// A step's screenshots go in `screenshots/<playbook>`: `01-visit-sign-up.png`
/// for the first step, named after its title, and `cart.png` for
/// `screenshot('cart')`. Steps inside a `scene()` carry the scene's number
/// first (`03-02-tap-pay.png`), so the files sort in the order they ran. The
/// screen of a failing step goes in `build/playbooks/failures` as
/// `<playbook>-<step>.png`.
///
/// A screenshot taken in a locale or theme of its own, or during a pass of
/// `--locales`/`--themes`, goes in a folder for it (`es`, `dark` or
/// `es-dark`), and a failure gets it in its name.
class PlaybookScreenshotFiles {
  /// Creates a [PlaybookScreenshotFiles] saving in [root].
  ///
  /// [device] is a folder name for the device, used when several apps play
  /// at once so their files stay apart. [cell] is the locale and theme of
  /// the pass being played, if any.
  PlaybookScreenshotFiles({required this.root, this.device, this.cell});

  /// The project directory.
  final String root;

  /// The device's folder name, or null for one app.
  final String? device;

  /// The locale and theme of the pass being played, or null.
  final LiveCell? cell;

  /// The group steps that have begun and not ended, innermost last.
  final List<({int depth, Object? index, String name})> _groups = [];

  /// The screenshots [event] reported, with where each one is saved.
  List<PlaybookScreenshotFile> filesFor(Map<String, Object?> event) {
    final int depth = _depthOf(event);
    switch (event['event']) {
      case 'begin' when event['group'] == true:
        _groups.add((
          depth: depth,
          index: event['index'],
          name: '${event['name']}',
        ));
      case 'step':
        // A group's own line can carry the screen of a failure that
        // happened before any of its steps ran.
        if (event['group'] == true &&
            _groups.isNotEmpty &&
            _groups.last.depth == depth &&
            _groups.last.index == event['index']) {
          _groups.removeLast();
        }
        final Object? shots = event['shots'];
        if (shots is! List) return const [];
        return [
          for (final Object? shot in shots)
            if (shot is Map && shot['id'] is String)
              _file(event, depth, Map<String, Object?>.from(shot)),
        ];
    }
    return const [];
  }

  PlaybookScreenshotFile _file(
    Map<String, Object?> event,
    int depth,
    Map<String, Object?> shot,
  ) {
    final String separator = Platform.pathSeparator;
    final String playbook = _fileName('${event['name'] ?? ''}');
    final String folder = playbook.isEmpty ? 'playbook' : playbook;
    final String title = '${event['title'] ?? ''}';
    final String number = [
      for (final ({int depth, Object? index, String name}) group in _groups)
        if (group.depth < depth && group.name == '${event['name']}')
          _two(group.index),
      _two(event['index']),
    ].join('-');
    final String kind = '${shot['kind'] ?? 'step'}';
    final String? name = shot['name'] is String ? shot['name'] as String : null;
    final LiveCell taken = LiveCell(
      locale: shot['locale'] is String
          ? shot['locale'] as String
          : cell?.locale,
      theme: shot['theme'] is String ? shot['theme'] as String : cell?.theme,
    );
    final String? cellName = taken.isEmpty ? null : taken.name;
    final String? store = shot['store'] is String
        ? _fileName(shot['store'] as String)
        : null;

    final String path;
    if (kind == 'failure') {
      final String file = [folder, ?device, ?cellName, number].join('-');
      path =
          '$root${separator}build${separator}playbooks${separator}failures'
          '$separator$file.png';
    } else {
      final String directory = [
        root,
        'screenshots',
        folder,
        ?store,
        ?device,
        ?cellName,
      ].join(separator);
      final String marked = name == null ? '' : _fileName(name);
      final String slug = liveSlug(title);
      final String file = marked.isNotEmpty
          ? marked
          : slug.isEmpty
          ? number
          : '$number-$slug';
      path = '$directory$separator$file.png';
    }

    return PlaybookScreenshotFile(
      id: shot['id'] as String,
      kind: kind,
      name: name,
      path: path,
      file: liveRelativePath(path, root),
      step: title,
      locale: taken.locale,
      theme: taken.theme,
      store: kind == 'failure' ? null : store,
      native: shot['native'] == true,
      nativeFallback: shot['nativeFallback'] is String
          ? shot['nativeFallback'] as String
          : null,
      width: _int(shot['width']),
      height: _int(shot['height']),
    );
  }

  static String _two(Object? index) =>
      '${index is num ? index.toInt() : 0}'.padLeft(2, '0');
}

int _depthOf(Map<String, Object?> event) => switch (event['depth']) {
  final num depth => depth.toInt(),
  _ => 0,
};

int? _int(Object? value) => value is num ? value.toInt() : null;

/// The PNG in a `screenshot.capture` or `screenshot.get` [payload].
///
/// Throws a [LiveCommandException] when there isn't one.
Uint8List liveScreenshotBytes(Object? payload) {
  final Object? png = payload is Map ? payload['png'] : null;
  if (png is String && png.isNotEmpty) {
    try {
      return base64Decode(png);
    } on FormatException {
      // Reported below.
    }
  }
  throw LiveCommandException('The app didn\'t send a PNG.');
}

/// Collects a playbook run's screenshots from [app] while the run carries
/// on, one at a time in the order their steps ended, and writes them.
///
/// The app holds a limited number of captures, so each is collected as soon
/// as its step arrives rather than once the run ends. A native screenshot is
/// already on disk, where [nativeFile] says, and is moved into place.
class PlaybookScreenshotSaver {
  /// Creates a [PlaybookScreenshotSaver] for [app]. [onFailed] hears about a
  /// screenshot that couldn't be saved, and why. [nativeFile] gives the file
  /// Metro captured for a native screenshot's id, or null when there's none.
  PlaybookScreenshotSaver(this.app, {required this.onFailed, this.nativeFile});

  /// The app holding the captures.
  final LiveApp app;

  /// Called with each screenshot that couldn't be saved, and why.
  final void Function(PlaybookScreenshotFile file, String reason) onFailed;

  /// The file Metro captured for the native screenshot with an id.
  final Future<String?> Function(String id)? nativeFile;

  Future<void> _queue = Future<void>.value();
  final Map<String, PlaybookScreenshotFile> _saved = {};

  /// The screenshots saved so far, one per file, in the order they were
  /// first saved.
  List<PlaybookScreenshotFile> get saved => List.unmodifiable(_saved.values);

  /// Completes once every screenshot passed to [collect] so far is saved or
  /// reported to [onFailed].
  Future<void> get done => _queue;

  /// Collects [file] from the app and writes it, after the ones before it.
  void collect(PlaybookScreenshotFile file) {
    _queue = _queue.then((_) => _save(file));
  }

  Future<void> _save(PlaybookScreenshotFile file) async {
    try {
      final File output = File(file.path);
      if (file.native) {
        final String? taken = await nativeFile?.call(file.id);
        if (taken == null || !File(taken).existsSync()) {
          throw LiveCommandException('Metro didn\'t take this screenshot.');
        }
        output.parent.createSync(recursive: true);
        _move(File(taken), output);
        final ({int width, int height})? size = livePngSize(_header(output));
        file = PlaybookScreenshotFile(
          id: file.id,
          kind: file.kind,
          path: file.path,
          file: file.file,
          step: file.step,
          name: file.name,
          locale: file.locale,
          theme: file.theme,
          native: true,
          width: size?.width,
          height: size?.height,
        );
      } else {
        final Uint8List bytes = liveScreenshotBytes(
          await app.call('screenshot.get', {
            'id': file.id,
          }, LiveRunner.commandTimeout),
        );
        output.parent.createSync(recursive: true);
        output.writeAsBytesSync(bytes);
      }
      _saved.remove(file.path);
      _saved[file.path] = file;
    } catch (e) {
      onFailed(file, describeLiveError(e));
    }
  }

  /// Moves [from] to [to], copying it when they're on different disks.
  static void _move(File from, File to) {
    try {
      from.renameSync(to.path);
    } on FileSystemException {
      from.copySync(to.path);
      from.deleteSync();
    }
  }

  /// The first bytes of [file], enough for [livePngSize].
  static List<int> _header(File file) {
    final RandomAccessFile open = file.openSync();
    try {
      return open.readSync(24);
    } finally {
      open.closeSync();
    }
  }
}

/// Adds a line for each folder of [saved] screenshots to [block], e.g.
/// `✓ 6 screenshots in screenshots/sign_up_to_dashboard/`.
///
/// A failing step's screenshot is already printed under the step, so only
/// the others are counted.
void renderScreenshotSummary(
  LiveBlock block,
  Iterable<PlaybookScreenshotFile> saved,
) => renderScreenshotFolders(block, [
  for (final PlaybookScreenshotFile file in saved)
    if (!file.isFailure) file.file,
]);

/// Adds a line for each folder of the screenshot [files] to [block], e.g.
/// `✓ 6 screenshots in screenshots/sign_up_to_dashboard/`.
void renderScreenshotFolders(LiveBlock block, Iterable<String> files) {
  final Map<String, int> folders = {};
  for (final String file in files) {
    final int slash = file.lastIndexOf(Platform.pathSeparator);
    final String folder = slash < 0 ? '' : file.substring(0, slash + 1);
    folders[folder] = (folders[folder] ?? 0) + 1;
  }
  for (final MapEntry<String, int> folder in folders.entries) {
    block.success(
      '${folder.value} ${folder.value == 1 ? 'screenshot' : 'screenshots'} '
      'in ${folder.key.isEmpty ? '.' : folder.key}',
    );
  }
}

/// A program to run, with its arguments.
typedef LiveProgram = ({String executable, List<String> arguments});

/// The program that opens [file] in the system's image viewer on [os] (as
/// [Platform.operatingSystem] names it).
///
/// Throws a [LiveCommandException] saying what to install when there's no
/// viewer to open it with.
LiveProgram liveOpenProgram(
  String file, {
  String? os,
  LiveProcesses processes = const LiveProcesses(),
}) {
  switch (os ?? Platform.operatingSystem) {
    case 'macos':
      return (executable: 'open', arguments: [file]);
    case 'windows':
      return (executable: 'cmd', arguments: ['/c', 'start', '', file]);
    default:
      if (processes.find('xdg-open') == null) {
        throw LiveCommandException(
          'Opening the screenshot needs xdg-open. Install xdg-utils, then '
          'try again.',
        );
      }
      // The viewer keeps running, so it's left in the background.
      return (
        executable: '/bin/sh',
        arguments: ['-c', r'xdg-open "$1" >/dev/null 2>&1 &', 'sh', file],
      );
  }
}

/// The program that copies the PNG [file] to the clipboard on [os] (as
/// [Platform.operatingSystem] names it).
///
/// On Linux that's `wl-copy` under Wayland, otherwise `xclip`. Throws a
/// [LiveCommandException] saying what to install when neither is there.
LiveProgram liveCopyProgram(
  String file, {
  String? os,
  LiveProcesses processes = const LiveProcesses(),
}) {
  switch (os ?? Platform.operatingSystem) {
    case 'macos':
      final String posix = file.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      return (
        executable: 'osascript',
        arguments: [
          '-e',
          'set the clipboard to (read (POSIX file "$posix") as «class PNGf»)',
        ],
      );
    case 'windows':
      final String path = file.replaceAll("'", "''");
      return (
        executable: 'powershell',
        arguments: [
          '-NoProfile',
          '-STA',
          '-Command',
          'Add-Type -AssemblyName System.Windows.Forms, System.Drawing; '
              '[System.Windows.Forms.Clipboard]::SetImage('
              "[System.Drawing.Image]::FromFile('$path'))",
        ],
      );
    default:
      final bool wayland = processes.environment.containsKey('WAYLAND_DISPLAY');
      final bool wlCopy = processes.find('wl-copy') != null;
      final bool xclip = processes.find('xclip') != null;
      // Both stay running to hand the image over, so their output is let go.
      if (wlCopy && (wayland || !xclip)) {
        return (
          executable: '/bin/sh',
          arguments: [
            '-c',
            r'wl-copy --type image/png < "$1" >/dev/null 2>&1',
            'sh',
            file,
          ],
        );
      }
      if (xclip) {
        return (
          executable: '/bin/sh',
          arguments: [
            '-c',
            r'xclip -selection clipboard -t image/png -i "$1" >/dev/null 2>&1',
            'sh',
            file,
          ],
        );
      }
      throw LiveCommandException(
        'Copying the screenshot needs ${wayland ? 'wl-clipboard' : 'xclip'}. '
        'Install it (e.g. sudo apt install '
        '${wayland ? 'wl-clipboard' : 'xclip'}), then try again.',
      );
  }
}
