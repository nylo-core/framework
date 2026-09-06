import 'dart:io';

import 'package:nylo_framework/metro/commands/built_in_commands.dart';
import 'package:nylo_framework/metro/menu.dart';
import 'package:nylo_framework/metro/ny_cli.dart';

void main(List<String> arguments) async {
  // Show menu if no arguments
  if (arguments.isEmpty) {
    print(metroMenu);

    // Discover and show the custom commands from the project and its packages
    final customCommands = await MetroService.discoverCustomCommands(
      reservedCommands: builtInCommands.keys,
    );
    final customCommandsMenu = MetroService.customCommandsMenu(customCommands);
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
