import 'dart:io';

import '/metro/ny_cli.dart';
import '/metro/stubs/navigation_tab_state_journey.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async =>
    await _MakeJourneyWidgetCommand(arguments).run();

/// Make Journey Widget Command
///
/// Usage:
///   [From Terminal] metro make:journey_widget welcome_tab --parent=Onboarding
/// Generates journey widgets inside /resources/pages/navigation_hubs/<parent_snake>/states.
class _MakeJourneyWidgetCommand extends NyCustomCommand {
  _MakeJourneyWidgetCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h",
        help: "e.g. make:journey_widget welcome_tab,users_dob,users_info");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new journey widget even if it already exists.");
    command.addOption("parent",
        abbr: "p", help: "The parent navigation hub for the journey widget.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final firstArgument = requireArgument(result, message: 'A journey widget name is required');
    final String parentNavigationHub = result.getString("parent") ?? "";

    if ((parentNavigationHub).isEmpty) {
      MetroConsole.writeInRed(
          "You must provide a parent navigation hub for the journey widget.\ne.g. make:journey_widget welcome_tab --parent=Onboarding");
      exit(1);
    }

    ReCase parentReCase = ReCase(parentNavigationHub);
    // Remove NavigationHub if it exists
    if (parentReCase.snakeCase.contains("navigation_hub")) {
      parentReCase = ReCase(
          parentReCase.snakeCase.replaceAll(RegExp(r'(_?navigation_hub)'), ""));
    }

    if (firstArgument.contains(",")) {
      // Handle comma-separated widget names
      List<String> argumentsList = firstArgument.split(",");
      for (var argument in argumentsList) {
        await _createJourneyWidget(
            argument.trim(), parentReCase, result.hasForceFlag);
      }
    } else {
      await _createJourneyWidget(
          firstArgument, parentReCase, result.hasForceFlag);
    }
  }

  Future<void> _createJourneyWidget(
      String widgetName, ReCase parentReCase, bool hasForceFlag) async {
    String cleanWidgetName =
        widgetName.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");

    ReCase classReCase = ReCase(cleanWidgetName);
    final creationPath = "navigation_hubs/${parentReCase.snakeCase}/states";

    String stubStatefulWidget = navigationTabJourneyStateStub(classReCase,
        parentNavigationHub: parentReCase);
    await MetroService.makeJourneyWidget(
        classReCase.snakeCase, stubStatefulWidget,
        forceCreate: hasForceFlag,
        creationPath: creationPath,
        folderPath: pagesPath);
  }
}
