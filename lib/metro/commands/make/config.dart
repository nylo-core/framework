import '/metro/ny_cli.dart';
import '/metro/stubs/config_stub.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async => await _MakeConfigCommand(arguments).run();

/// Make Config Command
///
/// Usage:
///   [From Terminal] metro make:config
class _MakeConfigCommand extends NyCustomCommand {
  _MakeConfigCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help", abbr: "h", help: "e.g. make:config currencies");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new config file even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final configName = requireArgument(result, message: 'A config name is required');

    String cleanConfigName =
        configName.snakeCase.replaceAll(RegExp(r'(_?config)'), "");

    ReCase classReCase = ReCase(cleanConfigName);

    String stubConfig = configStub(classReCase);
    await MetroService.makeConfig(classReCase.snakeCase, stubConfig,
        forceCreate: result.hasForceFlag);
  }
}
