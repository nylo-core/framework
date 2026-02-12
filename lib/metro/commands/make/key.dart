import 'dart:io';
import 'dart:math';

import '/metro/ny_cli.dart';

/// Entry point for the make:key command.
Future<void> main(List<String> arguments) async =>
    await _MakeKeyCommand(arguments).run();

/// Make Key Command
///
/// Generates a secure APP_KEY for environment encryption.
///
/// Usage:
///   [From Terminal] metro make:key
class _MakeKeyCommand extends NyCustomCommand {
  _MakeKeyCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag("help",
        abbr: "h", help: 'Generates a secure APP_KEY for your .env file');
    command.addFlag("force",
        abbr: "f", help: "Overwrites existing APP_KEY if present.");
    command.addOption("file",
        abbr: "e", help: "The .env file to update.", defaultValue: ".env");
    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final envFile = result.getString("file", defaultValue: ".env")!;
    final hasForceFlag = result.hasForceFlag;

    // Generate a 32-character secure key
    final appKey = _generateSecureKey(32);

    // Read existing .env file or create new one
    final file = File(envFile);
    String envContent = '';

    if (await file.exists()) {
      envContent = await file.readAsString();

      // Check if APP_KEY already exists
      final appKeyRegex = RegExp(r'^APP_KEY=.*$', multiLine: true);
      if (appKeyRegex.hasMatch(envContent)) {
        if (!hasForceFlag) {
          warning('APP_KEY already exists in $envFile');
          info('Use --force to overwrite the existing key.');
          return;
        }
        // Replace existing APP_KEY
        envContent = envContent.replaceAll(appKeyRegex, 'APP_KEY=$appKey');
        await file.writeAsString(envContent);
        success('APP_KEY updated in $envFile');
        return;
      }
    }

    // Append APP_KEY to the file
    if (envContent.isNotEmpty && !envContent.endsWith('\n')) {
      envContent += '\n';
    }
    envContent += 'APP_KEY=$appKey\n';

    await file.writeAsString(envContent);
    success('APP_KEY generated and added to $envFile');
  }

  /// Generates a cryptographically secure random key
  String _generateSecureKey(int length) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
