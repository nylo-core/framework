import 'dart:io';

import '/metro/doctor.dart';
import '/metro/ny_cli.dart';

/// Entry point for the doctor command.
Future<void> main(List<String> arguments) async =>
    await _DoctorCommand(arguments).run();

/// Doctor Command
///
/// Lists everything that's wired wrong in the project, with file paths, and
/// exits non-zero when something is, so it can run in CI.
///
/// Usage:
///   [From Terminal] metro doctor
///   [Fail on notes] metro doctor --strict
class _DoctorCommand extends NyCustomCommand {
  _DoctorCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag(
      "help",
      abbr: "h",
      help: "Lists everything that's wired wrong in your project",
    );
    command.addFlag(
      "strict",
      help: "Also exit non-zero for notes, such as images nothing refers to.",
    );
    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    if (!File('pubspec.yaml').existsSync()) {
      error('Run metro doctor from the root of your Flutter project.');
      exit(64);
    }

    final List<DoctorCheck> checks = runDoctor();
    stdout.write(formatDoctorReport(checks, ansi: stdout.supportsAnsiEscapes));

    final int code = doctorExitCode(
      checks,
      strict: result.getBool("strict") ?? false,
    );
    if (code != 0) exit(code);
  }
}
