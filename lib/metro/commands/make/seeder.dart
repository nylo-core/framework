import 'dart:io';

import '/metro/live/live_registry.dart';
import '/metro/ny_cli.dart';
import '/metro/stubs/seeder_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:seeder command.
Future<void> main(List<String> arguments) async =>
    await _MakeSeederCommand(arguments).run();

/// Make Seeder Command
///
/// Usage:
///   [From Terminal] metro make:seeder demo_user
class _MakeSeederCommand extends NyCustomCommand {
  _MakeSeederCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help", abbr: "h", help: "e.g. make:seeder demo_user");
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new seeder file even if it already exists.",
    );
    command.addOption(
      "description",
      help: "A one-line description, shown when metro live lists seeders.",
    );
    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final String seederName = requireArgument(
      result,
      message: 'A seeder name is required, e.g. metro make:seeder demo_user',
    );

    final MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      seederName,
      prefix: RegExp(r'_?seeder$', caseSensitive: false),
    );
    final ReCase seeder = ReCase(
      projectFile.name.snakeCase.replaceAll(RegExp(r'_?seeder$'), ''),
    );
    final String? creationPath = projectFile.creationPath;

    await MetroService.makeSeeder(
      seeder.snakeCase,
      seederStub(seeder: seeder, description: result.getString("description")),
      forceCreate: result.hasForceFlag,
      creationPath: creationPath,
    );

    final String className = '${seeder.pascalCase}Seeder';
    final LiveRegistration registration = await registerSeeder(
      name: seeder.snakeCase,
      className: className,
      importPath:
          'app/seeders/${creationPath != null ? '$creationPath/' : ''}${seeder.snakeCase}_seeder.dart',
    );
    if (registration == LiveRegistration.mapNotFound) {
      warning(
        '[Seeder] Couldn\'t find the seeders map in $seedersRegistryPath. Add this entry to it:\n'
        "  '${seeder.snakeCase}': $className.new,",
      );
    }

    final String providerPath = '$providerFolder/app_provider.dart';
    switch (await wireSeeders(File(providerPath))) {
      case LiveWiring.added:
        info('[Seeder] $providerPath now passes seeders to Nylo');
      case LiveWiring.alreadyWired:
        break;
      case LiveWiring.configureNotFound:
      case LiveWiring.providerMissing:
        warning(
          '[Seeder] One more step: pass your seeders to Nylo in $providerPath\n'
          '  $seedersImport\n'
          '  await nylo.configure(..., seeders: seeders);\n'
          '  // or: nylo.addSeeders(seeders);',
        );
    }

    success(
      '[Seeder] Run it while your app is running: open metro live, then seed ${seeder.snakeCase}',
    );
    info(
      '[Seeder] If your app is already running, hot restart it first: '
      'restart in metro live',
    );
  }
}
