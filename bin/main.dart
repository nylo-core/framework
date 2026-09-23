import 'dart:io';

import 'package:nylo_framework/metro/commands/built_in_commands.dart';
import 'package:nylo_framework/metro/commands/live/live_commands.dart'
    show liveRunActions, liveCommandMoved;
import 'package:nylo_framework/metro/live/live_manifest.dart';
import 'package:nylo_framework/metro/live/live_runner.dart';
import 'package:nylo_framework/metro/menu.dart';
import 'package:nylo_framework/metro/ny_cli.dart';

void main(List<String> arguments) async {
  // Show menu if no arguments
  if (arguments.isEmpty) {
    // The menu ends with [Live Commands]; the project's live commands from
    // commands.json continue that section instead of [Custom Commands].
    stdout.write(metroMenu);
    final List<LiveManifestEntry> liveEntries = LiveManifest.load();
    stdout.write(LiveManifest.menuLines(liveEntries));
    stdout.writeln();

    // Discover and show the custom commands from the project and its packages
    final customCommands = await MetroService.discoverCustomCommands(
      reservedCommands: builtInCommands.keys,
    );
    final Set<String> liveNames = liveEntries
        .map((entry) => entry.fullName)
        .toSet();
    final customCommandsMenu = MetroService.customCommandsMenu(
      customCommands
          .where(
            (command) =>
                command.isFromPackage || !liveNames.contains(command.fullName),
          )
          .toList(),
    );
    if (customCommandsMenu.isNotEmpty) {
      print(customCommandsMenu.trimRight());
    }
    exit(0);
  }

  final commandName = arguments.first;
  final commandArgs = arguments.length > 1 ? arguments.sublist(1) : <String>[];

  // Check if it's a built-in command
  if (builtInCommands.containsKey(commandName)) {
    await builtInCommands[commandName]!(commandArgs);
    exit(0);
  }

  // Built-in live actions run through live:run, e.g. metro live:run route /home
  if (commandName.startsWith('live:') &&
      liveRunActions.containsKey(commandName.substring('live:'.length))) {
    MetroConsole.writeInRed(
      'Did you mean: metro live:run ${commandName.substring('live:'.length)}',
    );
    exit(64);
  }

  // A live command another one took over, e.g. metro live:import
  if (commandName.startsWith('live:')) {
    final String? moved = liveCommandMoved(
      commandName.substring('live:'.length),
    );
    if (moved != null) {
      MetroConsole.writeInRed(moved);
      exit(64);
    }
  }

  // A "type": "live" command in commands.json runs inside the running app
  final LiveManifestEntry? liveCommand = LiveManifest.find(commandName);
  if (liveCommand != null) {
    exit(await runLiveCustomCommand(liveCommand.fullName, commandArgs));
  }

  // Otherwise, try to run as a custom command from the project or a package
  final customCommands = await MetroService.discoverCustomCommands(
    reservedCommands: builtInCommands.keys,
  );
  final exitCode = await MetroService.runCommand(
    arguments,
    allCommands: customCommands,
    menu: metroMenu,
  );
  exit(exitCode);
}
