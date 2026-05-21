import 'dart:io';

import '/metro/ny_cli.dart';
import '/metro/stubs/button_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:button command.
Future<void> main(List<String> arguments) async =>
    await _MakeButtonCommand(arguments).run();

/// Make Button Command
///
/// Usage:
///   [From Terminal] metro make:button
class _MakeButtonCommand extends NyCustomCommand {
  _MakeButtonCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag(
      "help",
      abbr: "h",
      help: "Creates a new button widget for your project.",
    );
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new button even if it already exists.",
    );

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final buttonNameArg = requireArgument(
      result,
      message: 'You cannot create a button with an empty name',
    );

    // Strip 'button' suffix if user included it (e.g., "PrimaryButton" -> "Primary")
    final buttonName = buttonNameArg.replaceAll(
      RegExp(r'button$', caseSensitive: false),
      '',
    );

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      buttonName,
      prefix: RegExp(r'(_?button)'),
    );

    ReCase nameReCase = ReCase(
      projectFile.name.replaceAll(RegExp(r'(_?button)'), ""),
    );

    // Create the button widget stub
    String stubButton = buttonStub(nameReCase);

    // Create the button widget file
    await _createButtonWidget(
      nameReCase,
      stubButton,
      forceCreate: result.hasForceFlag,
    );

    // Add the button to buttons.dart
    await _addToButtonsFile(nameReCase);
  }

  /// Creates the button widget file in partials folder
  Future<void> _createButtonWidget(
    ReCase nameReCase,
    String stubContent, {
    bool forceCreate = false,
  }) async {
    const String folderPath = 'lib/resources/widgets/buttons/partials';
    final String filePath =
        '$folderPath/${nameReCase.snakeCase}_button_widget.dart';

    // Ensure directory exists
    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Check if file already exists
    final file = File(filePath);
    if (await file.exists() && !forceCreate) {
      MetroConsole.writeInRed('$filePath already exists');
      MetroConsole.writeInBlack('Use --force to overwrite.');
      exit(1);
    }

    // Create the file
    await file.writeAsString(stubContent);
    final linkText = '${nameReCase.snakeCase}_button_widget';
    final link = MetroConsole.hyperlink(linkText, filePath);
    MetroConsole.writeInGreen('[Button] $link created 🎉');
  }

  /// Adds the import and static method to buttons.dart
  Future<void> _addToButtonsFile(ReCase nameReCase) async {
    const String buttonsFilePath = 'lib/resources/widgets/buttons/buttons.dart';

    final file = File(buttonsFilePath);
    if (!await file.exists()) {
      MetroConsole.writeInRed('buttons.dart not found at $buttonsFilePath');
      return;
    }

    String fileContent = await file.readAsString();

    // Check if button already exists
    final buttonClassName = '${nameReCase.pascalCase}Button';
    if (fileContent.contains(buttonClassName)) {
      MetroConsole.writeInBlack(
        '$buttonClassName already exists in buttons.dart',
      );
      return;
    }

    // Add import statement
    final importStatement =
        "import '/resources/widgets/buttons/partials/${nameReCase.snakeCase}_button_widget.dart';";

    // Find the last import statement and add after it
    final importRegex = RegExp(r"^import .*?;$", multiLine: true);
    final matches = importRegex.allMatches(fileContent).toList();

    if (matches.isNotEmpty) {
      final lastImportEnd = matches.last.end;
      fileContent =
          fileContent.substring(0, lastImportEnd) +
          '\n$importStatement' +
          fileContent.substring(lastImportEnd);
    } else {
      // No imports found, add at the beginning
      fileContent = '$importStatement\n$fileContent';
    }

    // Add static method before the closing brace of the Button class
    final staticMethod = buttonStaticMethodStub(nameReCase);

    // Find the closing brace of the last class in the file
    final classMatches = RegExp(
      r'class\s+\w+',
    ).allMatches(fileContent).toList();
    if (classMatches.isNotEmpty) {
      final lastClassStart = classMatches.last.start;
      int braceCount = 0;
      int? classBraceIndex;
      for (int i = lastClassStart; i < fileContent.length; i++) {
        if (fileContent[i] == '{') braceCount++;
        if (fileContent[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            classBraceIndex = i;
            break;
          }
        }
      }
      if (classBraceIndex != null) {
        fileContent =
            fileContent.substring(0, classBraceIndex) +
            '\n$staticMethod' +
            fileContent.substring(classBraceIndex);
      }
    }

    // Write the updated content
    await file.writeAsString(fileContent);
    MetroConsole.writeInGreen(
      '[Button] Added Button.${nameReCase.camelCase}() to buttons.dart',
    );
  }
}
