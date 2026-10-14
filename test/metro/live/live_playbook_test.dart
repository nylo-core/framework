import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/commands/live/live_commands.dart';
import 'package:nylo_framework/metro/live/live_discovery.dart';
import 'package:nylo_framework/metro/live/live_options.dart';
import 'package:nylo_framework/metro/live/live_output.dart';
import 'package:nylo_framework/metro/live/live_runner.dart';

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
      project: LiveProject(Directory.systemTemp.path, 'shop'),
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
}
