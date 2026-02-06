import '/metro/ny_cli.dart';
import '/metro/stubs/provider_stub.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async =>
    await _MakeProviderCommand(arguments).run();

/// Make Provider Command
///
/// Usage:
///   [From Terminal] metro make:provider
class _MakeProviderCommand extends NyCustomCommand {
  _MakeProviderCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "e.g. make:provider storage_provider");
    command.addFlag("force",
        abbr: "f", help: "Creates a new provider even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final providerName = requireArgument(result, message: 'A provider name is required');

    String cleanProviderName =
        providerName.snakeCase.replaceAll(RegExp(r'(_?provider)'), "");

    ReCase classReCase = ReCase(cleanProviderName);

    String stubProvider = providerStub(classReCase);
    await MetroService.makeProvider(classReCase.snakeCase, stubProvider,
        forceCreate: result.hasForceFlag, addToConfig: true);
  }
}
