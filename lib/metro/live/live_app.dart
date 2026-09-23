import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'json_rpc_client.dart';

/// Thrown when a live command can't run, with a message for the terminal.
class LiveCommandException implements Exception {
  /// Creates a [LiveCommandException] with a user-facing [message].
  LiveCommandException(this.message);

  /// What went wrong and how to fix it.
  final String message;

  @override
  String toString() => message;
}

/// Thrown when a running app was built from a different project.
///
/// Many Nylo apps keep the default package name `flutter_app`, so a matching
/// package name alone doesn't prove an app belongs to the current project.
class LiveProjectMismatchException extends LiveCommandException {
  /// Creates a [LiveProjectMismatchException] for an app whose entrypoint is
  /// [entrypoint].
  LiveProjectMismatchException(this.entrypoint)
    : super('The app was built from $entrypoint, not this project.');

  /// The entrypoint file the app was built from.
  final String entrypoint;
}

/// An event a running app posted to the `nylo` VM service stream.
class LiveEvent {
  /// Creates a [LiveEvent] of [kind] with [data].
  const LiveEvent(this.kind, this.data, {this.timestamp});

  /// The event kind, e.g. `nylo.route` or `nylo.log`.
  final String kind;

  /// The event payload.
  final Map<String, Object?> data;

  /// When the VM service recorded the event.
  final DateTime? timestamp;
}

/// A running Nylo app that `metro live:*` can send commands to.
class LiveApp {
  /// Creates a [LiveApp] connected through [client].
  LiveApp({
    required this.device,
    required this.package,
    required this.uri,
    required this.client,
    required this.isolateId,
    required this.status,
    this.workspaceRoot,
    this.ideName,
  });

  /// The device name reported by the Dart Tooling Daemon, e.g. `iPhone 17e`.
  final String device;

  /// The app's pubspec package name.
  final String package;

  /// The VM service WebSocket URI.
  final Uri uri;

  /// The JSON-RPC connection to the app's VM service.
  final JsonRpcClient client;

  /// The isolate that registered the `ext.nylo.*` extensions.
  String isolateId;

  /// The latest `ext.nylo.status` payload.
  Map<String, Object?> status;

  /// The workspace root of the daemon that listed this app, if any.
  final String? workspaceRoot;

  /// The IDE hosting the daemon that listed this app, if any.
  final String? ideName;

  /// The extension every Nylo app registers; used to find the right isolate.
  static const String statusExtension = 'ext.nylo.status';

  final Map<String, String> _toolServices = {};
  bool _serviceStreamListening = false;

  /// Connects to the VM service at [uri] and finds the Nylo isolate.
  ///
  /// When [projectRoot] is given, the app's entrypoint is resolved to a file
  /// and must live inside [projectRoot]; an app built elsewhere throws a
  /// [LiveProjectMismatchException]. If the entrypoint can't be resolved,
  /// the app is only accepted when [trusted] (its daemon was started for
  /// this project).
  ///
  /// Throws a [LiveCommandException] when the app can't be reached or
  /// doesn't expose Nylo Live (a release build, or Nylo Live disabled).
  static Future<LiveApp> connect(
    Uri uri, {
    required String device,
    required String package,
    Duration timeout = const Duration(seconds: 3),
    String? workspaceRoot,
    String? ideName,
    String? projectRoot,
    bool trusted = false,
  }) async {
    final JsonRpcClient client;
    try {
      client = await JsonRpcClient.connect(uri, timeout: timeout);
    } catch (e) {
      throw LiveCommandException('Couldn\'t connect to $uri ($e)');
    }

    try {
      final ({String id, String? rootLib})? nylo = await _findNylo(
        client,
        timeout: timeout,
      );
      if (nylo == null) {
        throw LiveCommandException(
          'The app at $uri doesn\'t expose Nylo Live. It needs to be a debug '
          'build on a Nylo version with live commands.',
        );
      }
      final String isolateId = nylo.id;

      if (projectRoot != null) {
        final String? entrypoint = await resolveEntrypoint(
          client,
          isolateId,
          nylo.rootLib,
          timeout: timeout,
        );
        if (entrypoint != null && !isInside(entrypoint, projectRoot)) {
          throw LiveProjectMismatchException(entrypoint);
        }
        if (entrypoint == null && !trusted) {
          throw LiveCommandException(
            'Couldn\'t confirm the app at $uri was built from this project. '
            'Pass --uri to target it directly.',
          );
        }
      }

      final Object? status = _unwrap(
        await client.call(statusExtension, {'isolateId': isolateId}, timeout),
      );
      return LiveApp(
        device: device,
        package: package,
        uri: uri,
        client: client,
        isolateId: isolateId,
        status: status is Map ? Map<String, Object?>.from(status) : {},
        workspaceRoot: workspaceRoot,
        ideName: ideName,
      );
    } on LiveCommandException {
      await client.close();
      rethrow;
    } on TimeoutException {
      await client.close();
      throw LiveCommandException(
        'The app at $uri didn\'t respond within ${timeout.inSeconds}s. '
        'It may be paused in a debugger or in the background.',
      );
    } catch (e) {
      await client.close();
      throw LiveCommandException('Couldn\'t talk to the app at $uri ($e)');
    }
  }

  /// Returns the id of the isolate exposing `ext.nylo.status`, or null.
  static Future<String?> findNyloIsolate(
    JsonRpcClient client, {
    Duration? timeout,
  }) async => (await _findNylo(client, timeout: timeout))?.id;

  static Future<({String id, String? rootLib})?> _findNylo(
    JsonRpcClient client, {
    Duration? timeout,
  }) async {
    final Object? vm = await client.call('getVM', const {}, timeout);
    final Object? isolates = vm is Map ? vm['isolates'] : null;
    if (isolates is! List) return null;

    for (final Object? ref in isolates) {
      if (ref is! Map || ref['isSystemIsolate'] == true) continue;
      final Object? id = ref['id'];
      if (id is! String) continue;
      final Object? isolate = await client.call('getIsolate', {
        'isolateId': id,
      }, timeout);
      if (isolate is! Map) continue;
      final Object? rpcs = isolate['extensionRPCs'];
      if (rpcs is List && rpcs.contains(statusExtension)) {
        final Object? rootLib = isolate['rootLib'];
        final Object? rootUri = rootLib is Map ? rootLib['uri'] : null;
        return (id: id, rootLib: rootUri is String ? rootUri : null);
      }
    }
    return null;
  }

  /// Resolves the app's root library (e.g. `package:shop/main.dart`) to the
  /// file it was compiled from, or null when the VM service can't say.
  static Future<String?> resolveEntrypoint(
    JsonRpcClient client,
    String isolateId,
    String? rootLib, {
    Duration? timeout,
  }) async {
    if (rootLib == null) return null;
    final Uri? uri = Uri.tryParse(rootLib);
    if (uri == null) return null;
    if (uri.scheme == 'file') return uri.toFilePath();

    try {
      final Object? result = await client.call('lookupResolvedPackageUris', {
        'isolateId': isolateId,
        'uris': [rootLib],
      }, timeout);
      final Object? uris = result is Map ? result['uris'] : null;
      if (uris is List && uris.isNotEmpty && uris.first is String) {
        final Uri? resolved = Uri.tryParse(uris.first as String);
        if (resolved != null && resolved.scheme == 'file') {
          return resolved.toFilePath();
        }
      }
    } on JsonRpcException {
      // Not supported by this VM service (e.g. some web runtimes).
    }
    return null;
  }

  /// Whether [path] is [root] or inside it, after resolving symlinks such as
  /// macOS `/tmp` → `/private/tmp`.
  static bool isInside(String path, String root) {
    final String file = _canonical(path);
    final String directory = _canonical(root);
    return file == directory ||
        file.startsWith('$directory${Platform.pathSeparator}');
  }

  /// Resolves symlinks in the longest existing prefix of [path].
  static String _canonical(String path) {
    String existing = File(path).absolute.path;
    final List<String> missing = [];
    while (FileSystemEntity.typeSync(existing) ==
        FileSystemEntityType.notFound) {
      final String parent = File(existing).parent.path;
      if (parent == existing) break;
      missing.insert(
        0,
        existing.substring(parent.length).replaceAll(RegExp(r'^[\\/]+'), ''),
      );
      existing = parent;
    }
    String resolved = existing;
    try {
      resolved = File(existing).resolveSymbolicLinksSync();
    } on FileSystemException {
      // Keep the unresolved path.
    }
    for (final String segment in missing) {
      resolved = '$resolved${Platform.pathSeparator}$segment';
    }
    while (resolved.length > 1 &&
        (resolved.endsWith('/') || resolved.endsWith(r'\'))) {
      resolved = resolved.substring(0, resolved.length - 1);
    }
    return resolved;
  }

  /// Sends the live [command] (e.g. `route.push`) with [args] to the app.
  ///
  /// Returns the command's result payload. When the isolate has changed
  /// since connecting (a hot restart), it's found again and the call retried
  /// once.
  Future<Object?> call(
    String command, [
    Map<String, Object?>? args,
    Duration? timeout,
  ]) async {
    try {
      return await _callOnce(command, args, timeout);
    } on JsonRpcException catch (e) {
      if (!_mayBeStaleIsolate(e)) rethrow;
      final String? fresh = await findNyloIsolate(
        client,
        timeout: client.timeout,
      ).catchError((Object _) => null);
      if (fresh == null || fresh == isolateId) rethrow;
      isolateId = fresh;
      return await _callOnce(command, args, timeout);
    }
  }

  Future<Object?> _callOnce(
    String command,
    Map<String, Object?>? args,
    Duration? timeout,
  ) async {
    final Object? response = await client.call('ext.nylo.$command', {
      'isolateId': isolateId,
      if (args != null && args.isNotEmpty) 'args': jsonEncode(args),
    }, timeout);
    if (response is Map && response['type'] == 'Sentinel') {
      throw JsonRpcException(
        105,
        'The isolate $isolateId is no longer running',
      );
    }
    return _unwrap(response);
  }

  /// Streams the events this app posts to the `nylo` VM service stream.
  Stream<LiveEvent> events() {
    late final StreamController<LiveEvent> controller;
    StreamSubscription<JsonRpcNotification>? subscription;

    controller = StreamController<LiveEvent>(
      onListen: () async {
        subscription = client.notifications.listen((notification) {
          final LiveEvent? event = parseStreamEvent(notification, 'nylo');
          if (event != null) controller.add(event);
        }, onDone: controller.close);
        try {
          await client.call('streamListen', {'streamId': 'nylo'});
        } on JsonRpcException catch (e) {
          // 103: the stream is already subscribed on this connection.
          if (e.code != 103) controller.addError(e);
        } catch (e) {
          controller.addError(e);
        }
      },
      onCancel: () async {
        await subscription?.cancel();
        if (client.isClosed) return;
        try {
          await client.call('streamCancel', {'streamId': 'nylo'});
        } catch (_) {
          // Nothing to clean up if the app is already gone.
        }
      },
    );
    return controller.stream;
  }

  /// Parses a VM service `streamNotify` [notification] for [streamId].
  static LiveEvent? parseStreamEvent(
    JsonRpcNotification notification,
    String streamId,
  ) {
    if (notification.method != 'streamNotify') return null;
    if (notification.params['streamId'] != streamId) return null;
    final Object? event = notification.params['event'];
    if (event is! Map) return null;
    final Object? kind = event['extensionKind'];
    if (kind is! String) return null;
    final Object? data = event['extensionData'];
    final Object? timestamp = event['timestamp'];
    return LiveEvent(
      kind,
      data is Map ? Map<String, Object?>.from(data) : const {},
      timestamp: timestamp is int
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
    );
  }

  /// Finds the method the attached Flutter tool registered for [service]
  /// (`reloadSources` or `hotRestart`), e.g. `s1.reloadSources`.
  Future<String?> toolServiceMethod(
    String service, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final String? known = _toolServices[service];
    if (known != null) return known;

    final Completer<void> found = Completer<void>();
    final StreamSubscription<JsonRpcNotification> subscription = client
        .notifications
        .listen((notification) {
          if (notification.method != 'streamNotify') return;
          if (notification.params['streamId'] != 'Service') return;
          final Object? event = notification.params['event'];
          if (event is! Map || event['kind'] != 'ServiceRegistered') return;
          final Object? name = event['service'];
          final Object? method = event['method'];
          if (name is String && method is String) {
            _toolServices[name] = method;
            if (name == service && !found.isCompleted) found.complete();
          }
        });

    try {
      if (!_serviceStreamListening) {
        try {
          await client.call('streamListen', {'streamId': 'Service'}, timeout);
        } on JsonRpcException catch (e) {
          if (e.code != 103) rethrow;
        }
        _serviceStreamListening = true;
      }
      await found.future.timeout(timeout, onTimeout: () {});
      return _toolServices[service];
    } finally {
      await subscription.cancel();
    }
  }

  /// Hot reloads the app through the Flutter tool that launched it.
  Future<Duration> reload({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final String? method = await toolServiceMethod('reloadSources');
    if (method == null) {
      throw LiveCommandException(
        'Hot reload isn\'t available. The app needs to still be attached to '
        '`flutter run` or your IDE.',
      );
    }
    final Stopwatch stopwatch = Stopwatch()..start();
    final Object? result = await client.call(method, {
      'isolateId': isolateId,
    }, timeout);
    if (result is Map && result['success'] == false) {
      throw LiveCommandException('Hot reload failed: ${jsonEncode(result)}');
    }
    return stopwatch.elapsed;
  }

  /// Hot restarts the app through the Flutter tool that launched it, then
  /// finds the new Nylo isolate.
  Future<Duration> restart({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final String? method = await toolServiceMethod('hotRestart');
    if (method == null) {
      throw LiveCommandException(
        'Hot restart isn\'t available. The app needs to still be attached to '
        '`flutter run` or your IDE.',
      );
    }
    final String previous = isolateId;
    final Stopwatch stopwatch = Stopwatch()..start();
    await client.call(method, const {}, timeout);

    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final String? fresh = await findNyloIsolate(
        client,
        timeout: client.timeout,
      ).catchError((Object _) => null);
      if (fresh != null && fresh != previous) {
        isolateId = fresh;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (isolateId == previous) {
      throw LiveCommandException(
        'The app restarted but Nylo Live didn\'t come back within '
        '${timeout.inSeconds}s.',
      );
    }

    final Object? fresh = await call('status');
    if (fresh is Map) status = Map<String, Object?>.from(fresh);
    return stopwatch.elapsed;
  }

  /// Closes the connection to the app.
  Future<void> close() => client.close();

  static Object? _unwrap(Object? response) {
    if (response is Map && response.containsKey('result')) {
      return response['result'];
    }
    return response;
  }

  /// Errors a restarted app returns for a call aimed at its old isolate.
  static bool _mayBeStaleIsolate(JsonRpcException e) {
    if (e.code == -32601 || e.code == 105 || e.code == 106) return true;
    final String text = '${e.message} ${e.details}'.toLowerCase();
    return e.code == -32602 && text.contains('isolateid');
  }
}
