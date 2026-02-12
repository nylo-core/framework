import '/metro/ny_cli.dart';
import '/metro/stubs/interceptor_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:interceptor command.
Future<void> main(List<String> arguments) async =>
    await _MakeInterceptorCommand(arguments).run();

/// Make Interceptor Command
///
/// Usage:
///   [From Terminal] metro make:interceptor
class _MakeInterceptorCommand extends NyCustomCommand {
  _MakeInterceptorCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "e.g. make:interceptor auth_token");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new Interceptor even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final interceptorName =
        requireArgument(result, message: 'An interceptor name is required');

    String cleanInterceptorName =
        interceptorName.snakeCase.replaceAll(RegExp(r'(_?interceptor)'), "");

    ReCase classReCase = ReCase(cleanInterceptorName);

    String stubInterceptor = interceptorStub(interceptorName: classReCase);
    await MetroService.makeInterceptor(classReCase.snakeCase, stubInterceptor,
        forceCreate: result.hasForceFlag);
  }
}
