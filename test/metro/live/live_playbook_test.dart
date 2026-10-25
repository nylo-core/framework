import 'dart:async';
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

/// Posts a `nylo.playbook` event with [data] to every client of [app].
void post(FakeNyloApp app, Map<String, Object?> data) {
  for (final FakeConnection client in app.server.clients) {
    try {
      client.streamNotify('nylo', {
        'kind': 'Extension',
        'extensionKind': 'nylo.playbook',
        'extensionData': data,
      });
    } catch (_) {
      // A connection discovery already closed.
    }
  }
}

/// The events of a passing two-step run of `log_out`, for [runId].
List<Map<String, Object?>> passingRun(String runId) => [
  {
    'runId': runId,
    'event': 'start',
    'name': 'log_out',
    'speed': 'fast',
    'total': 2,
    'depth': 0,
    'path': ['log_out'],
    'loop': 1,
  },
  {
    'runId': runId,
    'event': 'begin',
    'name': 'log_out',
    'index': 1,
    'total': 2,
    'title': 'Tap "Log out"',
    'depth': 0,
    'group': false,
  },
  {
    'runId': runId,
    'event': 'step',
    'name': 'log_out',
    'index': 1,
    'total': 2,
    'title': 'Tap "Log out"',
    'depth': 0,
    'group': false,
    'status': 'passed',
    'ms': 239,
  },
  {
    'runId': runId,
    'event': 'step',
    'name': 'log_out',
    'index': 2,
    'total': 2,
    'title': 'See "Get started"',
    'depth': 0,
    'group': false,
    'status': 'passed',
    'ms': 2,
  },
  {
    'runId': runId,
    'event': 'finish',
    'name': 'log_out',
    'speed': 'fast',
    'depth': 0,
    'path': ['log_out'],
    'passed': true,
    'stopped': false,
    'ms': 1100,
    'report': {'name': 'log_out', 'passed': true, 'steps': []},
  },
  {
    'runId': runId,
    'event': 'done',
    'passed': true,
    'stopped': false,
    'ms': 1100,
    'runs': 1,
  },
];

String render(List<Map<String, Object?>> events) {
  final StringBuffer printed = StringBuffer();
  final LivePrinter printer = LivePrinter(sink: printed, ansi: false);
  final PlaybookEventRenderer renderer = PlaybookEventRenderer();
  for (final Map<String, Object?> event in events) {
    final LiveBlock block = LiveBlock();
    renderer.render(block, event);
    printer.block(block);
  }
  return printed.toString();
}

void main() {
  final List<Future<void> Function()> cleanup = [];
  late StringBuffer printed;

  tearDown(() async {
    for (final Future<void> Function() close in cleanup.reversed) {
      await close();
    }
    cleanup.clear();
  });

  Future<FakeNyloApp> app(
    Map<String, Future<Object?> Function(Map<String, Object?> args)> commands, {
    Map<String, Object?>? status,
  }) async {
    final FakeNyloApp fake = await FakeNyloApp.start(
      commands: commands,
      status: status ?? {'protocol': 9, 'route': '/home', 'playbooks': []},
    );
    cleanup.add(fake.close);
    return fake;
  }

  Future<LiveRunner> runnerFor(
    Map<String, FakeNyloApp> devices, {
    String? root,
  }) async {
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
      project: LiveProject(root ?? Directory.systemTemp.path, 'shop'),
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

  group('PlaybookEventRenderer', () {
    test('prints a heading, each step with its time, and the result', () {
      expect(
        render(passingRun('pb_1')),
        'Playbook "log_out" (fast)\n'
        '  ✓   239ms  Tap "Log out"\n'
        '  ✓     2ms  See "Get started"\n'
        '✓ Playbook "log_out" passed in 1.1s\n',
      );
    });

    test('nests a played playbook under its header', () {
      expect(
        render([
          {
            'event': 'begin',
            'index': 1,
            'title': 'Play log_out',
            'depth': 0,
            'group': true,
          },
          {'event': 'start', 'name': 'log_out', 'speed': 'fast', 'depth': 1},
          {
            'event': 'step',
            'index': 1,
            'title': 'Tap "Log out"',
            'depth': 1,
            'status': 'passed',
            'ms': 12,
          },
          {'event': 'finish', 'name': 'log_out', 'depth': 1, 'passed': true},
          {
            'event': 'step',
            'index': 1,
            'title': 'Play log_out',
            'depth': 0,
            'group': true,
            'status': 'passed',
            'ms': 12,
          },
        ]),
        '  ▸ Play log_out\n'
        '      ✓    12ms  Tap "Log out"\n',
      );
    });

    test('explains a failure once and marks the rest skipped', () {
      expect(
        render([
          {
            'event': 'begin',
            'index': 2,
            'title': 'Play broken',
            'depth': 0,
            'group': true,
          },
          {
            'event': 'step',
            'index': 1,
            'title': 'Tap "Does not exist"',
            'depth': 1,
            'status': 'failed',
            'ms': 10063,
            'error': 'Could not find "Does not exist" on screen after 10s.',
            'visible': ['Nylo', 'Get started'],
          },
          {
            'event': 'step',
            'index': 2,
            'title': 'Play broken',
            'depth': 0,
            'group': true,
            'status': 'failed',
            'ms': 10063,
            'error': 'broken failed at step 1/1',
          },
          {
            'event': 'step',
            'index': 3,
            'title': 'Play later',
            'depth': 0,
            'group': true,
            'status': 'skipped',
            'ms': 0,
          },
          {
            'event': 'finish',
            'name': 'journey',
            'depth': 0,
            'passed': false,
            'ms': 10200,
          },
        ]),
        '  ▸ Play broken\n'
        '      ✗ 10063ms  Tap "Does not exist"\n'
        '            Could not find "Does not exist" on screen after 10s.\n'
        '            Visible text: "Nylo", "Get started"\n'
        '  ·     0ms  Play later  (skipped)\n'
        '✗ Playbook "journey" failed in 10.2s\n',
      );
    });

    test('names the screenshots a step saved', () {
      const PlaybookScreenshotFile shot = PlaybookScreenshotFile(
        id: 's1',
        kind: 'step',
        path: '/app/screenshots/log_out/01-tap-log-out.png',
        file: 'screenshots/log_out/01-tap-log-out.png',
        step: 'Tap "Log out"',
      );
      const PlaybookScreenshotFile failure = PlaybookScreenshotFile(
        id: 's2',
        kind: 'failure',
        path: '/app/build/playbooks/failures/log_out-02.png',
        file: 'build/playbooks/failures/log_out-02.png',
        step: 'See "Get started"',
      );
      final StringBuffer printed = StringBuffer();
      final LivePrinter printer = LivePrinter(sink: printed, ansi: false);
      final PlaybookEventRenderer renderer = PlaybookEventRenderer();
      for (final (
            Map<String, Object?> event,
            List<PlaybookScreenshotFile> shots,
          )
          in [
            (passingRun('pb_1')[2], [shot]),
            (
              {
                'event': 'step',
                'index': 2,
                'title': 'See "Get started"',
                'depth': 0,
                'status': 'failed',
                'ms': 10000,
                'error': 'Could not find "Get started" on screen after 10s.',
              },
              [failure],
            ),
          ]) {
        final LiveBlock block = LiveBlock();
        renderer.render(block, event, shots: shots);
        printer.block(block);
      }

      expect(
        printed.toString(),
        '  ✓   239ms  Tap "Log out"  → 01-tap-log-out.png\n'
        '  ✗ 10000ms  See "Get started"\n'
        '        Could not find "Get started" on screen after 10s.\n'
        '        Screenshot: build/playbooks/failures/log_out-02.png\n',
      );
    });

    test('says when a run was stopped, and sums up several playbooks', () {
      expect(
        render([
          {
            'event': 'start',
            'name': 'demo',
            'speed': 'natural',
            'depth': 0,
            'loop': 2,
          },
          {
            'event': 'finish',
            'name': 'demo',
            'depth': 0,
            'passed': false,
            'stopped': true,
            'ms': 850,
          },
          {'event': 'done', 'runs': 3, 'ms': 61000},
        ]),
        'Playbook "demo" (natural) · run 2\n'
        '! Playbook "demo" stopped after 850ms\n'
        '· Played 3 playbooks in 61.0s\n',
      );
    });
  });

  group('playLivePlaybooks', () {
    test('streams the run, including events that beat the reply', () async {
      late final FakeNyloApp phone;
      phone = await app({
        'playbooks.run': (args) async {
          final List<Map<String, Object?>> events = passingRun('pb_7');
          // The first event arrives before Metro knows the run id.
          post(phone, events.first);
          post(phone, {...events.first, 'runId': 'pb_other'});
          Timer(const Duration(milliseconds: 20), () {
            for (final Map<String, Object?> event in events.skip(1)) {
              post(phone, event);
            }
          });
          return {'runId': 'pb_7', 'names': args['names']};
        },
      });
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        speed: 'fast',
        data: {'email': 'demo@nylo.dev'},
        overlay: false,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(phone.calls['playbooks.run']!.single, {
        'names': ['log_out'],
        'speed': 'fast',
        'data': {'email': 'demo@nylo.dev'},
        'overlay': false,
      });
      expect(
        printed.toString(),
        'Playbook "log_out" (fast)\n'
        '  ✓   239ms  Tap "Log out"\n'
        '  ✓     2ms  See "Get started"\n'
        '✓ Playbook "log_out" passed in 1.1s\n',
      );
    });

    test('fails with exit code 1 when a playbook fails', () async {
      late final FakeNyloApp phone;
      phone = await app({
        'playbooks.run': (args) async {
          Timer(const Duration(milliseconds: 20), () {
            post(phone, {
              'runId': 'pb_1',
              'event': 'step',
              'index': 1,
              'title': 'Tap "Nope"',
              'depth': 0,
              'status': 'failed',
              'ms': 10000,
              'error': 'Could not find "Nope" on screen after 10s.',
            });
            post(phone, {
              'runId': 'pb_1',
              'event': 'done',
              'passed': false,
              'stopped': false,
              'runs': 1,
            });
          });
          return {'runId': 'pb_1'};
        },
      });
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      final int code = await playLivePlaybooks(runner, const LiveOptions(), [
        'broken',
      ], interrupts: const Stream<Object?>.empty());

      expect(code, 1);
      expect(printed.toString(), contains('✗ 10000ms  Tap "Nope"'));
      expect(phone.calls['playbooks.run']!.single, {
        'names': ['broken'],
      });
    });

    test('Ctrl+C asks the app to stop and waits for it to say so', () async {
      late final FakeNyloApp phone;
      phone = await app({
        'playbooks.run': (args) async => {'runId': 'pb_2'},
        'playbooks.stop': (args) async {
          Timer(const Duration(milliseconds: 20), () {
            post(phone, {
              'runId': 'pb_2',
              'event': 'finish',
              'name': 'demo',
              'depth': 0,
              'passed': false,
              'stopped': true,
              'ms': 400,
            });
            post(phone, {
              'runId': 'pb_2',
              'event': 'done',
              'passed': false,
              'stopped': true,
              'runs': 1,
            });
          });
          return {'stopped': true, 'runId': args['runId']};
        },
      });
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});
      final StreamController<Object?> interrupts = StreamController<Object?>();
      cleanup.add(interrupts.close);

      final Future<int> playing = playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['demo'],
        loop: true,
        interrupts: interrupts.stream,
      );
      for (int i = 0; i < 100 && phone.calls['playbooks.run'] == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      interrupts.add(null);

      expect(await playing.timeout(const Duration(seconds: 3)), 130);
      expect(phone.calls['playbooks.run']!.single['loop'], isTrue);
      expect(phone.calls['playbooks.stop']!.single, {'runId': 'pb_2'});
      expect(
        printed.toString(),
        contains('! Playbook "demo" stopped after 400ms'),
      );
    });

    test('a second Ctrl+C stops waiting for an app that never ends', () async {
      final FakeNyloApp phone = await app({
        'playbooks.run': (args) async => {'runId': 'pb_3'},
        'playbooks.stop': (args) async => {'stopped': true},
      });
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});
      final StreamController<Object?> interrupts = StreamController<Object?>();
      cleanup.add(interrupts.close);

      final Future<int> playing = playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['demo'],
        interrupts: interrupts.stream,
      );
      for (int i = 0; i < 100 && phone.calls['playbooks.run'] == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      interrupts
        ..add(null)
        ..add(null);

      expect(await playing.timeout(const Duration(seconds: 3)), 130);
      expect(printed.toString(), contains('Stopped waiting'));
    });

    test('gives up when no step of the run ever arrives', () async {
      final FakeNyloApp phone = await app({
        'playbooks.run': (args) async => {'runId': 'pb_9'},
        'playbooks.stop': (args) async => {'stopped': true},
      });
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['demo'],
        interrupts: const Stream<Object?>.empty(),
        firstStepTimeout: const Duration(milliseconds: 200),
      ).timeout(const Duration(seconds: 3));

      expect(code, 1);
      expect(printed.toString(), contains('no steps reached Metro'));
      expect(printed.toString(), contains('--no-dds'));
      for (int i = 0; i < 100 && phone.calls['playbooks.stop'] == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(phone.calls['playbooks.stop']!.single, {'runId': 'pb_9'});
    });

    test('needs an app whose Nylo version has playbooks', () async {
      final FakeNyloApp phone = await app(const {}, status: {'route': '/'});
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      final int code = await playLivePlaybooks(runner, const LiveOptions(), [
        'demo',
      ], interrupts: const Stream<Object?>.empty());

      expect(code, 1);
      expect(printed.toString(), contains('doesn\'t support playbooks yet'));
      expect(phone.calls['playbooks.run'], isNull);
    });

    test('--json prints the reports and events at the end', () async {
      late final FakeNyloApp phone;
      phone = await app({
        'playbooks.run': (args) async {
          Timer(const Duration(milliseconds: 20), () {
            passingRun('pb_4').forEach((event) => post(phone, event));
          });
          return {'runId': 'pb_4'};
        },
      });
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(json: true),
        ['log_out'],
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      final List<Object?> document = jsonDecode(printed.toString()) as List;
      final Map<String, Object?> result =
          (document.single as Map)['result'] as Map<String, Object?>;
      expect(result['runId'], 'pb_4');
      expect(result['passed'], isTrue);
      expect(result['reports'], [
        {'name': 'log_out', 'passed': true, 'steps': []},
      ]);
      expect(result['events'], hasLength(6));
    });
  });

  group('playbook command', () {
    test('lists the playbooks without names', () async {
      final FakeNyloApp phone = await app({
        'playbooks.list': (args) async => {
          'playbooks': [
            {
              'name': 'sign_up_to_dashboard',
              'description': 'New user signs up',
              'speed': 'natural',
              'steps': ['Visit /sign-up', 'Tap "Create account"'],
            },
          ],
          'running': null,
        },
      });
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      expect(await runLiveShellCommand('playbook', const [], runner), 0);
      expect(
        printed.toString(),
        contains(
          RegExp(r'sign_up_to_dashboard +New user signs up +natural +2'),
        ),
      );
      expect(
        printed.toString(),
        contains('Play one with metro live:run playbook <name>'),
      );
    });

    test('rejects arguments that make no sense', () async {
      final FakeNyloApp phone = await app(const {});
      final LiveRunner runner = await runnerFor({'iPhone 17e': phone});

      expect(
        await runLiveShellCommand('playbook', ['--list', 'demo'], runner),
        64,
      );
      expect(
        await runLiveShellCommand('playbook', ['--speed', 'fast'], runner),
        64,
      );
      expect(
        await runLiveShellCommand('playbook', [
          'demo',
          '--speed',
          'warp',
        ], runner),
        64,
      );
      expect(
        await runLiveShellCommand('playbook', [
          'demo',
          '--data',
          '[1]',
        ], runner),
        64,
      );
      expect(printed.toString(), contains('--data must be a JSON object.'));
      expect(phone.calls['playbooks.run'], isNull);
    });
  });

  group('recording', () {
    const Map<String, Object?> simulator = {
      'protocol': 10,
      'platform': 'ios',
      'simulator': 'AAA',
      'route': '/home',
      'playbooks': [],
    };

    late Directory out;
    setUp(() => out = Directory.systemTemp.createTempSync('nylo_rec'));
    tearDown(() => out.deleteSync(recursive: true));

    Future<FakeNyloApp> playing(List<Map<String, Object?>> events) async {
      late final FakeNyloApp phone;
      phone = await app({
        'playbooks.run': (args) async {
          Timer(const Duration(milliseconds: 20), () {
            for (final Map<String, Object?> event in events) {
              post(phone, event);
            }
          });
          return {'runId': 'pb_1'};
        },
      }, status: simulator);
      return phone;
    }

    test('records the run and saves it with the steps as captions', () async {
      final FakeNyloApp phone = await playing(passingRun('pb_1'));
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});
      final FakeProcesses processes = fakeSimulatorTools();

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        countdown: 3,
        record: LivePlaybookRecording(file: '${out.path}/demo.mp4'),
        processes: processes,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(phone.calls['playbooks.run']!.single, {
        'names': ['log_out'],
        'countdown': 3,
      });
      expect(processes.started.single, containsAll(['recordVideo', 'AAA']));
      expect(processes.programs.single.signals, [ProcessSignal.sigint]);
      expect(File('${out.path}/demo.mp4').readAsStringSync(), 'video');
      expect(
        File('${out.path}/demo.vtt').readAsStringSync(),
        contains('Tap "Log out"'),
      );
      // Paths inside the project are printed relative to it.
      final String folder = out.path.split(Platform.pathSeparator).last;
      expect(
        printed.toString(),
        allOf(
          startsWith('· Recording iPhone 17\n'),
          contains('· Saving the recording\n✓ Saved $folder/demo.mp4 ('),
          contains('· Step captions in $folder/demo.vtt (1 step)'),
        ),
      );
    });

    test('still saves the video when a playbook fails', () async {
      final FakeNyloApp phone = await playing([
        {
          'runId': 'pb_1',
          'event': 'step',
          'index': 1,
          'title': 'Tap "Nope"',
          'depth': 0,
          'status': 'failed',
          'ms': 10,
          'error': 'Could not find "Nope" on screen.',
        },
        {'runId': 'pb_1', 'event': 'done', 'passed': false, 'runs': 1},
      ]);
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(json: true),
        ['broken'],
        record: LivePlaybookRecording(file: '${out.path}/bug.mp4'),
        processes: fakeSimulatorTools(),
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(File('${out.path}/bug.mp4').existsSync(), isTrue);
      final Map<String, Object?> result =
          ((jsonDecode(printed.toString()) as List).single as Map)['result']
              as Map<String, Object?>;
      expect(result['recording'], '${out.path}/bug.mp4');
      expect(result['passed'], isFalse);
    });

    test('needs ffmpeg before anything plays', () async {
      final FakeNyloApp phone = await playing(passingRun('pb_1'));
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        record: const LivePlaybookRecording(),
        processes: FakeProcesses(installed: {}),
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(printed.toString(), contains('Recording needs ffmpeg'));
      expect(phone.calls['playbooks.run'], isNull);
    });

    test('a clean status bar is put back afterwards', () async {
      final FakeNyloApp phone = await playing(passingRun('pb_1'));
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});
      final FakeProcesses processes = FakeProcesses();

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        cleanStatusBar: true,
        processes: processes,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(
        [for (final List<String> run in processes.ran) run[4]],
        ['list', 'override', 'clear'],
      );
      expect(processes.started, isEmpty);
    });

    test('a countdown needs an app on protocol 10', () async {
      final FakeNyloApp phone = await app({});
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        countdown: 3,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(printed.toString(), contains('doesn\'t support countdowns yet'));
    });

    test('the command checks --record and --countdown', () async {
      final FakeNyloApp phone = await app(const {});
      final LiveRunner runner = await runnerFor({'iPhone 17': phone});

      for (final List<String> arguments in [
        ['demo', '--record=demo.mov'],
        ['demo', '--record='],
        ['demo', '--countdown', '11'],
        ['demo', '--countdown', 'soon'],
        ['--record'],
      ]) {
        expect(
          await runLiveShellCommand('playbook', arguments, runner),
          64,
          reason: '$arguments',
        );
      }
      expect(printed.toString(), contains('--record saves an .mp4 or a .gif'));
      expect(phone.calls['playbooks.run'], isNull);
    });
  });

  group('screenshots', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('nylo_shots'));
    tearDown(() => root.deleteSync(recursive: true));

    /// [passingRun] with a screenshot after each step.
    List<Map<String, Object?>> shotRun(String runId) => [
      for (final Map<String, Object?> event in passingRun(runId))
        if (event['event'] == 'step')
          {
            ...event,
            'shots': [
              {
                'id': 's${event['index']}',
                'kind': 'step',
                'width': 1206,
                'height': 2622,
              },
            ],
          }
        else
          event,
    ];

    Future<FakeNyloApp> playing(
      List<Map<String, Object?>> events, {
      int protocol = 11,
      Set<String> missing = const {},
    }) async {
      late final FakeNyloApp phone;
      phone = await app(
        {
          'playbooks.run': (args) async {
            Timer(const Duration(milliseconds: 20), () {
              for (final Map<String, Object?> event in events) {
                post(phone, event);
              }
            });
            return {'runId': 'pb_1'};
          },
          'screenshot.get': (args) async {
            if (missing.contains(args['id'])) {
              throw FakeRpcError(-32000, 'No screenshot "${args['id']}"');
            }
            return {
              'png': base64Encode(utf8.encode('png ${args['id']}')),
              'width': 1206,
              'height': 2622,
            };
          },
        },
        status: {'protocol': protocol, 'route': '/home', 'playbooks': []},
      );
      return phone;
    }

    test('saves each step\'s screenshot as it arrives', () async {
      final FakeNyloApp phone = await playing(shotRun('pb_1'));
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        screenshots: 'auto',
        pixelRatio: 0.5,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(phone.calls['playbooks.run']!.single, {
        'names': ['log_out'],
        'screenshots': 'auto',
        'pixelRatio': 0.5,
      });
      expect(phone.calls['screenshot.get'], [
        {'id': 's1'},
        {'id': 's2'},
      ]);
      expect(
        File(
          '${root.path}/screenshots/log_out/01-tap-log-out.png',
        ).readAsStringSync(),
        'png s1',
      );
      expect(
        File(
          '${root.path}/screenshots/log_out/02-see-get-started.png',
        ).readAsStringSync(),
        'png s2',
      );
      expect(
        printed.toString(),
        'Playbook "log_out" (fast)\n'
        '  ✓   239ms  Tap "Log out"  → 01-tap-log-out.png\n'
        '  ✓     2ms  See "Get started"  → 02-see-get-started.png\n'
        '✓ Playbook "log_out" passed in 1.1s\n'
        '✓ 2 screenshots in screenshots/log_out/\n',
      );
    });

    test('asks for the marked screenshots by default', () async {
      final FakeNyloApp phone = await playing([
        {
          'runId': 'pb_1',
          'event': 'step',
          'name': 'broken',
          'index': 1,
          'title': 'Tap "Nope"',
          'depth': 0,
          'status': 'failed',
          'ms': 10,
          'error': 'Could not find "Nope" on screen.',
          'shots': [
            {'id': 's1', 'kind': 'failure'},
          ],
        },
        {'runId': 'pb_1', 'event': 'done', 'passed': false, 'runs': 1},
      ]);
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(runner, const LiveOptions(), [
        'broken',
      ], interrupts: const Stream<Object?>.empty());

      expect(code, 1);
      expect(phone.calls['playbooks.run']!.single, {
        'names': ['broken'],
        'screenshots': 'marked',
      });
      expect(
        File(
          '${root.path}/build/playbooks/failures/broken-01.png',
        ).existsSync(),
        isTrue,
      );
      expect(
        printed.toString(),
        contains(
          '        Could not find "Nope" on screen.\n'
          '        Screenshot: build/playbooks/failures/broken-01.png\n',
        ),
      );
      expect(printed.toString(), isNot(contains('screenshots in')));
    });

    test('says which screenshots couldn\'t be saved', () async {
      final FakeNyloApp phone = await playing(shotRun('pb_1'), missing: {'s1'});
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        screenshots: 'all',
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(
        printed.toString(),
        allOf(
          contains(
            '! Couldn\'t save screenshots/log_out/01-tap-log-out.png '
            '(No screenshot "s1")',
          ),
          contains('✓ 1 screenshot in screenshots/log_out/'),
        ),
      );
    });

    test('--json lists the screenshots that were saved', () async {
      final FakeNyloApp phone = await playing(shotRun('pb_1'), missing: {'s1'});
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(json: true),
        ['log_out'],
        screenshots: 'all',
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      final Map<String, Object?> result =
          ((jsonDecode(printed.toString()) as List).single as Map)['result']
              as Map<String, Object?>;
      expect(result['screenshots'], [
        {
          'file': '${root.path}/screenshots/log_out/02-see-get-started.png',
          'kind': 'step',
          'step': 'See "Get started"',
          'width': 1206,
          'height': 2622,
        },
      ]);
    });

    test('puts each device\'s screenshots in its own folder', () async {
      final LiveRunner runner = await runnerFor({
        'iPhone 17': await playing(shotRun('pb_1')),
        'Pixel 9': await playing(shotRun('pb_1')),
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(all: true),
        ['log_out'],
        screenshots: 'auto',
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      for (final String device in ['iphone-17', 'pixel-9']) {
        expect(
          File(
            '${root.path}/screenshots/log_out/$device/01-tap-log-out.png',
          ).existsSync(),
          isTrue,
          reason: device,
        );
      }
      expect(
        printed.toString(),
        contains('✓ 2 screenshots in screenshots/log_out/pixel-9/'),
      );
    });

    test('older apps play as before', () async {
      final FakeNyloApp phone = await playing(passingRun('pb_1'), protocol: 10);
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        pixelRatio: 2,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(phone.calls['playbooks.run']!.single, {
        'names': ['log_out'],
      });
    });

    test('--screenshots needs an app on protocol 11', () async {
      final FakeNyloApp phone = await playing(passingRun('pb_1'), protocol: 10);
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        screenshots: 'auto',
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(
        printed.toString(),
        contains('doesn\'t support playbook screenshots yet'),
      );
      expect(phone.calls['playbooks.run'], isNull);
    });

    test('the command reads --screenshots and --scale', () async {
      for (final (List<String> arguments, Map<String, Object?> sent) in [
        (<String>[], {'screenshots': 'marked'}),
        (['--screenshots=marked'], {'screenshots': 'marked'}),
        (['--screenshots=failures'], {'screenshots': 'failures'}),
        (['--screenshots'], {'screenshots': 'auto'}),
        (['--screenshots=all'], {'screenshots': 'all'}),
        (['--no-screenshots'], {'screenshots': 'off'}),
        (
          ['--screenshots', '--scale', '0.5'],
          {'screenshots': 'auto', 'pixelRatio': 0.5},
        ),
      ]) {
        final FakeNyloApp phone = await playing(passingRun('pb_1'));
        final LiveRunner runner = await runnerFor({
          'iPhone 17': phone,
        }, root: root.path);

        expect(
          await runLiveShellCommand('playbook', [
            'log_out',
            ...arguments,
          ], runner),
          0,
          reason: '$arguments',
        );
        expect(phone.calls['playbooks.run']!.single, {
          'names': ['log_out'],
          ...sent,
        }, reason: '$arguments');
      }
    });

    test('the command checks --screenshots and --scale', () async {
      final FakeNyloApp phone = await playing(passingRun('pb_1'));
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      for (final List<String> arguments in [
        ['demo', '--screenshots=some'],
        ['demo', '--scale', '9'],
        ['--screenshots'],
        ['--scale', '1'],
      ]) {
        expect(
          await runLiveShellCommand('playbook', arguments, runner),
          64,
          reason: '$arguments',
        );
      }
      expect(
        printed.toString(),
        contains(
          '--screenshots= takes all, auto, marked, failures or off, not '
          '"some"',
        ),
      );
      expect(phone.calls['playbooks.run'], isNull);
    });
  });

  group('locales and themes', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('nylo_matrix'));
    tearDown(() => root.deleteSync(recursive: true));

    const Map<String, Object?> status = {
      'protocol': 12,
      'route': '/home',
      'playbooks': [],
      'locale': 'en',
      'theme': 'light',
      'locales': ['en', 'es'],
      'themes': ['light', 'dark'],
    };

    /// Every call the app gets, in order, as `command args`.
    late List<String> calls;

    /// An app that plays [passingRun] with a screenshot after the first
    /// step, as a new run each time, failing the runs whose matrix
    /// [failing] picks.
    Future<FakeNyloApp> playing({
      Map<String, Object?> status = status,
      bool Function(Map<String, Object?> matrix)? failing,
      bool answerStop = false,
    }) async {
      calls = [];
      int runs = 0;
      late final FakeNyloApp phone;
      Future<Object?> Function(Map<String, Object?> args) noted(
        String command,
        Object? reply,
      ) => (args) async {
        calls.add('$command ${jsonEncode(args)}');
        return reply;
      };
      phone = await app({
        'locale.set': noted('locale.set', {'locale': 'es'}),
        'theme.set': noted('theme.set', {'theme': 'dark'}),
        'screenshot.get': (args) async => {
          'png': base64Encode(utf8.encode('png ${args['id']}')),
        },
        'playbooks.stop': (args) async {
          if (answerStop) {
            Timer(const Duration(milliseconds: 20), () {
              post(phone, {
                'runId': args['runId'],
                'event': 'done',
                'passed': false,
                'stopped': true,
                'runs': 1,
              });
            });
          }
          return {'stopped': true};
        },
        'playbooks.run': (args) async {
          calls.add('playbooks.run ${jsonEncode(args['matrix'])}');
          final String id = 'pb_${++runs}';
          final bool fails =
              failing?.call(
                Map<String, Object?>.from(args['matrix'] as Map? ?? {}),
              ) ??
              false;
          if (!answerStop) {
            Timer(const Duration(milliseconds: 20), () {
              for (final Map<String, Object?> event in passingRun(id)) {
                post(phone, switch (event['event']) {
                  'step' when event['index'] == 1 => {
                    ...event,
                    'name': 'log_out',
                    'shots': [
                      {'id': '${id}_s1', 'kind': 'step'},
                    ],
                  },
                  'done' when fails => {...event, 'passed': false},
                  _ => event,
                });
              }
            });
          }
          return {'runId': id};
        },
      }, status: status);
      return phone;
    }

    test('plays once per locale and theme, then puts them back', () async {
      final FakeNyloApp phone = await playing();
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        screenshots: 'all',
        locales: ['all'],
        themes: ['dark'],
        countdown: 3,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(calls, [
        'locale.set {"language":"en"}',
        'theme.set {"id":"dark","save":false}',
        'playbooks.run {"locale":"en","theme":"dark"}',
        'locale.set {"language":"es"}',
        'theme.set {"id":"dark","save":false}',
        'playbooks.run {"locale":"es","theme":"dark"}',
        'locale.set {"language":"en"}',
        'theme.set {"id":"light","save":false}',
      ]);
      final List<Map<String, Object?>> runs = phone.calls['playbooks.run']!;
      expect(runs.first['countdown'], 3);
      expect(runs.last.containsKey('countdown'), isFalse);
      expect(runs.first['screenshots'], 'all');
      for (final String cell in ['en-dark', 'es-dark']) {
        expect(
          File(
            '${root.path}/screenshots/log_out/$cell/01-tap-log-out.png',
          ).existsSync(),
          isTrue,
          reason: cell,
        );
      }
      expect(
        printed.toString(),
        allOf(
          startsWith('▸ en · dark\nPlaybook "log_out" (fast)\n'),
          contains('Tap "Log out"  → en-dark/01-tap-log-out.png\n'),
          contains('▸ es · dark\n'),
          contains('✓ 1 screenshot in screenshots/log_out/en-dark/\n'),
          contains('✓ 1 screenshot in screenshots/log_out/es-dark/\n'),
          endsWith('· Restored locale en and theme light.\n'),
        ),
      );
    });

    test('plays every pass when one fails, and puts them back', () async {
      final FakeNyloApp phone = await playing(
        failing: (matrix) => matrix['locale'] == 'en',
      );
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(json: true),
        ['log_out'],
        locales: ['en', 'es'],
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(calls, [
        'locale.set {"language":"en"}',
        'playbooks.run {"locale":"en"}',
        'locale.set {"language":"es"}',
        'playbooks.run {"locale":"es"}',
        'locale.set {"language":"en"}',
      ]);
      final Map<String, Object?> result =
          ((jsonDecode(printed.toString()) as List).single as Map)['result']
              as Map<String, Object?>;
      expect(result['passed'], isFalse);
      expect(result['passes'], [
        {'locale': 'en', 'runId': 'pb_1', 'passed': false, 'stopped': false},
        {'locale': 'es', 'runId': 'pb_2', 'passed': true, 'stopped': false},
      ]);
    });

    test('Ctrl+C stops the passes and puts the theme back', () async {
      final FakeNyloApp phone = await playing(answerStop: true);
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);
      final StreamController<Object?> interrupts = StreamController<Object?>();
      cleanup.add(interrupts.close);

      final Future<int> played = playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        themes: ['light', 'dark'],
        loop: true,
        interrupts: interrupts.stream,
      );
      for (int i = 0; i < 100 && phone.calls['playbooks.run'] == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      interrupts.add(null);

      expect(await played.timeout(const Duration(seconds: 3)), 130);
      expect(calls, [
        'theme.set {"id":"light","save":false}',
        'playbooks.run {"theme":"light"}',
        'theme.set {"id":"light","save":false}',
      ]);
      expect(phone.calls['playbooks.run']!.single.containsKey('loop'), false);
      expect(printed.toString(), endsWith('· Restored theme light.\n'));
    });

    test('names the themes the app has', () async {
      final FakeNyloApp phone = await playing();
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        themes: ['sepia'],
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(
        printed.toString(),
        contains('No theme "sepia" in this app. Its themes: light, dark.'),
      );
      expect(calls, isEmpty);
    });

    test('needs an app on protocol 12', () async {
      final FakeNyloApp phone = await playing(
        status: {...status, 'protocol': 11},
      );
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        locales: ['es'],
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(
        printed.toString(),
        contains('doesn\'t support playing in several locales and themes yet'),
      );
      expect(calls, isEmpty);
    });

    test('the command reads --locales and --themes', () async {
      final FakeNyloApp phone = await playing();
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      expect(
        await runLiveShellCommand('playbook', [
          'log_out',
          '--locales',
          'es',
          '--themes=all',
        ], runner),
        0,
      );
      expect(
        [
          for (final Map<String, Object?> run in phone.calls['playbooks.run']!)
            run['matrix'],
        ],
        [
          {'locale': 'es', 'theme': 'light'},
          {'locale': 'es', 'theme': 'dark'},
        ],
      );
      expect(
        await runLiveShellCommand('playbook', ['--locales', 'es'], runner),
        64,
      );
      expect(
        await runLiveShellCommand('playbook', [
          'log_out',
          '--themes',
          '',
        ], runner),
        64,
      );
    });
  });

  group('store screenshots', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('nylo_store'));
    tearDown(() => root.deleteSync(recursive: true));

    const Map<String, Object?> status = {
      'protocol': 13,
      'route': '/home',
      'playbooks': [],
      'stores': [
        {'id': 'ios-6.9', 'width': 1320, 'height': 2868},
      ],
    };

    Future<FakeNyloApp> playing({Map<String, Object?> status = status}) async {
      late final FakeNyloApp phone;
      phone = await app({
        'playbooks.run': (args) async {
          Timer(const Duration(milliseconds: 20), () {
            for (final Map<String, Object?> event in passingRun('pb_1')) {
              post(phone, switch (event['event']) {
                'step' when event['index'] == 2 => {
                  ...event,
                  'name': 'log_out',
                  'shots': [
                    {
                      'id': 's1',
                      'kind': 'marked',
                      'name': 'welcome',
                      'store': 'ios-6.9',
                      'width': 1320,
                      'height': 2868,
                    },
                  ],
                },
                _ => event,
              });
            }
          });
          return {'runId': 'pb_1'};
        },
        'screenshot.get': (args) async => {
          'png': base64Encode(utf8.encode('png ${args['id']}')),
        },
      }, status: status);
      return phone;
    }

    test(
      'sends the store and frame, and saves in the store\'s folder',
      () async {
        final FakeNyloApp phone = await playing();
        final LiveRunner runner = await runnerFor({
          'iPhone 17': phone,
        }, root: root.path);

        final int code = await playLivePlaybooks(
          runner,
          const LiveOptions(),
          ['log_out'],
          screenshots: 'auto',
          store: 'ios-6.9',
          frame: true,
          background: '#1B2027',
          interrupts: const Stream<Object?>.empty(),
        );

        expect(code, 0);
        expect(phone.calls['playbooks.run']!.single, {
          'names': ['log_out'],
          'screenshots': 'auto',
          'store': 'ios-6.9',
          'frame': true,
          'background': '#1B2027',
        });
        expect(
          File(
            '${root.path}/screenshots/log_out/ios-6.9/welcome.png',
          ).readAsStringSync(),
          'png s1',
        );
        expect(
          printed.toString(),
          allOf(
            contains('See "Get started"  → ios-6.9/welcome.png\n'),
            contains('✓ 1 screenshot in screenshots/log_out/ios-6.9/\n'),
          ),
        );
      },
    );

    test('names the stores the app has', () async {
      final FakeNyloApp phone = await playing();
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        screenshots: 'auto',
        store: 'ipad-11',
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(printed.toString(), contains('No store "ipad-11" in this app.'));
      expect(phone.calls['playbooks.run'], isNull);
    });

    test('needs an app on protocol 13', () async {
      final FakeNyloApp phone = await playing(
        status: {...status, 'protocol': 12},
      );
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        screenshots: 'auto',
        frame: true,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 1);
      expect(
        printed.toString(),
        contains('doesn\'t support store screenshots and frames yet'),
      );
    });

    test('the command reads and checks --store and --frame', () async {
      final FakeNyloApp phone = await playing();
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      for (final List<String> arguments in [
        ['log_out', '--screenshots=off', '--store', 'ios-6.9'],
        ['log_out', '--no-screenshots', '--store', 'ios-6.9'],
        ['log_out', '--screenshots=failures', '--frame'],
        ['log_out', '--screenshots', '--background', '#000000'],
        ['--store', 'ios-6.9'],
      ]) {
        expect(
          await runLiveShellCommand('playbook', arguments, runner),
          64,
          reason: '$arguments',
        );
      }
      expect(
        printed.toString(),
        allOf(
          contains(
            '--store goes with screenshots, so leave out --screenshots=off.',
          ),
          contains(
            '--frame goes with screenshots, so leave out '
            '--screenshots=failures.',
          ),
          contains('Name the playbooks to play'),
          contains('--background goes with --store or --frame'),
        ),
      );
      expect(phone.calls['playbooks.run'], isNull);

      expect(
        await runLiveShellCommand('playbook', [
          'log_out',
          '--store',
          'ios-6.9',
          '--frame',
        ], runner),
        0,
      );
      expect(
        await runLiveShellCommand('playbook', [
          'log_out',
          '--screenshots=all',
          '--store',
          'ios-6.9',
          '--frame',
        ], runner),
        0,
      );
      expect(
        await runLiveShellCommand('playbook', [
          'log_out',
          '--screenshots',
          '--store',
          'ios-6.9',
          '--background',
          '#ffffff',
        ], runner),
        0,
      );
      expect(phone.calls['playbooks.run'], [
        {
          'names': ['log_out'],
          'screenshots': 'marked',
          'store': 'ios-6.9',
          'frame': true,
        },
        {
          'names': ['log_out'],
          'screenshots': 'all',
          'store': 'ios-6.9',
          'frame': true,
        },
        {
          'names': ['log_out'],
          'screenshots': 'auto',
          'store': 'ios-6.9',
          'background': '#ffffff',
        },
      ]);
    });
  });

  group('native screenshots', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('nylo_native'));
    tearDown(() => root.deleteSync(recursive: true));

    const Map<String, Object?> simulator = {
      'protocol': 14,
      'platform': 'ios',
      'simulator': 'AAA',
      'route': '/home',
      'playbooks': [],
    };

    /// The start of a PNG [width] by [height].
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

    /// The iOS Simulator's tools, capturing a PNG unless [fails] says why.
    FakeProcesses simctl({String? fails}) => FakeProcesses(
      onRun: (String executable, List<String> arguments) {
        if (!arguments.contains('screenshot')) return null;
        if (fails != null) return ProcessResult(0, 1, '', fails);
        File(arguments.last).writeAsBytesSync(pngHeader(1206, 2622));
        return null;
      },
    );

    /// An app that asks Metro for a native screenshot of `form` after the
    /// first step, then reports [shot] once Metro answers.
    Future<FakeNyloApp> playing(
      Map<String, Object?> shot, {
      Map<String, Object?> status = simulator,
    }) async {
      final List<Map<String, Object?>> run = passingRun('pb_1');
      late final FakeNyloApp phone;
      void finish() {
        post(phone, {
          ...run[2],
          'name': 'log_out',
          'shots': [shot],
        });
        run.skip(3).forEach((event) => post(phone, event));
      }

      phone = await app({
        'playbooks.run': (args) async {
          Timer(const Duration(milliseconds: 20), () {
            post(phone, run[0]);
            post(phone, run[1]);
            if (args['native'] == true) {
              post(phone, {
                'runId': 'pb_1',
                'event': 'native',
                'id': 's1',
                'name': 'form',
              });
            } else {
              finish();
            }
          });
          return {'runId': 'pb_1'};
        },
        'screenshot.taken': (args) async {
          Timer(const Duration(milliseconds: 10), finish);
          return {'resumed': true};
        },
        'screenshot.get': (args) async => {
          'png': base64Encode(utf8.encode('png ${args['id']}')),
        },
      }, status: status);
      return phone;
    }

    test('captures the simulator and saves it as the step\'s', () async {
      final FakeNyloApp phone = await playing({
        'id': 's1',
        'kind': 'marked',
        'name': 'form',
        'native': true,
      });
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);
      final FakeProcesses processes = simctl();

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(json: true),
        ['log_out'],
        cleanStatusBar: true,
        processes: processes,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(phone.calls['playbooks.run']!.single, {
        'names': ['log_out'],
        'screenshots': 'marked',
        'native': true,
      });
      expect(
        [for (final List<String> run in processes.ran) run.sublist(1, 5)],
        [
          ['simctl', 'status_bar', 'AAA', 'list'],
          ['simctl', 'status_bar', 'AAA', 'override'],
          ['simctl', 'io', 'AAA', 'screenshot'],
          ['simctl', 'status_bar', 'AAA', 'clear'],
        ],
      );
      expect(
        processes.ran[2].last,
        startsWith('${root.path}/build/playbooks/.native/'),
      );
      expect(phone.calls['screenshot.taken'], [
        {'runId': 'pb_1', 'id': 's1', 'ok': true},
      ]);
      expect(phone.calls['screenshot.get'], isNull);
      expect(
        File('${root.path}/screenshots/log_out/form.png').readAsBytesSync(),
        pngHeader(1206, 2622),
      );
      expect(
        Directory('${root.path}/build/playbooks/.native').existsSync(),
        isFalse,
      );
      final Map<String, Object?> result =
          ((jsonDecode(printed.toString()) as List).single as Map)['result']
              as Map<String, Object?>;
      expect(result['screenshots'], [
        {
          'file': '${root.path}/screenshots/log_out/form.png',
          'kind': 'marked',
          'name': 'form',
          'step': 'Tap "Log out"',
          'native': true,
          'width': 1206,
          'height': 2622,
        },
      ]);
    });

    test('says why when the app took the screenshot itself', () async {
      final FakeNyloApp phone = await playing({
        'id': 's1',
        'kind': 'marked',
        'name': 'form',
        'nativeFallback': 'Metro couldn\'t capture the simulator.',
      });
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        processes: simctl(fails: 'Simulator is shut down'),
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(phone.calls['screenshot.taken']!.single, {
        'runId': 'pb_1',
        'id': 's1',
        'ok': false,
        'error': contains('Simulator is shut down'),
      });
      expect(
        File('${root.path}/screenshots/log_out/form.png').readAsStringSync(),
        'png s1',
      );
      expect(
        printed.toString(),
        contains(
          '  ✓   239ms  Tap "Log out"  → form.png\n'
          '        form.png is the app\'s own capture (Metro couldn\'t '
          'capture the simulator)\n',
        ),
      );
      expect(
        Directory('${root.path}/build/playbooks/.native').existsSync(),
        isFalse,
      );
    });

    test('leaves native screenshots to the app on other devices', () async {
      final FakeNyloApp phone = await playing(
        {
          'id': 's1',
          'kind': 'marked',
          'name': 'form',
          'nativeFallback':
              'Native screenshots need the iOS Simulator or an '
              'Android device',
        },
        status: {...simulator, 'platform': 'macos'},
      );
      final LiveRunner runner = await runnerFor({
        'macOS': phone,
      }, root: root.path);
      final FakeProcesses processes = simctl();

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        processes: processes,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(phone.calls['playbooks.run']!.single.containsKey('native'), false);
      expect(processes.ran, isEmpty);
      expect(phone.calls['screenshot.get'], [
        {'id': 's1'},
      ]);
    });

    test('offers native screenshots from protocol 14', () async {
      final FakeNyloApp phone = await playing(
        {'id': 's1', 'kind': 'marked', 'name': 'form'},
        status: {...simulator, 'protocol': 13},
      );
      final LiveRunner runner = await runnerFor({
        'iPhone 17': phone,
      }, root: root.path);
      final FakeProcesses processes = simctl();

      final int code = await playLivePlaybooks(
        runner,
        const LiveOptions(),
        ['log_out'],
        processes: processes,
        interrupts: const Stream<Object?>.empty(),
      );

      expect(code, 0);
      expect(phone.calls['playbooks.run']!.single.containsKey('native'), false);
      expect(processes.ran, isEmpty);
    });
  });
}
