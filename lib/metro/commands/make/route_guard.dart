import '/metro/ny_cli.dart';
import '/metro/stubs/route_guard_stub.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async =>
    await _MakeRouteGuardCommand(arguments).run();

/// Make Route Guard Command
///
/// Usage:
///   [From Terminal] metro make:route_guard
class _MakeRouteGuardCommand extends NyCustomCommand {
  _MakeRouteGuardCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "e.g. make:route_guard subscription_route_guard");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new route guard even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final routeGuardName = requireArgument(result, message: 'A route guard name is required');

    String cleanRouteGuardName =
        routeGuardName.snakeCase.replaceAll(RegExp(r'(_?route_guard)'), "");

    ReCase classReCase = ReCase(cleanRouteGuardName);

    String stubRouteGuard = routeGuardStub(classReCase);
    await MetroService.makeRouteGuard(classReCase.snakeCase, stubRouteGuard,
        forceCreate: result.hasForceFlag);
  }
}
