import 'dart:async';

import 'json_rpc_client.dart';
import 'live_app.dart';
import 'live_discovery.dart';
import 'live_options.dart';
import 'live_output.dart';
import 'live_runner.dart';
import 'live_targets.dart';

/// The running apps `metro live` is connected to, kept open between commands.
///
/// The session remembers which app commands run on, follows each app's
/// current page for the prompt, notices hot restarts and disconnects, and
/// reconnects when an app starts again.
class LiveSession {
  /// Creates a session that finds apps with [runner].
  LiveSession(
    this.runner, {
    this.timeout = LiveOptions.defaultTimeout,
    this.pollInterval = const Duration(seconds: 2),
    this.uri,
  });

  /// Finds the project's apps.
  final LiveRunner runner;

  /// A VM service address to connect to instead of finding apps.
  final Uri? uri;

  /// How long discovery waits for each app.
  final Duration timeout;

  /// How often the session looks for apps while none is connected.
  final Duration pollInterval;

  /// Receives a line to show when something happens in the background.
  void Function(String message)? onNotice;

  /// Called when what the prompt shows has changed.
  void Function()? onChange;

  /// Set while a command runs, so restarts it causes aren't announced.
  bool busy = false;

  final List<LiveApp> _apps = [];
  final Map<LiveApp, List<StreamSubscription<Object?>>> _subscriptions = {};
  bool _all = false;
  String? _chosenUri;
  String? _chosenDevice;
  Timer? _poll;
  Future<void>? _refreshing;
  bool _closed = false;

  /// The connected apps, in discovery order.
  List<LiveApp> get apps => List.unmodifiable(_apps);

  /// Whether commands run on every connected app.
  bool get all => _all;

  /// The app commands run on: the one picked with [use], or the only
  /// connected app. Null when commands run on every app or none is picked.
  LiveApp? get current {
    if (_all) return null;
    if (_chosenUri != null || _chosenDevice != null) {
      for (final LiveApp app in _apps) {
        if (app.uri.toString() == _chosenUri) return app;
      }
      final List<LiveApp> named = _apps
          .where((app) => app.device == _chosenDevice)
          .toList();
      return named.length == 1 ? named.single : null;
    }
    return _apps.length == 1 ? _apps.single : null;
  }

  /// The device picked with [use] that isn't connected, if any.
  String? get missingDevice =>
      (_chosenDevice != null && current == null && !_all)
      ? _chosenDevice
      : null;

  /// Finds running apps and connects to new ones, keeping the connections to
  /// apps that are still running. Returns the apps discovery had to skip.
  Future<List<LiveSkippedApp>> refresh() async {
    if (_closed) return const [];
    final Uri? address = uri;
    final LiveDiscoveryResult found = address == null
        ? await runner.discover(LiveOptions(timeout: timeout))
        : LiveDiscoveryResult([
            await LiveApp.connect(
              address,
              device: address.hasPort
                  ? '${address.host}:${address.port}'
                  : address.host,
              package: runner.project.packageName,
              timeout: timeout,
            ),
          ], const []);
    final Set<String> running = {
      for (final LiveApp app in found.apps) app.uri.toString(),
    };

    for (final LiveApp app in List<LiveApp>.of(_apps)) {
      if (!running.contains(app.uri.toString()) || app.client.isClosed) {
        await _drop(app);
      }
    }
    for (final LiveApp fresh in found.apps) {
      final LiveApp? known = _find(fresh.uri);
      if (known != null) {
        known.status = fresh.status;
        await fresh.close();
        continue;
      }
      _apps.add(fresh);
      await _watch(fresh);
    }
    _updatePolling();
    onChange?.call();
    return found.skipped;
  }

  /// Picks the app commands run on: a number from `devices`, a device name,
  /// `all` for every app, or `auto` to use the only running app.
  ///
  /// Returns why nothing was picked, with the apps to choose from, or null.
  Future<({String error, List<LiveApp> candidates})?> use(String query) async {
    final String wanted = query.trim();
    if (wanted == 'all' || wanted == 'auto') {
      _all = wanted == 'all';
      _chosenUri = null;
      _chosenDevice = null;
      if (_all) await _refreshQuietly();
      onChange?.call();
      return null;
    }

    LiveTargetSelection<LiveApp> selection = _select(device: wanted);
    if (!selection.isSuccess) {
      await _refreshQuietly();
      selection = _select(device: wanted);
    }
    if (!selection.isSuccess) {
      return (error: selection.error!, candidates: selection.candidates);
    }
    final LiveApp app = selection.targets.single;
    _all = false;
    _chosenUri = app.uri.toString();
    _chosenDevice = app.device;
    onChange?.call();
    return null;
  }

  /// The apps a command runs on, printing to [output] why when there are
  /// none. Per-command `-d` and `--all` in [options] win over [use].
  Future<({List<LiveApp> targets, int exitCode})> resolve(
    LiveOptions options,
    LivePrinter output,
  ) async {
    if (options.uri != null) {
      output.error(
        '--uri only works when starting the shell: metro live --uri <address>',
      );
      return (targets: <LiveApp>[], exitCode: 64);
    }

    await _pruneClosed();
    if (_apps.isEmpty) await _refreshQuietly();
    LiveTargetSelection<LiveApp> selection = _pick(options);
    if (!selection.isSuccess && _apps.isNotEmpty) {
      await _refreshQuietly();
      selection = _pick(options);
    }
    if (!selection.isSuccess) {
      output.error(selection.error!);
      for (final LiveApp app in selection.candidates) {
        output.line('  ${_apps.indexOf(app) + 1}  ${app.device}');
      }
      return (targets: <LiveApp>[], exitCode: selection.exitCode);
    }
    return (targets: selection.targets, exitCode: 0);
  }

  /// Stops watching and closes every connection.
  Future<void> close() async {
    _closed = true;
    _poll?.cancel();
    for (final LiveApp app in List<LiveApp>.of(_apps)) {
      await _drop(app);
    }
  }

  LiveTargetSelection<LiveApp> _pick(LiveOptions options) {
    if (options.device != null || options.all) {
      return _select(device: options.device, all: options.all);
    }
    if (_all) return _select(all: true);
    if (_chosenUri != null || _chosenDevice != null) {
      final LiveApp? app = current;
      if (app != null) return LiveTargetSelection<LiveApp>.targets([app]);
      return LiveTargetSelection<LiveApp>.error(
        '$_chosenDevice isn\'t running. Start it again, or pick another app '
        'with use:',
        1,
        candidates: _apps,
      );
    }
    final LiveTargetSelection<LiveApp> selection = _select();
    if (selection.isSuccess || selection.exitCode != 2) return selection;
    return LiveTargetSelection<LiveApp>.error(
      '${_apps.length} apps are running. Pick one with use <#|name>, or use '
      'all:',
      2,
      candidates: selection.candidates,
    );
  }

  LiveTargetSelection<LiveApp> _select({String? device, bool all = false}) {
    return selectLiveTargets(
      _apps,
      deviceOf: (app) => app.device,
      device: device,
      all: all,
      packageName: runner.project.packageName,
    );
  }

  LiveApp? _find(Uri uri) {
    for (final LiveApp app in _apps) {
      if (app.uri.toString() == uri.toString() && !app.client.isClosed) {
        return app;
      }
    }
    return null;
  }

  Future<void> _refreshQuietly() {
    return _refreshing ??= () async {
      try {
        await refresh();
      } on LiveDiscoveryException {
        // Try again on the next command or poll.
      } on LiveCommandException {
        // Try again on the next command or poll.
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<void> _pruneClosed() async {
    for (final LiveApp app in List<LiveApp>.of(_apps)) {
      if (app.client.isClosed) await _drop(app);
    }
  }

  Future<void> _drop(LiveApp app) async {
    _apps.remove(app);
    for (final StreamSubscription<Object?> subscription
        in _subscriptions.remove(app) ?? const []) {
      await subscription.cancel();
    }
    await app.close();
  }

  Future<void> _watch(LiveApp app) async {
    final List<StreamSubscription<Object?>> subscriptions = [
      app.events().listen((event) => _onEvent(app, event), onError: (_) {}),
      app.client.notifications.listen((notification) {
        _onNotification(app, notification);
      }),
    ];
    _subscriptions[app] = subscriptions;

    unawaited(
      app.client.done.then((_) {
        if (_closed || !_apps.contains(app)) return;
        unawaited(_drop(app));
        onNotice?.call('${app.device} disconnected');
        _updatePolling();
        onChange?.call();
      }),
    );

    try {
      await app.client.call('streamListen', {'streamId': 'Extension'});
    } catch (_) {
      // Without the Extension stream, restarts are noticed on the next call.
    }
  }

  void _onEvent(LiveApp app, LiveEvent event) {
    if (event.kind != 'nylo.route') return;
    final Object? route = switch (event.data['action']) {
      'push' || 'replace' => event.data['name'],
      'pop' => event.data['previous'],
      _ => null,
    };
    if (route is! String) return;
    app.status['route'] = route;
    onChange?.call();
  }

  void _onNotification(LiveApp app, JsonRpcNotification notification) {
    if (notification.method != 'streamNotify' ||
        notification.params['streamId'] != 'Extension') {
      return;
    }
    final Object? event = notification.params['event'];
    if (event is! Map ||
        event['kind'] != 'ServiceExtensionAdded' ||
        event['extensionRPC'] != LiveApp.statusExtension) {
      return;
    }
    final Object? isolate = event['isolate'];
    final Object? id = isolate is Map ? isolate['id'] : null;
    if (id is! String || id == app.isolateId) return;

    app.isolateId = id;
    final bool announce = !busy;
    unawaited(() async {
      try {
        final Object? status = await app.call('status');
        if (status is Map) app.status = Map<String, Object?>.from(status);
      } catch (_) {
        // The app is still starting; the next route event updates the prompt.
      }
      if (announce) onNotice?.call('${app.device} hot restarted, reconnected');
      onChange?.call();
    }());
  }

  void _updatePolling() {
    if (_closed || _apps.isNotEmpty) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(pollInterval, (_) async {
      if (_refreshing != null || busy) return;
      final int before = _apps.length;
      await _refreshQuietly();
      if (_apps.length > before) {
        for (final LiveApp app in _apps) {
          onNotice?.call('Connected to ${app.device}');
        }
      }
    });
  }
}
