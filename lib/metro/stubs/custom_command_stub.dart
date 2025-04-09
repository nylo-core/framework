import 'package:recase/recase.dart';

/// This stub is used to create a new Custom Command.
String customCommandStub(
        {required ReCase customCommand, String category = 'app'}) =>
    '''
import 'package:nylo_framework/metro/ny_cli.dart';

void main(arguments) => _${customCommand.pascalCase}Command(arguments).run();

/// ${customCommand.titleCase} Command
///
/// Usage:
///   [From Terminal] dart run nylo_framework:main ${category}:${customCommand.snakeCase}
///   [With Metro]    metro ${category}:${customCommand.snakeCase}
class _${customCommand.pascalCase}Command extends NyCustomCommand {
  _${customCommand.pascalCase}Command(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    /// Example adding flags and options
    // command.addFlag('verbose', abbr: 'v', defaultValue: false);
    // command.addOption('version', defaultValue: '1.0.0');

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    // final version = result.getString('version');
    // final verbose = result.getBool('verbose');
    //
    // if (verbose) {
    //   info('Verbose mode enabled');
    //   print('Command arguments: \${result.arguments}');
    // }
    //
    // implement your command logic...
  }
}
''';
