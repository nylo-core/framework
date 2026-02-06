import '/metro/ny_cli.dart';
import '/metro/stubs/widget_stateless_stub.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async =>
    await _MakeStatelessWidgetCommand(arguments).run();

/// Make Stateless Widget Command
///
/// Usage:
///   [From Terminal] metro make:stateless_widget
class _MakeStatelessWidgetCommand extends NyCustomCommand {
  _MakeStatelessWidgetCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "e.g. make:stateless_widget video_player_widget");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new stateless widget even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final firstArgument = requireArgument(result, message: 'A widget name is required');

    if (firstArgument.contains(",")) {
      // Handle comma-separated widget names
      List<String> argumentsList = firstArgument.split(",");
      for (var argument in argumentsList) {
        await _createStatelessWidget(argument.trim(), result.hasForceFlag);
      }
    } else {
      await _createStatelessWidget(firstArgument, result.hasForceFlag);
    }
  }

  Future<void> _createStatelessWidget(
      String widgetName, bool hasForceFlag) async {
    String cleanWidgetName =
        widgetName.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");

    ReCase classReCase = ReCase(cleanWidgetName);

    String stubStatelessWidget = widgetStatelessStub(classReCase);
    await MetroService.makeStatelessWidget(
        classReCase.snakeCase, stubStatelessWidget,
        forceCreate: hasForceFlag);
  }
}
