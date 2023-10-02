library metro;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:nylo_framework/json_dart_generator/dart_code_generator.dart';
import 'package:nylo_framework/metro/stubs/config_stub.dart';
import 'package:nylo_framework/metro/stubs/route_guard_stub.dart';
import 'package:nylo_support/metro/models/ny_command.dart';
import 'package:nylo_framework/metro/stubs/api_service_stub.dart';
import 'package:nylo_framework/metro/stubs/controller_stub.dart';
import 'package:nylo_framework/metro/stubs/event_stub.dart';
import 'package:nylo_framework/metro/stubs/model_stub.dart';
import 'package:nylo_framework/metro/stubs/network_method_stub.dart';
import 'package:nylo_framework/metro/stubs/page_stub.dart';
import 'package:nylo_framework/metro/stubs/page_w_controller_stub.dart';
import 'package:nylo_framework/metro/stubs/postman_api_service_stub.dart';
import 'package:nylo_framework/metro/stubs/provider_stub.dart';
import 'package:nylo_framework/metro/stubs/theme_colors_stub.dart';
import 'package:nylo_framework/metro/stubs/theme_stub.dart';
import 'package:nylo_framework/metro/stubs/widget_stateful_stub.dart';
import 'package:nylo_framework/metro/stubs/widget_stateless_stub.dart';
import 'package:nylo_support/metro/constants/strings.dart';
import 'package:nylo_support/metro/metro_console.dart';
import 'package:nylo_support/metro/metro_service.dart';
import 'package:recase/recase.dart';

final ArgParser parser = ArgParser(allowTrailingOptions: true);
List<NyCommand> allCommands = [
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
      arguments: ["-h", "-f", "-c"],
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
      name: "provider",
      options: 1,
      arguments: ["-h", "-f"],
      category: "make",
      action: _makeProvider),
  NyCommand(
      name: "event",
      options: 1,
      arguments: ["-h", "-f"],
      category: "make",
      action: _makeEvent),
  NyCommand(
      name: "api_service",
      options: 1,
      arguments: ["-h", "-f", "-model", "-resource"],
      category: "make",
      action: _makeApiService),
  NyCommand(
      name: "theme",
      options: 1,
      arguments: ["-h", "-f"],
      category: "make",
      action: _makeTheme),
  NyCommand(
      name: "route_guard",
      options: 1,
      arguments: ["-h", "-f"],
      category: "make",
      action: _makeRouteGuard),
  NyCommand(
      name: "config",
      options: 1,
      arguments: ["-h", "-f"],
      category: "make",
      action: _makeConfig),
];

_makeConfig(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h', help: 'e.g. make:config currencies', negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new config file even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];

  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  MetroService.checkArguments(arguments,
      'You are missing the \'name\' of the config file that you want to create.\ne.g. make:config settings');

  String configName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?config)'), "");

  ReCase classReCase = ReCase(configName);

  String stubConfig = configStub(classReCase);
  await MetroService.makeConfig(classReCase.snakeCase, stubConfig,
      forceCreate: hasForceFlag ?? false);
}

_makeStatefulWidget(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'e.g. make:stateful_widget video_player_widget',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new stateful widget even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];

  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  MetroService.checkArguments(arguments,
      'You are missing the \'name\' of the stateful widget that you want to create.\ne.g. make:stateful_widget my_new_widget');

  String widgetName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?widget)'), "");

  ReCase classReCase = ReCase(widgetName);

  String stubStatefulWidget = widgetStatefulStub(classReCase);
  await MetroService.makeStatefulWidget(
      classReCase.snakeCase, stubStatefulWidget,
      forceCreate: hasForceFlag ?? false);
}

_makeStatelessWidget(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'e.g. make:stateless_widget video_player_widget',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new stateless widget even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];

  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  MetroService.checkArguments(arguments,
      'You are missing the \'name\' of the widget that you want to create.\ne.g. make:stateless_widget my_new_widget');

  String widgetName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?widget)'), "");
  ReCase classReCase = ReCase(widgetName);

  String stubStatelessWidget = widgetStatelessStub(classReCase);
  await MetroService.makeStatelessWidget(
      classReCase.snakeCase, stubStatelessWidget,
      forceCreate: hasForceFlag ?? false);
}

_makeRouteGuard(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'e.g. make:route_guard subscription_route_guard',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new route guard even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];

  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  MetroService.checkArguments(arguments,
      'You are missing the \'name\' of the widget that you want to create.\ne.g. make:route_guard subscription_route_guard');

  String className =
      argResults.arguments.first.replaceAll(RegExp(r'(_?route_guard)'), "");
  ReCase classReCase = ReCase(className);

  String routeGuard = routeGuardStub(classReCase);
  await MetroService.makeRouteGuard(classReCase.snakeCase, routeGuard,
      forceCreate: hasForceFlag ?? false);
}

_makeProvider(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h', help: 'e.g. make:provider storage_provider', negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new provider even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];

  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  MetroService.checkArguments(arguments,
      'You are missing the \'name\' of the provider that you want to create.\ne.g. make:provider cache_provider');

  String providerName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?provider)'), "");
  ReCase classReCase = ReCase(providerName);

  String stubProvider = providerStub(classReCase);
  await MetroService.makeProvider(classReCase.snakeCase, stubProvider,
      forceCreate: hasForceFlag ?? false, addToConfig: true);
}

_makeEvent(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h', help: 'e.g. make:event login_event', negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new event even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];

  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  MetroService.checkArguments(arguments,
      'You are missing the \'name\' of the event that you want to create.\ne.g. make:event login_event');

  String eventName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?event)'), "");

  ReCase classReCase = ReCase(eventName);
  String stubEvent = eventStub(eventName: classReCase);
  await MetroService.makeEvent(classReCase.snakeCase, stubEvent,
      forceCreate: hasForceFlag ?? false, addToConfig: true);
}

_makeApiService(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'e.g. make:api_service user_api_service',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new API service even if it already exists.',
      negatable: false);
  parser.addOption(
    modelFlag,
    abbr: 'm',
    help: 'Provide the Model that should be used in the API service.',
  );
  parser.addOption(
    urlFlag,
    abbr: 'u',
    help: 'Provide the Base Url that should be used in the API service.',
  );
  parser.addOption(
    postmanCollectionOption,
    abbr: 'p',
    help:
        'Provide a Postman collection json file (v2.1) to create the API service.',
  );

  final ArgResults argResults = parser.parse(arguments);

  // options
  bool? hasForceFlag = argResults[forceFlag];
  String modelFlagValue = argResults[modelFlag] ?? "Model";
  String? baseUrlFlagValue = argResults[urlFlag];
  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);
  String apiServiceName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?api_service)'), "");
  ReCase classReCase = ReCase(apiServiceName);

  MetroService.checkArguments(arguments,
      'You are missing the \'name\' of the API service that you want to create.\ne.g. make:api_service user_api_service');
  if (baseUrlFlagValue == null) {
    baseUrlFlagValue = "getEnv('API_BASE_URL')";
  } else {
    baseUrlFlagValue = "\"$baseUrlFlagValue\"";
  }

  // handle postman collection
  if (argResults.options.contains(postmanCollectionOption)) {
    String? assetName = argResults[postmanCollectionOption];
    File file = File("public/assets/postman/$assetName");
    if ((await file.exists()) == false) {
      MetroConsole.writeInRed("Cannot locate \"$assetName\"");
      MetroConsole.writeInBlack(
          "Add \"$assetName\" to your \"/public/assets/postman/\" directory.");
      exit(0);
    }
    String fileJson = await file.readAsString();
    dynamic json = jsonDecode(fileJson);

    // get root postman contents
    File filePostman = File("postman.json");
    if ((await filePostman.exists()) == false) {
      MetroConsole.writeInBlack(
          "Your project is missing a 'postman.json' file. E.g.\n" +
              '''
  {
    "global": {
      "BASE_URL": "https://nylo.dev",
      "API_VERSION": "v2",
    }
  }
  ''' +
              "Create the file at the root of the project.");
      exit(1);
    }
    String jsonFilePostman = await filePostman.readAsString();

    Map<String, dynamic> postmanFileContents =
        Map<String, dynamic>.from(jsonDecode(jsonFilePostman));
    Map<String, dynamic> postmanGlobalVars = postmanFileContents['global'];

    await _makePostmanApiService(
        json: json,
        postmanGlobalVars: postmanGlobalVars,
        classReCase: classReCase,
        hasForceFlag: hasForceFlag,
        baseUrlFlagValue: baseUrlFlagValue);
    final arguments = <String>["format", "lib/app/models"];
    print('Dart format lib/app/models');
    print('============');
    final process = await Process.start('dart', arguments, runInShell: false);
    await stdout.addStream(process.stdout);
    await stderr.addStream(process.stderr);
    exit(0);
  }

  await _createApiService(classReCase,
      argResults: argResults,
      modelFlagValue: modelFlagValue,
      baseUrlFlagValue: baseUrlFlagValue,
      hasForceFlag: hasForceFlag);
}

_makePostmanApiService(
    {required dynamic json,
    required Map<String, dynamic> postmanGlobalVars,
    required ReCase classReCase,
    required bool? hasForceFlag,
    required String baseUrlFlagValue,
    String? exportPath}) async {
  List<String>? stubNetworkValue = [];
  List<Map<String, dynamic>> postmanItems =
      List<Map<String, dynamic>>.from(json['item']);
  List<String> imports = [];
  for (var postmanItem in postmanItems) {
    // handle folders
    if (postmanItem.containsKey('item')) {
      String pathName = postmanItem['name'].toString().toLowerCase();
      if (exportPath != null) {
        pathName = "$exportPath/$pathName";
      }

      // create a directory
      String directory = 'lib/app/networking/' + pathName;
      await MetroService.makeDirectory(directory);

      // add back to loop
      await _makePostmanApiService(
          json: postmanItem,
          postmanGlobalVars: postmanGlobalVars,
          exportPath: pathName,
          classReCase: classReCase,
          hasForceFlag: hasForceFlag,
          baseUrlFlagValue: baseUrlFlagValue);
      continue;
    }

    // handle items
    if (postmanItem.containsKey('request')) {
      String method = postmanItem["request"]["method"];

      // params
      Map<String, dynamic> queryParams = {}, dataParams = {}, headerParams = {};

      // find header params
      if (postmanItem["request"] != null &&
          Map<String, dynamic>.from(postmanItem["request"])
              .containsKey('header')) {
        if (postmanItem['request']['header'] != null) {
          List<Map<String, dynamic>> headerList =
              List<Map<String, dynamic>>.from(postmanItem['request']['header']);
          for (var header in headerList) {
            if (!header.containsKey('key')) {
              continue;
            }
            String key = header['key'];
            String? value;
            if (key == "") {
              continue;
            }
            if (header.containsKey('value')) {
              value = header['value'];
            }
            headerParams[key] = value ?? "";
          }
        }
      }

      // find query params
      if (postmanItem["request"] != null &&
          Map<String, dynamic>.from(postmanItem["request"])
              .containsKey('url')) {
        if (postmanItem['request']['url'] != null) {
          Map<String, dynamic> urlData = postmanItem['request']['url'];
          if (urlData.containsKey('query')) {
            List<Map<String, dynamic>>? queryData =
                List<Map<String, dynamic>>.from(urlData['query']);
            queryData.forEach((element) {
              queryParams[element['key']] = element['value'];
            });
          }
        }
      }

      // find data params
      if (postmanItem["request"] != null &&
          Map<String, dynamic>.from(postmanItem["request"])
              .containsKey('body')) {
        Map<String, dynamic> body = postmanItem['request']['body'];
        if (body.containsKey('mode')) {
          switch (body["mode"]) {
            case "formdata":
              {
                // tbc
                break;
              }
            case "raw":
              {
                if (body["raw"] is String) {
                  dynamic jsonRaw = jsonDecode(_replacePostmanStringVars(
                      postmanGlobalVars, body["raw"]));
                  if (jsonRaw is Map<String, dynamic>) {
                    Map<String, dynamic>.from(jsonRaw)
                        .entries
                        .forEach((element) {
                      dataParams[element.key] = element.value;
                    });
                  }
                }
                break;
              }
            default:
              {}
          }
        }
      }

      // search for body
      String? responseBody;
      String? modelName;
      bool? isList;
      if (postmanItem.containsKey('response') &&
          postmanItem['response'].length != 0) {
        String? name = postmanItem['name'];
        if (name != null) {
          modelName = ReCase(name).pascalCase;
        }
        Map<String, dynamic> responseData =
            Map<String, dynamic>.from(postmanItem['response'][0]);
        if (responseData.containsKey('body')) {
          responseBody = _replacePostmanStringVars(
              postmanGlobalVars, responseData['body']);
        }
      }

      if (responseBody != null && modelName != null) {
        dynamic jsonResponseBody = jsonDecode(responseBody);

        // create a model in the users directory
        var generator = DartCodeGenerator(
          rootClassName: modelName,
          rootClassNameWithPrefixSuffix: true,
          classPrefix: '',
          classSuffix: '',
        );

        String code = "";

        dynamic rsp = _NyJson.tryDecode(responseBody);
        if (rsp != null) {
          // call generate to generate code
          if (jsonResponseBody is List && jsonResponseBody.length > 0) {
            code = generator.generate(jsonEncode(jsonResponseBody[0]));
            isList = true;
          } else {
            isList = false;
            code = generator.generate(responseBody);
          }
        }
        // create model
        await _createNyloModel(ReCase(modelName),
            stubModel: code, hasForceFlag: hasForceFlag);
        imports.add(makeImportPathModel(ReCase(modelName).snakeCase));
      }

      String urlRaw = postmanItem["request"]["url"]['raw'];
      String cleanUrlRaw = _replacePostmanStringVars(postmanGlobalVars, urlRaw);

      String path =
          List<String>.from(postmanItem["request"]["url"]["path"]).join("/");
      String cleanPath = _replacePostmanStringVars(postmanGlobalVars, path);

      ReCase fullUrlPath = ReCase(postmanItem['name']);
      String methodName = method.toLowerCase() + fullUrlPath.pascalCase;

      String createdNetworkMethodStub = networkMethodStub(
          methodName: methodName,
          method: method,
          path: "/$cleanPath",
          urlFullPath: cleanUrlRaw,
          model: (modelName != null ? ReCase(modelName).pascalCase : null),
          isList: (isList ?? false),
          queryParams: queryParams,
          dataParams: dataParams,
          headerParams: headerParams);
      stubNetworkValue.add(createdNetworkMethodStub);
    }
  }

  if (stubNetworkValue.isEmpty) {
    return;
  }

  if (baseUrlFlagValue == "getEnv('API_BASE_URL')" &&
      postmanGlobalVars.containsKey('BASE_URL')) {
    baseUrlFlagValue = '"${postmanGlobalVars['BASE_URL']}"';
  }

  ReCase className;
  String stubPostmanApiService = "";
  if (exportPath != null) {
    ReCase reCase = ReCase("${classReCase.pathCase}/$exportPath");
    stubPostmanApiService = postmanApiServiceStub(reCase,
        imports: imports.join("\n"),
        networkMethods: (stubNetworkValue.join("\n")),
        baseUrl: baseUrlFlagValue);
    className = reCase;
  } else {
    stubPostmanApiService = postmanApiServiceStub(classReCase,
        imports: imports.join("\n"),
        networkMethods: (stubNetworkValue.join("\n")),
        baseUrl: baseUrlFlagValue);
    className = classReCase;
  }

  await MetroService.makeApiService(className.snakeCase, stubPostmanApiService,
      forceCreate: hasForceFlag ?? false,
      folderPath: exportPath != null
          ? "$networkingFolder/$exportPath"
          : networkingFolder,
      addToConfig: false);

  String classImport = makeImportPathApiService(exportPath != null
      ? "$exportPath/${className.snakeCase}"
      : className.snakeCase);
  await MetroService.addToConfig(
      configName: "decoders",
      classImport: classImport,
      createTemplate: (file) {
        String apiServiceName = "${className.pascalCase}ApiService";
        if (file.contains(apiServiceName)) {
          return "";
        }
        RegExp reg = RegExp(
            r'final Map<Type, BaseApiService> apiDecoders = {([\w\W\n\r\s:(),\/\/]+)};');
        String temp = """
final Map<Type, BaseApiService> apiDecoders = {${reg.allMatches(file).map((e) => e.group(1)).toList()[0]}
  $apiServiceName: $apiServiceName(),
};
  """;

        return file.replaceFirst(
          RegExp(
              r'final Map<Type, BaseApiService> apiDecoders = {[\w\W\n\r\s:(),\/\/]+(};)'),
          temp,
        );
      });
}

_replacePostmanStringVars(Map<String, dynamic> postmanGlobal, String string) =>
    string.replaceAllMapped(RegExp(r'\{\{[A-z_]+\}\}', caseSensitive: false),
        (Match m) {
      if (m.group(0) == null) {
        return "";
      }
      String group0 = m.group(0)!;
      group0 = group0.replaceAll(RegExp(r'{{|}}'), "");

      return postmanGlobal[group0].toString();
    });

_createApiService(ReCase classReCase,
    {required argResults,
    required modelFlagValue,
    required baseUrlFlagValue,
    required hasForceFlag}) async {
  String stubApiService = apiServiceStub(classReCase,
      model: ReCase(modelFlagValue), baseUrl: baseUrlFlagValue);
  await MetroService.makeApiService(classReCase.snakeCase, stubApiService,
      forceCreate: hasForceFlag ?? false, addToConfig: true);
}

_makeTheme(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h', help: 'e.g. make:theme bright_theme', negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new theme even if it already exists.',
      negatable: false);
  parser.addFlag(themeDarkFlag,
      abbr: 'd', help: 'Creates a new dark theme.', negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  bool? hasForceFlag = argResults[forceFlag];
  bool? hasThemeDarkFlag = argResults[themeDarkFlag];

  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  MetroService.checkArguments(arguments,
      'You are missing the \'name\' of the theme that you want to create.\ne.g. make:theme bright_theme');

  String themeName =
      argResults.arguments.first.replaceAll(RegExp(r'(_?theme)'), "");
  ReCase classReCase = ReCase(themeName);

  String stubTheme = themeStub(classReCase, isDark: hasThemeDarkFlag ?? false);
  await MetroService.makeTheme(classReCase.snakeCase, stubTheme,
      forceCreate: hasForceFlag ?? false);

  String stubThemeColors = themeColorsStub(classReCase);
  await MetroService.makeThemeColors(classReCase.snakeCase, stubThemeColors,
      forceCreate: hasForceFlag ?? false);
}

_makeController(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h',
      help: 'Used to make new controllers e.g. home_controller',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new controller even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);
  MetroService.checkArguments(arguments, parser.usage);

  bool? hasForceFlag = argResults[forceFlag];
  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  String className =
      argResults.arguments.first.replaceAll(RegExp(r'(_?controller)'), "");
  ReCase classReCase = ReCase(className);

  String stubController = controllerStub(controllerName: classReCase);

  await MetroService.makeController(classReCase.snakeCase, stubController,
      forceCreate: hasForceFlag ?? false);
}

_makeModel(List<String> arguments) async {
  parser.addFlag(helpFlag,
      abbr: 'h',
      help:
          'To create a new model, use e.g. "flutter pub run nylo_framework:main make:model user"',
      negatable: false);
  parser.addFlag(forceFlag,
      abbr: 'f',
      help: 'Creates a new model even if it already exists.',
      negatable: false);

  final ArgResults argResults = parser.parse(arguments);

  MetroService.checkArguments(argResults.arguments, parser.usage);

  bool? hasForceFlag = argResults[forceFlag];
  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  String className = argResults.arguments.first;
  ReCase classReCase = ReCase(className);

  String modelName = classReCase.pascalCase;
  String stubModel = modelStub(modelName: modelName);

  await _createNyloModel(classReCase,
      stubModel: stubModel, hasForceFlag: hasForceFlag);
}

_createNyloModel(ReCase classReCase,
    {required String stubModel, bool? hasForceFlag}) async {
  await MetroService.makeModel(classReCase.snakeCase, stubModel,
      forceCreate: hasForceFlag ?? false, addToConfig: true);
}

_makePage(List<String> arguments) async {
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
  parser.addFlag(
    forceFlag,
    abbr: 'f',
    help: 'Creates a new page even if it already exists.',
    negatable: false,
  );

  final ArgResults argResults = parser.parse(arguments);

  MetroService.hasHelpFlag(argResults[helpFlag], parser.usage);

  bool? hasForceFlag = argResults[forceFlag];

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
  ReCase classReCase = ReCase(className);

  if (shouldCreateController) {
    String stubPageAndController =
        pageWithControllerStub(className: classReCase);
    await MetroService.makePage(className.snakeCase, stubPageAndController,
        forceCreate: hasForceFlag ?? false, addToRoute: true);

    String stubController = controllerStub(controllerName: classReCase);
    await MetroService.makeController(className.snakeCase, stubController,
        forceCreate: hasForceFlag ?? false);
  } else {
    String stubPage = pageStub(pageName: classReCase);
    await MetroService.makePage(className.snakeCase, stubPage,
        forceCreate: hasForceFlag ?? false, addToRoute: true);
  }
}

/// helper to encode and decode data
class _NyJson {
  static dynamic tryDecode(data) {
    try {
      return jsonDecode(data);
    } catch (e) {
      return null;
    }
  }
}
