import 'dart:io';

import '/metro/live/live_registry.dart';
import '/metro/ny_cli.dart';
import '/metro/playbook_routes.dart';
import '/metro/stubs/playbook_stub.dart';

import 'package:recase/recase.dart';

/// Where new playbooks are created.
const String playbooksFolder = 'lib/app/playbooks';

/// Entry point for the make:playbook command.
Future<void> main(List<String> arguments) async =>
    await _MakePlaybookCommand(arguments).run();

/// Make Playbook Command
///
/// Usage:
///   [From Terminal] metro make:playbook sign_up_to_dashboard
///   [From Terminal] metro make:playbook tour --from-routes
class _MakePlaybookCommand extends NyCustomCommand {
  _MakePlaybookCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag(
      "help",
      abbr: "h",
      help: "e.g. make:playbook sign_up_to_dashboard",
    );
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new playbook file even if it already exists.",
    );
    command.addOption(
      "description",
      help: "A one-line description, shown when Metro lists playbooks.",
    );
    command.addFlag(
      "from-routes",
      help: "Visit every page in $routerPath and take a screenshot of each.",
    );
    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final String playbookName = requireArgument(
      result,
      message: 'A playbook name is required, e.g. metro make:playbook sign_up_to_dashboard',
    );

    final MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      playbookName,
      prefix: RegExp(r'_?playbook$', caseSensitive: false),
    );
    final ReCase playbook = ReCase(
      projectFile.name.snakeCase.replaceAll(RegExp(r'_?playbook$'), ''),
    );
    final String? creationPath = projectFile.creationPath;

    final bool fromRoutes = result.getBool("from-routes") ?? false;
    final List<PlaybookRoute> routes = fromRoutes
        ? readPlaybookRoutes()
        : const [];
    if (fromRoutes && routes.isEmpty) {
      info(
        '[Playbook] Metro reads pages from the router.add(SomePage.path) '
        'lines in $routerPath. There were none to read, so this is the '
        'starter playbook: add a visit() for each page.',
      );
    }

    await makePlaybookFile(
      playbook.snakeCase,
      playbookStub(
        playbook: playbook,
        description: result.getString("description"),
        routes: routes,
      ),
      forceCreate: result.hasForceFlag,
      creationPath: creationPath,
    );

    final String className = '${playbook.pascalCase}Playbook';
    final LiveRegistration registration = await registerPlaybook(
      name: playbook.snakeCase,
      className: className,
      importPath:
          'app/playbooks/${creationPath != null ? '$creationPath/' : ''}${playbook.snakeCase}_playbook.dart',
    );
    if (registration == LiveRegistration.mapNotFound) {
      warning(
        '[Playbook] Couldn\'t find the playbooks map in $playbooksRegistryPath. Add this entry to it:\n'
        "  '${playbook.snakeCase}': $className.new,",
      );
    }

    final String providerPath = '$providerFolder/app_provider.dart';
    switch (await wirePlaybooks(File(providerPath))) {
      case LiveWiring.added:
        info('[Playbook] $providerPath now passes playbooks to Nylo');
      case LiveWiring.alreadyWired:
        break;
      case LiveWiring.configureNotFound:
      case LiveWiring.providerMissing:
        warning(
          '[Playbook] One more step: pass your playbooks to Nylo in $providerPath\n'
          '  $playbooksImport\n'
          '  await nylo.configure(..., playbooks: playbooks);\n'
          '  // or: nylo.addPlaybooks(playbooks);',
        );
    }

    success(
      '[Playbook] Play it while your app is running: metro live:run playbook ${playbook.snakeCase}',
    );
    final int guarded = routes
        .where(
          (PlaybookRoute route) => route.guarded || route.parameters.isNotEmpty,
        )
        .length;
    if (guarded > 0) {
      info(
        '[Playbook] ${guarded == 1 ? '1 page has' : '$guarded pages have'} a '
        'comment saying what setUp may need to reach it.',
      );
    }
    info(
      '[Playbook] If your app is already running, hot restart it first: '
      'restart in metro live',
    );
  }
}

/// Creates the playbook [name] (in snake case) holding [contents] in
/// [folderPath], inside [creationPath] when it's given, and returns its path.
///
/// Exits when the file already exists, unless [forceCreate].
Future<String> makePlaybookFile(
  String name,
  String contents, {
  String folderPath = playbooksFolder,
  bool forceCreate = false,
  String? creationPath,
}) async {
  await MetroService.makeDirectory(folderPath);
  await MetroService.createDirectoriesFromCreationPath(
    creationPath,
    folderPath,
  );

  final String filePath = MetroService.createPathForDartFile(
    folderPath: folderPath,
    className: name,
    prefix: "playbook",
    creationPath: creationPath,
  );

  final File file = File(filePath);
  if (file.existsSync() && !forceCreate) {
    MetroConsole.writeInRed('$filePath already exists');
    exit(1);
  }
  await file.writeAsString(contents);

  final String link = MetroConsole.hyperlink('${name}_playbook', filePath);
  MetroConsole.writeInGreen('[Playbook] $link created 🎉');
  return filePath;
}
