import 'dart:io';

import 'package:nylo_framework/metro/commands/built_in_commands.dart';
import 'package:nylo_framework/metro/menu.dart';
import 'package:nylo_framework/metro/ny_cli.dart';

void main(List<String> arguments) async {
  // Show menu if no arguments
  if (arguments.isEmpty) {
    print(metroMenu);

    // Discover and show custom commands
    final customCommands = await MetroService.discoverCustomCommands();
    if (customCommands.isNotEmpty) {
      print('[Custom Commands]');
      for (var cmd in customCommands) {
        print('  ${cmd.category}:${cmd.name}');
      }
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

  // Otherwise, try to run as custom command
  final customCommands = await MetroService.discoverCustomCommands();
  await MetroService.runCommand(
    arguments,
    allCommands: customCommands,
    menu: metroMenu,
  );
  exit(0);
}
