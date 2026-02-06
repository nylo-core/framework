import '/metro/ny_cli.dart';
import '/metro/stubs/page_stub.dart';
import '/metro/stubs/page_w_controller_stub.dart';
import '/metro/stubs/controller_stub.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async => await _MakePageCommand(arguments).run();

/// Make Page Command
///
/// Usage:
///   [From Terminal] metro make:page
class _MakePageCommand extends NyCustomCommand {
  _MakePageCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: "Creates a new page widget for your project.");
    command.addFlag("controller",
        abbr: "c", help: "Creates a new page with a controller.");
    command.addFlag("auth",
        abbr: "a", help: "Creates a new page that will be the auth page.");
    command.addFlag("initial",
        abbr: "i", help: "Creates a new page that will be the initial page.");
    command.addFlag("force",
        abbr: "f", help: "Creates a new page even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final firstArg = requireArgument(result,
        message: 'You cannot create a page with an empty name');
    final bool shouldCreateController = result.getBool("controller") ?? false;
    final bool initialPage = result.getBool("initial") ?? false;
    final bool authPage = result.getBool("auth") ?? false;

    if (firstArg.contains(",")) {
      // Handle comma-separated page names
      List<String> pages = firstArg.split(",");
      for (var page in pages) {
        await _createPage(
          page.trim(),
          shouldCreateController: shouldCreateController,
          initialPage: initialPage,
          authPage: authPage,
          hasForceFlag: result.hasForceFlag,
        );
      }
    } else {
      await _createPage(
        firstArg,
        shouldCreateController: shouldCreateController,
        initialPage: initialPage,
        authPage: authPage,
        hasForceFlag: result.hasForceFlag,
      );
    }
  }

  Future<void> _createPage(
    String pageName, {
    required bool shouldCreateController,
    required bool initialPage,
    required bool authPage,
    required bool hasForceFlag,
  }) async {
    // Strip 'page' suffix if user included it (e.g., "HomePage" -> "Home")
    pageName = pageName.replaceAll(RegExp(r'page$', caseSensitive: false), '');

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(pageName,
        prefix: RegExp(r'(_?page)'));

    if (shouldCreateController) {
      String stubPageAndController = pageWithControllerStub(
          className:
              projectFile.name.snakeCase.replaceAll(RegExp(r'(_?page)'), ""),
          creationPath: projectFile.creationPath);
      await MetroService.makePage(
        projectFile.name.snakeCase.replaceAll(RegExp(r'(_?page)'), ""),
        stubPageAndController,
        forceCreate: hasForceFlag,
        addToRoute: true,
        isInitialPage: initialPage,
        isAuthPage: authPage,
        creationPath: projectFile.creationPath,
      );

      String stubController = controllerStub(
          controllerName: projectFile.name.snakeCase
              .replaceAll(RegExp(r'(_?controller)'), ""));
      await MetroService.makeController(
        projectFile.name.snakeCase.replaceAll(RegExp(r'(_?controller)'), ""),
        stubController,
        forceCreate: hasForceFlag,
        creationPath: projectFile.creationPath,
      );
    } else {
      String stubPage = pageStub(
          className:
              projectFile.name.snakeCase.replaceAll(RegExp(r'(_?page)'), ""));
      await MetroService.makePage(
        projectFile.name.snakeCase.replaceAll(RegExp(r'(_?page)'), ""),
        stubPage,
        forceCreate: hasForceFlag,
        addToRoute: true,
        isInitialPage: initialPage,
        isAuthPage: authPage,
        creationPath: projectFile.creationPath,
      );
    }
  }
}
