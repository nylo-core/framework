import '/metro/ny_cli.dart';
import '/metro/stubs/api_service_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:api_service command.
Future<void> main(List<String> arguments) async =>
    await _MakeApiServiceCommand(arguments).run();

/// Make API Service Command
///
/// Usage:
///   [From Terminal] metro make:api_service
class _MakeApiServiceCommand extends NyCustomCommand {
  _MakeApiServiceCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag(
      "help",
      abbr: "h",
      help: "e.g. make:api_service profile_api_service",
    );
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new API service even if it already exists.",
    );
    command.addOption(
      "model",
      abbr: "m",
      help: "The model to use for the API service.",
    );
    command.addOption(
      "url",
      abbr: "u",
      help: "The base URL for the API service.",
    );

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final apiServiceName = requireArgument(
      result,
      message: 'API service name is required',
    );

    ReCase classReCase = ReCase(cleanApiServiceName(apiServiceName));

    // Get model option or default to 'Model'
    String modelName = result.getString("model") ?? "Model";
    ReCase modelReCase = ReCase(modelName);

    // Get base URL option or default to getEnv
    String? userUrl = result.getString("url");
    String baseUrl = userUrl != null ? '"$userUrl"' : "getEnv('API_BASE_URL')";

    String stubApiService = apiServiceStub(
      classReCase,
      model: modelReCase,
      baseUrl: baseUrl,
    );

    await scaffold(
      path: '$networkingPath/${classReCase.snakeCase}_api_service.dart',
      content: stubApiService,
      force: result.hasForceFlag,
    );

    await dartFormat(
      '$networkingPath/${classReCase.snakeCase}_api_service.dart',
    );

    info('Add the API service to your bootstrap/decoders.dart file');
  }
}

/// Strips a trailing API service suffix from [rawName] and returns the resource
/// name in snake_case.
///
/// The suffix is matched case-insensitively so acronym spellings such as
/// `APIService` (which `snakeCase` would split into `a_p_i_service`) are handled
/// correctly and don't leave the class name doubled (e.g. `APIServiceApiService`).
/// When the input is nothing but the suffix (e.g. `APIService`), it falls back
/// to `api` so a non-empty name is always produced.
String cleanApiServiceName(String rawName) {
  String stripped = rawName.replaceFirst(
    RegExp(r'[-_ ]?api[-_ ]?service$', caseSensitive: false),
    "",
  );
  if (stripped.trim().isEmpty) {
    return "api";
  }
  return ReCase(stripped).snakeCase;
}
