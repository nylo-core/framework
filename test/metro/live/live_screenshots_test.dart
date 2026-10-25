import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/commands/live/live_commands.dart';
import 'package:nylo_framework/metro/live/live_discovery.dart';
import 'package:nylo_framework/metro/live/live_options.dart';
import 'package:nylo_framework/metro/live/live_output.dart';
import 'package:nylo_framework/metro/live/live_runner.dart';
import 'package:nylo_framework/metro/live/live_screenshots.dart';

import 'fake_processes.dart';
import 'fake_servers.dart';

/// Stands in for a PNG: the app's bytes are written as they are.
final List<int> png = utf8.encode('png bytes');

/// A `screenshot.capture` reply from an app in [mode], in [locale] and
/// [theme].
Map<String, Object?> capture({
  String mode = 'debug',
  String? locale,
  String? theme,
}) => {
  'png': base64Encode(png),
  'width': 1206,
  'height': 2622,
  'route': '/profile',
  'locale': locale ?? 'en',
  'theme': theme ?? 'light',
  'mode': mode,
};

/// The start of a real PNG [width] by [height]: enough for its size.
List<int> pngHeader(int width, int height) {
  List<int> int32(int value) => [
    value >> 24 & 255,
    value >> 16 & 255,
    value >> 8 & 255,
    value & 255,
  ];
  return [
    137, 80, 78, 71, 13, 10, 26, 10, // signature
    ...int32(13), ...utf8.encode('IHDR'), //
    ...int32(width), ...int32(height), 8, 6, 0, 0, 0,
  ];
}

void main() {
  group('liveSlug', () {
    test('keeps lowercase letters and digits, with a dash between', () {
      expect(
        liveSlug('Type "demo@nylo.dev" into Email'),
        'type-demo-nylo-dev-into-email',
      );
      expect(liveSlug('Type ••• into Password'), 'type-into-password');
      expect(liveSlug('Visit /sign-up'), 'visit-sign-up');
      expect(liveSlug('iPhone 17 Pro'), 'iphone-17-pro');
      expect(liveSlug('•••'), '');
    });

    test('cuts long titles without a dash at the end', () {
      final String slug = liveSlug(
        'See "Welcome back to your dashboard, have a lovely day"',
      );
      expect(slug.length, lessThanOrEqualTo(48));
      expect(slug, 'see-welcome-back-to-your-dashboard-have-a-lovely');
      expect(liveSlug('abc def', max: 4), 'abc');
    });
  });

  group('liveScreenshotPath', () {
    final DateTime at = DateTime(2026, 10, 13, 22, 51, 7);

    test('names the file after the mode, device and minute', () {
      expect(
        liveScreenshotPath(
          root: '/app',
          device: 'iPhone 17',
          mode: 'profile',
          at: at,
          exists: (_) => false,
        ),
        '/app/screenshots/profile-iphone-17-20261013-2251.png',
      );
    });

    test('adds the seconds, then a number, when the file is there', () {
      final Set<String> taken = {
        '/app/screenshots/debug-pixel-9-20261013-2251.png',
      };
      String next() {
        final String path = liveScreenshotPath(
          root: '/app',
          device: 'Pixel 9',
          mode: 'debug',
          at: at,
          exists: taken.contains,
        );
        taken.add(path);
        return path;
      }

      expect(next(), '/app/screenshots/debug-pixel-9-20261013-225107.png');
      expect(next(), '/app/screenshots/debug-pixel-9-20261013-225107-2.png');
      expect(next(), '/app/screenshots/debug-pixel-9-20261013-225107-3.png');
    });

    test('saves --out as named, adding the device for several apps', () {
      String out(String requested, {bool several = false}) =>
          liveScreenshotPath(
            root: '/app',
            device: 'iPhone 17',
            mode: 'debug',
            at: at,
            requested: requested,
            several: several,
            exists: (_) => true,
          );

      expect(out('home.png'), '/app/home.png');
      expect(out('/tmp/home.png'), '/tmp/home.png');
      expect(
        out('shots/home.png', several: true),
        '/app/shots/home-iphone-17.png',
      );
      expect(
        liveScreenshotPath(
          root: '/app',
          device: 'iPhone 17',
          mode: 'debug',
          at: at,
          requested: 'store/',
          exists: (_) => false,
        ),
        '/app/store/debug-iphone-17-20261013-2251.png',
      );
    });
  });

  group('liveScreenshotPath with a suffix or as a folder', () {
    final DateTime at = DateTime(2026, 10, 13, 22, 51, 7);

    test('puts the suffix before the extension, after the seconds', () {
      String native(Set<String> taken) => liveScreenshotPath(
        root: '/app',
        device: 'iPhone 17',
        mode: 'debug',
        at: at,
        suffix: '-native',
        exists: taken.contains,
      );

      expect(
        native({}),
        '/app/screenshots/debug-iphone-17-20261013-2251-native.png',
      );
      expect(
        native({'/app/screenshots/debug-iphone-17-20261013-2251-native.png'}),
        '/app/screenshots/debug-iphone-17-20261013-225107-native.png',
      );
    });

    test('names a folder the same way', () {
      expect(
        liveScreenshotPath(
          root: '/app',
          device: 'iPhone 17',
          mode: 'profile',
          at: at,
          extension: '',
          exists: {'/app/screenshots/profile-iphone-17-20261013-2251'}.contains,
        ),
        '/app/screenshots/profile-iphone-17-20261013-225107',
      );
    });
  });

  group('liveCells', () {
    const Map<String, Object?> status = {
      'locales': ['en', 'es', 'fr'],
      'themes': ['light', 'dark'],
    };

    test('pairs every locale with every theme, locales first', () {
      expect(
        liveCells(
          status,
          locales: ['en', 'es'],
          themes: ['light', 'dark'],
        ).map((cell) => cell.name),
        ['en-light', 'en-dark', 'es-light', 'es-dark'],
      );
      expect(liveCells(status, locales: ['all']).map((cell) => cell.name), [
        'en',
        'es',
        'fr',
      ]);
      expect(
        liveCells(status, themes: ['dark', 'dark']).map((cell) => cell.name),
        ['dark'],
      );
      expect(liveCells(status).single.isEmpty, isTrue);
    });

    test('a cell has a name, a label and the matrix it sends', () {
      const LiveCell cell = LiveCell(locale: 'es', theme: 'dark');

      expect(cell.name, 'es-dark');
      expect(cell.label, 'es · dark');
      expect(cell.toJson(), {'locale': 'es', 'theme': 'dark'});
      expect(const LiveCell(theme: 'dark').toJson(), {'theme': 'dark'});
    });

    test('names the app\'s locales and themes for one it doesn\'t have', () {
      expect(
        () => liveCells(status, locales: ['en', 'de']),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            'No locale "de" in this app. Its locales: en, es, fr.',
          ),
        ),
      );
      expect(
        () => liveCells(status, themes: ['sepia']),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            'No theme "sepia" in this app. Its themes: light, dark.',
          ),
        ),
      );
      expect(
        () => liveCells(const {'locales': []}, locales: ['all']),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('lang/*.json'),
          ),
        ),
      );
    });
  });

  group('liveCellScreenshotPaths', () {
    final DateTime at = DateTime(2026, 10, 21, 22, 51, 7);
    const List<LiveCell> cells = [
      LiveCell(locale: 'en'),
      LiveCell(locale: 'es'),
    ];

    List<String> paths({String? requested, bool several = false}) =>
        liveCellScreenshotPaths(
          root: '/app',
          device: 'iPhone 17',
          mode: 'profile',
          at: at,
          cells: cells,
          requested: requested,
          several: several,
          exists: (_) => false,
        );

    test('saves each cell in a folder named after the capture', () {
      expect(paths(), [
        '/app/screenshots/profile-iphone-17-20261021-2251/en.png',
        '/app/screenshots/profile-iphone-17-20261021-2251/es.png',
      ]);
    });

    test('saves into an --out folder, by device when there are several', () {
      expect(paths(requested: 'store/'), [
        '/app/store/en.png',
        '/app/store/es.png',
      ]);
      expect(paths(requested: 'store/', several: true), [
        '/app/store/iphone-17/en.png',
        '/app/store/iphone-17/es.png',
      ]);
    });

    test('adds each cell to an --out file', () {
      expect(paths(requested: 'home.png'), [
        '/app/home-en.png',
        '/app/home-es.png',
      ]);
      expect(paths(requested: 'home.png', several: true), [
        '/app/home-iphone-17-en.png',
        '/app/home-iphone-17-es.png',
      ]);
    });
  });

  group('stores', () {
    const Map<String, Object?> status = {
      'stores': [
        {
          'id': 'ios-6.9',
          'width': 1320,
          'height': 2868,
          'label': 'iPhone 6.9"',
        },
        {'id': 'play-phone', 'width': 1080, 'height': 1920},
      ],
    };

    test('finds a store the app lists', () {
      final LiveStore store = liveStore(status, 'ios-6.9');

      expect(store.size, '1320×2868');
      expect(store.label, 'iPhone 6.9"');
    });

    test('names the app\'s stores for one it doesn\'t list', () {
      expect(
        () => liveStore(status, 'ios-5.5'),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            'No store "ios-5.5" in this app. Its stores: ios-6.9 '
                '(1320×2868), play-phone (1080×1920).',
          ),
        ),
      );
    });

    test('lists the stores in a table', () {
      final LiveBlock block = LiveBlock();

      renderStoreList(block, status, use: 'screenshot --store');

      expect(block.lines.map((line) => line.$2), [
        'STORE       SIZE       NAME',
        'ios-6.9     1320×2868  iPhone 6.9"',
        'play-phone  1080×1920',
        '· Capture at one with screenshot --store ios-6.9',
      ]);
    });

    test('adds the store after each cell', () {
      expect(
        liveCellScreenshotPaths(
          root: '/app',
          device: 'iPhone 17',
          mode: 'debug',
          at: DateTime(2026, 10, 21, 23),
          cells: const [LiveCell(locale: 'en')],
          suffix: '-ios-6.9',
          exists: (_) => false,
        ),
        ['/app/screenshots/debug-iphone-17-20261021-2300/en-ios-6.9.png'],
      );
    });
  });

  group('livePngSize', () {
    test('reads the width and height from the header', () {
      expect(livePngSize(pngHeader(1206, 2622)), (width: 1206, height: 2622));
      expect(livePngSize(png), isNull);
    });
  });

  group('PlaybookScreenshotFiles', () {
    Map<String, Object?> step(
      int index,
      String title,
      List<Map<String, Object?>> shots, {
      String name = 'sign_up',
      int depth = 0,
      String status = 'passed',
    }) => {
      'event': 'step',
      'name': name,
      'index': index,
      'title': title,
      'depth': depth,
      'group': false,
      'status': status,
      'shots': shots,
    };

    Map<String, Object?> group(
      String event,
      int index,
      String title, {
      String name = 'sign_up',
      int depth = 0,
    }) => {
      'event': event,
      'name': name,
      'index': index,
      'title': title,
      'depth': depth,
      'group': true,
      if (event == 'step') 'status': 'passed',
    };

    test('names step screenshots by number and title', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      final List<PlaybookScreenshotFile> shots = files.filesFor(
        step(1, 'Visit /sign-up', [
          {'id': 's1', 'kind': 'step', 'width': 1206, 'height': 2622},
        ]),
      );

      expect(shots.single.id, 's1');
      expect(
        shots.single.path,
        '/app/screenshots/sign_up/01-visit-sign-up.png',
      );
      expect(shots.single.file, 'screenshots/sign_up/01-visit-sign-up.png');
      expect(shots.single.toJson(), {
        'file': '/app/screenshots/sign_up/01-visit-sign-up.png',
        'kind': 'step',
        'step': 'Visit /sign-up',
        'width': 1206,
        'height': 2622,
      });
      expect(
        files
            .filesFor(
              step(12, 'Type ••• into Password', [
                {'id': 's2', 'kind': 'step'},
              ]),
            )
            .single
            .file,
        'screenshots/sign_up/12-type-into-password.png',
      );
    });

    test('names marked screenshots by their name', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      expect(
        files
            .filesFor(
              step(4, 'Screenshot cart', [
                {'id': 's3', 'kind': 'marked', 'name': 'cart'},
              ]),
            )
            .single
            .file,
        'screenshots/sign_up/cart.png',
      );
    });

    test('saves a failing step\'s screen in build/playbooks/failures', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      final PlaybookScreenshotFile shot = files
          .filesFor(
            step(3, 'Tap "Nope"', [
              {'id': 's4', 'kind': 'failure'},
            ], status: 'failed'),
          )
          .single;

      expect(shot.isFailure, isTrue);
      expect(shot.file, 'build/playbooks/failures/sign_up-03.png');
    });

    test('saves the screen of a group that failed before its steps ran', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      files.filesFor(group('begin', 2, 'Play missing'));
      final PlaybookScreenshotFile shot = files.filesFor({
        ...group('step', 2, 'Play missing'),
        'status': 'failed',
        'shots': [
          {'id': 's5', 'kind': 'failure'},
        ],
      }).single;

      expect(shot.file, 'build/playbooks/failures/sign_up-02.png');
    });

    test('numbers a scene\'s steps after the scene', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      files.filesFor(group('begin', 3, 'Check out'));
      final PlaybookScreenshotFile inner = files
          .filesFor(
            step(2, 'Tap "Pay"', [
              {'id': 's5', 'kind': 'step'},
            ], depth: 1),
          )
          .single;
      final PlaybookScreenshotFile failure = files
          .filesFor(
            step(
              3,
              'See "Paid"',
              [
                {'id': 's6', 'kind': 'failure'},
              ],
              depth: 1,
              status: 'failed',
            ),
          )
          .single;
      expect(files.filesFor(group('step', 3, 'Check out')), isEmpty);
      final PlaybookScreenshotFile after = files
          .filesFor(
            step(4, 'See "Thanks"', [
              {'id': 's7', 'kind': 'step'},
            ]),
          )
          .single;

      expect(inner.file, 'screenshots/sign_up/03-02-tap-pay.png');
      expect(failure.file, 'build/playbooks/failures/sign_up-03-03.png');
      expect(after.file, 'screenshots/sign_up/04-see-thanks.png');
    });

    test('numbers a played playbook\'s steps as its own', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      files.filesFor(group('begin', 5, 'Play log_out'));
      final PlaybookScreenshotFile inner = files
          .filesFor(
            step(
              1,
              'Tap "Log out"',
              [
                {'id': 's8', 'kind': 'step'},
              ],
              name: 'log_out',
              depth: 1,
            ),
          )
          .single;

      expect(inner.file, 'screenshots/log_out/01-tap-log-out.png');
    });

    test('keeps each device\'s files apart', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
        device: 'pixel-9',
      );

      final List<PlaybookScreenshotFile> shots = files.filesFor(
        step(2, 'Tap "Next"', [
          {'id': 's9', 'kind': 'step'},
          {'id': 's10', 'kind': 'failure'},
        ], status: 'failed'),
      );

      expect(shots.map((shot) => shot.file), [
        'screenshots/sign_up/pixel-9/02-tap-next.png',
        'build/playbooks/failures/sign_up-pixel-9-02.png',
      ]);
    });

    test('puts a pass\'s screenshots in a folder for its locale and theme', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
        device: 'pixel-9',
        cell: const LiveCell(locale: 'es', theme: 'dark'),
      );

      final List<PlaybookScreenshotFile> shots = files.filesFor(
        step(2, 'Tap "Next"', [
          {'id': 's1', 'kind': 'step'},
          {'id': 's2', 'kind': 'failure'},
        ], status: 'failed'),
      );

      expect(shots.map((shot) => shot.file), [
        'screenshots/sign_up/pixel-9/es-dark/02-tap-next.png',
        'build/playbooks/failures/sign_up-pixel-9-es-dark-02.png',
      ]);
      expect(shots.first.shown, 'es-dark/02-tap-next.png');
      expect(shots.first.toJson(), containsPair('locale', 'es'));
      expect(shots.last.shown, 'sign_up-pixel-9-es-dark-02.png');
    });

    test('a shot\'s own locale or theme wins over the pass\'s', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
        cell: const LiveCell(theme: 'dark'),
      );

      final List<PlaybookScreenshotFile> shots = files.filesFor(
        step(4, 'Screenshot cart', [
          {'id': 's1', 'kind': 'marked', 'name': 'cart', 'locale': 'en'},
          {'id': 's2', 'kind': 'marked', 'name': 'cart', 'locale': 'es'},
          {'id': 's3', 'kind': 'marked', 'name': 'cart', 'theme': 'light'},
        ]),
      );

      expect(shots.map((shot) => shot.shown), [
        'en-dark/cart.png',
        'es-dark/cart.png',
        'light/cart.png',
      ]);
    });

    test('a shot taken in a locale of its own gets a folder for it', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      expect(
        files
            .filesFor(
              step(4, 'Screenshot cart', [
                {'id': 's1', 'kind': 'marked', 'name': 'cart', 'locale': 'es'},
              ]),
            )
            .single
            .file,
        'screenshots/sign_up/es/cart.png',
      );
    });

    test('puts store screenshots in a folder for the store', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
        device: 'pixel-9',
        cell: const LiveCell(locale: 'es'),
      );

      final List<PlaybookScreenshotFile> shots = files.filesFor(
        step(4, 'Screenshot cart', [
          {'id': 's1', 'kind': 'marked', 'name': 'cart', 'store': 'ios-6.9'},
          {'id': 's2', 'kind': 'failure'},
        ], status: 'failed'),
      );

      expect(shots.map((shot) => shot.file), [
        'screenshots/sign_up/ios-6.9/pixel-9/es/cart.png',
        'build/playbooks/failures/sign_up-pixel-9-es-04.png',
      ]);
      expect(shots.first.shown, 'ios-6.9/es/cart.png');
      expect(shots.first.toJson(), containsPair('store', 'ios-6.9'));
      expect(shots.last.store, isNull);
    });

    test('marks native screenshots, and the app\'s own in their place', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      final List<PlaybookScreenshotFile> shots = files.filesFor(
        step(4, 'Screenshot form', [
          {'id': 's1', 'kind': 'marked', 'name': 'form', 'native': true},
          {
            'id': 's2',
            'kind': 'marked',
            'name': 'form',
            'locale': 'es',
            'nativeFallback': 'Native screenshots need the iOS Simulator',
          },
        ]),
      );

      expect(shots.map((shot) => shot.file), [
        'screenshots/sign_up/form.png',
        'screenshots/sign_up/es/form.png',
      ]);
      expect(shots.first.native, isTrue);
      expect(shots.first.toJson(), containsPair('native', true));
      expect(shots.last.native, isFalse);
      expect(
        shots.last.toJson(),
        containsPair(
          'nativeFallback',
          'Native screenshots need the iOS Simulator',
        ),
      );
    });

    test('steps without screenshots have no files', () {
      final PlaybookScreenshotFiles files = PlaybookScreenshotFiles(
        root: '/app',
      );

      expect(
        files.filesFor({
          'event': 'step',
          'name': 'sign_up',
          'index': 1,
          'title': 'Wait',
          'depth': 0,
          'status': 'passed',
        }),
        isEmpty,
      );
      expect(files.filesFor({'event': 'start', 'name': 'sign_up'}), isEmpty);
    });
  });

  group('renderScreenshotSummary', () {
    test('counts the screenshots in each folder, leaving out failures', () {
      PlaybookScreenshotFile file(String path, {String kind = 'step'}) =>
          PlaybookScreenshotFile(
            id: 's1',
            kind: kind,
            path: '/app/$path',
            file: path,
            step: 'Step',
          );
      final LiveBlock block = LiveBlock();

      renderScreenshotSummary(block, [
        file('screenshots/sign_up/01-visit.png'),
        file('screenshots/sign_up/cart.png', kind: 'marked'),
        file('screenshots/log_out/01-tap.png'),
        file('build/playbooks/failures/sign_up-03.png', kind: 'failure'),
      ]);

      expect(block.lines.map((line) => line.$2), [
        '✓ 2 screenshots in screenshots/sign_up/',
        '✓ 1 screenshot in screenshots/log_out/',
      ]);
    });
  });

  group('opening and copying', () {
    test('opens with the system viewer', () {
      final LiveProgram mac = liveOpenProgram('/a/b.png', os: 'macos');
      expect([mac.executable, ...mac.arguments], ['open', '/a/b.png']);
      final LiveProgram windows = liveOpenProgram(r'C:\a\b.png', os: 'windows');
      expect(
        [windows.executable, ...windows.arguments],
        ['cmd', '/c', 'start', '', r'C:\a\b.png'],
      );
      expect(
        liveOpenProgram(
          '/a/b.png',
          os: 'linux',
          processes: FakeProcesses(
            installed: {'xdg-open': '/usr/bin/xdg-open'},
          ),
        ).arguments,
        contains(r'xdg-open "$1" >/dev/null 2>&1 &'),
      );
    });

    test('says what to install when Linux has no viewer', () {
      expect(
        () => liveOpenProgram(
          '/a/b.png',
          os: 'linux',
          processes: FakeProcesses(installed: {}),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('Install xdg-utils'),
          ),
        ),
      );
    });

    test('copies the PNG with osascript on macOS', () {
      final LiveProgram program = liveCopyProgram(
        '/a/my "shot".png',
        os: 'macos',
      );

      expect(program.executable, 'osascript');
      expect(program.arguments, [
        '-e',
        r'set the clipboard to (read (POSIX file "/a/my \"shot\".png") as '
            '«class PNGf»)',
      ]);
    });

    test('copies the PNG with PowerShell on Windows', () {
      final LiveProgram program = liveCopyProgram(
        r"C:\it's.png",
        os: 'windows',
      );

      expect(program.executable, 'powershell');
      expect(
        program.arguments.last,
        contains(
          "[System.Windows.Forms.Clipboard]::SetImage("
          "[System.Drawing.Image]::FromFile('C:\\it''s.png'))",
        ),
      );
    });

    test('copies with wl-copy under Wayland, otherwise xclip', () {
      final Map<String, String> both = {
        'wl-copy': '/usr/bin/wl-copy',
        'xclip': '/usr/bin/xclip',
      };

      expect(
        liveCopyProgram(
          '/a/b.png',
          os: 'linux',
          processes: FakeProcesses(
            installed: both,
            env: {'WAYLAND_DISPLAY': 'wayland-0'},
          ),
        ).arguments[1],
        startsWith('wl-copy --type image/png'),
      );
      expect(
        liveCopyProgram(
          '/a/b.png',
          os: 'linux',
          processes: FakeProcesses(installed: both),
        ).arguments[1],
        startsWith('xclip -selection clipboard -t image/png -i'),
      );
      expect(
        () => liveCopyProgram(
          '/a/b.png',
          os: 'linux',
          processes: FakeProcesses(installed: {}),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('sudo apt install xclip'),
          ),
        ),
      );
    });
  });

  group('takeLiveScreenshot', () {
    final List<Future<void> Function()> cleanup = [];
    late StringBuffer printed;
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('nylo_shot'));

    tearDown(() async {
      for (final Future<void> Function() close in cleanup.reversed) {
        await close();
      }
      cleanup.clear();
      root.deleteSync(recursive: true);
    });

    Future<FakeNyloApp> app({
      int protocol = 11,
      String mode = 'debug',
      Map<String, Object?> status = const {},
    }) async {
      final FakeNyloApp fake = await FakeNyloApp.start(
        status: {
          'protocol': protocol,
          'route': '/profile',
          'mode': mode,
          ...status,
        },
        commands: {
          'screenshot.capture': (args) async => capture(
            mode: mode,
            locale: args['locale'] as String?,
            theme: args['theme'] as String?,
          ),
        },
      );
      cleanup.add(fake.close);
      return fake;
    }

    Future<LiveRunner> runnerFor(Map<String, FakeNyloApp> devices) async {
      final FakeJsonRpcServer dtd = await startFakeDaemon([
        for (final MapEntry<String, FakeNyloApp> entry in devices.entries)
          (
            uri: entry.value.wsUri,
            name: 'Kind: Flutter - Device: ${entry.key} - Package: shop',
          ),
      ]);
      cleanup.add(dtd.close);
      printed = StringBuffer();
      return LiveRunner(
        output: LivePrinter(sink: printed, ansi: false),
        project: LiveProject(root.path, 'shop'),
        discovery: (project, timeout) => LiveDiscovery(
          projectRoot: project.root,
          packageName: project.packageName,
          timeout: timeout,
          listDaemons: () async => [
            LiveDaemon(wsUri: dtd.wsUri, workspaceRoot: project.root),
          ],
        ),
      );
    }

    DateTime at() => DateTime(2026, 10, 13, 22, 51, 7);

    test('saves the screen in screenshots/ and says how big it is', () async {
      final FakeNyloApp phone = await app(mode: 'profile');
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      final int code = await takeLiveScreenshot(
        runner,
        const LiveOptions(),
        area: 'receipt',
        pixelRatio: 0.5,
        now: at,
      );

      expect(code, 0);
      expect(phone.calls['screenshot.capture']!.single, {
        'area': 'receipt',
        'pixelRatio': 0.5,
      });
      const String file = 'screenshots/profile-iphone-17-20261013-2251.png';
      expect(File('${root.path}/$file').readAsBytesSync(), png);
      expect(
        printed.toString(),
        matches(RegExp('^✓ $file  1206×2622 · 9 B · \\d+ms\n\$')),
      );
    });

    test('a second screenshot in the same minute gets its own file', () async {
      final FakeNyloApp phone = await app();
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      await takeLiveScreenshot(runner, const LiveOptions(), now: at);
      await takeLiveScreenshot(runner, const LiveOptions(), now: at);

      expect(
        Directory(
            '${root.path}/screenshots',
          ).listSync().map((entry) => entry.path.split('/').last).toList()
          ..sort(),
        [
          'debug-iphone-17-20261013-2251.png',
          'debug-iphone-17-20261013-225107.png',
        ],
      );
    });

    test('--all with --out saves a file per device', () async {
      final LiveRunner runner = await runnerFor({
        'iPhone 17': await app(),
        'Pixel 9': await app(),
      });

      final int code = await takeLiveScreenshot(
        runner,
        const LiveOptions(all: true),
        out: 'store/home.png',
        now: at,
      );

      expect(code, 0);
      expect(File('${root.path}/store/home-iphone-17.png').existsSync(), true);
      expect(File('${root.path}/store/home-pixel-9.png').existsSync(), true);
      expect(printed.toString(), contains('[iPhone 17]  ✓ store/home-'));
    });

    test('opens and copies the file', () async {
      final LiveRunner runner = await runnerFor({'iPhone 17': await app()});
      final FakeProcesses processes = FakeProcesses();

      final int code = await takeLiveScreenshot(
        runner,
        const LiveOptions(),
        out: 'home.png',
        open: true,
        copy: true,
        processes: processes,
        os: 'macos',
      );

      expect(code, 0);
      expect(processes.ran, [
        ['open', '${root.path}/home.png'],
        [
          'osascript',
          '-e',
          'set the clipboard to (read (POSIX file "${root.path}/home.png") '
              'as «class PNGf»)',
        ],
      ]);
      expect(printed.toString(), contains('· Copied to the clipboard'));
    });

    test('still saves when the clipboard tool is missing', () async {
      final LiveRunner runner = await runnerFor({'iPhone 17': await app()});

      final int code = await takeLiveScreenshot(
        runner,
        const LiveOptions(),
        out: 'home.png',
        copy: true,
        processes: FakeProcesses(installed: {}),
        os: 'linux',
      );

      expect(code, 0);
      expect(File('${root.path}/home.png').existsSync(), isTrue);
      expect(printed.toString(), contains('! Copying the screenshot needs'));
    });

    test('needs an app on protocol 11', () async {
      final FakeNyloApp phone = await app(protocol: 10);
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      final int code = await takeLiveScreenshot(runner, const LiveOptions());

      expect(code, 1);
      expect(
        printed.toString(),
        contains('doesn\'t support screenshots yet. Update nylo_framework'),
      );
      expect(phone.calls['screenshot.capture'], isNull);
    });

    test('shows the app\'s error, such as an unknown area', () async {
      final FakeNyloApp phone = await FakeNyloApp.start(
        status: {'protocol': 11, 'route': '/'},
        commands: {
          'screenshot.capture': (args) async =>
              throw FakeRpcError(-32000, 'No ScreenshotArea "nope"'),
        },
      );
      cleanup.add(phone.close);
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      final int code = await takeLiveScreenshot(
        runner,
        const LiveOptions(),
        area: 'nope',
      );

      expect(code, 1);
      expect(printed.toString(), contains('No ScreenshotArea "nope"'));
      expect(Directory('${root.path}/screenshots').existsSync(), isFalse);
    });

    test('the command checks --scale and --out', () async {
      final FakeNyloApp phone = await app();
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      for (final List<String> arguments in [
        ['--scale', '0'],
        ['--scale', '5'],
        ['--scale', 'big'],
        ['--out', 'home.jpg'],
      ]) {
        expect(
          await runLiveShellCommand('screenshot', arguments, runner),
          64,
          reason: '$arguments',
        );
      }
      expect(printed.toString(), contains('--scale must be a number above 0'));
      expect(printed.toString(), contains('--out saves a .png'));
      expect(phone.calls['screenshot.capture'], isNull);
    });

    test('runs from metro live as screenshot', () async {
      final FakeNyloApp phone = await app();
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      expect(
        await runLiveShellCommand('screenshot', [
          '--out',
          'shots/',
          '--scale',
          '2',
        ], runner),
        0,
      );
      expect(phone.calls['screenshot.capture']!.single, {'pixelRatio': 2.0});
      expect(
        Directory('${root.path}/shots').listSync().single.path,
        contains('debug-iphone-17-'),
      );
    });

    group('in several locales and themes', () {
      const Map<String, Object?> lists = {
        'locales': ['en', 'es'],
        'themes': ['light', 'dark'],
      };

      test('captures each pair into a folder', () async {
        final FakeNyloApp phone = await app(
          protocol: 12,
          mode: 'profile',
          status: lists,
        );
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          locales: ['all'],
          themes: ['dark'],
          area: 'receipt',
          now: () => DateTime(2026, 10, 21, 22, 51),
        );

        expect(code, 0);
        expect(phone.calls['screenshot.capture'], [
          {'area': 'receipt', 'locale': 'en', 'theme': 'dark'},
          {'area': 'receipt', 'locale': 'es', 'theme': 'dark'},
        ]);
        const String folder = 'screenshots/profile-iphone-17-20261021-2251';
        expect(File('${root.path}/$folder/en-dark.png').existsSync(), isTrue);
        expect(File('${root.path}/$folder/es-dark.png').existsSync(), isTrue);
        expect(
          printed.toString(),
          matches(
            RegExp(
              '^✓ $folder/en-dark.png  1206×2622 · 9 B · \\d+ms\n'
              '✓ $folder/es-dark.png  1206×2622 · 9 B · \\d+ms\n'
              '✓ 2 screenshots in $folder/\n\$',
            ),
          ),
        );
      });

      test('opens the folder and copies the first file', () async {
        final FakeNyloApp phone = await app(protocol: 12, status: lists);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});
        final FakeProcesses processes = FakeProcesses();

        await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          locales: ['en', 'es'],
          out: 'store/',
          open: true,
          copy: true,
          processes: processes,
          os: 'macos',
        );

        expect(processes.ran.first, ['open', '${root.path}/store']);
        expect(processes.ran.last.last, contains('${root.path}/store/en.png'));
      });

      test('names the locales the app has', () async {
        final FakeNyloApp phone = await app(protocol: 12, status: lists);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          locales: ['de'],
        );

        expect(code, 1);
        expect(
          printed.toString(),
          contains('No locale "de" in this app. Its locales: en, es.'),
        );
        expect(phone.calls['screenshot.capture'], isNull);
      });

      test('needs an app on protocol 12', () async {
        final FakeNyloApp phone = await app(status: lists);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          themes: ['dark'],
        );

        expect(code, 1);
        expect(
          printed.toString(),
          contains(
            'doesn\'t support screenshots in other locales and themes yet',
          ),
        );
      });
    });

    group('--native', () {
      test('captures the iOS Simulator with simctl', () async {
        final FakeNyloApp phone = await app(
          protocol: 12,
          status: {'platform': 'ios', 'simulator': 'AAA'},
        );
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});
        final FakeProcesses processes = FakeProcesses(
          onRun: (String executable, List<String> arguments) {
            if (arguments.contains('screenshot')) {
              File(arguments.last).writeAsBytesSync(pngHeader(1206, 2622));
            }
            return null;
          },
        );

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          native: true,
          cleanStatusBar: true,
          processes: processes,
          now: at,
        );

        expect(code, 0);
        const String file =
            'screenshots/debug-iphone-17-20261013-2251-native.png';
        expect(
          [for (final List<String> run in processes.ran) run.sublist(1, 5)],
          [
            ['simctl', 'status_bar', 'AAA', 'list'],
            ['simctl', 'status_bar', 'AAA', 'override'],
            ['simctl', 'io', 'AAA', 'screenshot'],
            ['simctl', 'status_bar', 'AAA', 'clear'],
          ],
        );
        expect(processes.ran[2].last, '${root.path}/$file');
        expect(
          printed.toString(),
          matches(RegExp('^✓ $file  1206×2622 · 29 B · \\d+ms\n\$')),
        );
        expect(phone.calls['screenshot.capture'], isNull);
      });

      test('captures Android with adb exec-out screencap', () async {
        final FakeNyloApp phone = await app(status: {'platform': 'android'});
        final LiveRunner runner = await runnerFor({'Pixel 9': phone});
        final FakeProcesses processes = FakeProcesses(
          installed: {'adb': '/bin/adb'},
          env: {'ANDROID_SERIAL': 'emulator-5554'},
        )..printsToFile['/bin/adb'] = pngHeader(1080, 2400);

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          native: true,
          out: 'pixel.png',
          processes: processes,
        );

        expect(code, 0);
        expect(processes.ran.single, [
          '/bin/adb',
          '-s',
          'emulator-5554',
          'exec-out',
          'screencap',
          '-p',
        ]);
        expect(
          File('${root.path}/pixel.png').readAsBytesSync(),
          pngHeader(1080, 2400),
        );
        expect(printed.toString(), contains('✓ pixel.png  1080×2400 · '));
      });

      test('takes the app\'s own capture on other devices', () async {
        final FakeNyloApp phone = await app(status: {'platform': 'macos'});
        final LiveRunner runner = await runnerFor({'macOS': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          native: true,
          processes: FakeProcesses(),
          now: at,
        );

        expect(code, 0);
        expect(
          printed.toString(),
          startsWith(
            '· --native captures the iOS Simulator and Android devices, so '
            'this is the app\'s own capture of macOS.\n'
            '✓ screenshots/debug-macos-20261013-2251.png  1206×2622',
          ),
        );
        expect(phone.calls['screenshot.capture'], hasLength(1));
      });

      test('without --native, falls back quietly to the app\'s own '
          'capture', () async {
        final FakeNyloApp phone = await app(status: {'platform': 'macos'});
        final LiveRunner runner = await runnerFor({'macOS': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          native: true,
          nativeQuietly: true,
          processes: FakeProcesses(),
          now: at,
        );

        expect(code, 0);
        expect(
          printed.toString(),
          startsWith('✓ screenshots/debug-macos-20261013-2251.png  1206×2622'),
        );
        expect(phone.calls['screenshot.capture'], hasLength(1));
      });

      test('without --native, Android without adb gets the app\'s own '
          'capture', () async {
        final FakeNyloApp phone = await app(status: {'platform': 'android'});
        final LiveRunner runner = await runnerFor({'Pixel 9': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          native: true,
          nativeQuietly: true,
          processes: FakeProcesses(),
          now: at,
        );

        expect(code, 0);
        expect(printed.toString(), isNot(contains('adb')));
        expect(phone.calls['screenshot.capture'], hasLength(1));
      });

      test('switches the app to each locale and theme, then back', () async {
        final List<String> drawn = [];
        final FakeNyloApp phone = await FakeNyloApp.start(
          status: {
            'protocol': 12,
            'route': '/profile',
            'mode': 'debug',
            'platform': 'ios',
            'simulator': 'AAA',
            'locale': 'en',
            'theme': 'light',
            'locales': ['en', 'es'],
            'themes': ['light', 'dark'],
          },
          commands: {
            'locale.set': (args) async {
              drawn.add('locale ${args['language']}');
              return {'locale': args['language']};
            },
            'theme.set': (args) async {
              drawn.add('theme ${args['id']} save ${args['save']}');
              return {'theme': args['id']};
            },
          },
        );
        cleanup.add(phone.close);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});
        final FakeProcesses processes = FakeProcesses(
          onRun: (String executable, List<String> arguments) {
            if (arguments.contains('screenshot')) {
              drawn.add('shot ${arguments.last.split('/').last}');
              File(arguments.last).writeAsBytesSync(pngHeader(1206, 2622));
            }
            return null;
          },
        );

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          native: true,
          locales: ['all'],
          themes: ['dark'],
          processes: processes,
          now: at,
        );

        expect(code, 0);
        expect(drawn, [
          'locale en',
          'theme dark save false',
          'shot en-dark-native.png',
          'locale es',
          'theme dark save false',
          'shot es-dark-native.png',
          'locale en',
          'theme light save false',
        ]);
        expect(
          File(
            '${root.path}/screenshots/debug-iphone-17-20261013-2251/'
            'es-dark-native.png',
          ).existsSync(),
          isTrue,
        );
        expect(
          printed.toString(),
          contains('Restored locale en and theme light.'),
        );
        expect(phone.calls['screenshot.capture'], isNull);
      });

      test('the command captures natively by default', () async {
        final FakeNyloApp phone = await app();
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        for (final List<String> arguments in [
          <String>[],
          ['--clean-status-bar'],
          ['--area', 'receipt'],
          ['--no-native'],
        ]) {
          expect(
            await runLiveShellCommand('screenshot', arguments, runner),
            0,
            reason: '$arguments',
          );
        }
        expect(printed.toString(), isNot(contains('--native captures')));
        expect(phone.calls['screenshot.capture'], hasLength(4));
      });

      test('the command keeps --native to the whole screen', () async {
        final FakeNyloApp phone = await app();
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        for (final List<String> arguments in [
          ['--native', '--area', 'receipt'],
          ['--native', '--scale', '0.5'],
          ['--no-native', '--clean-status-bar'],
          ['--clean-status-bar', '--area', 'receipt'],
          ['--locales', ','],
        ]) {
          expect(
            await runLiveShellCommand('screenshot', arguments, runner),
            64,
            reason: '$arguments',
          );
        }
        expect(
          printed.toString(),
          allOf(
            contains(
              '--native captures the whole screen as it is now, so leave '
              'out --area.',
            ),
            contains('--clean-status-bar goes with --native'),
            contains(
              '--clean-status-bar goes with the native capture of the whole '
              'screen, so leave out --area.',
            ),
            contains('Name them after --locales'),
          ),
        );
        expect(phone.calls['screenshot.capture'], isNull);
      });
    });

    group('--store', () {
      const Map<String, Object?> stores = {
        'stores': [
          {
            'id': 'ios-6.9',
            'width': 1320,
            'height': 2868,
            'label': 'iPhone 6.9"',
          },
          {'id': 'play-phone', 'width': 1080, 'height': 1920},
        ],
        'locales': ['en', 'es'],
      };

      test('draws the screen at the store\'s size, in a frame', () async {
        final FakeNyloApp phone = await app(protocol: 13, status: stores);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          store: 'ios-6.9',
          frame: true,
          caption: 'checkout.caption',
          background: '#1B2027',
          now: () => DateTime(2026, 10, 21, 23),
        );

        expect(code, 0);
        expect(phone.calls['screenshot.capture']!.single, {
          'store': 'ios-6.9',
          'frame': true,
          'caption': 'checkout.caption',
          'background': '#1B2027',
        });
        expect(
          File(
            '${root.path}/screenshots/debug-iphone-17-20261021-2300-ios-6.9.png',
          ).existsSync(),
          isTrue,
        );
      });

      test('adds the store to each locale\'s file', () async {
        final FakeNyloApp phone = await app(protocol: 13, status: stores);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          store: 'play-phone',
          locales: ['all'],
          out: 'store/',
        );

        expect(
          phone.calls['screenshot.capture']!.map((args) => args['store']),
          ['play-phone', 'play-phone'],
        );
        expect(
          Directory(
              '${root.path}/store',
            ).listSync().map((entry) => entry.path.split('/').last).toList()
            ..sort(),
          ['en-play-phone.png', 'es-play-phone.png'],
        );
      });

      test('names the stores the app has', () async {
        final FakeNyloApp phone = await app(protocol: 13, status: stores);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          store: 'ios-5.5',
        );

        expect(code, 1);
        expect(printed.toString(), contains('Its stores: ios-6.9 (1320×2868)'));
        expect(phone.calls['screenshot.capture'], isNull);
      });

      test('needs an app on protocol 13', () async {
        final FakeNyloApp phone = await app(protocol: 12, status: stores);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        final int code = await takeLiveScreenshot(
          runner,
          const LiveOptions(),
          frame: true,
        );

        expect(code, 1);
        expect(
          printed.toString(),
          contains('doesn\'t support store screenshots and frames yet'),
        );
      });

      test('--store on its own lists the stores', () async {
        final FakeNyloApp phone = await app(protocol: 13, status: stores);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        expect(await runLiveShellCommand('screenshot', ['--store'], runner), 0);
        expect(
          printed.toString(),
          contains(
            'ios-6.9     1320×2868  iPhone 6.9"\n'
            'play-phone  1080×1920\n'
            '· Capture at one with metro live:run screenshot --store ios-6.9',
          ),
        );
        expect(phone.calls['screenshot.capture'], isNull);
      });

      test('the command reads --store, --frame and --caption', () async {
        final FakeNyloApp phone = await app(protocol: 13, status: stores);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        expect(
          await runLiveShellCommand('screenshot', [
            '--store',
            'ios-6.9',
            '--frame',
            '--caption',
            'Checkout in one tap',
            '--background',
            '1b2027',
          ], runner),
          0,
        );
        expect(phone.calls['screenshot.capture']!.single, {
          'store': 'ios-6.9',
          'frame': true,
          'caption': 'Checkout in one tap',
          'background': '#1b2027',
        });
      });

      test('sends --background with --store alone', () async {
        final FakeNyloApp phone = await app(protocol: 13, status: stores);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        expect(
          await runLiveShellCommand('screenshot', [
            '--store',
            'play-phone',
            '--background',
            '#FFFFFF',
          ], runner),
          0,
        );
        expect(phone.calls['screenshot.capture']!.single, {
          'store': 'play-phone',
          'background': '#FFFFFF',
        });
      });

      test('the command checks what goes with --store and --frame', () async {
        final FakeNyloApp phone = await app(protocol: 13, status: stores);
        final LiveRunner runner = await runnerFor({'iPhone 17': phone});

        for (final List<String> arguments in [
          ['--store', 'ios-6.9', '--scale', '2'],
          ['--native', '--store', 'ios-6.9'],
          ['--native', '--frame'],
          ['--caption', 'Hi'],
          ['--background', '#000000'],
          ['--frame', '--background', 'navy'],
        ]) {
          expect(
            await runLiveShellCommand('screenshot', arguments, runner),
            64,
            reason: '$arguments',
          );
        }
        expect(
          printed.toString(),
          allOf(
            contains('--store sets the size, so leave out --scale.'),
            contains('so leave out --store.'),
            contains('so leave out --frame.'),
            contains('--caption goes with --frame'),
            contains('--background goes with --store or --frame'),
            contains('--background takes a hex color'),
          ),
        );
        expect(phone.calls['screenshot.capture'], isNull);
      });
    });
  });
}
