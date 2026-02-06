import 'dart:io';

import '/metro/ny_cli.dart';
import '/metro/stubs/model_stub.dart';
import '/json_dart_generator/dart_code_generator.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async => await _MakeModelCommand(arguments).run();

/// Make Model Command
///
/// Usage:
///   [From Terminal] metro make:model
class _MakeModelCommand extends NyCustomCommand {
  _MakeModelCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h",
        help:
            'To create a new model, use e.g. "flutter pub run nylo_framework:main make:model user"');
    command.addFlag("force",
        abbr: "f", help: "Creates a new model even if it already exists.");
    command.addFlag("json",
        abbr: "j", help: "Creates a new model from a JSON object.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final modelNameArg =
        requireArgument(result, message: 'A model name is required');
    final bool hasJsonFlag = result.getBool("json") ?? false;

    MetroProjectFile projectFile =
        MetroService.createMetroProjectFile(modelNameArg);

    String modelName = projectFile.name.pascalCase;
    String stubModel = "";

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
          modelName:
              ReCase(modelName.snakeCase.replaceAll(RegExp(r'(_?model)'), "")));
    }

    await createNyloModel(projectFile.name,
        stubModel: stubModel,
        hasForceFlag: result.hasForceFlag,
        creationPath: projectFile.creationPath);

    if (hasJsonFlag) {
      String creationPath = (projectFile.creationPath != null
          ? "${projectFile.creationPath!}/"
          : "");

      final formatProcess = await Process.start(
          "dart",
          [
            "format",
            "lib/app/models/$creationPath${projectFile.name.snakeCase}.dart"
          ],
          runInShell: true,
          mode: ProcessStartMode.normal);
      await formatProcess.exitCode;
    }
  }
}
