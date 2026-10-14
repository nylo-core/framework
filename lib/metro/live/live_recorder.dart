import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'live_app.dart';

/// Runs the programs a recording needs: `xcrun`, `adb`, `scrcpy` and
/// `ffmpeg`.
///
/// Tests stand in for it, so recording can be tested without a device.
class LiveProcesses {
  /// Creates a [LiveProcesses] that runs real programs.
  const LiveProcesses();

  /// The environment programs are found and run in.
  Map<String, String> get environment => Platform.environment;

  /// Runs [executable] to the end and returns what it printed.
  ///
  /// It runs in its own process group, so the Ctrl+C that stops a playbook
  /// doesn't also cut short ffmpeg saving the video, or adb copying it.
  Future<ProcessResult> run(String executable, List<String> arguments) async {
    if (Platform.isWindows) return Process.run(executable, arguments);
    // A detached process has no exit code of its own, so a shell reports it.
    final Process process = await Process.start('/bin/sh', [
      '-c',
      r'"$@"; echo "nylo-exit:$?" >&2',
      'sh',
      executable,
      ...arguments,
    ], mode: ProcessStartMode.detachedWithStdio);
    await process.stdin.close();
    const Utf8Decoder decoder = Utf8Decoder(allowMalformed: true);
    final List<String> printed = await Future.wait([
      process.stdout.transform(decoder).join(),
      process.stderr.transform(decoder).join(),
    ]);
    final RegExpMatch? exit = RegExp(
      r'nylo-exit:(\d+)\s*$',
    ).firstMatch(printed[1]);
    return ProcessResult(
      process.pid,
      exit == null ? -1 : int.parse(exit.group(1)!),
      printed[0],
      exit == null ? printed[1] : printed[1].substring(0, exit.start),
    );
  }

  /// Starts [executable] in its own process group, so a Ctrl+C typed in the
  /// terminal doesn't reach it. Metro stops it with [LiveProcess.interrupt]
  /// once the playbook has finished.
  Future<LiveProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    final Process process = await Process.start(
      executable,
      arguments,
      environment: environment,
      mode: ProcessStartMode.detachedWithStdio,
    );
    return LiveProcess(
      stdout: process.stdout,
      stderr: process.stderr,
      signal: (ProcessSignal signal) => Process.killPid(process.pid, signal),
    );
  }

  /// Waits for [duration].
  Future<void> delay(Duration duration) => Future<void>.delayed(duration);

  /// The path of the program [name], or null when it isn't installed.
  ///
  /// Looks on the `PATH`, then in [extraDirectories].
  String? find(String name, {List<String> extraDirectories = const []}) {
    final bool windows = Platform.isWindows;
    final String separator = windows ? ';' : ':';
    final List<String> directories = [
      ...(environment['PATH'] ?? '').split(separator),
      ...extraDirectories,
    ];
    for (final String directory in directories) {
      if (directory.isEmpty) continue;
      for (final String candidate in [
        '$directory${Platform.pathSeparator}$name',
        if (windows) '$directory${Platform.pathSeparator}$name.exe',
      ]) {
        if (File(candidate).existsSync()) return candidate;
      }
    }
    return null;
  }
}

/// A program a recorder started, such as `simctl io recordVideo`.
class LiveProcess {
  /// Creates a [LiveProcess] reading [stdout] and [stderr], and sending
  /// signals with [signal].
  LiveProcess({
    required Stream<List<int>> stdout,
    required Stream<List<int>> stderr,
    required this._signal,
  }) {
    int open = 2;
    void closed() {
      if (--open > 0) return;
      if (!_exited.isCompleted) _exited.complete();
      _lines.close();
    }

    for (final Stream<List<int>> stream in [stdout, stderr]) {
      stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            (String line) {
              output.add(line);
              _lines.add(line);
            },
            onError: (Object _) {},
            onDone: closed,
          );
    }
  }

  final bool Function(ProcessSignal signal) _signal;
  final Completer<void> _exited = Completer<void>();
  final StreamController<String> _lines = StreamController<String>.broadcast();

  /// Every line the program has printed so far.
  final List<String> output = [];

  /// Completes when the program has exited.
  Future<void> get exited => _exited.future;

  /// Whether the program has exited.
  bool get hasExited => _exited.isCompleted;

  /// Waits for the program to print a line that passes [test].
  ///
  /// Returns false when the program exits first or [timeout] passes.
  Future<bool> waitFor(bool Function(String line) test, Duration timeout) {
    if (output.any(test)) return Future<bool>.value(true);
    if (hasExited) return Future<bool>.value(false);
    final Completer<bool> seen = Completer<bool>();
    late final StreamSubscription<String> subscription;
    subscription = _lines.stream.listen(
      (String line) {
        if (test(line) && !seen.isCompleted) seen.complete(true);
      },
      onDone: () {
        if (!seen.isCompleted) seen.complete(false);
      },
    );
    return seen.future
        .timeout(timeout, onTimeout: () => false)
        .whenComplete(subscription.cancel);
  }

  /// Asks the program to stop, as Ctrl+C would.
  void interrupt() => _signal(ProcessSignal.sigint);

  /// Ends the program straight away.
  void kill() => _signal(ProcessSignal.sigkill);

  /// Stops the program with [interrupt] and waits up to [timeout] for it to
  /// finish writing, then kills it.
  Future<void> stop(Duration timeout) async {
    if (hasExited) return;
    interrupt();
    await exited.timeout(
      timeout,
      onTimeout: () {
        kill();
      },
    );
  }

  /// The last few lines of output, to explain a failure.
  String get tail {
    final Iterable<String> lines = output
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty);
    return lines.skip(lines.length > 3 ? lines.length - 3 : 0).join(' ');
  }
}

/// Records the screen of the device an app runs on.
abstract class LiveRecorder {
  /// Creates a [LiveRecorder] that runs programs with [processes].
  LiveRecorder(this.processes);

  /// Runs the recording programs.
  final LiveProcesses processes;

  /// The device's id: a simulator UDID or an adb serial.
  String get id;

  /// The extension of the file the recorder writes, e.g. `.mov`.
  String get extension;

  /// How long the recorder can record, or null when there's no limit.
  Duration? get limit => null;

  /// Starts recording into [file], and completes once it's recording.
  Future<void> start(String file);

  /// Stops recording, and completes once the file has been written.
  Future<void> stop();

  /// Shows a clean status bar (9:41, full battery and signal), and returns
  /// how to put the old one back.
  Future<Future<void> Function()> cleanStatusBar();
}

/// Records the iOS Simulator with `xcrun simctl io recordVideo`.
class SimctlRecorder extends LiveRecorder {
  /// Creates a [SimctlRecorder] for the simulator [udid].
  SimctlRecorder(super.processes, {required this.xcrun, required this.udid});

  /// The path of `xcrun`.
  final String xcrun;

  /// The simulator's UDID.
  final String udid;

  LiveProcess? _process;

  @override
  String get id => udid;

  @override
  String get extension => '.mov';

  @override
  Future<void> start(String file) async {
    final LiveProcess process = await processes.start(xcrun, [
      'simctl',
      'io',
      udid,
      'recordVideo',
      '--codec=h264',
      '--force',
      file,
    ]);
    // simctl prints this once the first frame has been captured.
    final bool started = await process.waitFor(
      (String line) => line.contains('Recording started'),
      const Duration(seconds: 15),
    );
    if (!started) {
      process.kill();
      throw LiveCommandException(
        'The iOS Simulator didn\'t start recording'
        '${process.tail.isEmpty ? '.' : ': ${process.tail}'}',
      );
    }
    _process = process;
  }

  @override
  Future<void> stop() async {
    final LiveProcess? process = _process;
    _process = null;
    await process?.stop(const Duration(seconds: 15));
  }

  @override
  Future<Future<void> Function()> cleanStatusBar() async {
    final ProcessResult current = await processes.run(xcrun, [
      'simctl',
      'status_bar',
      udid,
      'list',
    ]);
    // Keep a status bar someone already set up, rather than replacing it
    // and then clearing it.
    if (current.exitCode == 0 && simulatorHasStatusBarOverrides(current)) {
      return () async {};
    }
    final ProcessResult set = await processes.run(xcrun, [
      'simctl',
      'status_bar',
      udid,
      'override',
      '--time',
      '9:41',
      '--dataNetwork',
      'wifi',
      '--wifiMode',
      'active',
      '--wifiBars',
      '3',
      '--cellularMode',
      'active',
      '--cellularBars',
      '4',
      '--batteryState',
      'charged',
      '--batteryLevel',
      '100',
    ]);
    if (set.exitCode != 0) {
      throw LiveCommandException(
        'Couldn\'t set the simulator\'s status bar: ${'${set.stderr}'.trim()}',
      );
    }
    return () async {
      await processes.run(xcrun, ['simctl', 'status_bar', udid, 'clear']);
    };
  }
}

/// Whether `simctl status_bar <udid> list` printed any overrides.
///
/// It prints a two-line heading, then one line per override.
bool simulatorHasStatusBarOverrides(ProcessResult result) => '${result.stdout}'
    .split('\n')
    .skip(2)
    .any((String line) => line.trim().isNotEmpty);

/// What Android recorders share: the device's serial and its demo mode.
abstract class _AndroidRecorder extends LiveRecorder {
  _AndroidRecorder(super.processes, {required this.adb, required this.serial});

  /// The path of `adb`.
  final String adb;

  /// The device's adb serial.
  final String serial;

  @override
  String get id => serial;

  Future<ProcessResult> _shell(String command) =>
      processes.run(adb, ['-s', serial, 'shell', command]);

  @override
  Future<Future<void> Function()> cleanStatusBar() async {
    final String previous =
        '${(await _shell('settings get global '
            'sysui_demo_allowed')).stdout}'
            .trim();
    const String demo = 'am broadcast -a com.android.systemui.demo -e command';
    await _shell(
      [
        'settings put global sysui_demo_allowed 1',
        '$demo enter',
        '$demo clock -e hhmm 0941',
        '$demo battery -e level 100 -e plugged false',
        '$demo network -e wifi show -e level 4',
        '$demo network -e mobile show -e level 4 -e datatype none',
        '$demo notifications -e visible false',
      ].join('; '),
    );
    return () async {
      await _shell(
        [
          '$demo exit',
          if (previous == '1' || previous == '0')
            'settings put global sysui_demo_allowed $previous'
          else
            'settings delete global sysui_demo_allowed',
        ].join('; '),
      );
    };
  }
}

/// Records Android with `adb shell screenrecord`, which stops by itself
/// after three minutes.
class AdbRecorder extends _AndroidRecorder {
  /// Creates an [AdbRecorder] for the device [serial].
  AdbRecorder(super.processes, {required super.adb, required super.serial});

  LiveProcess? _process;
  String? _remote;
  String? _file;

  @override
  String get extension => '.mp4';

  @override
  Duration? get limit => const Duration(minutes: 3);

  @override
  Future<void> start(String file) async {
    final String remote =
        '/sdcard/nylo_playbook_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final String? size = screenrecordSize(
      '${(await _shell('wm size')).stdout}',
    );
    final LiveProcess process = await processes.start(adb, [
      '-s',
      serial,
      'shell',
      'screenrecord',
      '--verbose',
      if (size != null) ...['--size', size],
      remote,
    ]);
    // --verbose describes the display, then the encoder, before the first
    // frame. Older versions word it differently, so carry on after a few
    // seconds unless screenrecord has given up.
    await process.waitFor(
      (String line) =>
          line.contains('Content area') ||
          line.contains('Configuring recorder'),
      const Duration(seconds: 5),
    );
    if (process.hasExited) {
      throw LiveCommandException(
        'adb screenrecord didn\'t start'
        '${process.tail.isEmpty ? '.' : ': ${process.tail}'}',
      );
    }
    _process = process;
    _remote = remote;
    _file = file;
  }

  @override
  Future<void> stop() async {
    final LiveProcess? process = _process;
    final String? remote = _remote;
    final String? file = _file;
    _process = null;
    if (process == null || remote == null || file == null) return;
    // Interrupting the local adb can leave a broken file, so stop
    // screenrecord on the device and let it finish writing.
    await _shell('pkill -2 screenrecord');
    await process.exited.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        process.kill();
      },
    );
    await processes.delay(const Duration(milliseconds: 300));
    final ProcessResult pulled = await processes.run(adb, [
      '-s',
      serial,
      'pull',
      remote,
      file,
    ]);
    await _shell('rm -f $remote');
    if (pulled.exitCode != 0) {
      throw LiveCommandException(
        'Couldn\'t copy the recording off the device: '
        '${'${pulled.stderr}'.trim()}',
      );
    }
  }
}

/// The `--size` for `screenrecord` on a screen `wm size` describes as
/// [wmSize], or null to record it as it is.
///
/// Encoders often can't take a screen wider than 1080 pixels, and then
/// screenrecord drops to 720x1280 with black bars, so a wider screen is
/// scaled down to 1080 wide, keeping its shape.
String? screenrecordSize(String wmSize) {
  final RegExpMatch? match =
      RegExp(r'Override size: (\d+)x(\d+)').firstMatch(wmSize) ??
      RegExp(r'Physical size: (\d+)x(\d+)').firstMatch(wmSize);
  if (match == null) return null;
  final int width = int.parse(match.group(1)!);
  final int height = int.parse(match.group(2)!);
  final int short = min(width, height);
  if (short <= 1080) return null;
  int scaled(int side) => (side * 1080 / short / 2).round() * 2;
  return '${scaled(width)}x${scaled(height)}';
}

/// Records Android with `scrcpy`, which has no time limit and records the
/// app's sound on Android 11 and later.
class ScrcpyRecorder extends _AndroidRecorder {
  /// Creates a [ScrcpyRecorder] for the device [serial].
  ScrcpyRecorder(
    super.processes, {
    required this.scrcpy,
    required super.adb,
    required super.serial,
  });

  /// The path of `scrcpy`.
  final String scrcpy;

  LiveProcess? _process;

  @override
  String get extension => '.mp4';

  @override
  Future<void> start(String file) async {
    final LiveProcess process = await processes.start(
      scrcpy,
      ['--serial=$serial', '--no-playback', '--no-control', '--record=$file'],
      environment: {'ADB': adb},
    );
    final bool started = await process.waitFor(
      (String line) => line.contains('Recording started'),
      const Duration(seconds: 20),
    );
    if (!started) {
      process.kill();
      throw LiveCommandException(
        'scrcpy didn\'t start recording'
        '${process.tail.isEmpty ? '.' : ': ${process.tail}'}',
      );
    }
    _process = process;
  }

  @override
  Future<void> stop() async {
    final LiveProcess? process = _process;
    _process = null;
    await process?.stop(const Duration(seconds: 20));
  }
}

/// Finds a recorder for the device [app] runs on.
///
/// The iOS Simulator is found by the UDID the app reports (protocol 10), or
/// else by its name. An Android device is the one running the app's
/// `applicationId`, or `ANDROID_SERIAL`. Throws a [LiveCommandException]
/// when the device can't be recorded.
Future<LiveRecorder> findLiveRecorder(
  LiveApp app, {
  required String projectRoot,
  LiveProcesses processes = const LiveProcesses(),
}) async {
  final Object? platform = app.status['platform'];
  switch (platform) {
    case 'ios':
      return _findSimulator(app, processes);
    case 'android':
      return _findAndroid(app, projectRoot, processes);
    default:
      throw LiveCommandException(
        'Metro can record playbooks on the iOS Simulator and Android, not on '
        '${platform ?? app.device} yet.',
      );
  }
}

Future<LiveRecorder> _findSimulator(
  LiveApp app,
  LiveProcesses processes,
) async {
  final String xcrun = processes.find('xcrun') ?? '/usr/bin/xcrun';
  final Object? reported = app.status['simulator'];
  if (reported is String && reported.isNotEmpty) {
    return SimctlRecorder(processes, xcrun: xcrun, udid: reported);
  }
  final Object? protocol = app.status['protocol'];
  if (protocol is num && protocol >= 10) {
    // The app would have said which simulator it's on.
    throw LiveCommandException(
      '${app.device} is an iPhone, and Metro can only record the iOS '
      'Simulator. Record it with QuickTime or Control Center, and add '
      '--countdown 3 for time to start.',
    );
  }

  final ProcessResult listed = await processes.run(xcrun, [
    'simctl',
    'list',
    'devices',
    'booted',
    '-j',
  ]);
  final List<String> matches = listed.exitCode == 0
      ? bootedSimulatorsNamed(app.device, '${listed.stdout}')
      : const [];
  if (matches.length == 1) {
    return SimctlRecorder(processes, xcrun: xcrun, udid: matches.single);
  }
  if (matches.isEmpty) {
    throw LiveCommandException(
      'There\'s no booted iOS Simulator called "${app.device}". Metro can '
      'only record the iOS Simulator. On an iPhone, record with QuickTime or '
      'Control Center, and add --countdown 3 for time to start.',
    );
  }
  throw LiveCommandException(
    '${matches.length} booted simulators are called "${app.device}". Update '
    'nylo_framework and restart the app, so Metro can tell which one it\'s '
    'on.',
  );
}

/// The UDIDs of the booted simulators called [name], from the JSON of
/// `simctl list devices booted -j`.
List<String> bootedSimulatorsNamed(String name, String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  final Object? runtimes = decoded is Map ? decoded['devices'] : null;
  if (runtimes is! Map) return const [];
  return [
    for (final Object? devices in runtimes.values)
      if (devices is List)
        for (final Object? device in devices)
          if (device is Map &&
              device['name'] == name &&
              device['state'] == 'Booted' &&
              device['udid'] is String)
            device['udid'] as String,
  ];
}

Future<LiveRecorder> _findAndroid(
  LiveApp app,
  String projectRoot,
  LiveProcesses processes,
) async {
  final Map<String, String> env = processes.environment;
  final String? home = env['HOME'] ?? env['USERPROFILE'];
  final String? adb = processes.find(
    'adb',
    extraDirectories: [
      for (final String? sdk in [
        env['ANDROID_HOME'],
        env['ANDROID_SDK_ROOT'],
        if (home != null) '$home/Library/Android/sdk',
        if (home != null) '$home/Android/Sdk',
        if (env['LOCALAPPDATA'] != null) '${env['LOCALAPPDATA']}/Android/Sdk',
      ])
        if (sdk != null && sdk.isNotEmpty) '$sdk/platform-tools',
    ],
  );
  if (adb == null) {
    throw LiveCommandException(
      'Recording Android needs adb. Install the Android SDK platform-tools, '
      'or add adb to your PATH.',
    );
  }

  final String serial = await _androidSerial(app, adb, projectRoot, processes);
  final String? scrcpy = processes.find('scrcpy');
  if (scrcpy != null) {
    return ScrcpyRecorder(processes, scrcpy: scrcpy, adb: adb, serial: serial);
  }
  return AdbRecorder(processes, adb: adb, serial: serial);
}

Future<String> _androidSerial(
  LiveApp app,
  String adb,
  String projectRoot,
  LiveProcesses processes,
) async {
  final String? chosen = processes.environment['ANDROID_SERIAL'];
  if (chosen != null && chosen.isNotEmpty) return chosen;

  final ProcessResult listed = await processes.run(adb, ['devices']);
  final List<String> serials = adbSerials('${listed.stdout}');
  if (serials.length == 1) return serials.single;
  if (serials.isEmpty) {
    throw LiveCommandException(
      'adb doesn\'t list any Android devices, so there\'s nothing to record.',
    );
  }

  final String? applicationId = readAndroidApplicationId(projectRoot);
  if (applicationId != null) {
    final List<String> running = [];
    for (final String serial in serials) {
      final ProcessResult pid = await processes.run(adb, [
        '-s',
        serial,
        'shell',
        'pidof',
        applicationId,
      ]);
      if (pid.exitCode == 0 && '${pid.stdout}'.trim().isNotEmpty) {
        running.add(serial);
      }
    }
    if (running.length == 1) return running.single;
  }
  throw LiveCommandException(
    'Couldn\'t tell which Android device ${app.device} is '
    '(${serials.join(', ')}). Set ANDROID_SERIAL to the one to record.',
  );
}

/// The serials of the devices `adb devices` lists as ready.
List<String> adbSerials(String output) => [
  for (final String line in const LineSplitter().convert(output))
    if (RegExp(r'^(\S+)\s+device$').firstMatch(line.trim()) case final match?)
      match.group(1)!,
];

/// The `applicationId` in the project's `android/app/build.gradle(.kts)`, or
/// null when there isn't one.
String? readAndroidApplicationId(String projectRoot) {
  for (final String name in ['build.gradle.kts', 'build.gradle']) {
    final File file = File('$projectRoot/android/app/$name');
    if (!file.existsSync()) continue;
    final RegExpMatch? match = RegExp(
      r'''applicationId\s*=?\s*["']([^"']+)["']''',
    ).firstMatch(file.readAsStringSync());
    if (match != null) return match.group(1);
  }
  return null;
}

/// A step caption in a recording.
class LiveCue {
  /// Creates a [LiveCue] showing [text] from [start] to [end].
  const LiveCue(this.start, this.end, this.text);

  /// When the caption appears, from the start of the recording.
  final Duration start;

  /// When it goes.
  final Duration end;

  /// The step's title.
  final String text;
}

/// What a finished recording saved.
class LiveRecordingSaved {
  /// Creates a [LiveRecordingSaved].
  const LiveRecordingSaved({
    required this.file,
    required this.length,
    this.captions,
    this.cues = 0,
    this.limit,
  });

  /// The video.
  final String file;

  /// The `.vtt` captions beside it, if any.
  final String? captions;

  /// How long the recording is.
  final Duration length;

  /// How many step captions it has.
  final int cues;

  /// The recorder's time limit, when the recording reached it.
  final Duration? limit;
}

/// One playbook run being recorded: starts the [recorder], timestamps the
/// run's events, and saves the video with ffmpeg.
class LiveRecording {
  /// Creates a [LiveRecording] saved to [output] (`.mp4` or `.gif`).
  ///
  /// With [captions], an `.mp4` gets a `.vtt` file beside it and a chapter
  /// for each step.
  LiveRecording({
    required this.recorder,
    required this.ffmpeg,
    required this.output,
    this.captions = true,
  });

  /// Records the screen.
  final LiveRecorder recorder;

  /// The path of `ffmpeg`.
  final String ffmpeg;

  /// Where the video is saved.
  final String output;

  /// Whether to save step captions and chapters.
  final bool captions;

  final Stopwatch _clock = Stopwatch();
  final List<({Duration at, String title})> _steps = [];
  Duration? _done;
  Directory? _temp;
  bool _recording = false;

  /// Whether the recorder is running.
  bool get isRecording => _recording;

  /// How long it has been recording.
  Duration get elapsed => _clock.elapsed;

  String get _raw => '${_temp!.path}/raw${recorder.extension}';

  /// Starts recording, and completes once the first frame is captured.
  Future<void> start() async {
    _temp = await Directory.systemTemp.createTemp('nylo_playbook_');
    try {
      await recorder.start(_raw);
    } catch (_) {
      await _cleanUp();
      rethrow;
    }
    _clock.start();
    _recording = true;
  }

  /// Notes a `nylo.playbook` [event] that arrived [at] into the recording.
  void mark(Map<String, Object?> event, Duration at) {
    switch (event['event']) {
      case 'begin' when event['group'] != true:
        _steps.add((at: at, title: '${event['title'] ?? ''}'));
      case 'done':
        _done = at;
    }
  }

  /// The step captions so far, each lasting until the next step begins.
  List<LiveCue> cues([Duration? length]) {
    final Duration last = _done ?? length ?? elapsed;
    return [
      for (int i = 0; i < _steps.length; i++)
        if (_steps[i].title.isNotEmpty)
          LiveCue(
            _steps[i].at,
            _cueEnd(
              _steps[i].at,
              i + 1 < _steps.length ? _steps[i + 1].at : last,
            ),
            _steps[i].title,
          ),
    ];
  }

  static Duration _cueEnd(Duration start, Duration end) =>
      end > start ? end : start + const Duration(milliseconds: 500);

  /// Stops recording and saves the video, converting it with ffmpeg.
  ///
  /// When ffmpeg fails, the original is kept beside [output] and a
  /// [LiveCommandException] says where.
  Future<LiveRecordingSaved> finish() async {
    if (!_recording) throw StateError('The recording isn\'t running.');
    _recording = false;
    final Duration length = _clock.elapsed;
    _clock.stop();
    try {
      await recorder.stop();
      final bool mp4 = output.toLowerCase().endsWith('.mp4');
      final List<LiveCue> steps = cues(length);
      final bool chapters = mp4 && captions && steps.isNotEmpty;
      final String metadata = '${_temp!.path}/chapters.txt';
      if (chapters) {
        File(metadata).writeAsStringSync(liveChapters(steps, length));
      }

      Directory(File(output).parent.path).createSync(recursive: true);
      final ProcessResult encoded = await recorder.processes.run(
        ffmpeg,
        mp4
            ? liveMp4Arguments(
                _raw,
                output,
                length: length,
                chapters: chapters ? metadata : null,
              )
            : liveGifArguments(_raw, output, length: length),
      );
      if (encoded.exitCode != 0) {
        final String kept = _withExtension(output, recorder.extension);
        File(_raw).copySync(kept);
        final String reason = '${encoded.stderr}'.trim().split('\n').last;
        throw LiveCommandException(
          'ffmpeg couldn\'t convert the recording'
          '${reason.isEmpty ? '' : ' ($reason)'}. The original is at $kept',
        );
      }

      String? vtt;
      if (chapters) {
        vtt = _withExtension(output, '.vtt');
        File(vtt).writeAsStringSync(liveWebVtt(steps));
      }
      final Duration? limit = recorder.limit;
      return LiveRecordingSaved(
        file: output,
        captions: vtt,
        length: length,
        cues: chapters ? steps.length : 0,
        limit: limit != null && length >= limit ? limit : null,
      );
    } finally {
      await _cleanUp();
    }
  }

  Future<void> _cleanUp() async {
    final Directory? temp = _temp;
    _temp = null;
    try {
      await temp?.delete(recursive: true);
    } catch (_) {
      // A temp folder left behind is harmless.
    }
  }
}

String _withExtension(String path, String extension) {
  final int dot = path.lastIndexOf('.');
  final int slash = path.lastIndexOf(Platform.pathSeparator);
  return '${dot > slash ? path.substring(0, dot) : path}$extension';
}

/// The ffmpeg arguments that turn the recorder's [input] into an `.mp4` at
/// [output]: H.264 at a steady 60 fps, which editors and browsers play, with
/// the [chapters] metadata file when there is one.
///
/// The video lasts exactly [length], the time Metro recorded for. The iOS
/// Simulator only writes a frame when the screen changes, and can give its
/// last frame any length, so the last frame is held and then cut there.
List<String> liveMp4Arguments(
  String input,
  String output, {
  required Duration length,
  String? chapters,
}) => [
  '-y',
  '-v',
  'error',
  '-i',
  input,
  if (chapters != null) ...['-i', chapters],
  '-map',
  '0:v:0',
  '-map',
  '0:a?',
  if (chapters != null) ...['-map_metadata', '1', '-map_chapters', '1'],
  '-vf',
  '${_holdLastFrame(length)},fps=60,scale=trunc(iw/2)*2:trunc(ih/2)*2',
  '-c:v',
  'libx264',
  '-preset',
  'veryfast',
  '-crf',
  '20',
  '-pix_fmt',
  'yuv420p',
  '-c:a',
  'aac',
  '-movflags',
  '+faststart',
  '-t',
  _seconds(length),
  output,
];

/// The ffmpeg arguments that turn the recorder's [input] into a GIF at
/// [output], 480 pixels wide at 15 fps, lasting exactly [length].
List<String> liveGifArguments(
  String input,
  String output, {
  required Duration length,
}) => [
  '-y',
  '-v',
  'error',
  '-i',
  input,
  '-vf',
  '${_holdLastFrame(length)},fps=15,scale=480:-1:flags=lanczos,'
      'split[a][b];[a]palettegen[p];'
      '[b][p]paletteuse',
  '-t',
  _seconds(length),
  output,
];

String _holdLastFrame(Duration length) =>
    'tpad=stop_mode=clone:stop_duration=${_seconds(length)}';

String _seconds(Duration duration) =>
    (duration.inMilliseconds / 1000).toStringAsFixed(3);

/// The [cues] as a WebVTT captions file.
String liveWebVtt(List<LiveCue> cues) {
  final StringBuffer vtt = StringBuffer('WEBVTT\n');
  for (int i = 0; i < cues.length; i++) {
    final LiveCue cue = cues[i];
    final String text = cue.text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\n', ' ');
    vtt
      ..write('\n${i + 1}\n')
      ..write('${_timestamp(cue.start)} --> ${_timestamp(cue.end)}\n')
      ..write('$text\n');
  }
  return vtt.toString();
}

/// The [cues] as an ffmpeg metadata file of chapters, the last one running
/// to [length].
String liveChapters(List<LiveCue> cues, Duration length) {
  final StringBuffer metadata = StringBuffer(';FFMETADATA1\n');
  for (int i = 0; i < cues.length; i++) {
    final LiveCue cue = cues[i];
    final Duration end = i + 1 < cues.length
        ? cues[i + 1].start
        : (length > cue.end ? length : cue.end);
    final String title = cue.text
        .replaceAllMapped(RegExp(r'[=;#\\]'), (Match m) => '\\${m[0]}')
        .replaceAll('\n', ' ');
    metadata
      ..write('\n[CHAPTER]\nTIMEBASE=1/1000\n')
      ..write('START=${cue.start.inMilliseconds}\n')
      ..write('END=${end.inMilliseconds}\n')
      ..write('title=$title\n');
  }
  return metadata.toString();
}

String _timestamp(Duration time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final int ms = time.inMilliseconds;
  return '${two(ms ~/ 3600000)}:${two(ms ~/ 60000 % 60)}:'
      '${two(ms ~/ 1000 % 60)}.${(ms % 1000).toString().padLeft(3, '0')}';
}

/// Where a recording of [names] on [device] is saved.
///
/// By default that's `build/playbooks/<names>-<device>-<time>.mp4` in
/// [root]. [requested] is the file from `--record=<file>`, relative to
/// [root]; when [several] apps are recorded, each gets its device name added.
/// [deviceId] is added after the device name when another app being recorded
/// has the same one, so their files can't collide.
String liveRecordingPath({
  required String root,
  required List<String> names,
  required String device,
  required DateTime at,
  String? requested,
  String? deviceId,
  bool several = false,
}) {
  final String id = (deviceId ?? '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toLowerCase();
  final String slug = [
    _slug(device),
    if (id.isNotEmpty) id.substring(0, min(4, id.length)),
  ].where((String part) => part.isNotEmpty).join('-');

  if (requested != null) {
    final String path = File(requested).isAbsolute
        ? requested
        : '$root${Platform.pathSeparator}$requested';
    if (!several) return path;
    final int dot = path.lastIndexOf('.');
    return '${path.substring(0, dot)}-$slug${path.substring(dot)}';
  }

  String two(int n) => n.toString().padLeft(2, '0');
  final String stamp =
      '${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}';
  final String playbooks = names
      .map((String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '-'))
      .join('+');
  final String separator = Platform.pathSeparator;
  return '$root${separator}build${separator}playbooks$separator'
      '$playbooks-$slug-$stamp.mp4';
}

String _slug(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
