import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/json_rpc_client.dart';

import 'fake_servers.dart';

void main() {
  group('JsonRpcClient', () {
    late FakeJsonRpcServer server;

    tearDown(() async => server.close());

    test('returns the result of a call', () async {
      server = await FakeJsonRpcServer.start(
        (method, params, connection) => {'echo': method, 'params': params},
      );
      final JsonRpcClient client = await JsonRpcClient.connect(server.wsUri);

      final Object? result = await client.call('getVM', {'a': 1});

      expect(result, {
        'echo': 'getVM',
        'params': {'a': 1},
      });
      await client.close();
    });

    test('matches concurrent responses to their calls', () async {
      server = await FakeJsonRpcServer.start((
        method,
        params,
        connection,
      ) async {
        if (method == 'slow') {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        return method;
      });
      final JsonRpcClient client = await JsonRpcClient.connect(server.wsUri);

      final List<Object?> results = await Future.wait([
        client.call('slow'),
        client.call('fast'),
      ]);

      expect(results, ['slow', 'fast']);
      await client.close();
    });

    test('throws JsonRpcException with the details from error data', () async {
      server = await FakeJsonRpcServer.start((method, params, connection) {
        throw FakeRpcError(-32602, 'Invalid params', {
          'details': 'path is required',
        });
      });
      final JsonRpcClient client = await JsonRpcClient.connect(server.wsUri);

      await expectLater(
        client.call('ext.nylo.route.push'),
        throwsA(
          isA<JsonRpcException>()
              .having((e) => e.code, 'code', -32602)
              .having((e) => e.details, 'details', 'path is required'),
        ),
      );
      await client.close();
    });

    test('falls back to the message when there are no details', () async {
      server = await FakeJsonRpcServer.start((method, params, connection) {
        throw FakeRpcError(-32601, 'Method not found');
      });
      final JsonRpcClient client = await JsonRpcClient.connect(server.wsUri);

      await expectLater(
        client.call('nope'),
        throwsA(
          isA<JsonRpcException>().having(
            (e) => e.details,
            'details',
            'Method not found',
          ),
        ),
      );
      await client.close();
    });

    test('times out when the server never responds', () async {
      server = await FakeJsonRpcServer.start(
        (method, params, connection) => noResponse,
      );
      final JsonRpcClient client = await JsonRpcClient.connect(
        server.wsUri,
        timeout: const Duration(milliseconds: 200),
      );
      final Stopwatch stopwatch = Stopwatch()..start();

      await expectLater(client.call('getVM'), throwsA(isA<TimeoutException>()));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      await client.close();
    });

    test('a per-call timeout overrides the default', () async {
      server = await FakeJsonRpcServer.start(
        (method, params, connection) => noResponse,
      );
      final JsonRpcClient client = await JsonRpcClient.connect(server.wsUri);
      final Stopwatch stopwatch = Stopwatch()..start();

      await expectLater(
        client.call('getVM', const {}, const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      await client.close();
    });

    test('surfaces notifications pushed by the server', () async {
      server = await FakeJsonRpcServer.start((method, params, connection) {
        Timer.run(
          () => connection.streamNotify('nylo', {
            'kind': 'Extension',
            'extensionKind': 'nylo.route',
          }),
        );
        return {'type': 'Success'};
      });
      final JsonRpcClient client = await JsonRpcClient.connect(server.wsUri);
      final Future<JsonRpcNotification> next = client.notifications.first;

      await client.call('streamListen', {'streamId': 'nylo'});
      final JsonRpcNotification notification = await next;

      expect(notification.method, 'streamNotify');
      expect(notification.params['streamId'], 'nylo');
      await client.close();
    });

    test('fails pending calls when the connection closes', () async {
      server = await FakeJsonRpcServer.start((method, params, connection) {
        Timer.run(() => connection.socket.close());
        return noResponse;
      });
      final JsonRpcClient client = await JsonRpcClient.connect(server.wsUri);

      await expectLater(
        client.call('getVM', const {}, const Duration(seconds: 5)),
        throwsA(
          isA<JsonRpcConnectionClosed>().having(
            (e) => e.method,
            'method',
            'getVM',
          ),
        ),
      );
      expect(client.isClosed, isTrue);
      await expectLater(
        client.call('getVM'),
        throwsA(isA<JsonRpcConnectionClosed>()),
      );
    });

    test(
      'times out connecting to a server that never answers the handshake',
      () async {
        final ServerSocket silent = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final List<Socket> accepted = [];
        silent.listen(accepted.add);
        server = await FakeJsonRpcServer.start(
          (method, params, connection) => null,
        );
        final Stopwatch stopwatch = Stopwatch()..start();

        await expectLater(
          JsonRpcClient.connect(
            Uri.parse('ws://127.0.0.1:${silent.port}/ws'),
            timeout: const Duration(milliseconds: 300),
          ),
          throwsA(isA<TimeoutException>()),
        );
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));

        for (final Socket socket in accepted) {
          socket.destroy();
        }
        await silent.close();
      },
    );

    test('fails to connect when nothing is listening', () async {
      server = await FakeJsonRpcServer.start(
        (method, params, connection) => null,
      );
      final int port = await closedPort();

      await expectLater(
        JsonRpcClient.connect(Uri.parse('ws://127.0.0.1:$port/ws')),
        throwsA(anything),
      );
    });
  });
}
