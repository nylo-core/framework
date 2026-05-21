import '/metro/ny_cli.dart';
import '/metro/stubs/widget_state_managed_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:state_managed_widget command.
Future<void> main(List<String> arguments) async =>
    await _MakeStateManagedWidgetCommand(arguments).run();

/// Make State Managed Widget Command
///
/// Usage:
///   [From Terminal] metro make:state_managed_widget
class _MakeStateManagedWidgetCommand extends NyCustomCommand {
  _MakeStateManagedWidgetCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag(
      "help",
      abbr: "h",
      help: "e.g. make:state_managed_widget cart_icon",
    );
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new state_managed widget even if it already exists.",
    );

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final widgetName = requireArgument(
      result,
      message: 'A widget name is required',
    );

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      widgetName,
      prefix: RegExp(r'(_?widget)'),
    );

    String cleanWidgetName = projectFile.name.snakeCase.replaceAll(
      RegExp(r'(_?widget)'),
      "",
    );

    ReCase classReCase = ReCase(cleanWidgetName);

    String stubStatefulWidget = widgetStateManagedStub(classReCase);
    await MetroService.makeStateManagedWidget(
      classReCase.snakeCase,
      stubStatefulWidget,
      forceCreate: result.hasForceFlag,
      creationPath: projectFile.creationPath,
    );
  }
}
