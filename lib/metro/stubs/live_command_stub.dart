import 'package:recase/recase.dart';

/// This stub is used to create a new Live Command.
String liveCommandStub({
  required ReCase customCommand,
  String category = 'app',
}) =>
    '''
import 'package:nylo_framework/nylo_framework.dart';
import 'package:nylo_framework/live.dart';

/// ${customCommand.titleCase} Command
///
/// Runs inside your app while it's running in debug mode, so it can use
/// NyStorage, routeTo, Auth and anything else your app can.
///
/// Usage:
///   [From Terminal] metro ${category}:${customCommand.snakeCase}
class ${customCommand.pascalCase}Command extends LiveCommand {
  @override
  CommandBuilder builder(CommandBuilder command) {
    /// Example adding flags and options
    // command.addFlag('open', help: 'Open the page afterwards');
    // command.addOption('count', abbr: 'c', defaultValue: '3');

    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    // final count = result.getInt('count');
    // await NyStorage.save('count', count);
    //
    // if (result.getBool('open') == true) {
    //   routeTo('/home');
    // }

    success('${customCommand.titleCase} ran on \${Nylo.getCurrentRouteName()}');
  }
}
''';
