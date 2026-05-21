import '/metro/ny_cli.dart';
import '/metro/stubs/deep_link_provider_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:deep_link_provider command.
Future<void> main(List<String> arguments) async =>
    await _MakeDeepLinkProviderCommand(arguments).run();

/// Make Deep Link Provider Command
///
/// Usage:
///   [From Terminal] metro make:deep_link_provider
///   [From Terminal] metro make:deep_link_provider my_deep_link
class _MakeDeepLinkProviderCommand extends NyCustomCommand {
  _MakeDeepLinkProviderCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help", abbr: "h", help: "e.g. make:deep_link_provider");
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new deep link provider even if it already exists.",
    );

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    // Default to "deep_link" so `metro make:deep_link_provider` with no args
    // produces lib/app/providers/deep_link_provider.dart -> DeepLinkProvider.
    final String providerName = result.rest.isNotEmpty
        ? result.rest.first
        : 'deep_link';

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      providerName,
      prefix: RegExp(r'(_?provider)'),
    );

    String cleanProviderName = projectFile.name.snakeCase.replaceAll(
      RegExp(r'(_?provider)'),
      "",
    );

    ReCase classReCase = ReCase(cleanProviderName);

    String stub = deepLinkProviderStub(classReCase);
    await MetroService.makeProvider(
      classReCase.snakeCase,
      stub,
      forceCreate: result.hasForceFlag,
      addToConfig: true,
      creationPath: projectFile.creationPath,
    );
  }
}
