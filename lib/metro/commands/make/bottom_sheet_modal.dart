import 'dart:io';

import '/metro/ny_cli.dart';
import '/metro/stubs/bottom_sheet_modal_stub.dart';
import 'package:recase/recase.dart';

Future<void> main(arguments) async =>
    await _MakeBottomSheetModalCommand(arguments).run();

/// Make Bottom Sheet Modal Command
///
/// Usage:
///   [From Terminal] metro make:bottom_sheet_modal
class _MakeBottomSheetModalCommand extends NyCustomCommand {
  _MakeBottomSheetModalCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h",
        help: "Creates a new bottom sheet modal widget for your project.");
    command.addFlag("force",
        abbr: "f",
        help: "Creates a new bottom sheet modal even if it already exists.");

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final modalNameArg = requireArgument(result,
        message: 'You cannot create a bottom sheet modal with an empty name');

    // Strip 'modal' suffix if user included it (e.g., "StripeModal" -> "Stripe")
    final modalName =
        modalNameArg.replaceAll(RegExp(r'modal$', caseSensitive: false), '');

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
        modalName,
        prefix: RegExp(r'(_?modal)'));

    ReCase nameReCase =
        ReCase(projectFile.name.replaceAll(RegExp(r'(_?modal)'), ""));

    // Create the modal widget stub
    String stubModal = bottomSheetModalStub(nameReCase);

    // Create the modal widget file
    await _createModalWidget(
      nameReCase,
      stubModal,
      forceCreate: result.hasForceFlag,
    );

    // Add the modal to bottom_sheet_modals.dart
    await _addToBottomSheetModalsFile(nameReCase);
  }

  /// Creates the modal widget file in partials folder
  Future<void> _createModalWidget(
    ReCase nameReCase,
    String stubContent, {
    bool forceCreate = false,
  }) async {
    const String folderPath =
        'lib/resources/widgets/bottom_sheet_modals/modals';
    final String filePath = '$folderPath/${nameReCase.snakeCase}_modal.dart';

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
    final linkText = '${nameReCase.snakeCase}_modal';
    final link = MetroConsole.hyperlink(linkText, filePath);
    MetroConsole.writeInGreen('[BottomSheetModal] $link created 🎉');
  }

  /// Adds the import and static method to bottom_sheet_modals.dart
  Future<void> _addToBottomSheetModalsFile(ReCase nameReCase) async {
    const String modalsFilePath =
        'lib/resources/widgets/bottom_sheet_modals/bottom_sheet_modals.dart';

    final file = File(modalsFilePath);
    if (!await file.exists()) {
      MetroConsole.writeInRed(
          'bottom_sheet_modals.dart not found at $modalsFilePath');
      return;
    }

    String fileContent = await file.readAsString();

    // Check if modal already exists
    final modalClassName = '${nameReCase.pascalCase}Modal';
    if (fileContent.contains(modalClassName)) {
      MetroConsole.writeInBlack(
          '$modalClassName already exists in bottom_sheet_modals.dart');
      return;
    }

    // Add import statement
    final importStatement =
        "import 'modals/${nameReCase.snakeCase}_modal.dart';";

    // Find the last import statement and add after it
    final importRegex = RegExp(r"^import .*?;$", multiLine: true);
    final matches = importRegex.allMatches(fileContent).toList();

    if (matches.isNotEmpty) {
      final lastImportEnd = matches.last.end;
      fileContent = fileContent.substring(0, lastImportEnd) +
          '\n$importStatement' +
          fileContent.substring(lastImportEnd);
    } else {
      // No imports found, add at the beginning
      fileContent = '$importStatement\n$fileContent';
    }

    // Add static method before the closing brace of the BottomSheetModal class
    final staticMethod = bottomSheetModalStaticMethodStub(nameReCase);

    // Find the closing brace of the last class in the file
    final classMatches = RegExp(r'class\s+\w+').allMatches(fileContent).toList();
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
        fileContent = fileContent.substring(0, classBraceIndex) +
            '\n$staticMethod' +
            fileContent.substring(classBraceIndex);
      }
    }

    // Write the updated content
    await file.writeAsString(fileContent);
    MetroConsole.writeInGreen(
        '[BottomSheetModal] Added BottomSheetModal.show${nameReCase.pascalCase}() to bottom_sheet_modals.dart');
  }
}
