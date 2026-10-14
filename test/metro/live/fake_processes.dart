import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nylo_framework/metro/live/live_recorder.dart';

/// A program started through [FakeProcesses], which a test drives.
class FakeProgram {
  FakeProgram({this.onInterrupt});

  /// Runs when the program is interrupted, before it exits.
  final void Function()? onInterrupt;

  final StreamController<List<int>> _out = StreamController<List<int>>();
  final StreamController<List<int>> _err = StreamController<List<int>>();

  /// The signals sent to the program.
  final List<ProcessSignal> signals = [];

  late final LiveProcess process = LiveProcess(
    stdout: _out.stream,
    stderr: _err.stream,
    signal: (ProcessSignal signal) {
      signals.add(signal);
      if (signal == ProcessSignal.sigint) onInterrupt?.call();
      exit();
      return true;
    },
  );

  /// Prints [line] on the program's stderr.
  void say(String line) => _err.add(utf8.encode('$line\n'));

  bool _exited = false;

  /// Ends the program.
  void exit() {
    if (_exited) return;
    _exited = true;
    _out.close();
    _err.close();
  }
}

/// Stands in for the programs a recording runs.
class FakeProcesses extends LiveProcesses {
  FakeProcesses({
    Map<String, String>? installed,
    this.env = const {},
    this.onRun,
    this.onStart,
  }) : installed =
           installed ?? {'ffmpeg': '/bin/ffmpeg', 'xcrun': '/usr/bin/xcrun'};

  /// The installed programs, by name.
  final Map<String, String> installed;

  final Map<String, String> env;

  /// Answers [run]; exits 0 with no output when it returns null.
  final ProcessResult? Function(String executable, List<String> arguments)?
  onRun;

  /// Starts a program for [start].
  final FakeProgram Function(String executable, List<String> arguments)?
  onStart;

  /// Every [run], as the executable followed by its arguments.
  final List<List<String>> ran = [];

  /// Every [start], as the executable followed by its arguments.
  final List<List<String>> started = [];

  /// The programs [start] returned.
  final List<FakeProgram> programs = [];

  @override
  Map<String, String> get environment => env;

  @override
  String? find(String name, {List<String> extraDirectories = const []}) =>
      installed[name];

  @override
  Future<ProcessResult> run(String executable, List<String> arguments) async {
    ran.add([executable, ...arguments]);
    return onRun?.call(executable, arguments) ?? ProcessResult(0, 0, '', '');
  }

  @override
  Future<LiveProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    started.add([executable, ...arguments]);
    final FakeProgram program = onStart!(executable, arguments);
    programs.add(program);
    return program.process;
  }

  @override
  Future<void> delay(Duration duration) async {}
}

/// A [FakeProcesses] with a working simctl recorder and ffmpeg: the
/// recorder writes its file and says it started, and ffmpeg writes the
/// file it's given.
FakeProcesses fakeSimulatorTools({
  ProcessResult? Function(String executable, List<String> arguments)? onRun,
}) => FakeProcesses(
  onStart: (String executable, List<String> arguments) {
    File(arguments.last).writeAsStringSync('raw video');
    return FakeProgram()..say('Recording started');
  },
  onRun: (String executable, List<String> arguments) {
    final ProcessResult? answer = onRun?.call(executable, arguments);
    if (answer != null) return answer;
    if (executable == '/bin/ffmpeg') {
      File(arguments.last).writeAsStringSync('video');
    }
    return null;
  },
);
