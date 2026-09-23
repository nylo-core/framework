import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/json_rpc_client.dart';
import 'package:nylo_framework/metro/live/live_app.dart';

import 'fake_servers.dart';

void main() {
  group('LiveApp.parseStreamEvent', () {
    test('parses a nylo stream event', () {
      final LiveEvent? event = LiveApp.parseStreamEvent(
        const JsonRpcNotification('streamNotify', {
          'streamId': 'nylo',
          'event': {
            'extensionKind': 'nylo.log',
            'extensionData': {'type': 'info', 'message': 'hi'},
          },
        }),
        'nylo',
      );

      expect(event?.kind, 'nylo.log');
      expect(event?.data['message'], 'hi');
    });

    test('ignores other streams and notifications', () {
      expect(
        LiveApp.parseStreamEvent(
          const JsonRpcNotification('streamNotify', {
            'streamId': 'Extension',
            'event': {'extensionKind': 'Flutter.Frame'},
          }),
          'nylo',
        ),
        isNull,
      );
      expect(
        LiveApp.parseStreamEvent(
          const JsonRpcNotification('somethingElse', {}),
          'nylo',
        ),
        isNull,
      );
    });
  });

  group('LiveApp', () {
    late FakeNyloApp fake;
    LiveApp? app;

    tearDown(() async {
      await app?.close();
      app = null;
      await fake.close();
    });

    Future<LiveApp> connect() async => app = await LiveApp.connect(
      fake.wsUri,
      device: 'iPhone 17e',
      package: 'shop',
    );

    test('connect finds the Nylo isolate and loads status', () async {
      fake = await FakeNyloApp.start();

      final LiveApp live = await connect();

      expect(live.isolateId, 'isolates/100');
      expect(live.status['platform'], 'ios');
    });

    test(
      'call sends args as one JSON-encoded parameter and unwraps the result',
      () async {
        fake = await FakeNyloApp.start(
          commands: {
            'route.push': (args) => {'from': '/home', 'current': args['path']},
          },
        );
        final LiveApp live = await connect();

        final Object? result = await live.call('route.push', {
          'path': '/profile',
          'data': {'id': 42},
        });

        expect(result, {'from': '/home', 'current': '/profile'});
        expect(fake.calls['route.push']!.single, {
          'path': '/profile',
          'data': {'id': 42},
        });
      },
    );

    test('call surfaces app errors with their details', () async {
      fake = await FakeNyloApp.start(
        commands: {
          'storage.get': (args) => throw FakeRpcError(
            -32602,
            'Invalid params',
            {'details': 'key is required'},
          ),
        },
      );
      final LiveApp live = await connect();

      await expectLater(
        live.call('storage.get'),
        throwsA(
          isA<JsonRpcException>().having(
            (e) => e.details,
            'details',
            'key is required',
          ),
        ),
      );
    });

    test('call finds the new isolate after a hot restart', () async {
      fake = await FakeNyloApp.start(
        commands: {
          'routes': (args) => {
            'routes': ['/home'],
          },
        },
      );
      final LiveApp live = await connect();
      fake.state.isolateId = 'isolates/300';

      final Object? result = await live.call('routes');

      expect(result, {
        'routes': ['/home'],
      });
      expect(live.isolateId, 'isolates/300');
    });

    test(
      'connect fails with a clear message when the app never responds',
      () async {
        fake = await FakeNyloApp.start(respond: false);

        await expectLater(
          LiveApp.connect(
            fake.wsUri,
            device: 'iPhone 17e',
            package: 'shop',
            timeout: const Duration(milliseconds: 300),
          ),
          throwsA(
            isA<LiveCommandException>().having(
              (e) => e.message,
              'message',
              contains('didn\'t respond'),
            ),
          ),
        );
      },
    );

    test('events streams nylo stream notifications', () async {
      fake = await FakeNyloApp.start();
      final LiveApp live = await connect();
      final Future<LiveEvent> first = live.events().first;

      await Future<void>.delayed(const Duration(milliseconds: 100));
      fake.server.clients.single.streamNotify('nylo', {
        'kind': 'Extension',
        'extensionKind': 'nylo.route',
        'extensionData': {'action': 'push', 'name': '/profile'},
        'timestamp': 1700000000000,
      });
      final LiveEvent event = await first.timeout(const Duration(seconds: 2));

      expect(event.kind, 'nylo.route');
      expect(event.data['name'], '/profile');
      expect(event.timestamp, isNotNull);
      expect(fake.server.methods, contains('streamListen'));
    });

    test('reload calls the tool service the Flutter tool registered', () async {
      fake = await FakeNyloApp.start();
      final LiveApp live = await connect();

      await live.reload();

      expect(await live.toolServiceMethod('reloadSources'), 's1.reloadSources');
      expect(fake.server.methods, contains('s1.reloadSources'));
    });

    test('restart re-resolves the isolate and refreshes status', () async {
      fake = await FakeNyloApp.start();
      final LiveApp live = await connect();

      await live.restart(timeout: const Duration(seconds: 5));

      expect(live.isolateId, 'isolates/200');
      expect(fake.server.methods, contains('s1.hotRestart'));
    });
  });
}
