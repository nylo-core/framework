import 'dart:io';

import '/metro/ny_cli.dart';
import '/metro/stubs/model_stub.dart';
import '/metro/stubs/one_of_model_stub.dart';
import '/json_dart_generator/dart_code_generator.dart';

import 'package:recase/recase.dart';

/// Entry point for the make:model command.
Future<void> main(List<String> arguments) async =>
    await _MakeModelCommand(arguments).run();

/// Make Model Command
///
/// Usage:
///   [From Terminal] metro make:model
class _MakeModelCommand extends NyCustomCommand {
  _MakeModelCommand(List<String> arguments) : super(_allowBareOneOf(arguments));

  /// Lets `--one-of` be passed without a value, so the subtype names are
  /// asked for instead. A bare option would otherwise fail to parse.
  static List<String> _allowBareOneOf(List<String> arguments) => [
    for (int i = 0; i < arguments.length; i++)
      arguments[i] == '--one-of' &&
              (i == arguments.length - 1 || arguments[i + 1].startsWith('-'))
          ? '--one-of='
          : arguments[i],
  ];

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag(
      "help",
      abbr: "h",
      help: 'To create a new model, use e.g. "flutter pub run nylo_framework:main make:model user"',
    );
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new model even if it already exists.",
    );
    command.addFlag(
      "json",
      abbr: "j",
      help: "Creates a new model from a JSON object.",
    );
    command.addOption(
      "one-of",
      help: 'Creates a OneOf model: a sealed parent with the given subtypes, e.g. --one-of="accepted,rejected"',
    );

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final String modelNameArg = requireArgument(
      result,
      message: 'A model name is required',
    );
    final bool hasJsonFlag = result.getBool("json") ?? false;
    final String? oneOf = result.getString("one-of");

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      modelNameArg,
    );

    String modelName = projectFile.name.pascalCase;
    String stubModel = "";

    if (oneOf != null) {
      await _makeOneOfModel(projectFile, oneOf, result.hasForceFlag);
      return;
    }

    if (hasJsonFlag) {
      const fileName = 'nylo-model.json';

      String? consoleMessage;
      if (Platform.isMacOS || Platform.isLinux) {
        consoleMessage = 'Input your text and press Ctrl + D to save and exit.';
      }
      if (Platform.isWindows) {
        consoleMessage = 'Input your text and press Ctrl + C to save and exit.';
      }

      if (consoleMessage != null) {
        MetroConsole.writeInGreen(consoleMessage);
      }

      // Read user input from stdin
      final StringBuffer buffer = StringBuffer();
      await stdin.forEach((List<int> data) {
        buffer.write(String.fromCharCodes(data));
      });

      // Save the user's text to the file
      final file = File(fileName);
      await file.writeAsString(buffer.toString());

      String modelData = await MetroService.loadAsset("nylo-model.json");

      // Delete "nylo-model.json"
      await File(fileName).delete();
      MetroConsole.writeInBlack("\n");

      DartCodeGenerator generator = DartCodeGenerator(
        rootClassName: modelName,
        rootClassNameWithPrefixSuffix: true,
        classPrefix: '',
        classSuffix: '',
      );

      stubModel = generator.generate(modelData);
    } else {
      stubModel = modelStub(
        modelName: ReCase(
          modelName.snakeCase.replaceAll(RegExp(r'(_?model)'), ""),
        ),
      );
    }

    await createNyloModel(
      projectFile.name,
      stubModel: stubModel,
      hasForceFlag: result.hasForceFlag,
      creationPath: projectFile.creationPath,
    );

    if (hasJsonFlag) {
      String creationPath = (projectFile.creationPath != null
          ? "${projectFile.creationPath!}/"
          : "");

      final Process formatProcess = await Process.start(
        "dart",
        [
          "format",
          "lib/app/models/$creationPath${projectFile.name.snakeCase}.dart",
        ],
        runInShell: true,
        mode: ProcessStartMode.normal,
      );
      await formatProcess.exitCode;
    }
  }

  /// Whether the app's pubspec.yaml allows primary constructors.
  bool _appSupportsPrimaryConstructors() {
    final File pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) return false;
    return supportsPrimaryConstructors(pubspec.readAsStringSync());
  }

  /// Creates a sealed parent with one subtype per name in [oneOf], and
  /// registers a `OneOf.byKey` entry for it in decoders.dart.
  Future<void> _makeOneOfModel(
    MetroProjectFile projectFile,
    String oneOf,
    bool hasForceFlag,
  ) async {
    String input = oneOf;
    if (input.trim().isEmpty) {
      MetroConsole.writeInGreen(
        'Enter the subtype names, separated by commas (e.g. accepted,rejected):',
      );
      input = stdin.readLineSync() ?? '';
    }

    final List<ReCase> types = parseOneOfTypes(input);
    if (types.isEmpty) {
      MetroConsole.writeInRed(
        'A OneOf model needs at least one subtype, e.g. --one-of="accepted,rejected"',
      );
      exit(1);
    }

    final ReCase modelName = ReCase(
      projectFile.name.snakeCase.replaceAll(RegExp(r'(_?model)'), ""),
    );
    if (types.any((type) => type.pascalCase == modelName.pascalCase)) {
      MetroConsole.writeInRed(
        'A subtype can\'t have the same name as the model (${modelName.pascalCase}).',
      );
      exit(1);
    }

    await MetroService.makeModel(
      modelName.snakeCase,
      oneOfModelStub(
        modelName: modelName,
        types: types,
        primaryConstructors: _appSupportsPrimaryConstructors(),
      ),
      forceCreate: hasForceFlag,
      addToConfig: false,
      creationPath: projectFile.creationPath,
    );

    await MetroService.addToConfig(
      configName: "decoders",
      classImport: makeImportPathModel(
        modelName.snakeCase,
        creationPath: projectFile.creationPath ?? "",
      ),
      createTemplate: (file) =>
          addOneOfDecoders(file, modelName: modelName, types: types),
    );
  }
}
