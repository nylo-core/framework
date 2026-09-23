import 'dart:io';

import '/metro/commands/live/live_commands.dart' show liveRunActions;
import '/metro/live/live_manifest.dart';
import '/metro/live/live_registry.dart';
import '/metro/ny_cli.dart';
import '/metro/stubs/custom_command_stub.dart';
import '/metro/stubs/live_command_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:command command.
Future<void> main(List<String> arguments) async =>
    await _MakeCommandCommand(arguments).run();

/// Make Command Command
///
/// Usage:
///   [From Terminal] metro make:command
class _MakeCommandCommand extends NyCustomCommand {
  _MakeCommandCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag(
      "help",
      abbr: "h",
      help: "e.g. make:command OptimizeAssets",
    );
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new command file even if it already exists.",
    );
    command.addOption(
      "category",
      abbr: "c",
      help: "The category for the command.",
      defaultValue: "app",
    );
    command.addFlag(
      "live",
      help:
          "Creates a live command that runs inside your running app, e.g. make:command seed_cart --live",
    );
    command.addOption(
      "description",
      help: "A one-line description shown in the Metro menu.",
    );

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final commandName = requireArgument(
      result,
      message: 'A command name is required',
    );
    final String categoryValue = result.getString(
      "category",
      defaultValue: "app",
    )!;

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      commandName,
      prefix: RegExp(r'(_?command)'),
    );

    String cleanCommandName = projectFile.name.snakeCase.replaceAll(
      RegExp(r'(_?command)'),
      "",
    );

    ReCase classReCase = ReCase(cleanCommandName);
    final bool isLive = result.getBool("live") ?? false;

    String stubCommand = isLive
        ? liveCommandStub(customCommand: classReCase, category: categoryValue)
        : customCommandStub(
            customCommand: classReCase,
            category: categoryValue,
          );
    await MetroService.makeCommand(
      classReCase.snakeCase,
      stubCommand,
      forceCreate: result.hasForceFlag,
      category: categoryValue,
      creationPath: projectFile.creationPath,
    );

    if (isLive) {
      await _registerLiveCommand(
        classReCase,
        category: categoryValue,
        description: result.getString("description"),
        creationPath: projectFile.creationPath,
      );
    }
  }

  /// Marks the new command as live and registers it with the app.
  Future<void> _registerLiveCommand(
    ReCase command, {
    required String category,
    String? description,
    String? creationPath,
  }) async {
    final String fileName = '${command.snakeCase}.dart';
    final String fullName = '$category:${command.snakeCase}';

    LiveManifest.markLive(
      File('$commandsFolder/commands.json'),
      name: command.snakeCase,
      category: category,
      script: fileName,
      description: description,
    );

    final LiveRegistration registration = await registerLiveCommand(
      fullName: fullName,
      className: '${command.pascalCase}Command',
      importPath:
          'app/commands/${creationPath != null ? '$creationPath/' : ''}$fileName',
    );
    if (registration == LiveRegistration.mapNotFound) {
      warning(
        '[Live Command] Couldn\'t find the liveCommands map in $liveCommandsRegistryPath. Add this entry to it:\n'
        "  '$fullName': () => ${command.pascalCase}Command(),",
      );
    }

    final String providerPath = '$providerFolder/app_provider.dart';
    switch (await wireLiveCommands(File(providerPath))) {
      case LiveWiring.added:
        info('[Live Command] $providerPath now passes liveCommands to Nylo');
      case LiveWiring.alreadyWired:
        break;
      case LiveWiring.configureNotFound:
      case LiveWiring.providerMissing:
        warning(
          '[Live Command] One more step: pass your live commands to Nylo in $providerPath\n'
          '  $liveCommandsImport\n'
          '  await nylo.configure(..., liveCommands: liveCommands);\n'
          '  // or: nylo.addLiveCommands(liveCommands);',
        );
    }

    if (liveRunActions.containsKey(fullName)) {
      warning(
        '[Live Command] metro live:run $fullName runs the built-in command with '
        'that name. Run yours with metro $fullName instead.',
      );
    }

    success('[Live Command] Run it while your app is running: metro $fullName');
    info(
      '[Live Command] If your app is already running, hot restart it first: '
      'restart in metro live',
    );
  }
}
