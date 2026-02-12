import '/metro/ny_cli.dart';
import '/metro/stubs/navigation_hub_stub.dart';
import '/metro/stubs/navigation_tab_state_journey.dart';
import '/metro/stubs/widget_stateful_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:navigation_hub command.
Future<void> main(List<String> arguments) async =>
    await _MakeNavigationHubCommand(arguments).run();

/// Make Navigation Hub Command
///
/// Usage:
///   [From Terminal] metro make:navigation_hub
/// Prompts for layout (navigation tabs or journey states) and generates
/// hub + child widgets under /resources/pages/navigation_hubs/`<hub>`/.
class _MakeNavigationHubCommand extends NyCustomCommand {
  _MakeNavigationHubCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "e.g. make:navigation_hub nav_base_page");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new navigation hub even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final className =
        requireArgument(result, message: 'A navigation hub name is required');

    String cleanClassName =
        className.snakeCase.replaceAll(RegExp(r'(_?page)'), "");

    ReCase classReCase = ReCase(cleanClassName);

    // Welcome header
    newLine();
    info('Creating Navigation Hub: ${classReCase.pascalCase}NavigationHub');
    newLine();

    // Layout descriptions
    info('Choose a layout type:');
    newLine();
    line('  1. navigation_tabs');
    line(
        '     Bottom navigation with persistent tabs (e.g., Home, Search, Profile)');
    line('     Best for: Main app navigation with 3-5 primary sections');
    newLine();
    line('  2. journey_states');
    line('     Sequential flow navigation (e.g., Onboarding, Checkout steps)');
    line('     Best for: Multi-step wizards or linear user journeys');
    newLine();

    final layoutSelection = select(
        "Select layout:", ["navigation_tabs", "journey_states"],
        defaultOption: "navigation_tabs");
    final isJourney = layoutSelection == "journey_states";

    // Context and examples for tab/state input
    newLine();
    if (isJourney) {
      info('Enter the journey state names for your flow.');
      line('Example: welcome, personal_info, preferences, complete');
      line('These will create sequential states the user progresses through.');
    } else {
      info('Enter the navigation tab names.');
      line('Example: home, search, favorites, profile');
      line('These will appear in your bottom navigation bar.');
    }
    newLine();

    final childrenInput = prompt(
        isJourney
            ? "State names (comma-separated):"
            : "Tab names (comma-separated):",
        defaultValue: "");
    final children = childrenInput
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final hubPath = "navigation_hubs/${classReCase.snakeCase}";
    final childFolder = isJourney ? "states" : "tabs";
    final layoutBuilder = isJourney
        ? "NavigationHubLayout.journey(\n    progressStyle: JourneyProgressStyle(\n      indicator: JourneyProgressIndicator.segments()\n    )\n  )"
        : "NavigationHubLayout.bottomNav()";

    final childImports = <String>[];
    final navigationEntries = <String>[];

    for (int i = 0; i < children.length; i++) {
      final cleanChildName =
          children[i].snakeCase.replaceAll(RegExp(r'(_?widget|_?tab)'), "");
      // For tabs, append "_tab" suffix; for journey states, keep as-is
      final childName = isJourney ? cleanChildName : "${cleanChildName}_tab";
      final childRc = ReCase(childName);
      // Use clean name for display title (without "_tab" suffix)
      final titleRc = ReCase(cleanChildName);
      final importPath =
          "/resources/pages/$hubPath/$childFolder/${childRc.snakeCase}_widget.dart";
      childImports.add("import '$importPath';");

      if (isJourney) {
        navigationEntries.add(
            "      $i: NavigationTab.journey(page: ${childRc.pascalCase}()),");
      } else {
        navigationEntries.add(
            "      $i: NavigationTab.tab(title: \"${titleRc.titleCase}\", page: ${childRc.pascalCase}()),");
      }
    }

    String navigationHub = navigationHubStub(
        rc: classReCase,
        layoutBuilder: layoutBuilder,
        imports: childImports,
        navigationEntries: navigationEntries);

    await MetroService.makeNavigationHub(classReCase.snakeCase, navigationHub,
        forceCreate: result.hasForceFlag,
        creationPath: hubPath,
        folderPath: pagesPath);

    for (final child in children) {
      final cleanChildName =
          child.snakeCase.replaceAll(RegExp(r'(_?widget|_?tab)'), "");
      // For tabs, append "_tab" suffix; for journey states, keep as-is
      final childName = isJourney ? cleanChildName : "${cleanChildName}_tab";
      final childRc = ReCase(childName);
      final childCreationPath = "$hubPath/$childFolder";

      if (isJourney) {
        final isLast = child == children.last;
        final stub = navigationTabJourneyStateStub(childRc,
            parentNavigationHub: classReCase, isLastStep: isLast);
        await MetroService.makeJourneyWidget(childRc.snakeCase, stub,
            forceCreate: result.hasForceFlag,
            creationPath: childCreationPath,
            folderPath: pagesPath);
      } else {
        final stub = widgetStatefulStub(childRc,
            content: 'Center(child: Text("${childRc.titleCase}").bodyLarge())');
        await MetroService.makeStatefulWidget(childRc.snakeCase, stub,
            forceCreate: result.hasForceFlag,
            creationPath: childCreationPath,
            folderPath: pagesPath);
      }
    }
  }
}
