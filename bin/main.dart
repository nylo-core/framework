import 'dart:io';

import 'package:nylo_framework/metro/menu.dart';
import 'package:nylo_framework/metro/metro.dart' as metro_cli;
import 'package:nylo_support/metro/metro_service.dart';

void main(List<String> arguments) async {
  // Discover custom commands
  final customCommands = await MetroService.discoverCustomCommands();

  // Merge with built-in commands
  final allCommands = [...metro_cli.allCommands, ...customCommands];

  String commandMenu = metroMenu;
  if (customCommands.isNotEmpty) {
    commandMenu += '\n[Custom Commands]\n';
    for (var customCommand in customCommands) {
      commandMenu += '  ${customCommand.category}:${customCommand.name}\n';
    }
  }

  // Run with the combined command set
  await MetroService.runCommand(arguments,
      allCommands: allCommands, menu: commandMenu);
  exit(0);
}
