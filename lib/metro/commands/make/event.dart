import '/metro/ny_cli.dart';
import '/metro/stubs/event_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:event command.
Future<void> main(List<String> arguments) async =>
    await _MakeEventCommand(arguments).run();

/// Make Event Command
///
/// Usage:
///   [From Terminal] metro make:event
class _MakeEventCommand extends NyCustomCommand {
  _MakeEventCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help", abbr: "h", help: "e.g. make:event login_event");
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new event even if it already exists.",
    );

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final eventName = requireArgument(
      result,
      message: 'An event name is required',
    );

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      eventName,
      prefix: RegExp(r'(_?event)'),
    );

    String cleanEventName = projectFile.name.snakeCase.replaceAll(
      RegExp(r'(_?event)'),
      "",
    );

    ReCase classReCase = ReCase(cleanEventName);

    String stubEvent = eventStub(eventName: classReCase);
    await MetroService.makeEvent(
      classReCase.snakeCase,
      stubEvent,
      forceCreate: result.hasForceFlag,
      addToConfig: true,
      creationPath: projectFile.creationPath,
    );
  }
}
