import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Returned by a handler to leave a request unanswered.
const Object noResponse = Object();

/// Thrown by a handler to send a JSON-RPC error response.
class FakeRpcError implements Exception {
  FakeRpcError(this.code, this.message, [this.data]);

  final int code;
  final String message;
  final Object? data;
}

/// A connected client of a [FakeJsonRpcServer].
class FakeConnection {
  FakeConnection(this.socket);

  final WebSocket socket;

  /// Pushes a JSON-RPC notification to the client.
  void notify(String method, Map<String, Object?> params) {
    socket.add(
      jsonEncode({'jsonrpc': '2.0', 'method': method, 'params': params}),
    );
  }

  /// Pushes a VM service `streamNotify` event for [streamId].
  void streamNotify(String streamId, Map<String, Object?> event) =>
      notify('streamNotify', {'streamId': streamId, 'event': event});
}

typedef FakeHandler =
    FutureOr<Object?> Function(
      String method,
      Map<String, Object?> params,
      FakeConnection connection,
    );

/// An in-process JSON-RPC 2.0 WebSocket server.
class FakeJsonRpcServer {
  FakeJsonRpcServer._(this._server, this._handler) {
    _server.listen(_onRequest);
  }

  static Future<FakeJsonRpcServer> start(FakeHandler handler) async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    return FakeJsonRpcServer._(server, handler);
  }

  final HttpServer _server;
  final FakeHandler _handler;
  final List<FakeConnection> clients = [];

  /// Every method called, in order.
  final List<String> methods = [];

  /// How many WebSocket connections were accepted.
  int connections = 0;

  /// The server's WebSocket URI, with a fake secret path.
  Uri get wsUri => Uri.parse('ws://127.0.0.1:${_server.port}/secret=/ws');

  Future<void> _onRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    final WebSocket socket = await WebSocketTransformer.upgrade(request);
    connections++;
    final FakeConnection connection = FakeConnection(socket);
    clients.add(connection);
    socket.listen((raw) async {
      final Map<String, Object?> message = Map<String, Object?>.from(
        jsonDecode(raw as String) as Map,
      );
      final String method = message['method'] as String;
      methods.add(method);
      final Object? id = message['id'];
      final Object? params = message['params'];
      try {
        final Object? result = await _handler(
          method,
          params is Map ? Map<String, Object?>.from(params) : {},
          connection,
        );
        if (identical(result, noResponse)) return;
        socket.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}));
      } on FakeRpcError catch (e) {
        socket.add(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'error': {
              'code': e.code,
              'message': e.message,
              if (e.data != null) 'data': e.data,
            },
          }),
        );
      }
    });
  }

  Future<void> close() async {
    for (final FakeConnection client in clients) {
      await client.socket.close();
    }
    await _server.close(force: true);
  }
}

/// A fake Nylo app's VM service: one main isolate exposing `ext.nylo.*`.
class FakeNyloApp {
  FakeNyloApp._(this.server, this.state);

  static Future<FakeNyloApp> start({
    Map<String, Object?>? status,
    Map<String, FutureOr<Object?> Function(Map<String, Object?> args)>
        commands =
        const {},
    bool respond = true,
    String? entrypoint,
    bool resolvesPackageUris = true,
    FakeStateObject? inspected,
  }) async {
    final _FakeAppState state = _FakeAppState(
      status ??
          {
            'protocol': 1,
            'app': 'Nylo',
            'platform': 'ios',
            'mode': 'debug',
            'route': '/home',
          },
      commands,
      entrypoint: entrypoint,
      resolvesPackageUris: resolvesPackageUris,
      inspected: inspected,
    );
    final FakeJsonRpcServer server = await FakeJsonRpcServer.start((
      method,
      params,
      connection,
    ) {
      if (!respond) return noResponse;
      return state.handle(method, params, connection);
    });
    return FakeNyloApp._(server, state);
  }

  final FakeJsonRpcServer server;
  final _FakeAppState state;

  Uri get wsUri => server.wsUri;

  /// The current Nylo isolate id (changes on hot restart).
  String get isolateId => state.isolateId;

  /// The args JSON sent with each `ext.nylo.*` call, by command.
  Map<String, List<Map<String, Object?>>> get calls => state.calls;

  Future<void> close() => server.close();
}

class _FakeAppState {
  _FakeAppState(
    this.status,
    this.commands, {
    this.entrypoint,
    this.resolvesPackageUris = true,
    this.inspected,
  });

  /// The state object `getObject` walks to, or null when there is none.
  final FakeStateObject? inspected;

  /// The file the app's root library resolves to, or null if unknown.
  final String? entrypoint;

  /// Whether `lookupResolvedPackageUris` is supported.
  final bool resolvesPackageUris;

  final Map<String, Object?> status;
  final Map<String, FutureOr<Object?> Function(Map<String, Object?> args)>
  commands;
  final Map<String, List<Map<String, Object?>>> calls = {};
  String isolateId = 'isolates/100';

  Future<Object?> handle(
    String method,
    Map<String, Object?> params,
    FakeConnection connection,
  ) async {
    switch (method) {
      case 'getVM':
        return {
          'type': 'VM',
          'isolates': [
            {'type': '@Isolate', 'id': 'isolates/1', 'isSystemIsolate': true},
            {'type': '@Isolate', 'id': 'isolates/50', 'name': 'worker'},
            {'type': '@Isolate', 'id': isolateId, 'name': 'main'},
          ],
        };
      case 'getIsolate':
        return {
          'type': 'Isolate',
          'id': params['isolateId'],
          'rootLib': {'type': '@Library', 'uri': 'package:shop/main.dart'},
          if (inspected != null) 'libraries': inspected!.libraries,
          'extensionRPCs': params['isolateId'] == isolateId
              ? ['ext.flutter.reassemble', 'ext.nylo.status']
              : ['ext.flutter.reassemble'],
        };
      case 'lookupResolvedPackageUris':
        if (!resolvesPackageUris) {
          throw FakeRpcError(-32601, 'Method not found');
        }
        return {
          'type': 'UriList',
          'uris': [
            for (final Object? _ in (params['uris'] as List? ?? const []))
              entrypoint == null ? null : Uri.file(entrypoint!).toString(),
          ],
        };
      case 'getObject':
        final Object? object = inspected?.object('${params['objectId']}');
        if (object == null) throw FakeRpcError(112, 'Object not found');
        return object;
      case 'evaluate':
        final Object? evaluated = inspected?.evaluate(
          '${params['targetId']}',
          '${params['expression']}',
          Map<String, Object?>.from(params['scope'] as Map? ?? const {}),
        );
        if (evaluated == null) throw FakeRpcError(113, 'Cannot evaluate');
        return evaluated;
      case 'streamListen':
        if (params['streamId'] == 'Service') {
          Timer.run(() {
            connection.streamNotify('Service', {
              'kind': 'ServiceRegistered',
              'service': 'reloadSources',
              'method': 's1.reloadSources',
            });
            connection.streamNotify('Service', {
              'kind': 'ServiceRegistered',
              'service': 'hotRestart',
              'method': 's1.hotRestart',
            });
          });
        }
        return {'type': 'Success'};
      case 'streamCancel':
        return {'type': 'Success'};
      case 's1.reloadSources':
        return {'type': 'Success'};
      case 's1.hotRestart':
        isolateId = 'isolates/200';
        return {'type': 'Success'};
    }

    if (method.startsWith('ext.nylo.')) {
      if (params['isolateId'] != isolateId) {
        throw FakeRpcError(-32601, 'Method not found');
      }
      final String command = method.substring('ext.nylo.'.length);
      final Object? rawArgs = params['args'];
      final Map<String, Object?> args = rawArgs is String
          ? Map<String, Object?>.from(jsonDecode(rawArgs) as Map)
          : {};
      calls.putIfAbsent(command, () => []).add(args);
      final Object? payload;
      if (command == 'status') {
        payload = status;
      } else if (commands.containsKey(command)) {
        payload = await commands[command]!(args);
      } else {
        throw FakeRpcError(-32601, 'Method not found');
      }
      return {'result': payload, 'type': '_extensionType', 'method': method};
    }

    throw FakeRpcError(-32601, 'Method not found');
  }
}

/// A fake Dart Tooling Daemon listing [apps] as `ConnectedApp` VM services.
Future<FakeJsonRpcServer> startFakeDaemon(List<({Uri uri, String name})> apps) {
  return FakeJsonRpcServer.start((method, params, connection) {
    if (method != 'ConnectedApp.getVmServices') {
      throw FakeRpcError(-32601, 'Method not found');
    }
    return {
      'type': 'VmServicesResponse',
      'vmServices': [
        for (final ({Uri uri, String name}) app in apps)
          {'uri': app.uri.toString(), 'name': app.name},
      ],
    };
  });
}

/// A loopback port with nothing listening on it.
Future<int> closedPort() async {
  final ServerSocket socket = await ServerSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  final int port = socket.port;
  await socket.close();
  return port;
}

/// A field of a [FakeStateObject], as the VM service reports it.
class FakeField {
  const FakeField({
    required this.name,
    required this.owner,
    this.value,
    this.type = 'PlainInstance',
    this.className = 'Object',
    this.sentinel,
  });

  /// A field declared on the state class itself, holding [value].
  const FakeField.own(
    String name, {
    required Object? value,
    String className = 'Object',
  }) : this(
         name: name,
         owner: 'HomePageState',
         value: value,
         className: className,
       );

  /// A field Nylo declares, which `data` must not show.
  const FakeField.framework(String name, {String owner = 'NyBaseState'})
    : this(name: name, owner: owner);

  /// A field with nothing to read, e.g. an uninitialized `late`.
  const FakeField.sentinel(String name, String kind)
    : this(name: name, owner: 'HomePageState', sentinel: kind);

  final String name;
  final String owner;
  final Object? value;
  final String type;
  final String className;
  final String? sentinel;
}

/// A fake captured page state, reachable the way `metro live:run data`
/// reaches a real one: library → top-level variable → instance → fields.
class FakeStateObject {
  FakeStateObject({
    required this.fields,
    this.libraryUri = 'package:nylo_support/live/src/live_state_inspector.dart',
    this.variable = 'nyLiveInspectedState',
    this.captured = true,
    this.evaluates = true,
    this.evaluationError,
    this.truncateAt,
  });

  final List<FakeField> fields;
  final String libraryUri;
  final String variable;

  /// Whether a state was captured, or the variable is still null.
  final bool captured;

  /// Whether `evaluate` works, as it doesn't in an AOT build.
  final bool evaluates;

  /// An app-side error `evaluate` reports instead of a result.
  final String? evaluationError;

  /// Where the VM service truncates an evaluated string.
  final int? truncateAt;

  static const String libraryId = 'libraries/@1';
  static const String instanceId = 'objects/state';

  /// The expression the last `evaluate` was called with.
  String? lastExpression;

  /// The scope the last `evaluate` was called with.
  Map<String, Object?> lastScope = const {};

  List<Map<String, Object?>> get libraries => [
    {'type': '@Library', 'id': 'libraries/@0', 'uri': 'package:shop/main.dart'},
    {'type': '@Library', 'id': libraryId, 'uri': libraryUri},
  ];

  Map<String, Object?>? object(String id) {
    if (id == libraryId) {
      return {
        'type': 'Library',
        'id': libraryId,
        'uri': libraryUri,
        'variables': [
          {
            'type': '@Field',
            'id': '$libraryId/fields/$variable',
            'name': variable,
          },
        ],
      };
    }
    if (id == '$libraryId/fields/$variable') {
      return {
        'type': 'Field',
        'id': id,
        'name': variable,
        'staticValue': captured
            ? {'type': '@Instance', 'kind': 'PlainInstance', 'id': instanceId}
            : {'type': '@Instance', 'kind': 'Null', 'id': 'objects/null'},
      };
    }
    if (id == instanceId) {
      return {
        'type': 'Instance',
        'kind': 'PlainInstance',
        'id': instanceId,
        'class': {'type': '@Class', 'name': 'HomePageState'},
        'fields': [
          for (int i = 0; i < fields.length; i++) _boundField(fields[i], i),
        ],
      };
    }
    if (id == _evaluatedId) {
      return {
        'type': 'Instance',
        'kind': 'String',
        'id': id,
        'valueAsString': _encoded,
      };
    }
    return null;
  }

  Map<String, Object?> _boundField(FakeField field, int index) => {
    'decl': {
      'type': '@Field',
      'name': field.name,
      'owner': {'type': '@Class', 'name': field.owner},
    },
    'name': field.name,
    'value': field.sentinel != null
        ? {'type': '@Instance', 'kind': field.sentinel, 'id': 'objects/$index'}
        : {
            'type': '@Instance',
            'kind': field.type,
            'id': 'objects/$index',
            'class': {'type': '@Class', 'name': field.className},
          },
  };

  Object? evaluate(
    String target,
    String expression,
    Map<String, Object?> scope,
  ) {
    lastExpression = expression;
    lastScope = scope;
    if (!evaluates) return null;
    if (evaluationError != null) {
      return {
        'type': '@Error',
        'kind': 'UnhandledException',
        'id': 'objects/error',
        'message': evaluationError,
      };
    }
    final String encoded = _encoded;
    final int? cut = truncateAt;
    if (cut != null && encoded.length > cut) {
      return {
        'type': '@Instance',
        'kind': 'String',
        'id': _evaluatedId,
        'valueAsString': encoded.substring(0, cut),
        'valueAsStringIsTruncated': true,
      };
    }
    return {
      'type': '@Instance',
      'kind': 'String',
      'id': _evaluatedId,
      'valueAsString': encoded,
    };
  }

  static const String _evaluatedId = 'objects/encoded';

  /// What the app's encoder would return for the fields it was handed.
  String get _encoded => jsonEncode([
    for (final FakeField field in fields)
      if (field.owner == 'HomePageState')
        if (field.sentinel != null)
          null
        else
          {
            'type': field.className,
            if (field.value is List) 'count': (field.value as List).length,
            'value': field.value,
          },
  ]);
}
