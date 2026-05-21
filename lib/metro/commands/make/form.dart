import '/metro/ny_cli.dart';
import '/metro/stubs/form_stub.dart';
import 'package:recase/recase.dart';

/// Entry point for the make:form command.
Future<void> main(List<String> arguments) async =>
    await _MakeFormCommand(arguments).run();

/// Make Form Command
///
/// Usage:
///   [From Terminal] metro make:form
class _MakeFormCommand extends NyCustomCommand {
  _MakeFormCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help", abbr: "h", help: "e.g. make:form register_form");
    command.addFlag(
      "force",
      abbr: "f",
      help: "Creates a new form even if it already exists.",
    );

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final formName = requireArgument(
      result,
      message: 'A form name is required',
    );

    MetroProjectFile projectFile = MetroService.createMetroProjectFile(
      formName,
      prefix: RegExp(r'(_?form)'),
    );

    String cleanFormName = projectFile.name.snakeCase.replaceAll(
      RegExp(r'(_?form)'),
      "",
    );

    ReCase classReCase = ReCase(cleanFormName);

    String stubForm = formStub(classReCase);
    await MetroService.makeForm(
      classReCase.snakeCase,
      stubForm,
      forceCreate: result.hasForceFlag,
      creationPath: projectFile.creationPath,
    );
  }
}
