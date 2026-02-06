import '/metro/ny_cli.dart';
import '/metro/stubs/custom_command_stub.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async =>
    await _MakeCommandCommand(arguments).run();

/// Make Command Command
///
/// Usage:
///   [From Terminal] metro make:command
class _MakeCommandCommand extends NyCustomCommand {
  _MakeCommandCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "e.g. make:command OptimizeAssets");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new command file even if it already exists.");
    command.addOption("category",
        abbr: "c", help: "The category for the command.", defaultValue: "app");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final commandName =
        requireArgument(result, message: 'A command name is required');
    final String categoryValue =
        result.getString("category", defaultValue: "app")!;

    String cleanCommandName =
        commandName.snakeCase.replaceAll(RegExp(r'(_?command)'), "");

    ReCase classReCase = ReCase(cleanCommandName);

    String stubCommand =
        customCommandStub(customCommand: classReCase, category: categoryValue);
    await MetroService.makeCommand(classReCase.snakeCase, stubCommand,
        forceCreate: result.hasForceFlag, category: categoryValue);
  }
}
