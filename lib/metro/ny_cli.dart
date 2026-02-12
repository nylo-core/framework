/// Metro CLI - Nylo's command-line companion for scaffolding Flutter apps.
///
/// Provides the base classes and utilities for creating custom Metro commands.
library nylo_framework;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:recase/recase.dart';
import 'package:yaml/yaml.dart';
export 'package:nylo_support/metro/ny_metro.dart';
export '/metro/helpers/metro_helpers.dart';
import 'package:nylo_support/metro/ny_metro.dart'
    show MetroService, forceFlag, helpFlag;
export 'package:dio/dio.dart';

/// Base class for custom commands
abstract class NyCustomCommand {
  /// Define the command configuration
  CommandBuilder builder(CommandBuilder commandBuilder) => commandBuilder;

  CommandBuilder? _builder;

  /// The command-line arguments passed to the command.
  List<String> arguments;

  /// Execute the command with parsed results
  Future<void> handle(CommandResult result);

  /// Creates a new command with the given [arguments].
  NyCustomCommand(this.arguments) {
    CommandBuilder commandBuilder = CommandBuilder();
    _builder = builder(commandBuilder);
  }

  /// Run the command
  Future<void> run() async {
    assert(
      _builder != null,
      'CommandBuilder must be initialized before running the command.',
    );

    // Handle help flag
    if (arguments.contains('--help') || arguments.contains('-h')) {
      print('\nUsage:');
      print(_builder!.usage);
      return;
    }

    final CommandResult result = _builder!.parse(arguments);
    await handle(result);
  }

  /// Run a process with the given command
  Future<int> runProcess(String command,
      {String? workingDirectory, bool? runInShell, bool silent = false}) async {
    // Parse command properly handling quotes
    final List<String> parts = _parseCommand(command);
    final String executable = parts[0];
    final List<String> args = parts.sublist(1);

    // Run the process
    final Process process = await Process.start(
      executable,
      args,
      mode: ProcessStartMode.normal,
      workingDirectory: workingDirectory,
      runInShell: runInShell ?? false,
    );

    if (silent == false) {
      // Listen to the process output
      process.stdout.transform(SystemEncoding().decoder).listen((String data) {
        // Print the output of the command
        print(data);
      });

      process.stderr.transform(SystemEncoding().decoder).listen((String data) {
        // Print the error output of the command
        print(data);
      });
    }

    // Wait for the process to complete
    final int exitCode = await process.exitCode;
    if (silent == false) {
      if (exitCode != 0) {
        // Print an error message if the process failed
        error('Command failed with exit code: $exitCode');
      }
    }

    // Return the exit code
    return exitCode;
  }

  // Helper method to parse command strings correctly handling quotes
  List<String> _parseCommand(String command) {
    final List<String> parts = [];
    bool inQuotes = false;
    String currentPart = '';
    String quoteChar = '';

    for (int i = 0; i < command.length; i++) {
      final char = command[i];

      if ((char == '"' || char == "'") && (i == 0 || command[i - 1] != '\\')) {
        if (!inQuotes) {
          inQuotes = true;
          quoteChar = char;
        } else if (char == quoteChar) {
          inQuotes = false;
          quoteChar = '';
        } else {
          currentPart += char;
        }
      } else if (char == ' ' && !inQuotes) {
        if (currentPart.isNotEmpty) {
          parts.add(currentPart);
          currentPart = '';
        }
      } else {
        currentPart += char;
      }
    }

    if (currentPart.isNotEmpty) {
      parts.add(currentPart);
    }

    return parts;
  }

  /// Add a package to the pubspec.yaml file
  Future<void> addPackage(String package,
      {String? version, bool dev = false}) async {
    await MetroService.addPackage(package, dev: dev, version: version);
  }

  /// Add multiple packages to the pubspec.yaml file
  Future<void> addPackages(List<String> packages, {bool dev = false}) async {
    await MetroService.addPackages(packages, dev: dev);
  }

  /// Prints a message in blue color
  void info(String message) {
    // Print info message in blue
    print('\x1B[34m$message\x1B[0m');
  }

  /// Prints a message in red color
  void error(String message) {
    // Print error message in red
    print('\x1B[31m$message\x1B[0m');
  }

  /// Prints a message in green color
  void success(String message) {
    // Print success message in green
    print('\x1B[32m$message\x1B[0m');
  }

  /// Prints a message in yellow color
  void warning(String message) {
    // Print warning message in yellow
    print('\x1B[33m$message\x1B[0m');
  }

  /// Asks the user a question and returns their response
  String prompt(String question, {String defaultValue = ''}) {
    // Print the question and default value if provided
    if (defaultValue.isNotEmpty) {
      print('$question (default: $defaultValue)');
    } else {
      print('$question');
    }

    // Explicitly flush stdout to ensure the prompt is displayed
    stdout.flush();

    // Try to read input in a more robust way
    String? input;
    try {
      input = stdin.readLineSync();
    } catch (e) {
      error('Error reading input: $e');
      // Fall back to default value in case of error
      return defaultValue;
    }

    // Trim the input and handle null/empty cases
    final trimmedInput = input?.trim() ?? '';

    // Return default value if user just presses Enter
    return trimmedInput.isEmpty ? defaultValue : trimmedInput;
  }

  /// Alias for [prompt] for brevity.
  String ask(String question, {String defaultValue = ''}) =>
      prompt(question, defaultValue: defaultValue);

  /// Asks the user a yes/no question and returns a boolean
  bool confirm(String question, {bool defaultValue = false}) {
    final defaultText = defaultValue ? 'Y/n' : 'y/N';
    stdout.write('$question [$defaultText] ');

    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';

    if (input.isEmpty) {
      return defaultValue;
    }

    return input == 'y' || input == 'yes';
  }

  /// Asks the user to select an option from a list
  String select(String question, List<String> options,
      {String? defaultOption}) {
    info(question);

    for (int i = 0; i < options.length; i++) {
      final option = options[i];
      final isDefault = option == defaultOption;
      final marker = isDefault ? '*' : ' ';

      print('  $marker ${i + 1}. $option');
    }

    stdout.write('Enter your choice (1-${options.length}): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    // Try to parse as integer first
    try {
      final index = int.parse(input) - 1;
      if (index >= 0 && index < options.length) {
        return options[index];
      }
    } catch (_) {
      // Not a number, check if it matches an option directly
      if (options.contains(input)) {
        return input;
      }
    }

    // Return default or first option if input is invalid
    return defaultOption ?? options.first;
  }

  /// Multi-select - allows user to select multiple options
  List<String> multiSelect(String question, List<String> options) {
    final selected = <String>[];

    print('$question');
    print(
        'Enter the numbers of your choices (comma-separated) or "all" for all options:');

    // Display options with numbers
    for (int i = 0; i < options.length; i++) {
      print('  ${i + 1}. ${options[i]}');
    }

    print('\nYour selection (e.g. "1,3,4" or "all"): ');
    final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';

    if (input == 'all') {
      return List<String>.from(options);
    }

    // Parse number inputs
    final selections = input.split(',');
    for (final selection in selections) {
      try {
        final index = int.parse(selection.trim()) - 1;
        if (index >= 0 && index < options.length) {
          selected.add(options[index]);
        }
      } catch (_) {
        // Skip invalid inputs
      }
    }

    return selected;
  }

  /// A simplified API wrapper function that doesn't require type parameter
  Future<T?> api<T>(Future<T?> Function(ApiService) request) async {
    final service = ApiService();
    try {
      return await request(service);
    } catch (e) {
      error('API Error: $e');
      rethrow;
    }
  }

  /// Sleeps for a specified number of [seconds].
  ///
  /// Optionally accepts [microseconds] for finer control.
  Future<void> sleep(int seconds, [int microseconds = 0]) async {
    await Future.delayed(Duration(
      seconds: seconds,
      microseconds: microseconds,
    ));
  }

  // ============================================
  // Output Helpers
  // ============================================

  /// Prints a message without any color formatting
  void line(String message) {
    print(message);
  }

  /// Prints one or more blank lines
  void newLine([int count = 1]) {
    for (int i = 0; i < count; i++) {
      print('');
    }
  }

  /// Prints a message in gray/muted color
  void comment(String message) {
    print('\x1B[90m$message\x1B[0m');
  }

  /// Prints a prominent alert box with a message
  void alert(String message) {
    final border = '═' * (message.length + 4);
    print('\x1B[33m╔$border╗\x1B[0m');
    print('\x1B[33m║\x1B[0m  $message  \x1B[33m║\x1B[0m');
    print('\x1B[33m╚$border╝\x1B[0m');
  }

  // ============================================
  // File System Helpers
  // ============================================

  /// Check if a file exists at the given path
  bool fileExists(String path) {
    return File(path).existsSync();
  }

  /// Check if a directory exists at the given path
  bool directoryExists(String path) {
    return Directory(path).existsSync();
  }

  /// Read the contents of a file as a string
  Future<String> readFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', path);
    }
    return await file.readAsString();
  }

  /// Read the contents of a file synchronously
  String readFileSync(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', path);
    }
    return file.readAsStringSync();
  }

  /// Write content to a file (creates the file if it doesn't exist)
  Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Write content to a file synchronously
  void writeFileSync(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  /// Append content to a file (creates the file if it doesn't exist)
  Future<void> appendFile(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, mode: FileMode.append);
  }

  /// Ensure a directory exists, creating it if necessary
  Future<void> ensureDirectory(String path) async {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
  }

  /// Delete a file if it exists
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Copy a file from source to destination
  Future<void> copyFile(String source, String destination) async {
    final sourceFile = File(source);
    if (!sourceFile.existsSync()) {
      throw FileSystemException('Source file not found', source);
    }
    await File(destination).parent.create(recursive: true);
    await sourceFile.copy(destination);
  }

  // ============================================
  // Environment & Platform Helpers
  // ============================================

  /// Get an environment variable value with optional default
  String env(String key, [String defaultValue = '']) {
    return Platform.environment[key] ?? defaultValue;
  }

  /// Check if running on Windows
  bool get isWindows => Platform.isWindows;

  /// Check if running on macOS
  bool get isMacOS => Platform.isMacOS;

  /// Check if running on Linux
  bool get isLinux => Platform.isLinux;

  /// Get the current working directory
  String get workingDirectory => Directory.current.path;

  // ============================================
  // Input Helpers
  // ============================================

  /// Asks the user for sensitive input (password, tokens, etc.)
  /// Input is hidden from display
  String promptSecret(String question) {
    stdout.write('$question ');
    stdout.flush();

    // Try to disable echo for password input
    try {
      stdin.echoMode = false;
      final input = stdin.readLineSync() ?? '';
      stdin.echoMode = true;
      print(''); // New line after hidden input
      return input.trim();
    } catch (e) {
      // Fallback if echoMode is not supported
      stdin.echoMode = true;
      warning('Warning: Input may be visible');
      return stdin.readLineSync()?.trim() ?? '';
    }
  }

  // ============================================
  // Control Flow Helpers
  // ============================================

  /// Exit the command with an error message and exit code
  Never abort([String? message, int exitCode = 1]) {
    if (message != null) {
      error(message);
    }
    exit(exitCode);
  }

  // ============================================
  // Table Helper
  // ============================================

  /// Display data in a formatted table
  void table(List<String> headers, List<List<String>> rows) {
    final consoleTable = ConsoleTable(headers: headers, rows: rows);
    consoleTable.render();
  }

  // ============================================
  // Progress Bar Helper
  // ============================================

  /// Create a progress bar for manual control
  ConsoleProgressBar progressBar(int total, {String? message}) {
    return ConsoleProgressBar(total: total, message: message);
  }

  // ============================================
  // String Case Conversion Helpers
  // ============================================

  /// Convert a string to snake_case
  /// Example: "MyComponent" -> "my_component"
  String snakeCase(String input) => ReCase(input).snakeCase;

  /// Convert a string to camelCase
  /// Example: "my_component" -> "myComponent"
  String camelCase(String input) => ReCase(input).camelCase;

  /// Convert a string to PascalCase
  /// Example: "my_component" -> "MyComponent"
  String pascalCase(String input) => ReCase(input).pascalCase;

  /// Convert a string to Title Case
  /// Example: "my_component" -> "My Component"
  String titleCase(String input) => ReCase(input).titleCase;

  /// Convert a string to kebab-case
  /// Example: "MyComponent" -> "my-component"
  String kebabCase(String input) => ReCase(input).paramCase;

  /// Convert a string to CONSTANT_CASE
  /// Example: "myComponent" -> "MY_COMPONENT"
  String constantCase(String input) => ReCase(input).constantCase;

  // ============================================
  // Flutter Project Path Helpers
  // ============================================

  /// Path to models directory
  String get modelsPath => 'lib/app/models';

  /// Path to controllers directory
  String get controllersPath => 'lib/app/controllers';

  /// Path to widgets directory
  String get widgetsPath => 'lib/resources/widgets';

  /// Path to pages directory
  String get pagesPath => 'lib/resources/pages';

  /// Path to commands directory
  String get commandsPath => 'lib/app/commands';

  /// Path to config directory
  String get configPath => 'lib/config';

  /// Path to providers directory
  String get providersPath => 'lib/app/providers';

  /// Path to events directory
  String get eventsPath => 'lib/app/events';

  /// Path to networking directory
  String get networkingPath => 'lib/app/networking';

  /// Path to themes directory
  String get themesPath => 'lib/resources/themes';

  /// Build a path within the project
  /// Example: projectPath('app/models/user.dart') -> 'lib/app/models/user.dart'
  String projectPath(String relativePath) {
    if (relativePath.startsWith('lib/')) {
      return relativePath;
    }
    return 'lib/$relativePath';
  }

  // ============================================
  // File Scaffolding Helpers
  // ============================================

  /// Create a file with common scaffolding patterns
  /// Returns true if the file was created successfully
  Future<bool> scaffold({
    required String path,
    required String content,
    bool force = false,
    String? successMessage,
  }) async {
    final file = File(path);

    // Check if file already exists
    if (await file.exists() && !force) {
      error('$path already exists');
      comment('Use --force to overwrite.');
      return false;
    }

    // Ensure directory exists
    await file.parent.create(recursive: true);

    // Write the file
    await file.writeAsString(content);

    if (successMessage != null) {
      success(successMessage);
    } else {
      success('Created: $path');
    }

    return true;
  }

  /// Create multiple files at once
  Future<void> scaffoldMany(List<ScaffoldFile> files,
      {bool force = false}) async {
    for (final file in files) {
      await scaffold(
        path: file.path,
        content: file.content,
        force: force,
        successMessage: file.successMessage,
      );
    }
  }

  // ============================================
  // JSON/YAML File Helpers
  // ============================================

  /// Read a JSON file and return its contents as a Map
  Future<Map<String, dynamic>> readJson(String path) async {
    final content = await readFile(path);
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Read a JSON file and return its contents as a List
  Future<List<dynamic>> readJsonArray(String path) async {
    final content = await readFile(path);
    return jsonDecode(content) as List<dynamic>;
  }

  /// Write data to a JSON file
  Future<void> writeJson(String path, dynamic data,
      {bool pretty = true}) async {
    String content;
    if (pretty) {
      content = const JsonEncoder.withIndent('  ').convert(data);
    } else {
      content = jsonEncode(data);
    }
    await writeFile(path, content);
  }

  /// Append an item to a JSON array file
  Future<void> appendToJsonArray(String path, Map<String, dynamic> item,
      {String? uniqueKey}) async {
    List<dynamic> array;

    if (fileExists(path)) {
      array = await readJsonArray(path);
    } else {
      array = [];
    }

    // Check for duplicates if uniqueKey is provided
    if (uniqueKey != null) {
      final exists =
          array.any((existing) => existing[uniqueKey] == item[uniqueKey]);
      if (exists) {
        comment('Item with $uniqueKey="${item[uniqueKey]}" already exists');
        return;
      }
    }

    array.add(item);
    await writeJson(path, array);
  }

  /// Read a YAML file and return its contents as a Map
  Future<Map<String, dynamic>> readYaml(String path) async {
    final content = await readFile(path);
    final yaml = loadYaml(content);
    return _yamlToMap(yaml);
  }

  /// Convert YamlMap to regular Map/List/scalar recursively
  dynamic _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      return yaml
          .map((key, value) => MapEntry(key.toString(), _yamlToMap(value)));
    } else if (yaml is YamlList) {
      return yaml.map((e) => _yamlToMap(e)).toList();
    }
    return yaml is Map ? Map<String, dynamic>.from(yaml) : yaml;
  }

  // ============================================
  // Dart/Flutter Command Helpers
  // ============================================

  /// Run dart format on a file or directory
  Future<int> dartFormat(String path) async {
    return await runProcess('dart format $path',
        runInShell: true, silent: true);
  }

  /// Run dart analyze on a path (defaults to current directory)
  Future<int> dartAnalyze([String? path]) async {
    final target = path ?? '.';
    return await runProcess('dart analyze $target', runInShell: true);
  }

  /// Run flutter pub get
  Future<int> flutterPubGet() async {
    return await runProcess('flutter pub get', runInShell: true);
  }

  /// Run flutter clean
  Future<int> flutterClean() async {
    return await runProcess('flutter clean', runInShell: true);
  }

  /// Run flutter build with a target
  Future<int> flutterBuild(String target,
      {List<String> args = const []}) async {
    final argsStr = args.isNotEmpty ? ' ${args.join(' ')}' : '';
    return await runProcess('flutter build $target$argsStr', runInShell: true);
  }

  /// Run flutter test
  Future<int> flutterTest([String? path]) async {
    final target = path != null ? ' $path' : '';
    return await runProcess('flutter test$target', runInShell: true);
  }

  // ============================================
  // Dart File Manipulation Helpers
  // ============================================

  /// Add an import statement to a Dart file
  /// The import will be added after the last existing import
  Future<void> addImport(String filePath, String importStatement) async {
    if (!fileExists(filePath)) {
      error('File not found: $filePath');
      return;
    }

    String content = await readFile(filePath);

    // Check if import already exists
    if (content.contains(importStatement)) {
      comment('Import already exists in $filePath');
      return;
    }

    // Find the last import statement
    final importRegex = RegExp(r"^import .*?;$", multiLine: true);
    final matches = importRegex.allMatches(content).toList();

    if (matches.isNotEmpty) {
      final lastImportEnd = matches.last.end;
      content = content.substring(0, lastImportEnd) +
          '\n$importStatement' +
          content.substring(lastImportEnd);
    } else {
      // No imports found, add at the beginning
      content = '$importStatement\n$content';
    }

    await writeFile(filePath, content);
  }

  /// Insert code before the closing brace of the last class in a file
  /// Useful for adding methods to a class
  Future<void> insertBeforeClosingBrace(String filePath, String code) async {
    if (!fileExists(filePath)) {
      error('File not found: $filePath');
      return;
    }

    String content = await readFile(filePath);

    // Find the last class declaration and track its closing brace
    final classMatches = RegExp(r'class\s+\w+').allMatches(content).toList();
    if (classMatches.isNotEmpty) {
      final lastClassStart = classMatches.last.start;
      int braceCount = 0;
      int? classBraceIndex;
      for (int i = lastClassStart; i < content.length; i++) {
        if (content[i] == '{') braceCount++;
        if (content[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            classBraceIndex = i;
            break;
          }
        }
      }
      if (classBraceIndex != null) {
        content = content.substring(0, classBraceIndex) +
            '\n$code\n' +
            content.substring(classBraceIndex);
        await writeFile(filePath, content);
      }
    }
  }

  /// Check if a file contains a specific string or pattern
  Future<bool> fileContains(String filePath, String identifier) async {
    if (!fileExists(filePath)) {
      return false;
    }
    final content = await readFile(filePath);
    return content.contains(identifier);
  }

  /// Check if a file contains a pattern (regex)
  Future<bool> fileContainsPattern(String filePath, Pattern pattern) async {
    if (!fileExists(filePath)) {
      return false;
    }
    final content = await readFile(filePath);
    return pattern.allMatches(content).isNotEmpty;
  }

  // ============================================
  // Directory Helpers
  // ============================================

  /// List all entities in a directory
  List<FileSystemEntity> listDirectory(String path, {bool recursive = false}) {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return [];
    }
    return directory.listSync(recursive: recursive);
  }

  /// Find files matching criteria in a directory
  List<File> findFiles(
    String directory, {
    String? extension,
    Pattern? namePattern,
    bool recursive = true,
  }) {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      return [];
    }

    return dir.listSync(recursive: recursive).whereType<File>().where((file) {
      final fileName = file.path.split(Platform.pathSeparator).last;

      if (extension != null && !fileName.endsWith(extension)) {
        return false;
      }

      if (namePattern != null && !namePattern.allMatches(fileName).isNotEmpty) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Delete a directory and all its contents
  Future<void> deleteDirectory(String path) async {
    final directory = Directory(path);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Copy a directory and all its contents to a new location
  Future<void> copyDirectory(String source, String destination) async {
    final sourceDir = Directory(source);
    if (!await sourceDir.exists()) {
      throw FileSystemException('Source directory not found', source);
    }

    final destDir = Directory(destination);
    await destDir.create(recursive: true);

    await for (final entity in sourceDir.list(recursive: true)) {
      final relativePath = entity.path.substring(sourceDir.path.length + 1);
      final destPath = '$destination${Platform.pathSeparator}$relativePath';

      if (entity is File) {
        await File(destPath).parent.create(recursive: true);
        await entity.copy(destPath);
      } else if (entity is Directory) {
        await Directory(destPath).create(recursive: true);
      }
    }
  }

  // ============================================
  // Validation Helpers
  // ============================================

  /// Check if a string is a valid Dart identifier
  bool isValidDartIdentifier(String name) {
    if (name.isEmpty) return false;

    // Must start with letter or underscore
    if (!RegExp(r'^[a-zA-Z_]').hasMatch(name)) return false;

    // Can only contain letters, digits, and underscores
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name)) return false;

    // Cannot be a Dart reserved word
    const reservedWords = {
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'covariant',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'Function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'late',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'required',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield',
    };

    return !reservedWords.contains(name);
  }

  /// Require a non-empty first argument from the command result
  /// Exits with an error if no argument is provided
  String requireArgument(CommandResult result, {String? message}) {
    if (result.arguments.isEmpty || result.arguments.first.trim().isEmpty) {
      abort(message ?? 'A name argument is required');
    }
    return result.arguments.first.trim();
  }

  /// Clean and validate a class name
  /// Removes common suffixes and converts to PascalCase
  String cleanClassName(String name, {List<String> removeSuffixes = const []}) {
    String cleaned = name;

    for (final suffix in removeSuffixes) {
      final pattern = RegExp('(_?$suffix)\$', caseSensitive: false);
      cleaned = cleaned.replaceAll(pattern, '');
    }

    return pascalCase(cleaned);
  }

  /// Clean a file name (converts to snake_case and adds .dart extension if missing)
  String cleanFileName(String name, {String extension = '.dart'}) {
    String cleaned = snakeCase(name);
    if (!cleaned.endsWith(extension)) {
      cleaned += extension;
    }
    return cleaned;
  }

  // ============================================
  // Task Runner Helpers
  // ============================================

  /// Run a list of named tasks with status output
  Future<void> runTasks(List<CommandTask> tasks) async {
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final taskNumber = '[${i + 1}/${tasks.length}]';

      try {
        info('$taskNumber ${task.name}...');
        await task.action();
        success('$taskNumber ${task.name} completed');
      } catch (e) {
        error('$taskNumber ${task.name} failed: $e');
        if (task.stopOnError) {
          rethrow;
        }
      }
    }
  }

  /// Run tasks with a spinner animation
  Future<void> runTasksWithSpinner(List<CommandTask> tasks) async {
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final spinner = ConsoleSpinner('${task.name}...');
      spinner.start();

      try {
        await task.action();
        spinner.stop(
          completionMessage: '${task.name} completed',
          success: true,
        );
      } catch (e) {
        spinner.stop(
          completionMessage: '${task.name} failed: $e',
          success: false,
        );
        if (task.stopOnError) {
          rethrow;
        }
      }
    }
  }
}

/// A class that handles showing a spinner animation in the console
class ConsoleSpinner {
  static const List<String> _spinnerFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏'
  ];

  Timer? _timer;
  String _message;
  bool _running = false;
  int _currentFrame = 0;
  String? _previousLine;

  /// Creates a [ConsoleSpinner] with the given initial [_message].
  ConsoleSpinner(this._message);

  /// Start the spinner with an optional message
  void start([String? message]) {
    if (_running) return;

    if (message != null) {
      _message = message;
    }

    _running = true;
    _currentFrame = 0;

    // Hide cursor
    stdout.write('\x1B[?25l');

    _timer = Timer.periodic(Duration(milliseconds: 80), (_) {
      _clearPreviousLine();
      final frame = _spinnerFrames[_currentFrame];
      stdout.write('\r\x1B[36m$frame\x1B[0m $_message');
      _previousLine = '\r\x1B[36m$frame\x1B[0m $_message';
      _currentFrame = (_currentFrame + 1) % _spinnerFrames.length;
    });
  }

  /// Update the spinner message
  void update(String message) {
    _message = message;
  }

  /// Stop the spinner with an optional completion message
  void stop({String? completionMessage, bool success = true}) {
    if (!_running) return;

    _timer?.cancel();
    _timer = null;
    _running = false;

    _clearPreviousLine();

    if (completionMessage != null) {
      final color = success ? '\x1B[32m' : '\x1B[31m';
      final symbol = success ? '✓' : '✗';
      stdout.write('\r$color$symbol\x1B[0m $completionMessage\n');
    }

    // Show cursor again
    stdout.write('\x1B[?25h');
  }

  void _clearPreviousLine() {
    if (_previousLine != null) {
      final length = _previousLine!.length;
      stdout.write('\r${' ' * length}\r');
    }
  }
}

/// A class that renders a formatted ASCII table in the console.
class ConsoleTable {
  /// The column headers for the table.
  final List<String> headers;

  /// The data rows to display.
  final List<List<String>> rows;

  /// Creates a [ConsoleTable] with the given [headers] and [rows].
  ConsoleTable({required this.headers, required this.rows});

  /// Render the table to stdout
  void render() {
    if (headers.isEmpty) return;

    // Calculate column widths
    final columnWidths = _calculateColumnWidths();

    // Build and print the table
    _printHorizontalBorder(columnWidths, '┌', '┬', '┐');
    _printRow(headers, columnWidths, isHeader: true);
    _printHorizontalBorder(columnWidths, '├', '┼', '┤');

    for (final row in rows) {
      _printRow(row, columnWidths);
    }

    _printHorizontalBorder(columnWidths, '└', '┴', '┘');
  }

  List<int> _calculateColumnWidths() {
    final widths = List<int>.filled(headers.length, 0);

    // Check header widths
    for (int i = 0; i < headers.length; i++) {
      widths[i] = headers[i].length;
    }

    // Check row widths
    for (final row in rows) {
      for (int i = 0; i < row.length && i < widths.length; i++) {
        if (row[i].length > widths[i]) {
          widths[i] = row[i].length;
        }
      }
    }

    return widths;
  }

  void _printHorizontalBorder(
      List<int> widths, String left, String middle, String right) {
    final buffer = StringBuffer(left);
    for (int i = 0; i < widths.length; i++) {
      buffer.write('─' * (widths[i] + 2));
      if (i < widths.length - 1) {
        buffer.write(middle);
      }
    }
    buffer.write(right);
    print(buffer.toString());
  }

  void _printRow(List<String> cells, List<int> widths,
      {bool isHeader = false}) {
    final buffer = StringBuffer('│');
    for (int i = 0; i < widths.length; i++) {
      final cell = i < cells.length ? cells[i] : '';
      final paddedCell = cell.padRight(widths[i]);
      if (isHeader) {
        buffer.write(' \x1B[1m$paddedCell\x1B[0m │');
      } else {
        buffer.write(' $paddedCell │');
      }
    }
    print(buffer.toString());
  }
}

/// A class that displays a progress bar in the console.
class ConsoleProgressBar {
  /// The total number of steps.
  final int total;

  /// Optional message displayed alongside the progress bar.
  String? message;
  int _current = 0;
  bool _started = false;
  final int _barWidth;

  /// Creates a [ConsoleProgressBar] with the given [total] steps.
  ConsoleProgressBar({
    required this.total,
    this.message,
    int barWidth = 30,
  }) : _barWidth = barWidth;

  /// Get the current progress value
  int get current => _current;

  /// Get the progress as a percentage (0-100)
  double get percentage => total > 0 ? (_current / total) * 100 : 0;

  /// Start the progress bar
  void start() {
    if (_started) return;
    _started = true;
    // Hide cursor
    stdout.write('\x1B[?25l');
    _render();
  }

  /// Update the progress bar by incrementing the current value
  void tick([int amount = 1]) {
    _current = (_current + amount).clamp(0, total);
    _render();
  }

  /// Set the progress bar to a specific value
  void update(int value) {
    _current = value.clamp(0, total);
    _render();
  }

  /// Update the message displayed alongside the progress bar
  void updateMessage(String newMessage) {
    message = newMessage;
    _render();
  }

  /// Complete the progress bar
  void complete([String? completionMessage]) {
    _current = total;
    _render();
    print(''); // New line
    // Show cursor
    stdout.write('\x1B[?25h');
    if (completionMessage != null) {
      print('\x1B[32m✓\x1B[0m $completionMessage');
    }
  }

  /// Stop the progress bar without completing
  void stop() {
    print(''); // New line
    // Show cursor
    stdout.write('\x1B[?25h');
  }

  void _render() {
    final filledWidth =
        total > 0 ? ((_current / total) * _barWidth).round() : 0;
    final emptyWidth = _barWidth - filledWidth;

    final filled = '█' * filledWidth;
    final empty = '░' * emptyWidth;
    final percent = percentage.toStringAsFixed(0).padLeft(3);

    final messageStr = message != null ? ' $message' : '';

    stdout.write('\r[$filled$empty] $percent%$messageStr');
  }
}

/// Extension method to add spinner functionality to NyCustomCommand
extension SpinnerExtension on NyCustomCommand {
  /// Run a task with a spinner animation
  Future<T> withSpinner<T>({
    required Future<T> Function() task,
    required String message,
    String? successMessage,
    String? errorMessage,
  }) async {
    final spinner = ConsoleSpinner(message);
    spinner.start();

    try {
      final result = await task();
      spinner.stop(
        completionMessage: successMessage ?? '$message completed',
        success: true,
      );
      return result;
    } catch (e) {
      spinner.stop(
        completionMessage: errorMessage ?? 'Failed: $e',
        success: false,
      );
      rethrow;
    }
  }

  /// Create and return a spinner instance for manual control
  ConsoleSpinner createSpinner(String message) {
    return ConsoleSpinner(message);
  }

  /// Process a list of items with a progress bar
  /// Returns a list of results from processing each item
  Future<List<R>> withProgress<T, R>({
    required List<T> items,
    required Future<R> Function(T item, int index) process,
    String? message,
    String? completionMessage,
  }) async {
    final progress = ConsoleProgressBar(total: items.length, message: message);
    progress.start();

    final results = <R>[];

    for (int i = 0; i < items.length; i++) {
      final result = await process(items[i], i);
      results.add(result);
      progress.tick();
    }

    progress.complete(completionMessage);
    return results;
  }

  /// Process items synchronously with a progress bar
  List<R> withProgressSync<T, R>({
    required List<T> items,
    required R Function(T item, int index) process,
    String? message,
    String? completionMessage,
  }) {
    final progress = ConsoleProgressBar(total: items.length, message: message);
    progress.start();

    final results = <R>[];

    for (int i = 0; i < items.length; i++) {
      final result = process(items[i], i);
      results.add(result);
      progress.tick();
    }

    progress.complete(completionMessage);
    return results;
  }
}

/// A simple API service that wraps Dio for making HTTP requests.
class ApiService {
  final Dio _dio;

  /// Creates an [ApiService] with an optional custom [dio] instance.
  ApiService({Dio? dio}) : _dio = dio ?? Dio() {
    // Configure dio instance with defaults
    _dio.options.connectTimeout = Duration(seconds: 30);
    _dio.options.receiveTimeout = Duration(seconds: 30);
    _dio.options.responseType = ResponseType.json;

    // Add interceptors if needed
    _dio.interceptors.add(LogInterceptor(responseBody: true));
  }

  /// GET request
  Future<T?> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return _handleResponse<T>(response);
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// POST request
  Future<T?> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _handleResponse<T>(response);
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// PUT request
  Future<T?> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _handleResponse<T>(response);
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// DELETE request
  Future<T?> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return _handleResponse<T>(response);
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// PATCH request
  Future<T?> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _handleResponse<T>(response);
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// Handle successful response
  T? _handleResponse<T>(Response response) {
    if (response.statusCode! >= 200 && response.statusCode! < 300) {
      return response.data;
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Server responded with status code: ${response.statusCode}',
      );
    }
  }

  /// Handle errors
  void _handleError(dynamic error) {
    if (error is DioException) {
      // Handle Dio specific errors
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw TimeoutException('Request timeout');
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;
          throw ApiException(
            code: statusCode ?? 0,
            message: 'Server error: $statusCode',
            data: data,
          );
        case DioExceptionType.cancel:
          throw RequestCancelledException('Request was cancelled');
        default:
          throw NetworkException('Network error occurred');
      }
    } else {
      throw UnknownException('Unknown error: ${error.toString()}');
    }
  }
}

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  /// The HTTP status code.
  final int code;

  /// A description of the error.
  final String message;

  /// Optional response data.
  final dynamic data;

  /// Creates an [ApiException] with the given [code], [message], and optional [data].
  ApiException({required this.code, required this.message, this.data});

  @override
  String toString() => 'ApiException: $code - $message';
}

/// Exception thrown when a request times out.
class TimeoutException implements Exception {
  /// A description of the timeout.
  final String message;

  /// Creates a [TimeoutException] with the given [message].
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

/// Exception thrown when a network error occurs.
class NetworkException implements Exception {
  /// A description of the error.
  final String message;

  /// Creates a [NetworkException] with the given [message].
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception thrown when a request is cancelled.
class RequestCancelledException implements Exception {
  /// A description of the cancellation.
  final String message;

  /// Creates a [RequestCancelledException] with the given [message].
  RequestCancelledException(this.message);

  @override
  String toString() => 'RequestCancelledException: $message';
}

/// Exception thrown when an unknown error occurs.
class UnknownException implements Exception {
  /// A description of the error.
  final String message;

  /// Creates an [UnknownException] with the given [message].
  UnknownException(this.message);

  @override
  String toString() => 'UnknownException: $message';
}

/// A fluent wrapper around [ArgParser] to make command definitions more readable.
class CommandBuilder {
  final ArgParser _parser = ArgParser();
  final Map<String, dynamic> _defaults = {};

  /// Creates a new [CommandBuilder].
  CommandBuilder() {}

  /// Add an option (--option or -o)
  CommandBuilder addOption(
    String name, {
    String? abbr,
    String? help,
    List<String>? allowed,
    String? defaultValue,
  }) {
    _parser.addOption(
      name,
      abbr: abbr,
      help: help,
      allowed: allowed,
    );

    if (defaultValue != null) {
      _defaults[name] = defaultValue;
    }

    return this;
  }

  /// Add a flag (boolean option, --flag or -f)
  CommandBuilder addFlag(
    String name, {
    String? abbr,
    String? help,
    bool defaultValue = false,
  }) {
    _parser.addFlag(
      name,
      abbr: abbr,
      help: help,
      defaultsTo: defaultValue,
    );

    _defaults[name] = defaultValue;

    return this;
  }

  /// Parse arguments and return a result object with convenient accessors
  CommandResult parse(List<String> arguments) {
    final ArgResults results = _parser.parse(arguments);
    return CommandResult(results, _defaults);
  }

  /// Get the usage string for help text
  String get usage => _parser.usage;
}

/// Wrapper around [ArgResults] with convenient typed accessors.
class CommandResult {
  final ArgResults _results;
  final Map<String, dynamic> _defaults;

  /// Creates a [CommandResult] from parsed [_results] and [_defaults].
  CommandResult(this._results, this._defaults);

  /// Check if help flag is set
  bool get hasHelpFlag => getBool(helpFlag) ?? false;

  /// Check if force flag is set
  bool get hasForceFlag => getBool(forceFlag) ?? false;

  /// Get a value with typed access, falling back to default if provided
  T? get<T>(String name) {
    if (_results.wasParsed(name)) {
      return _results[name] as T?;
    }
    return _defaults.containsKey(name) ? _defaults[name] as T? : null;
  }

  /// Get a string value with a fallback
  String? getString(String name, {String? defaultValue}) {
    return get<String>(name) ?? defaultValue;
  }

  /// Get a boolean value with a fallback
  bool? getBool(String name, {bool? defaultValue}) {
    return get<bool>(name) ?? defaultValue;
  }

  /// Get an integer value with a fallback
  int? getInt(String name, {int? defaultValue}) {
    return get<int>(name) ?? defaultValue;
  }

  /// Get all the command line arguments
  List<String> get arguments => _results.arguments;

  /// Get the rest arguments (unparsed)
  List<String> get rest => _results.rest;
}

/// Represents a file to be scaffolded
class ScaffoldFile {
  /// The path where the file will be created
  final String path;

  /// The content to write to the file
  final String content;

  /// Optional success message to display after creation
  final String? successMessage;

  const ScaffoldFile({
    required this.path,
    required this.content,
    this.successMessage,
  });
}

/// Represents a task to be executed by the task runner
class CommandTask {
  /// The name/description of the task
  final String name;

  /// The action to execute
  final Future<void> Function() action;

  /// Whether to stop execution if this task fails
  final bool stopOnError;

  const CommandTask(
    this.name,
    this.action, {
    this.stopOnError = true,
  });
}
