library metro;

import 'dart:convert';
import 'package:flutter_launcher_icons/main.dart' as launcherIcons;
import 'package:http/http.dart' as http show Response;
import 'package:args/args.dart';
import 'package:json_to_dart/json_to_dart.dart';
import 'package:nylo_framework/metro/constants/strings.dart';
import 'package:nylo_framework/metro/models/ny_api_request.dart';
import 'package:nylo_framework/metro/networking/api_request_networking.dart';
import 'package:nylo_framework/metro/stubs/api_request_stub.dart';
import 'package:nylo_framework/metro/stubs/api_service_stub.dart';
import 'package:nylo_framework/metro/stubs/controller_stub.dart';
import 'package:nylo_framework/metro/stubs/model_stub.dart';
import 'package:nylo_framework/metro/stubs/page_stub.dart';
import 'package:nylo_framework/metro/stubs/page_w_controller_stub.dart';
import 'package:nylo_framework/metro/stubs/widget_stub.dart';
import 'models/ny_command.dart';
import 'dart:io';

List<NyCommand> _allProjectCommands = [
  NyCommand(name: "init", options: 1, arguments: ["-h"], action: _projectInit),
];

List<NyCommand> _allMakeCommands = [
  NyCommand(
      name: "controller",
      options: 1,
      arguments: ["-h", "-f"],
      action: _makeController),
  NyCommand(
      name: "model", options: 1, arguments: ["-h", "-f"], action: _makeModel),
  NyCommand(
      name: "page", options: 1, arguments: ["-h", "-f"], action: _makePage),
  NyCommand(
      name: "widget", options: 1, arguments: ["-h", "-f"], action: _makeWidget),
];

List<NyCommand> _allApiSpecCommands = [
  NyCommand(
      name: "build", options: 1, arguments: ["-h"], action: _apiSpecBuild),
];

List<NyCommand> _allAppIconsCommands = [
  NyCommand(
      name: "build", options: 1, arguments: ["-h"], action: _makeAppIcons),
];

Future<void> commands(List<String> arguments) async {
  if (arguments.length == 0) {
    _handleMenu();
    exit(0);
  }

  List<String> argumentSplit = arguments[0].split(":");

  if (argumentSplit.length == 0 || argumentSplit.length <= 1) {
    writeInBlack('Invalid arguments ' + arguments.toString());
    exit(2);
  }

  String type = argumentSplit[0];
  String action = argumentSplit[1];

  NyCommand nyCommand;
  switch (type) {
    case "project":
      {
        nyCommand = _allProjectCommands.firstWhere(
            (command) => command.name == action,
            orElse: () => null);
        break;
      }
    case "make":
      {
        nyCommand = _allMakeCommands.firstWhere(
            (command) => command.name == action,
            orElse: () => null);
        break;
      }
    case "apispec":
      {
        nyCommand = _allApiSpecCommands.firstWhere(
            (command) => command.name == action,
            orElse: () => null);
        break;
      }
    case "appicons":
      {
        nyCommand = _allAppIconsCommands.firstWhere(
            (command) => command.name == action,
            orElse: () => null);
        break;
      }
    default:
      {}
  }

  if (nyCommand == null) {
    writeInBlack('Invalid arguments ' + arguments.toString());
    return;
  }

  arguments.removeAt(0);
  nyCommand.action(arguments);
}

_handleMenu() {
  writeInBlack(
      'Metro - Nylo\'s Companion to Build Flutter apps by Anthony Gordon');
  writeInBlack('Version: 1.0.0');

  writeInBlack('');

  writeInBlack('Usage: ');
  writeInBlack('    command [options] [arguments]');

  writeInBlack('');
  writeInBlack('Options');
  writeInBlack('    -h');

  writeInBlack('');

  writeInBlack('All commands:');

  _writeInGreen(' project');
  _allProjectCommands.forEach((command) {
    writeInBlack('  project:' + command.name);
  });

  writeInBlack('');

  _writeInGreen(' make');
  _allMakeCommands.forEach((command) {
    writeInBlack('  make:' + command.name);
  });

  writeInBlack('');

  _writeInGreen(' appicons');
  _allApiSpecCommands.forEach((command) {
    writeInBlack('  appicons:' + command.name);
  });

  writeInBlack('');

  _writeInGreen(' apispec');
  _allApiSpecCommands.forEach((command) {
    writeInBlack('  apispec:' + command.name);
  });
}

_projectInit(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h', help: 'Initializes the Nylo project', negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  if (argResults[helpFlag]) {
    writeInBlack('Help - Initializes the Nylo project');
    writeInBlack(parser.usage);
    exit(0);
  }

  final File envExample = File('.env-example');
  final File env = File('.env');

  await env.writeAsString(await envExample.readAsString());

  _writeInGreen('Project initialized, create something great 🎉');
  exit(0);
}

_makeWidget(List<String> arguments) async {
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

  bool hasForceFlag = argResults[forceFlag];
  bool hasHelpFlag = argResults[helpFlag];

  if (hasHelpFlag) {
    writeInBlack(parser.usage);
    exit(0);
  }

  String widgetName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?widget)'), "");

  String path = '$widgetFolder/${widgetName.toLowerCase()}_widget.dart';

  if (await File(path).exists() && hasForceFlag == false) {
    _writeInRed(widgetName + '_widget already exists');
    exit(0);
  }

  final File file = File(path);

  await _makeDirectory(widgetFolder);

  await file.writeAsString(widgetStub(_parseToPascal(widgetName)));

  _writeInGreen(widgetName + '_widget created 🎉');

  exit(0);
}

_makeAppIcons(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'Generates your app icons in the project.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  if (argResults[helpFlag]) {
    writeInBlack('Help - Creates App Icons in Nylo');
    writeInBlack(parser.usage);
    exit(0);
  }

  launcherIcons.createIconsFromArguments(arguments);

  _writeInGreen('App icons created 🎉');
  exit(0);
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

  if (argResults.arguments.length == 0) {
    writeInBlack(parser.usage);
    exit(0);
  }

  bool hasForceFlag = argResults[forceFlag];
  bool hasHelpFlag = argResults[helpFlag];

  if (hasHelpFlag) {
    writeInBlack(parser.usage);
    exit(0);
  }

  String className =
      argResults.arguments.first.replaceAll(RegExp(r'(_?controller)'), "");
  String path = '$controllerFolder/${className.toLowerCase()}_controller.dart';

  if (await File(path).exists() && hasForceFlag == false) {
    _writeInRed(className + ' already exists');
    exit(0);
  }

  String controllerName = _parseToPascal(className);
  String strController = controllerStub(controllerName: controllerName);

  await _writeToFilePath(path, strController);

  _writeInGreen(className + '_controller created 🎉');

  exit(0);
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

  final ArgResults argResults = parser.parse(arguments);

  if (argResults.arguments.length == 0) {
    writeInBlack(parser.usage);
    exit(0);
  }

  bool hasForceFlag = argResults[forceFlag];
  bool hasHelpFlag = argResults[helpFlag];

  if (hasHelpFlag) {
    writeInBlack(parser.usage);
    exit(0);
  }

  String firstArg = argResults.arguments.first;
  String path = '$modelFolder/${firstArg.toLowerCase()}.dart';

  if (await File(path).exists() && hasForceFlag == false) {
    _writeInRed(firstArg + ' already exists');
    exit(0);
  }

  final File file = File(path);

  String modelName = _parseToPascal(firstArg);
  String strModel = modelStub(modelName: modelName);

  await _makeDirectory(modelFolder);

  await file.writeAsString(strModel);

  _writeInGreen(modelName + ' created 🎉');

  exit(0);
}

_makePage(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'Creates a new page widget for your project.',
      negatable: false);

  bool shouldCreateController = false;
  parser.addFlag(controllerFlag,
      abbr: 'c',
      help: 'Creates a new page with a controller',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  if (argResults[helpFlag]) {
    writeInBlack('Help - Creates a new page in Nylo');
    writeInBlack(parser.usage);
    exit(0);
  }

  if (argResults["controller"]) {
    shouldCreateController = true;
  }

  if (argResults.arguments.first == " ") {
    exit(0);
  }

  String className =
      argResults.arguments.first.replaceAll(RegExp(r'(_?page)'), "");

  String pathPage = '$pageFolder/${className.toLowerCase()}_page.dart';
  String pathController =
      '$controllerFolder/${className.toLowerCase()}_controller.dart';
  if (shouldCreateController) {
    if (await File(pathPage).exists()) {
      _writeInRed('${className}_page already exists');
      return;
    }

    if (await File(pathController).exists()) {
      _writeInRed('${className}_controller already exists');
      return;
    }

    final File filePage = File(pathPage);

    await _makeDirectory(controllerFolder);

    await filePage.writeAsString(pageWithControllerStub(
        className: _parseToPascal(className),
        importName: argResults.arguments.first.replaceAll("_page", "")));

    final File fileController = File(pathController);

    String strController =
        controllerStub(controllerName: _parseToPascal(className));

    await fileController.writeAsString(strController);

    _writeInGreen('${className}_page & ${className}_controller created 🎉');
    exit(0);
  }

  if (await File(pathPage).exists()) {
    _writeInRed(argResults.arguments.first + ' already exists');
    return;
  }

  final File file = File(pathPage);

  await _makeDirectory(pageFolder);

  await file.writeAsString(pageStub(pageName: className));

  _writeInGreen('${className}_page created 🎉');

  exit(0);
}

_apiSpecBuild(List<String> arguments) async {
  writeInBlack("Building API Spec\n");

  File file;
  Iterable json;

  try {
    file = File("apispec.json");
    json = jsonDecode(await file.readAsString());
  } on Exception catch (e) {
    _writeInRed("Error");
    writeInBlack("Please check your apispec.yaml");
    writeInBlack(e.toString());
    exit(2);
  }

  List<NyApiRequest> nyApiRequests =
      List.of(json).map((e) => NyApiRequest.fromJson(e)).toList();

  String apiRequests = "";
  String importApiRequests = "";

  final ArgParser parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'Used to auto build models from your apispec.yaml',
      negatable: false);
  parser.addFlag('payload',
      abbr: 'p',
      help: 'Add a representation of the JSON used to create the model',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool hasIncludePayloadFlag = argResults['payload'];
  bool hasHelpFlag = argResults[helpFlag];

  if (hasHelpFlag) {
    writeInBlack(parser.usage);
    exit(0);
  }

  for (int i = 0; i < nyApiRequests.length; i++) {
    String modelPath =
        '$modelFolder/${nyApiRequests[i].modelName.toLowerCase()}.dart';

    http.Response json = await metroApiRequest(nyApiRequests[i]);
    final classGenerator = new ModelGenerator(nyApiRequests[i].modelName);
    DartCode dartCode = classGenerator.generateDartClasses(json.body);

    final File file = File(modelPath);
    await file.writeAsString(dartCode.code +
        (hasIncludePayloadFlag == true
            ? '''
    
/* PAYLOAD USED IN CREATION
  ${json.body}
*/
    '''
            : ''));
    _writeInBlue(nyApiRequests[i].modelName + " model created");
    apiRequests = apiRequestStub(nyApiRequests[i]) + "\n" + apiRequests;

    importApiRequests =
        "import \"../models/${nyApiRequests[i].modelName.toLowerCase()}.dart\";\n" +
            importApiRequests;
  }

  String networkingServicePath = '$networkServicesFolder/api_service.dart';
  final File networkingServiceFile = File(networkingServicePath);

  await _makeDirectory(networkServicesFolder);

  await networkingServiceFile.writeAsString(
      apiServiceStub(imports: importApiRequests, apiRequests: apiRequests));

  _writeInGreen("Api Spec Built 🚨");
  exit(0);
}

_writeInGreen(String message) {
  stdout.writeln('\x1B[92m' + message + '\x1B[0m');
}

_writeInRed(String message) {
  stdout.writeln('\x1B[91m' + message + '\x1B[0m');
}

_writeInBlue(String message) {
  stdout.writeln('\x1B[94m' + message + '\x1B[0m');
}

writeInBlack(String message) {
  stdout.writeln(message);
}

String _parseToPascal(name) {
  List<String> split = name.split("_");
  List<String> map = split.map((e) => capitalize(e)).toList();
  return map.join("");
}

_writeToFilePath(path, strFile) async {
  final File file = File(path);

  await file.writeAsString(strFile);
}

_makeDirectory(String path) async {
  final File dirFolder = File(path);
  if (!(await dirFolder.exists())) {
    await Directory(path).create();
  }
}

String capitalize(String input) {
  if (input == null) {
    throw new ArgumentError("string: $input");
  }
  if (input.length == 0) {
    return input;
  }
  return input[0].toUpperCase() + input.substring(1);
}
