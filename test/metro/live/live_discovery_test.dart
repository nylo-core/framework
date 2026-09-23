import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_discovery.dart';

import 'fake_servers.dart';

void main() {
  group('LiveAppDescriptor.parse', () {
    test('reads the device and package from a ConnectedApp name', () {
      final LiveAppDescriptor? descriptor = LiveAppDescriptor.parse(
        'Kind: Flutter - Device: iPhone 17 Pro Max - Package: flutter_app',
      );

      expect(descriptor?.kind, 'Flutter');
      expect(descriptor?.device, 'iPhone 17 Pro Max');
      expect(descriptor?.package, 'flutter_app');
    });

    test('keeps dashes inside device names', () {
      final LiveAppDescriptor? descriptor = LiveAppDescriptor.parse(
        'Kind: Flutter - Device: Pixel 9 - API 36 - Package: shop',
      );

      expect(descriptor?.device, 'Pixel 9 - API 36');
      expect(descriptor?.package, 'shop');
    });

    test('returns null for names without a package', () {
      expect(LiveAppDescriptor.parse('Kind: Dart - Device: macOS'), isNull);
      expect(LiveAppDescriptor.parse(null), isNull);
      expect(LiveAppDescriptor.parse(''), isNull);
    });
  });

  group('LiveDaemon.fromJson', () {
    test('parses tooling-daemon --list entries', () {
      final LiveDaemon? daemon = LiveDaemon.fromJson({
        'wsUri': 'ws://127.0.0.1:53843/J8lWPqVlF6M=',
        'pid': 4417,
        'workspaceRoot': '/projects/shop',
        'ideName': 'Android Studio',
      });

      expect(daemon?.wsUri.port, 53843);
      expect(daemon?.pid, 4417);
      expect(daemon?.workspaceRoot, '/projects/shop');
      expect(daemon?.ideName, 'Android Studio');
    });

    test('rejects entries without a wsUri', () {
      expect(LiveDaemon.fromJson({'pid': 1}), isNull);
      expect(LiveDaemon.fromJson('nope'), isNull);
    });
  });

  group('LiveDiscovery.normalizeVmServiceUri', () {
    test('keeps a DDS WebSocket URI', () {
      expect(
        LiveDiscovery.normalizeVmServiceUri(
          'ws://127.0.0.1:53844/F0ZlHE-L7fI=/ws',
        ).toString(),
        'ws://127.0.0.1:53844/F0ZlHE-L7fI=/ws',
      );
    });

    test('converts the printed http address', () {
      expect(
        LiveDiscovery.normalizeVmServiceUri(
          'http://127.0.0.1:53844/F0ZlHE-L7fI=/',
        ).toString(),
        'ws://127.0.0.1:53844/F0ZlHE-L7fI=/ws',
      );
    });

    test('drops a trailing slash after /ws', () {
      expect(
        LiveDiscovery.normalizeVmServiceUri(
          'ws://127.0.0.1:53844/F0ZlHE-L7fI=/ws/',
        ).toString(),
        'ws://127.0.0.1:53844/F0ZlHE-L7fI=/ws',
      );
    });

    test('adds /ws to a WebSocket URI without it', () {
      expect(
        LiveDiscovery.normalizeVmServiceUri(
          'ws://127.0.0.1:53844/F0ZlHE-L7fI=',
        ).toString(),
        'ws://127.0.0.1:53844/F0ZlHE-L7fI=/ws',
      );
    });

    test('reads the address out of a DevTools link', () {
      expect(
        LiveDiscovery.normalizeVmServiceUri(
          'http://127.0.0.1:9100/devtools/?uri=ws://127.0.0.1:53844/abc=/ws',
        ).toString(),
        'ws://127.0.0.1:53844/abc=/ws',
      );
    });

    test('rejects addresses that are not VM service URIs', () {
      expect(LiveDiscovery.normalizeVmServiceUri('not a uri'), isNull);
      expect(LiveDiscovery.normalizeVmServiceUri('ftp://host/x'), isNull);
    });
  });

  group('LiveDiscovery.discover', () {
    final List<Future<void> Function()> cleanup = [];
    late Directory project;

    /// Creates a Flutter project folder with a pubspec and lib/main.dart.
    Directory makeProject(String name) {
      final Directory dir = Directory.systemTemp.createTempSync(name);
      File('${dir.path}/pubspec.yaml').writeAsStringSync('name: shop\n');
      File('${dir.path}/lib/main.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      cleanup.add(() async => dir.deleteSync(recursive: true));
      return dir;
    }

    setUp(() {
      project = makeProject('nylo_live_shop_');
    });

    tearDown(() async {
      for (final Future<void> Function() close in cleanup.reversed) {
        await close();
      }
      cleanup.clear();
    });

    Future<FakeNyloApp> app({
      Map<String, Object?>? status,
      bool respond = true,
      String? entrypoint,
      bool resolvesPackageUris = true,
    }) async {
      final FakeNyloApp fake = await FakeNyloApp.start(
        status: status,
        respond: respond,
        entrypoint: entrypoint ?? '${project.path}/lib/main.dart',
        resolvesPackageUris: resolvesPackageUris,
      );
      cleanup.add(fake.close);
      return fake;
    }

    Future<FakeJsonRpcServer> daemon(
      List<({Uri uri, String name})> apps,
    ) async {
      final FakeJsonRpcServer fake = await startFakeDaemon(apps);
      cleanup.add(fake.close);
      return fake;
    }

    test('finds a running app of this project', () async {
      final FakeNyloApp phone = await app();
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: phone.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
        ),
      ]);

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async => [LiveDaemon(wsUri: dtd.wsUri)],
      ).discover();

      expect(result.apps, hasLength(1));
      final app0 = result.apps.single;
      expect(app0.device, 'iPhone 17e');
      expect(app0.package, 'shop');
      expect(app0.isolateId, 'isolates/100');
      expect(app0.status['route'], '/home');
      expect(result.skipped, isEmpty);
      await app0.close();
    });

    test('never connects to apps of another package', () async {
      final FakeNyloApp mine = await app();
      final FakeNyloApp other = await app();
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: mine.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
        ),
        (
          uri: other.wsUri,
          name: 'Kind: Flutter - Device: Pixel 9 - Package: tudae',
        ),
      ]);

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async => [LiveDaemon(wsUri: dtd.wsUri)],
      ).discover();

      expect(result.apps.map((a) => a.device), ['iPhone 17e']);
      expect(other.server.connections, 0);
      for (final a in result.apps) {
        await a.close();
      }
    });

    test('skips an app that does not respond, within the timeout', () async {
      final FakeNyloApp awake = await app();
      final FakeNyloApp asleep = await app(respond: false);
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: awake.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17 Pro - Package: shop',
        ),
        (
          uri: asleep.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
        ),
      ]);
      final Stopwatch stopwatch = Stopwatch()..start();

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        timeout: const Duration(milliseconds: 400),
        listDaemons: () async => [LiveDaemon(wsUri: dtd.wsUri)],
      ).discover();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(result.apps.map((a) => a.device), ['iPhone 17 Pro']);
      expect(result.skipped.map((s) => s.device), ['iPhone 17e']);
      expect(result.skipped.single.reason, contains('didn\'t respond'));
      expect(asleep.server.connections, 1);
      for (final a in result.apps) {
        await a.close();
      }
    });

    test('ignores unreachable and unresponsive daemons', () async {
      final FakeNyloApp phone = await app();
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: phone.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
        ),
      ]);
      final FakeJsonRpcServer silentDaemon = await FakeJsonRpcServer.start(
        (method, params, connection) => noResponse,
      );
      cleanup.add(silentDaemon.close);
      final int deadPort = await closedPort();

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        timeout: const Duration(milliseconds: 400),
        listDaemons: () async => [
          LiveDaemon(wsUri: Uri.parse('ws://127.0.0.1:$deadPort/x=')),
          LiveDaemon(wsUri: silentDaemon.wsUri),
          LiveDaemon(wsUri: dtd.wsUri),
        ],
      ).discover();

      expect(result.apps.map((a) => a.device), ['iPhone 17e']);
      for (final a in result.apps) {
        await a.close();
      }
    });

    test('lists an app once when several daemons know it', () async {
      final FakeNyloApp phone = await app();
      final String name = 'Kind: Flutter - Device: iPhone 17e - Package: shop';
      final FakeJsonRpcServer terminalDaemon = await daemon([
        (uri: phone.wsUri, name: name),
      ]);
      final FakeJsonRpcServer ideDaemon = await daemon([
        (
          uri: Uri.parse('http://127.0.0.1:${phone.wsUri.port}/secret=/'),
          name: name,
        ),
      ]);

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async => [
          LiveDaemon(wsUri: ideDaemon.wsUri, ideName: 'Android Studio'),
          LiveDaemon(wsUri: terminalDaemon.wsUri),
        ],
      ).discover();

      expect(result.apps, hasLength(1));
      expect(phone.server.connections, 1);
      await result.apps.single.close();
    });

    test('sorts apps by device name so -d numbers are stable', () async {
      final FakeNyloApp a = await app();
      final FakeNyloApp b = await app();
      final FakeNyloApp c = await app();
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: a.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
        ),
        (uri: b.wsUri, name: 'Kind: Flutter - Device: Pixel 9 - Package: shop'),
        (
          uri: c.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17 Pro - Package: shop',
        ),
      ]);

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async => [LiveDaemon(wsUri: dtd.wsUri)],
      ).discover();

      expect(result.apps.map((app) => app.device), [
        'iPhone 17 Pro',
        'iPhone 17e',
        'Pixel 9',
      ]);
      for (final app0 in result.apps) {
        await app0.close();
      }
    });

    test('skips an app without Nylo Live', () async {
      final FakeJsonRpcServer plainApp = await FakeJsonRpcServer.start((
        method,
        params,
        connection,
      ) {
        if (method == 'getVM') {
          return {
            'isolates': [
              {'id': 'isolates/1', 'name': 'main'},
            ],
          };
        }
        return {'extensionRPCs': <String>[]};
      });
      cleanup.add(plainApp.close);
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: plainApp.wsUri,
          name: 'Kind: Flutter - Device: macOS - Package: shop',
        ),
      ]);

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async => [LiveDaemon(wsUri: dtd.wsUri)],
      ).discover();

      expect(result.apps, isEmpty);
      expect(
        result.skipped.single.reason,
        contains('doesn\'t expose Nylo Live'),
      );
    });

    test(
      'never contacts same-named apps from another project\'s daemon',
      () async {
        final Directory tudae = makeProject('nylo_live_tudae_');
        final FakeNyloApp theirs = await app(
          entrypoint: '${tudae.path}/lib/main.dart',
        );
        final FakeJsonRpcServer dtd = await daemon([
          (
            uri: theirs.wsUri,
            name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
          ),
        ]);

        final LiveDiscoveryResult result = await LiveDiscovery(
          projectRoot: project.path,
          packageName: 'shop',
          listDaemons: () async => [
            LiveDaemon(
              wsUri: dtd.wsUri,
              workspaceRoot: tudae.path,
              ideName: 'Android Studio',
            ),
          ],
        ).discover();

        expect(result.apps, isEmpty);
        expect(result.skipped, isEmpty);
        expect(theirs.server.connections, 0);
      },
    );

    test('ignores same-named apps built from another project', () async {
      final Directory other = makeProject('nylo_live_other_');
      final FakeNyloApp mine = await app();
      final FakeNyloApp theirs = await app(
        entrypoint: '${other.path}/lib/main.dart',
      );
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: mine.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17 Pro - Package: shop',
        ),
        (
          uri: theirs.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
        ),
      ]);

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async => [
          LiveDaemon(wsUri: dtd.wsUri, workspaceRoot: '/'),
        ],
      ).discover();

      expect(result.apps.map((a) => a.device), ['iPhone 17 Pro']);
      expect(result.skipped, isEmpty);
      for (final a in result.apps) {
        await a.close();
      }
    });

    test('accepts entrypoints under the project, e.g. flavor mains', () async {
      final FakeNyloApp staging = await app(
        entrypoint: '${project.path}/lib/main_staging.dart',
      );
      final Directory monorepo = project.parent;
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: staging.wsUri,
          name: 'Kind: Flutter - Device: Pixel 9 - Package: shop',
        ),
      ]);

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async => [
          LiveDaemon(wsUri: dtd.wsUri, workspaceRoot: monorepo.path),
        ],
      ).discover();

      expect(result.apps.map((a) => a.device), ['Pixel 9']);
      await result.apps.single.close();
    });

    test(
      'trusts the project\'s own daemon when the entrypoint is unknown',
      () async {
        final FakeNyloApp phone = await app(resolvesPackageUris: false);
        final FakeJsonRpcServer dtd = await daemon([
          (
            uri: phone.wsUri,
            name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
          ),
        ]);

        final LiveDiscoveryResult result = await LiveDiscovery(
          projectRoot: project.path,
          packageName: 'shop',
          listDaemons: () async => [
            LiveDaemon(wsUri: dtd.wsUri, workspaceRoot: project.path),
          ],
        ).discover();

        expect(result.apps.map((a) => a.device), ['iPhone 17e']);
        await result.apps.single.close();
      },
    );

    test('skips unverifiable apps from other daemons', () async {
      final FakeNyloApp phone = await app(resolvesPackageUris: false);
      final FakeJsonRpcServer dtd = await daemon([
        (
          uri: phone.wsUri,
          name: 'Kind: Flutter - Device: iPhone 17e - Package: shop',
        ),
      ]);

      final LiveDiscoveryResult result = await LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async => [LiveDaemon(wsUri: dtd.wsUri)],
      ).discover();

      expect(result.apps, isEmpty);
      expect(result.skipped.single.reason, contains('Couldn\'t confirm'));
    });

    test('reports a failure to list daemons', () async {
      final LiveDiscovery discovery = LiveDiscovery(
        projectRoot: project.path,
        packageName: 'shop',
        listDaemons: () async =>
            throw LiveDiscoveryException('Pass --uri instead.'),
      );

      await expectLater(
        discovery.discover(),
        throwsA(isA<LiveDiscoveryException>()),
      );
    });
  });

  group('LiveDiscovery.canonicalPath', () {
    test('ignores trailing separators', () {
      final String temp = Directory.systemTemp.path;
      expect(
        LiveDiscovery.canonicalPath('$temp/'),
        LiveDiscovery.canonicalPath(temp),
      );
    });
  });
}
