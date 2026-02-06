import '/metro/ny_cli.dart';
import '/metro/stubs/widget_stateful_stub.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async =>
    await _MakeStatefulWidgetCommand(arguments).run();

/// Make Stateful Widget Command
///
/// Usage:
///   [From Terminal] metro make:stateful_widget
class _MakeStatefulWidgetCommand extends NyCustomCommand {
  _MakeStatefulWidgetCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "e.g. make:stateful_widget video_player_widget");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new stateful widget even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final firstArgument =
        requireArgument(result, message: 'A widget name is required');

    if (firstArgument.contains(",")) {
      // Handle comma-separated widget names
      List<String> argumentsList = firstArgument.split(",");
      for (var argument in argumentsList) {
        await _createStatefulWidget(argument.trim(), result.hasForceFlag);
      }
    } else {
      await _createStatefulWidget(firstArgument, result.hasForceFlag);
    }
  }

  Future<void> _createStatefulWidget(
      String widgetName, bool hasForceFlag) async {
    String cleanWidgetName =
        widgetName.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");

    ReCase classReCase = ReCase(cleanWidgetName);

    String stubStatefulWidget = widgetStatefulStub(classReCase);
    await MetroService.makeStatefulWidget(
        classReCase.snakeCase, stubStatefulWidget,
        forceCreate: hasForceFlag);
  }
}
