import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// An error response returned by a JSON-RPC 2.0 peer.
class JsonRpcException implements Exception {
  /// Creates a [JsonRpcException] from an error [code], [message] and [data].
  JsonRpcException(this.code, this.message, [this.data]);

  /// The JSON-RPC error code, e.g. `-32601` (method not found).
  final int code;

  /// The error message sent by the peer.
  final String message;

  /// Optional structured error data sent by the peer.
  final Object? data;

  /// The most useful human-readable text for this error.
  ///
  /// VM service extension errors carry the app's message in
  /// `data.details`, so that wins over the generic [message].
  String get details {
    final Object? value = data;
    if (value is Map && value['details'] is String) {
      final String text = value['details'] as String;
      if (text.isNotEmpty) return text;
    }
    return message;
  }

  @override
  String toString() => 'JsonRpcException($code): $details';
}

/// Thrown for calls that can't complete because the connection closed.
class JsonRpcConnectionClosed implements Exception {
  /// Creates a [JsonRpcConnectionClosed] for the call to [method].
  JsonRpcConnectionClosed(this.method);

  /// The method that was waiting for a response.
  final String method;

  @override
  String toString() => 'The connection closed before "$method" responded';
}

/// A notification pushed by the peer, such as a VM service `streamNotify`.
class JsonRpcNotification {
  /// Creates a [JsonRpcNotification] for [method] with [params].
  const JsonRpcNotification(this.method, this.params);

  /// The notification method, e.g. `streamNotify`.
  final String method;

  /// The notification parameters.
  final Map<String, Object?> params;
}

/// A minimal JSON-RPC 2.0 client over a WebSocket.
///
/// Used by `metro live:*` to talk to the Dart Tooling Daemon and to the
/// VM service of a running app without extra package dependencies.
class JsonRpcClient {
  JsonRpcClient._(this._socket, this.timeout) {
    _socket.listen(
      _onMessage,
      onDone: _onDone,
      onError: (Object _) => _onDone(),
      cancelOnError: true,
    );
  }

  /// Opens a connection to the WebSocket at [uri].
  ///
  /// Throws a [TimeoutException] when the server doesn't complete the
  /// handshake within [timeout], which then becomes the default timeout for
  /// every [call].
  static Future<JsonRpcClient> connect(
    Uri uri, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final HttpClient http = HttpClient()..connectionTimeout = timeout;
    final Future<WebSocket> pending = WebSocket.connect(
      uri.toString(),
      customClient: http,
    );
    try {
      final WebSocket socket = await pending.timeout(timeout);
      return JsonRpcClient._(socket, timeout);
    } on TimeoutException {
      http.close(force: true);
      pending.then((socket) => socket.close(), onError: (Object _) {});
      throw TimeoutException('Timed out connecting to $uri', timeout);
    } finally {
      http.close();
    }
  }

  final WebSocket _socket;

  /// The default time to wait for a response to a [call].
  final Duration timeout;

  final Map<String, ({String method, Completer<Object?> completer})> _pending =
      {};
  final StreamController<JsonRpcNotification> _notifications =
      StreamController<JsonRpcNotification>.broadcast();
  final Completer<void> _done = Completer<void>();
  int _nextId = 1;
  bool _closed = false;

  /// Notifications pushed by the peer.
  Stream<JsonRpcNotification> get notifications => _notifications.stream;

  /// Whether the connection has closed.
  bool get isClosed => _closed;

  /// Completes when the connection closes.
  Future<void> get done => _done.future;

  /// Calls [method] with [params] and returns the `result` of the response.
  ///
  /// Throws a [JsonRpcException] for error responses, a [TimeoutException]
  /// when no response arrives within [timeout] (or the client default), and
  /// a [JsonRpcConnectionClosed] when the connection closes first.
  Future<Object?> call(
    String method, [
    Map<String, Object?> params = const {},
    Duration? timeout,
  ]) {
    if (_closed) return Future.error(JsonRpcConnectionClosed(method));

    final String id = '${_nextId++}';
    final Completer<Object?> completer = Completer<Object?>();
    _pending[id] = (method: method, completer: completer);
    try {
      _socket.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          'params': params,
        }),
      );
    } on StateError {
      _pending.remove(id);
      return Future.error(JsonRpcConnectionClosed(method));
    }

    final Duration limit = timeout ?? this.timeout;
    return completer.future.timeout(
      limit,
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('No response to $method', limit);
      },
    );
  }

  /// Closes the connection and fails any calls still waiting.
  Future<void> close() async {
    if (_closed) return;
    try {
      await _socket.close().timeout(
        const Duration(seconds: 1),
        onTimeout: () {},
      );
    } catch (_) {
      // Closing a broken socket can throw; the connection is gone either way.
    }
    _onDone();
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is List) {
      decoded.forEach(_handle);
      return;
    }
    _handle(decoded);
  }

  void _handle(Object? message) {
    if (message is! Map) return;

    if (message.containsKey('method')) {
      // Requests from the peer aren't served; notifications are surfaced.
      if (message['id'] != null) return;
      final Object? method = message['method'];
      final Object? params = message['params'];
      if (method is! String || _notifications.isClosed) return;
      _notifications.add(
        JsonRpcNotification(
          method,
          params is Map ? Map<String, Object?>.from(params) : const {},
        ),
      );
      return;
    }

    final Completer<Object?>? completer = _pending
        .remove('${message['id']}')
        ?.completer;
    if (completer == null || completer.isCompleted) return;

    if (message.containsKey('error')) {
      final Object? error = message['error'];
      if (error is Map) {
        completer.completeError(
          JsonRpcException(
            (error['code'] as num?)?.toInt() ?? -32603,
            '${error['message'] ?? 'Unknown error'}',
            error['data'],
          ),
        );
      } else {
        completer.completeError(JsonRpcException(-32603, '$error'));
      }
      return;
    }

    completer.complete(message['result']);
  }

  void _onDone() {
    if (_closed) return;
    _closed = true;
    final List<({String method, Completer<Object?> completer})> waiting =
        _pending.values.toList();
    _pending.clear();
    for (final ({String method, Completer<Object?> completer}) call
        in waiting) {
      if (!call.completer.isCompleted) {
        call.completer.completeError(JsonRpcConnectionClosed(call.method));
      }
    }
    _notifications.close();
    if (!_done.isCompleted) _done.complete();
  }
}
