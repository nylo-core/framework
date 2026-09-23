import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'json_rpc_client.dart';
import 'live_app.dart';

/// Thrown when the running Dart Tooling Daemons can't be listed.
class LiveDiscoveryException implements Exception {
  /// Creates a [LiveDiscoveryException] with a user-facing [message].
  LiveDiscoveryException(this.message);

  /// What went wrong and how to work around it.
  final String message;

  @override
  String toString() => message;
}

/// A Dart Tooling Daemon listed by `dart tooling-daemon --list --machine`.
class LiveDaemon {
  /// Creates a [LiveDaemon] reachable at [wsUri].
  const LiveDaemon({
    required this.wsUri,
    this.workspaceRoot,
    this.ideName,
    this.pid,
  });

  /// Parses one entry of `dart tooling-daemon --list --machine`.
  static LiveDaemon? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? wsUri = json['wsUri'];
    if (wsUri is! String) return null;
    final Uri? uri = Uri.tryParse(wsUri);
    if (uri == null) return null;
    final Object? root = json['workspaceRoot'];
    final Object? ide = json['ideName'];
    final Object? pid = json['pid'];
    return LiveDaemon(
      wsUri: uri,
      workspaceRoot: root is String ? root : null,
      ideName: ide is String ? ide : null,
      pid: pid is int ? pid : null,
    );
  }

  /// The daemon's WebSocket URI, including its secret path.
  final Uri wsUri;

  /// The workspace the daemon was started for (a project root for
  /// `flutter run`, the IDE workspace otherwise).
  final String? workspaceRoot;

  /// The IDE that started the daemon, when an IDE did.
  final String? ideName;

  /// The daemon's process id.
  final int? pid;
}

/// A connected app as described by a daemon's `ConnectedApp` service,
/// parsed from names like `Kind: Flutter - Device: iPhone 17e - Package: my_app`.
class LiveAppDescriptor {
  /// Creates a [LiveAppDescriptor].
  const LiveAppDescriptor({
    required this.kind,
    required this.device,
    required this.package,
  });

  static final RegExp _pattern = RegExp(
    r'^Kind: (.*?) - Device: (.*) - Package: (\S+)\s*$',
  );

  /// Parses a `ConnectedApp` VM service [name], or returns null when it
  /// doesn't name a device and package.
  static LiveAppDescriptor? parse(String? name) {
    if (name == null) return null;
    final RegExpMatch? match = _pattern.firstMatch(name.trim());
    if (match == null) return null;
    return LiveAppDescriptor(
      kind: match.group(1)!,
      device: match.group(2)!,
      package: match.group(3)!,
    );
  }

  /// The app kind, e.g. `Flutter`.
  final String kind;

  /// The device name, e.g. `iPhone 17e`.
  final String device;

  /// The app's pubspec package name.
  final String package;
}

/// An app that matched this project but couldn't be used.
class LiveSkippedApp {
  /// Creates a [LiveSkippedApp].
  const LiveSkippedApp(this.device, this.uri, this.reason);

  /// The device name reported by the daemon.
  final String device;

  /// The VM service URI that was tried.
  final Uri uri;

  /// Why the app was skipped.
  final String reason;
}

/// The outcome of discovering running apps for a project.
class LiveDiscoveryResult {
  /// Creates a [LiveDiscoveryResult].
  const LiveDiscoveryResult(this.apps, this.skipped);

  /// Connected apps, sorted by device name.
  final List<LiveApp> apps;

  /// Apps of this project that didn't respond or don't expose Nylo Live.
  final List<LiveSkippedApp> skipped;
}

/// Lists the running Dart Tooling Daemons.
typedef LiveDaemonLister = Future<List<LiveDaemon>> Function();

/// Finds the running apps of one project through the Dart Tooling Daemons
/// that `flutter run` sessions and IDEs register them with.
class LiveDiscovery {
  /// Creates a [LiveDiscovery] for the project at [projectRoot] whose pubspec
  /// name is [packageName].
  LiveDiscovery({
    required this.projectRoot,
    required this.packageName,
    this.timeout = const Duration(seconds: 3),
    LiveDaemonLister? listDaemons,
  }) : _listDaemons = listDaemons ?? listToolingDaemons;

  /// The project root, used to prefer the project's own daemons.
  final String projectRoot;

  /// The project's pubspec name; apps of other packages are never contacted.
  final String packageName;

  /// How long to wait for each daemon and app.
  final Duration timeout;

  final LiveDaemonLister _listDaemons;

  /// Discovers this project's running apps.
  ///
  /// Apps are filtered by package name before any connection is made to
  /// them, listed once even when several daemons know them, and skipped when
  /// they don't respond within [timeout].
  Future<LiveDiscoveryResult> discover() async {
    final List<LiveDaemon> daemons = List<LiveDaemon>.of(await _listDaemons());
    final String root = canonicalPath(projectRoot);
    final List<LiveDaemon> ordered = [
      ...daemons.where((d) => _isProjectDaemon(d, root)),
      ...daemons.where((d) => !_isProjectDaemon(d, root)),
    ];

    final List<List<_Candidate>> listed = await Future.wait(
      ordered.map(_queryDaemon),
    );

    final Set<String> seen = {};
    final List<_Candidate> candidates = [];
    for (final List<_Candidate> daemonApps in listed) {
      for (final _Candidate candidate in daemonApps) {
        if (candidate.descriptor.package != packageName) continue;
        // Nylo apps often share the package name `flutter_app`, so apps from a
        // daemon started for a different project are left alone entirely.
        if (_isAnotherProjectDaemon(candidate.daemon, root)) continue;
        if (!seen.add(_uriKey(candidate.uri))) continue;
        candidates.add(candidate);
      }
    }

    final List<LiveSkippedApp> skipped = [];
    final List<LiveApp?> connected = await Future.wait(
      candidates.map((candidate) async {
        try {
          return await LiveApp.connect(
            candidate.uri,
            device: candidate.descriptor.device,
            package: candidate.descriptor.package,
            timeout: timeout,
            workspaceRoot: candidate.daemon.workspaceRoot,
            ideName: candidate.daemon.ideName,
            projectRoot: projectRoot,
            trusted: _isProjectDaemon(candidate.daemon, root),
          );
        } on LiveProjectMismatchException {
          // Same package name, different project: not one of this project's apps.
          return null;
        } on LiveCommandException catch (e) {
          skipped.add(
            LiveSkippedApp(
              candidate.descriptor.device,
              candidate.uri,
              e.message,
            ),
          );
          return null;
        }
      }),
    );

    final List<LiveApp> apps = connected.whereType<LiveApp>().toList()
      ..sort((a, b) {
        final int byDevice = a.device.toLowerCase().compareTo(
          b.device.toLowerCase(),
        );
        return byDevice != 0
            ? byDevice
            : a.uri.toString().compareTo(b.uri.toString());
      });
    return LiveDiscoveryResult(apps, skipped);
  }

  Future<List<_Candidate>> _queryDaemon(LiveDaemon daemon) async {
    JsonRpcClient? client;
    try {
      client = await JsonRpcClient.connect(daemon.wsUri, timeout: timeout);
      final Object? response = await client.call(
        'ConnectedApp.getVmServices',
        const {},
      );
      final Object? services = response is Map ? response['vmServices'] : null;
      if (services is! List) return const [];

      final List<_Candidate> candidates = [];
      for (final Object? service in services) {
        if (service is! Map) continue;
        final Object? name = service['name'];
        final LiveAppDescriptor? descriptor = LiveAppDescriptor.parse(
          name is String ? name : null,
        );
        final Object? exposed = service['exposedUri'];
        final Object? raw = exposed is String && exposed.isNotEmpty
            ? exposed
            : service['uri'];
        if (descriptor == null || raw is! String) continue;
        final Uri? uri = normalizeVmServiceUri(raw);
        if (uri == null) continue;
        candidates.add(_Candidate(uri, descriptor, daemon));
      }
      return candidates;
    } catch (_) {
      // Stale or unreachable daemons are common (crashed IDEs leave pid files).
      return const [];
    } finally {
      await client?.close();
    }
  }

  static bool _isProjectDaemon(LiveDaemon daemon, String root) {
    final String? workspace = daemon.workspaceRoot;
    return workspace != null && canonicalPath(workspace) == root;
  }

  /// Whether [daemon] was started for a different Flutter or Dart project: its
  /// workspace has its own pubspec.yaml and neither is nor contains [root].
  static bool _isAnotherProjectDaemon(LiveDaemon daemon, String root) {
    final String? workspace = daemon.workspaceRoot;
    if (workspace == null) return false;
    final String candidate = canonicalPath(workspace);
    if (candidate == root) return false;
    if (root.startsWith('$candidate${Platform.pathSeparator}')) return false;
    return File('$candidate${Platform.pathSeparator}pubspec.yaml').existsSync();
  }

  static String _uriKey(Uri uri) {
    final String text = uri.toString();
    return text.endsWith('/') ? text.substring(0, text.length - 1) : text;
  }

  /// Resolves symlinks (e.g. macOS `/tmp` → `/private/tmp`) and trailing
  /// separators so workspace roots compare reliably.
  static String canonicalPath(String path) {
    String resolved = path;
    try {
      resolved = Directory(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      resolved = Directory(path).absolute.path;
    }
    while (resolved.length > 1 &&
        (resolved.endsWith('/') || resolved.endsWith(r'\'))) {
      resolved = resolved.substring(0, resolved.length - 1);
    }
    return resolved;
  }

  /// Turns a VM service address in any of its printed forms into the
  /// WebSocket URI clients connect to.
  ///
  /// `http://127.0.0.1:5000/abc=/` and `ws://127.0.0.1:5000/abc=` both
  /// become `ws://127.0.0.1:5000/abc=/ws`.
  static Uri? normalizeVmServiceUri(String address) {
    Uri? uri = Uri.tryParse(address.trim());
    if (uri == null || uri.host.isEmpty) return null;

    // A DevTools link carries the VM service address in its `uri` parameter.
    final String? embedded = uri.queryParameters['uri'];
    if (embedded != null && embedded != address) {
      return normalizeVmServiceUri(embedded);
    }

    final String scheme = switch (uri.scheme) {
      'http' || 'ws' => 'ws',
      'https' || 'wss' => 'wss',
      _ => '',
    };
    if (scheme.isEmpty) return null;

    String path = uri.path;
    if (path.endsWith('/ws/')) path = path.substring(0, path.length - 1);
    if (!path.endsWith('/ws')) {
      path = path.endsWith('/') ? '${path}ws' : '$path/ws';
    }
    return Uri(
      scheme: scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    );
  }
}

/// Lists running Dart Tooling Daemons with `dart tooling-daemon --list`.
Future<List<LiveDaemon>> listToolingDaemons() async {
  final String executable = _dartExecutable();

  final ProcessResult result;
  try {
    result = await Process.run(executable, [
      'tooling-daemon',
      '--list',
      '--machine',
    ]).timeout(const Duration(seconds: 15));
  } catch (e) {
    throw LiveDiscoveryException(
      'Couldn\'t list running apps with `dart tooling-daemon --list` ($e). '
      'Pass --uri with the "Dart VM Service is available at" address instead.',
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode('${result.stdout}'.trim());
  } on FormatException {
    throw LiveDiscoveryException(
      'Couldn\'t list running apps: `dart tooling-daemon --list` needs '
      'Dart 3.12 or newer. Pass --uri with the "Dart VM Service is available '
      'at" address instead.',
    );
  }
  if (result.exitCode != 0 || decoded is! List) {
    throw LiveDiscoveryException(
      'Couldn\'t list running apps (`dart tooling-daemon --list` exited with '
      '${result.exitCode}). Pass --uri with the "Dart VM Service is available '
      'at" address instead.',
    );
  }
  return decoded.map(LiveDaemon.fromJson).whereType<LiveDaemon>().toList();
}

class _Candidate {
  const _Candidate(this.uri, this.descriptor, this.daemon);

  final Uri uri;
  final LiveAppDescriptor descriptor;
  final LiveDaemon daemon;
}

/// The `dart` launcher next to the running VM, falling back to `PATH`.
String _dartExecutable() {
  final File current = File(Platform.resolvedExecutable);
  final File sibling = File(
    '${current.parent.path}${Platform.pathSeparator}'
    '${Platform.isWindows ? 'dart.exe' : 'dart'}',
  );
  return sibling.existsSync() ? sibling.path : 'dart';
}
