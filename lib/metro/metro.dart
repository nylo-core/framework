library metro;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter_launcher_icons/main.dart' as launcherIcons;
import 'package:args/args.dart';
import 'package:nylo_framework/metro/menu.dart';
import 'package:nylo_support/metro/constants/strings.dart';
import 'package:nylo_support/metro/metro_console.dart';
import 'package:nylo_support/metro/metro_service.dart';
import 'package:nylo_framework/metro/models/ny_command.dart';
import 'package:nylo_framework/metro/stubs/controller_stub.dart';
import 'package:nylo_framework/metro/stubs/model_stub.dart';
import 'package:nylo_framework/metro/stubs/page_stub.dart';
import 'package:nylo_framework/metro/stubs/page_w_controller_stub.dart';
import 'package:nylo_framework/metro/stubs/widget_stateful_stub.dart';
import 'package:nylo_framework/metro/stubs/widget_stateless_stub.dart';
import 'dart:io';

List<NyCommand> _allCommands = [
  NyCommand(
      name: "init",
      options: 1,
      arguments: ["-h"],
      category: "project",
      action: _projectInit),
  NyCommand(
      name: "controller",
      options: 1,
      arguments: ["-h", "-f"],
      category: "make",
      action: _makeController),
  NyCommand(
      name: "model",
      options: 1,
      arguments: ["-h", "-f", "-s"],
      category: "make",
      action: _makeModel),
  NyCommand(
      name: "page",
      options: 1,
      category: "make",
      arguments: ["-h", "-f"],
      action: _makePage),
  NyCommand(
      name: "stateful_widget",
      options: 1,
      arguments: ["-h", "-f"],
      category: "make",
      action: _makeStatefulWidget),
  NyCommand(
      name: "stateless_widget",
      options: 1,
      arguments: ["-h", "-f"],
      category: "make",
      action: _makeStatelessWidget),
  NyCommand(
      name: "build",
      options: 1,
      arguments: ["-h"],
      category: "appicons",
      action: _makeAppIcons),
];

Future<void> commands(List<String> arguments) async {
  if (arguments.isEmpty) {
    MetroConsole.writeInBlack(metroMenu);
    return;
  }

  List<String> argumentSplit = arguments[0].split(":");

  if (argumentSplit.length == 0 || argumentSplit.length <= 1) {
    MetroConsole.writeInBlack('Invalid arguments ' + arguments.toString());
    exit(2);
  }

  String type = argumentSplit[0];
  String action = argumentSplit[1];

  NyCommand? nyCommand = _allCommands.firstWhereOrNull(
      (command) => type == command.category && command.name == action);

  if (nyCommand == null) {
    MetroConsole.writeInBlack('Invalid arguments ' + arguments.toString());
    exit(1);
  }

  arguments.removeAt(0);
  await nyCommand.action!(arguments);
}

_projectInit(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h', help: 'Initializes the Nylo project', negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  _checkHelpFlag(argResults[helpFlag], parser.usage);

  if (await MetroService.hasFile(".env") == false) {
    final File envExample = File('.env-example');
    final File env = File('.env');
    await env.writeAsString(await envExample.readAsString());
    MetroConsole.writeInGreen('.env file add from .env-example 🎉');
  }

  MetroConsole.writeInGreen('Project initialized, create something great 🎉');
}

_makeStatefulWidget(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'e.g. make:widget video_player_widget',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new widget even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];

  _checkHelpFlag(argResults[helpFlag], parser.usage);

  String widgetName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?widget)'), "");

  String stubStatefulWidget = widgetStatefulStub(_parseToPascal(widgetName));
  await MetroService.makeStatefulWidget(widgetName, stubStatefulWidget,
      forceCreate: hasForceFlag ?? false);

  MetroConsole.writeInGreen(widgetName + '_widget created 🎉');
}

_makeStatelessWidget(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'e.g. make:widget video_player_widget',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new widget even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];

  _checkHelpFlag(argResults[helpFlag], parser.usage);

  _checkArguments(arguments,
      'You are missing the \'name\' of the widget that you want to create.\ne.g. make:stateless_widget my_new_widget');

  String widgetName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?widget)'), "");

  String stubStatelessWidget = widgetStatelessStub(_parseToPascal(widgetName));
  await MetroService.makeStatelessWidget(widgetName, stubStatelessWidget,
      forceCreate: hasForceFlag ?? false);

  MetroConsole.writeInGreen(widgetName + '_widget created 🎉');
}

_makeAppIcons(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'Generates your app icons in the project.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  _checkHelpFlag(argResults[helpFlag], parser.usage);

  launcherIcons.createIconsFromArguments(arguments);

  MetroConsole.writeInGreen('App icons created 🎉');
}

_makeController(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'Used to make new controllers e.g. home_controller',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new controller even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);
  _checkArguments(arguments, parser.usage);

  bool? hasForceFlag = argResults[forceFlag];
  _checkHelpFlag(argResults[helpFlag], parser.usage);

  String className =
      argResults.arguments.first.replaceAll(RegExp(r'(_?controller)'), "");

  String stubController =
      controllerStub(controllerName: _parseToPascal(className));

  await MetroService.makeController(className, stubController,
      forceCreate: hasForceFlag ?? false);

  MetroConsole.writeInGreen(className + '_controller created 🎉');
}

_makeModel(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'Creates a new model in your project.',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new model even if it already exists.',
      negatable: false);
  parser.addFlag(storableFlag,
      abbr: 's', help: 'Create a new Storable model.', negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  _checkArguments(argResults.arguments, parser.usage);

  bool? hasForceFlag = argResults[forceFlag];
  bool? hasStorableFlag = argResults[storableFlag];

  _checkHelpFlag(argResults[helpFlag], parser.usage);

  String className = argResults.arguments.first;
  String modelName = _parseToPascal(className);
  String stubModel =
      modelStub(modelName: modelName, isStorable: hasStorableFlag);
  await MetroService.makeModel(className, stubModel,
      forceCreate: hasForceFlag ?? false);

  MetroConsole.writeInGreen(modelName + ' created 🎉');
}

_makePage(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(
    helpFlag,
    abbr: 'h',
    help: 'Creates a new page widget for your project.',
    negatable: false,
  );
  parser.addFlag(
    controllerFlag,
    abbr: 'c',
    help: 'Creates a new page with a controller',
    negatable: false,
  );

  final ArgResults argResults = parser.parse(arguments);

  _checkHelpFlag(argResults[helpFlag], parser.usage);

  bool shouldCreateController = false;
  if (argResults["controller"]) {
    shouldCreateController = true;
  }

  if (argResults.arguments.first.trim() == "") {
    MetroConsole.writeInRed('You cannot create a page with an empty string');
    exit(1);
  }

  String className =
      argResults.arguments.first.replaceAll(RegExp(r'(_?page)'), "");

  if (shouldCreateController) {
    String stubPageAndController = pageWithControllerStub(
        className: _parseToPascal(className),
        importName: arguments.first.replaceAll("_page", ""));
    await MetroService.makePage(className, stubPageAndController);

    String stubController =
        controllerStub(controllerName: _parseToPascal(className));
    await MetroService.makeController(className, stubController);

    MetroConsole.writeInGreen(
        '${className}_page & ${className}_controller created 🎉');
  } else {
    String stubPage = pageStub(pageName: _parseToPascal(className));
    await MetroService.makePage(className, stubPage);
    MetroConsole.writeInGreen('${className}_page created 🎉');
  }
}

String _parseToPascal(name) {
  List<String> split = name.split("_");
  List<String> map = split.map((e) => capitalize(e)).toList();
  return map.join("");
}

_checkArguments(List<String> arguments, String usage) {
  if (arguments.isEmpty) {
    MetroConsole.writeInBlack(usage);
    exit(1);
  }
}

_checkHelpFlag(bool hasHelpFlag, String usage) {
  if (hasHelpFlag) {
    MetroConsole.writeInBlack(usage);
    exit(0);
  }
}
