library nylo_framework;

import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:nylo_support/metro/metro_service.dart';
import 'package:dio/dio.dart';

export 'package:nylo_support/metro/metro_service.dart';
export 'package:nylo_support/metro/metro_console.dart';
export 'package:nylo_support/metro/constants/strings.dart';
export 'package:nylo_support/metro/models/metro_project_file.dart';
export 'package:nylo_support/metro/models/ny_command.dart';
export 'package:nylo_support/metro/models/ny_template.dart';
export 'package:dio/dio.dart';

/// Base class for custom commands
abstract class NyCustomCommand {
  /// Define the command configuration
  CommandBuilder get builder;

  List<String> arguments;

  /// Execute the command with parsed results
  Future<void> handle(CommandResult result);

  NyCustomCommand(this.arguments);

  /// Run the command
  run() {
    // Handle help flag
    if (arguments.contains('--help') || arguments.contains('-h')) {
      print('\nUsage:');
      print(builder.usage);
      return;
    }

    final CommandResult result = builder.parse(arguments);
    handle(result);
  }

  /// Run a process with the given command
  runProcess(String command,
      {String? workingDirectory, bool? runInShell, bool silent = false}) async {
    if (silent == false) {
      // Print the command being run
      print('Running command: $command');
    }

    // Split the command into parts
    final List<String> parts = command.split(' ');
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
      } else {
        // Print a success message if the process succeeded
        success('Command completed successfully.');
      }
    }

    // Return the exit code
    return exitCode;
  }

  /// Add a package to the pubspec.yaml file
  addPackage(String package, {String? version, bool dev = false}) {
    MetroService.addPackage(package, dev: dev, version: version);
  }

  /// Add multiple packages to the pubspec.yaml file
  addPackages(List<String> packages, {bool dev = false}) {
    MetroService.addPackages(packages, dev: dev);
  }

  /// Prints a message in blue color
  info(String message) {
    // Print info message in blue
    print('\x1B[34m$message\x1B[0m');
  }

  /// Prints a message in red color
  error(String message) {
    // Print error message in red
    print('\x1B[31m$message\x1B[0m');
  }

  /// Prints a message in green color
  success(String message) {
    // Print success message in green
    print('\x1B[32m$message\x1B[0m');
  }

  /// Prints a message in yellow color
  warning(String message) {
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

  /// sleep for a specified number of seconds
  /// [optional] microseconds
  Future<void> sleep(int seconds, [int microseconds = 0]) async {
    await Future.delayed(Duration(
      seconds: seconds,
      microseconds: microseconds,
    ));
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
}

/// API Service that wraps Dio
class ApiService {
  final Dio _dio;

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

/// Custom exception classes
class ApiException implements Exception {
  final int code;
  final String message;
  final dynamic data;

  ApiException({required this.code, required this.message, this.data});

  @override
  String toString() => 'ApiException: $code - $message';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class RequestCancelledException implements Exception {
  final String message;
  RequestCancelledException(this.message);

  @override
  String toString() => 'RequestCancelledException: $message';
}

class UnknownException implements Exception {
  final String message;
  UnknownException(this.message);

  @override
  String toString() => 'UnknownException: $message';
}

/// A fluent wrapper around ArgParser to make command definitions more readable
class CommandBuilder {
  final ArgParser _parser = ArgParser();
  final Map<String, dynamic> _defaults = {};

  CommandBuilder() {
    // Add help flag by default
    addFlag('help', abbr: 'h', help: 'Show help information');
  }

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

/// Wrapper around ArgResults with convenient accessors
class CommandResult {
  final ArgResults _results;
  final Map<String, dynamic> _defaults;

  CommandResult(this._results, this._defaults);

  /// Get a value with typed access, falling back to default if provided
  T? get<T>(String name) {
    if (_results.wasParsed(name)) {
      return _results[name] as T?;
    }
    return _defaults.containsKey(name) ? _defaults[name] as T? : null;
  }

  /// Get a string value with a fallback
  String getString(String name, {String defaultValue = ''}) {
    return get<String>(name) ?? defaultValue;
  }

  /// Get a boolean value with a fallback
  bool getBool(String name, {bool defaultValue = false}) {
    return get<bool>(name) ?? defaultValue;
  }

  /// Get an integer value with a fallback
  int getInt(String name, {int defaultValue = 0}) {
    return get<int>(name) ?? defaultValue;
  }

  /// Get all the command line arguments
  List<String> get arguments => _results.arguments;

  /// Get the rest arguments (unparsed)
  List<String> get rest => _results.rest;
}
