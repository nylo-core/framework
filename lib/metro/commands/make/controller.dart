import '/metro/ny_cli.dart';
import '/metro/stubs/controller_stub.dart';

/// Entry point for the make:controller command.
Future<void> main(List<String> arguments) async =>
    await _MakeControllerCommand(arguments).run();

/// Make Controller Command
///
/// Usage:
///   [From Terminal] metro make:controller
class _MakeControllerCommand extends NyCustomCommand {
  _MakeControllerCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "Used to make new controllers e.g. home_controller");
    command.addFlag("force",
        abbr: "f", help: "Creates a new controller even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    String controllerName =
        requireArgument(result, message: 'A controller name is required');

    // Remove Controller suffix if present (case-insensitive) to avoid duplication
    controllerName = controllerName.replaceAll(
        RegExp(r'controller$', caseSensitive: false), '');

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
        controllerName,
        prefix: RegExp(r'(_?controller)'));

    String stubController = controllerStub(
        controllerName:
            projectFile.name.replaceAll(RegExp(r'(_?controller)'), ""));

    await MetroService.makeController(projectFile.name, stubController,
        forceCreate: result.hasForceFlag);
  }
}
