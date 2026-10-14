import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_app.dart';
import 'package:nylo_framework/metro/live/live_recorder.dart';

import 'fake_processes.dart';
import 'fake_servers.dart';

void main() {
  final String sep = Platform.pathSeparator;

  group('liveRecordingPath', () {
    final DateTime at = DateTime(2026, 10, 13, 22, 31, 5);

    test('names the file after the playbooks, device and time', () {
      expect(
        liveRecordingPath(
          root: '/app',
          names: ['sign_up', 'log_out'],
          device: 'Anthony’s iPhone 17',
          at: at,
        ),
        '/app${sep}build${sep}playbooks$sep'
        'sign_up+log_out-anthony-s-iphone-17-20261013-223105.mp4',
      );
    });

    test('adds the start of the device id when device names clash', () {
      expect(
        liveRecordingPath(
          root: '/app',
          names: ['sign_up'],
          device: 'iPhone 17',
          at: at,
          deviceId: '5C3B43A5-2149-445F-8D80-6F72B766D4D4',
          several: true,
        ),
        endsWith('sign_up-iphone-17-5c3b-20261013-223105.mp4'),
      );
    });

    test('uses the requested file, with the device when there are several', () {
      expect(
        liveRecordingPath(
          root: '/app',
          names: ['sign_up'],
          device: 'iPhone 17',
          at: at,
          requested: 'docs/demo.gif',
        ),
        '/app${sep}docs/demo.gif',
      );
      expect(
        liveRecordingPath(
          root: '/app',
          names: ['sign_up'],
          device: 'Pixel 10 Pro',
          at: at,
          requested: '/tmp/demo.mp4',
          several: true,
        ),
        '/tmp/demo-pixel-10-pro.mp4',
      );
    });
  });

  group('captions and chapters', () {
    const List<LiveCue> cues = [
      LiveCue(
        Duration(milliseconds: 600),
        Duration(milliseconds: 1850),
        'Type "a<b & c" into Email',
      ),
      LiveCue(
        Duration(milliseconds: 1850),
        Duration(seconds: 3723, milliseconds: 4),
        'Tap "Save; done = yes"',
      ),
    ];

    test('writes WebVTT cues', () {
      expect(
        liveWebVtt(cues),
        'WEBVTT\n'
        '\n1\n00:00:00.600 --> 00:00:01.850\nType "a&lt;b &amp; c" into Email\n'
        '\n2\n00:00:01.850 --> 01:02:03.004\nTap "Save; done = yes"\n',
      );
    });

    test('writes ffmpeg chapters, the last running to the end', () {
      expect(
        liveChapters(cues, const Duration(seconds: 4000)),
        ';FFMETADATA1\n'
        '\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=600\nEND=1850\n'
        'title=Type "a<b & c" into Email\n'
        '\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=1850\nEND=4000000\n'
        'title=Tap "Save\\; done \\= yes"\n',
      );
    });
  });

  group('device lookups', () {
    test('finds booted simulators by name', () {
      const String json = '''
{"devices": {
  "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
    {"name": "iPhone 17", "udid": "AAA", "state": "Booted"},
    {"name": "iPhone 18 Pro", "udid": "BBB", "state": "Booted"}
  ],
  "com.apple.CoreSimulator.SimRuntime.iOS-26-4": [
    {"name": "iPhone 17", "udid": "CCC", "state": "Booted"},
    {"name": "iPhone 17", "udid": "DDD", "state": "Shutdown"}
  ]
}}''';
      expect(bootedSimulatorsNamed('iPhone 17', json), ['AAA', 'CCC']);
      expect(bootedSimulatorsNamed('iPhone 18 Pro', json), ['BBB']);
      expect(bootedSimulatorsNamed('iPhone 17', 'not json'), isEmpty);
    });

    test('reads adb serials that are ready', () {
      expect(
        adbSerials(
          'List of devices attached\n'
          'emulator-5554\tdevice\n'
          '1A2B3C\tunauthorized\n'
          'R5CT\tdevice product:x model:Pixel_10 device:y\n\n',
        ),
        ['emulator-5554'],
      );
    });

    test('reads the applicationId from Kotlin and Groovy build files', () {
      final Directory root = Directory.systemTemp.createTempSync('nylo_app');
      addTearDown(() => root.deleteSync(recursive: true));
      Directory('${root.path}/android/app').createSync(recursive: true);
      expect(readAndroidApplicationId(root.path), isNull);

      File('${root.path}/android/app/build.gradle').writeAsStringSync(
        "defaultConfig {\n  applicationId 'com.shop.groovy'\n}",
      );
      expect(readAndroidApplicationId(root.path), 'com.shop.groovy');

      File('${root.path}/android/app/build.gradle.kts').writeAsStringSync(
        'defaultConfig {\n  applicationId = "com.shop.app"\n}',
      );
      expect(readAndroidApplicationId(root.path), 'com.shop.app');
    });

    test('tells a simulator status bar with overrides from one without', () {
      const String heading =
          'Current Status Bar Overrides:\n=============================\n';
      expect(
        simulatorHasStatusBarOverrides(ProcessResult(0, 0, heading, '')),
        isFalse,
      );
      expect(
        simulatorHasStatusBarOverrides(
          ProcessResult(0, 0, '${heading}Time: 9:41\n', ''),
        ),
        isTrue,
      );
    });
  });

  group('SimctlRecorder', () {
    test('starts once simctl says so, and stops it with Ctrl+C', () async {
      final FakeProcesses processes = FakeProcesses(
        onStart: (executable, arguments) => FakeProgram()
          ..say('Note: No display specified.')
          ..say('Recording started'),
      );
      final SimctlRecorder recorder = SimctlRecorder(
        processes,
        xcrun: '/usr/bin/xcrun',
        udid: 'AAA',
      );

      await recorder.start('/tmp/raw.mov');
      expect(processes.started.single, [
        '/usr/bin/xcrun',
        'simctl',
        'io',
        'AAA',
        'recordVideo',
        '--codec=h264',
        '--force',
        '/tmp/raw.mov',
      ]);
      await recorder.stop();
      expect(processes.programs.single.signals, [ProcessSignal.sigint]);
    });

    test('says why when simctl gives up before recording', () async {
      final FakeProcesses processes = FakeProcesses(
        onStart: (executable, arguments) => FakeProgram()
          ..say('Invalid device: AAA')
          ..exit(),
      );
      final SimctlRecorder recorder = SimctlRecorder(
        processes,
        xcrun: 'xcrun',
        udid: 'AAA',
      );

      await expectLater(
        recorder.start('/tmp/raw.mov'),
        throwsA(
          isA<LiveCommandException>().having(
            (e) => e.message,
            'message',
            'The iOS Simulator didn\'t start recording: Invalid device: AAA',
          ),
        ),
      );
    });

    test('sets a clean status bar and clears it after', () async {
      final FakeProcesses processes = FakeProcesses();
      final SimctlRecorder recorder = SimctlRecorder(
        processes,
        xcrun: 'xcrun',
        udid: 'AAA',
      );

      final Future<void> Function() restore = await recorder.cleanStatusBar();
      expect(processes.ran[1].sublist(0, 6), [
        'xcrun',
        'simctl',
        'status_bar',
        'AAA',
        'override',
        '--time',
      ]);
      await restore();
      expect(processes.ran.last, [
        'xcrun',
        'simctl',
        'status_bar',
        'AAA',
        'clear',
      ]);
    });

    test('keeps a status bar someone already set', () async {
      final FakeProcesses processes = FakeProcesses(
        onRun: (executable, arguments) => ProcessResult(
          0,
          0,
          'Current Status Bar Overrides:\n=====\nTime: 10:10\n',
          '',
        ),
      );
      final SimctlRecorder recorder = SimctlRecorder(
        processes,
        xcrun: 'xcrun',
        udid: 'AAA',
      );

      await (await recorder.cleanStatusBar())();
      expect(processes.ran, hasLength(1));
    });
  });

  group('AdbRecorder', () {
    test('scales a screen wider than 1080 down, keeping its shape', () {
      expect(screenrecordSize('Physical size: 1280x2856\n'), '1080x2410');
      expect(
        screenrecordSize('Physical size: 1440x3120\nOverride size: 1080x2340'),
        isNull,
      );
      expect(screenrecordSize('Physical size: 1080x2400'), isNull);
      expect(screenrecordSize('Physical size: 2856x1280'), '2410x1080');
      expect(screenrecordSize('error: no devices'), isNull);
    });

    test('stops screenrecord on the device, then copies the file', () async {
      final FakeProcesses processes = FakeProcesses(
        onStart: (executable, arguments) =>
            FakeProgram()..say('Configuring recorder for 1080x2400'),
      );
      final AdbRecorder recorder = AdbRecorder(
        processes,
        adb: 'adb',
        serial: 'emulator-5554',
      );

      await recorder.start('/tmp/raw.mp4');
      final String remote = processes.started.single.last;
      expect(processes.started.single.sublist(0, 5), [
        'adb',
        '-s',
        'emulator-5554',
        'shell',
        'screenrecord',
      ]);
      // screenrecord exits once it's told to stop on the device.
      final FakeProgram program = processes.programs.single;
      final Future<void> stopping = recorder.stop();
      program.exit();
      await stopping;

      expect(processes.ran, [
        ['adb', '-s', 'emulator-5554', 'shell', 'wm size'],
        ['adb', '-s', 'emulator-5554', 'shell', 'pkill -2 screenrecord'],
        ['adb', '-s', 'emulator-5554', 'pull', remote, '/tmp/raw.mp4'],
        ['adb', '-s', 'emulator-5554', 'shell', 'rm -f $remote'],
      ]);
      expect(program.signals, isEmpty);
      expect(recorder.limit, const Duration(minutes: 3));
    });
  });

  group('findLiveRecorder', () {
    final List<Future<void> Function()> cleanup = [];
    tearDown(() async {
      for (final Future<void> Function() close in cleanup.reversed) {
        await close();
      }
      cleanup.clear();
    });

    Future<LiveApp> appWith(
      Map<String, Object?> status, {
      String device = 'iPhone 17',
    }) async {
      final FakeNyloApp fake = await FakeNyloApp.start(status: status);
      cleanup.add(fake.close);
      final LiveApp app = await LiveApp.connect(
        fake.wsUri,
        device: device,
        package: 'shop',
      );
      cleanup.add(app.close);
      return app;
    }

    test('records the simulator the app says it runs on', () async {
      final LiveApp app = await appWith({
        'protocol': 10,
        'platform': 'ios',
        'simulator': 'AAA',
      });
      final LiveRecorder recorder = await findLiveRecorder(
        app,
        projectRoot: '/app',
        processes: FakeProcesses(),
      );
      expect(recorder, isA<SimctlRecorder>());
      expect(recorder.id, 'AAA');
    });

    test('explains that an iPhone can\'t be recorded', () async {
      final LiveApp app = await appWith({'protocol': 10, 'platform': 'ios'});
      await expectLater(
        findLiveRecorder(app, projectRoot: '/app', processes: FakeProcesses()),
        throwsA(
          isA<LiveCommandException>().having(
            (e) => e.message,
            'message',
            contains('QuickTime'),
          ),
        ),
      );
    });

    test('finds the simulator by name for an older app', () async {
      final LiveApp app = await appWith({'protocol': 9, 'platform': 'ios'});
      ProcessResult listed(String json) => ProcessResult(0, 0, json, '');
      const String one =
          '{"devices":{"r":[{"name":"iPhone 17","udid":"AAA","state":"Booted"}]}}';
      final LiveRecorder recorder = await findLiveRecorder(
        app,
        projectRoot: '/app',
        processes: FakeProcesses(onRun: (_, _) => listed(one)),
      );
      expect(recorder.id, 'AAA');

      const String two =
          '{"devices":{"r":[{"name":"iPhone 17","udid":"AAA","state":"Booted"},'
          '{"name":"iPhone 17","udid":"BBB","state":"Booted"}]}}';
      await expectLater(
        findLiveRecorder(
          app,
          projectRoot: '/app',
          processes: FakeProcesses(onRun: (_, _) => listed(two)),
        ),
        throwsA(
          isA<LiveCommandException>().having(
            (e) => e.message,
            'message',
            startsWith('2 booted simulators are called "iPhone 17"'),
          ),
        ),
      );
    });

    test('picks the Android device that runs the app', () async {
      final LiveApp app = await appWith({
        'protocol': 10,
        'platform': 'android',
      }, device: 'Pixel 10 Pro');
      final Directory root = Directory.systemTemp.createTempSync('nylo_app');
      addTearDown(() => root.deleteSync(recursive: true));
      Directory('${root.path}/android/app').createSync(recursive: true);
      File(
        '${root.path}/android/app/build.gradle.kts',
      ).writeAsStringSync('applicationId = "com.shop.app"');

      final FakeProcesses processes = FakeProcesses(
        installed: {'adb': '/sdk/adb'},
        onRun: (executable, arguments) {
          if (arguments.first == 'devices') {
            return ProcessResult(
              0,
              0,
              'List of devices attached\nemulator-5554\tdevice\n'
                  'emulator-5556\tdevice\n',
              '',
            );
          }
          final bool running =
              arguments[1] == 'emulator-5556' &&
              arguments.last == 'com.shop.app';
          return ProcessResult(0, running ? 0 : 1, running ? '4242\n' : '', '');
        },
      );
      final LiveRecorder recorder = await findLiveRecorder(
        app,
        projectRoot: root.path,
        processes: processes,
      );
      expect(recorder, isA<AdbRecorder>());
      expect(recorder.id, 'emulator-5556');

      final LiveRecorder withScrcpy = await findLiveRecorder(
        app,
        projectRoot: root.path,
        processes: FakeProcesses(
          installed: {'adb': '/sdk/adb', 'scrcpy': '/bin/scrcpy'},
          env: {'ANDROID_SERIAL': 'R5CT'},
        ),
      );
      expect(withScrcpy, isA<ScrcpyRecorder>());
      expect(withScrcpy.id, 'R5CT');
    });

    test('needs adb for Android, and refuses other platforms', () async {
      final LiveApp android = await appWith({'platform': 'android'});
      await expectLater(
        findLiveRecorder(
          android,
          projectRoot: '/app',
          processes: FakeProcesses(installed: {}),
        ),
        throwsA(
          isA<LiveCommandException>().having(
            (e) => e.message,
            'message',
            startsWith('Recording Android needs adb.'),
          ),
        ),
      );

      final LiveApp mac = await appWith({'platform': 'macos'});
      await expectLater(
        findLiveRecorder(mac, projectRoot: '/app', processes: FakeProcesses()),
        throwsA(
          isA<LiveCommandException>().having(
            (e) => e.message,
            'message',
            contains('not on macos yet'),
          ),
        ),
      );
    });
  });

  group('LiveRecording', () {
    test('turns step events into captions that last until the next', () {
      final LiveRecording recording = LiveRecording(
        recorder: SimctlRecorder(FakeProcesses(), xcrun: 'x', udid: 'A'),
        ffmpeg: 'ffmpeg',
        output: '/tmp/x.mp4',
      );
      recording
        ..mark({'event': 'start'}, Duration.zero)
        ..mark({
          'event': 'begin',
          'title': 'Sign up',
          'group': true,
        }, const Duration(milliseconds: 600))
        ..mark({
          'event': 'begin',
          'title': 'Tap "Next"',
        }, const Duration(milliseconds: 700))
        ..mark({
          'event': 'begin',
          'title': 'See "Done"',
        }, const Duration(milliseconds: 1500))
        ..mark({'event': 'done'}, const Duration(milliseconds: 1900));

      expect(
        [
          for (final LiveCue cue in recording.cues())
            '${cue.start.inMilliseconds}-${cue.end.inMilliseconds} ${cue.text}',
        ],
        ['700-1500 Tap "Next"', '1500-1900 See "Done"'],
      );
    });

    test('saves an mp4 with captions through ffmpeg', () async {
      final Directory out = Directory.systemTemp.createTempSync('nylo_rec');
      addTearDown(() => out.deleteSync(recursive: true));
      final FakeProcesses processes = fakeSimulatorTools();
      final LiveRecording recording = LiveRecording(
        recorder: SimctlRecorder(processes, xcrun: 'xcrun', udid: 'A'),
        ffmpeg: '/bin/ffmpeg',
        output: '${out.path}/videos/demo.mp4',
      );

      await recording.start();
      recording.mark({'event': 'begin', 'title': 'Tap "Next"'}, Duration.zero);
      final LiveRecordingSaved saved = await recording.finish();

      expect(File(saved.file).readAsStringSync(), 'video');
      expect(saved.captions, '${out.path}/videos/demo.vtt');
      expect(File(saved.captions!).readAsStringSync(), contains('Tap "Next"'));
      expect(saved.cues, 1);
      final List<String> ffmpeg = processes.ran.single;
      expect(
        ffmpeg,
        containsAllInOrder(['-map_chapters', '1', 'libx264', '-t']),
      );
      // Cut at the time recorded, not the simulator's idea of the end.
      expect(double.parse(ffmpeg[ffmpeg.indexOf('-t') + 1]), lessThan(5));
      // The raw recording is in a temp folder that's gone once it's saved.
      expect(File(ffmpeg[4]).existsSync(), isFalse);
      expect(processes.programs.single.signals, [ProcessSignal.sigint]);
    });

    test('keeps the original when ffmpeg fails', () async {
      final Directory out = Directory.systemTemp.createTempSync('nylo_rec');
      addTearDown(() => out.deleteSync(recursive: true));
      final FakeProcesses processes = fakeSimulatorTools(
        onRun: (executable, arguments) =>
            ProcessResult(0, 1, '', 'Unknown encoder \'libx264\''),
      );
      final LiveRecording recording = LiveRecording(
        recorder: SimctlRecorder(processes, xcrun: 'xcrun', udid: 'A'),
        ffmpeg: '/bin/ffmpeg',
        output: '${out.path}/demo.gif',
      );

      await recording.start();
      await expectLater(
        recording.finish(),
        throwsA(
          isA<LiveCommandException>().having(
            (e) => e.message,
            'message',
            'ffmpeg couldn\'t convert the recording (Unknown encoder '
                '\'libx264\'). The original is at ${out.path}/demo.mov',
          ),
        ),
      );
      expect(File('${out.path}/demo.mov').readAsStringSync(), 'raw video');
      // The last frame is held until the time recorded, then cut there.
      final List<String> ffmpeg = processes.ran.single;
      final String length = ffmpeg[ffmpeg.indexOf('-t') + 1];
      expect(
        ffmpeg,
        contains(
          'tpad=stop_mode=clone:stop_duration=$length,fps=15,scale=480:-1:'
          'flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse',
        ),
      );
    });
  });
}
