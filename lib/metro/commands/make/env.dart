import 'dart:convert';
import 'dart:io';

import '/metro/ny_cli.dart';
import '/metro/stubs/env_stub.dart';

/// Entry point for the make:env command.
Future<void> main(List<String> arguments) async =>
    await _MakeEnvCommand(arguments).run();

/// Make Env Command
///
/// Generates an encrypted env.g.dart file from .env
///
/// Usage:
///   [From Terminal] dart run nylo_framework:main make:env
///   [With Metro]    metro make:env
///   [With options]  metro make:env --file=.env.production
///   [Dart define]   metro make:env --dart-define
class _MakeEnvCommand extends NyCustomCommand {
  _MakeEnvCommand(super.arguments);

  @override
  CommandBuilder builder(CommandBuilder command) {
    command.addFlag(
      "help",
      abbr: "h",
      help: 'Generates an encrypted env.g.dart file from your .env file',
    );
    command.addOption(
      "file",
      abbr: "e",
      help: "The .env file to read from.",
      defaultValue: ".env",
    );
    command.addFlag(
      "dart-define",
      abbr: "d",
      help:
          "Use --dart-define mode for APP_KEY injection at build time instead of runtime.",
    );
    return command;
  }

  @override
  Future<void> handle(CommandResult result) async {
    final String envFileName = result.getString("file", defaultValue: ".env")!;
    final bool? useDartDefine = result.getBool("dart-define");

    final envFile = File(envFileName);
    final outputPath = 'lib/bootstrap/env.g.dart';
    final outputFile = File(outputPath);

    // Check if .env file exists
    if (!await envFile.exists()) {
      error('File not found: $envFileName');
      info('Create a .env file first or specify a different file with --file');
      return;
    }

    // Parse .env file
    final envContent = await envFile.readAsString();
    final envMap = _parseEnvFile(envContent);

    // Validate APP_KEY exists
    if (!envMap.containsKey('APP_KEY') || envMap['APP_KEY']!.isEmpty) {
      error('APP_KEY not found in $envFileName');
      info('Run "metro make:key" to generate an APP_KEY first.');
      return;
    }

    final appKey = envMap['APP_KEY']!;

    // Remove APP_KEY from the map (we don't want to include it in the generated file)
    envMap.remove('APP_KEY');

    // Encrypt all values using XOR with APP_KEY
    final encryptedMap = <String, String>{};
    for (final entry in envMap.entries) {
      encryptedMap[entry.key] = _xorEncrypt(entry.value, appKey);
    }

    // Generate the Dart file
    final dartCode = envStub(
      encryptedMap: encryptedMap,
      appKey: (useDartDefine ?? false) ? null : appKey,
      useDartDefine: useDartDefine ?? false,
    );

    // Ensure directory exists
    await outputFile.parent.create(recursive: true);

    // Write the file
    await outputFile.writeAsString(dartCode);

    info('Encrypted ${envFileName}');
    success('Generated $outputPath');

    if (useDartDefine == true) {
      info('');
      info('Build your app with:');
      info('  flutter build apk --dart-define=APP_KEY=$appKey');
      info('  flutter build ios --dart-define=APP_KEY=$appKey');
    }

    // Format the generated file
    await runProcess('dart format $outputPath', silent: true);
  }

  /// Parses a .env file content into a Map
  Map<String, String> _parseEnvFile(String content) {
    final map = <String, String>{};
    final lines = content.split('\n');

    for (var line in lines) {
      line = line.trim();

      // Skip empty lines and comments
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      // Find the first = sign
      final equalsIndex = line.indexOf('=');
      if (equalsIndex == -1) {
        continue;
      }

      final key = line.substring(0, equalsIndex).trim();
      var value = line.substring(equalsIndex + 1).trim();

      // Remove surrounding quotes if present
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      if (key.isNotEmpty) {
        map[key] = value;
      }
    }

    return map;
  }

  /// XOR encrypts a string using the provided key
  String _xorEncrypt(String text, String key) {
    final textBytes = utf8.encode(text);
    final keyBytes = utf8.encode(key);
    final encryptedBytes = <int>[];

    for (var i = 0; i < textBytes.length; i++) {
      encryptedBytes.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64Encode(encryptedBytes);
  }
}
