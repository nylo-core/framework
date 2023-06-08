import 'dart:io';

import 'package:nylo_framework/metro/menu.dart';
import 'package:nylo_framework/metro/metro.dart' as metro_cli;
import 'package:nylo_support/metro/metro_service.dart';

void main(List<String> arguments) async {
  await MetroService.runCommand(arguments,
      allCommands: metro_cli.allCommands, menu: metroMenu);
  exit(0);
}
