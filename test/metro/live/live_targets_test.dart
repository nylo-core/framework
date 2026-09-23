import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_targets.dart';

void main() {
  LiveTargetSelection<String> select(
    List<String> apps, {
    String? device,
    bool all = false,
  }) => selectLiveTargets<String>(
    apps,
    deviceOf: (app) => app,
    device: device,
    all: all,
    packageName: 'shop',
  );

  const List<String> three = ['iPhone 17 Pro', 'iPhone 17e', 'Pixel 9'];

  group('selectLiveTargets', () {
    test('no running apps is an error with exit code 1', () {
      final LiveTargetSelection<String> selection = select([]);

      expect(selection.isSuccess, isFalse);
      expect(selection.exitCode, 1);
      expect(selection.error, contains('No running shop app found'));
      expect(selection.targets, isEmpty);
    });

    test('no running apps is still an error with --all or -d', () {
      expect(select([], all: true).exitCode, 1);
      expect(select([], device: '1').exitCode, 1);
    });

    test('a single app is used without flags', () {
      final LiveTargetSelection<String> selection = select(['iPhone 17e']);

      expect(selection.isSuccess, isTrue);
      expect(selection.targets, ['iPhone 17e']);
    });

    test('several apps without a target never guess (exit code 2)', () {
      final LiveTargetSelection<String> selection = select(three);

      expect(selection.isSuccess, isFalse);
      expect(selection.exitCode, 2);
      expect(selection.error, contains('3 apps are running'));
      expect(selection.candidates, three);
    });

    test('--all selects every app', () {
      expect(select(three, all: true).targets, three);
    });

    test('--all wins over -d', () {
      expect(select(three, all: true, device: 'Pixel').targets, three);
    });

    test('-d with a number picks by 1-based index', () {
      expect(select(three, device: '1').targets, ['iPhone 17 Pro']);
      expect(select(three, device: '3').targets, ['Pixel 9']);
    });

    test('-d with an out-of-range number is an error listing the apps', () {
      for (final String index in ['0', '4', '-1']) {
        final LiveTargetSelection<String> selection = select(
          three,
          device: index,
        );
        expect(selection.exitCode, 1, reason: index);
        expect(selection.candidates, three, reason: index);
      }
    });

    test('-d matches part of a device name, case-insensitively', () {
      expect(select(three, device: 'pixel').targets, ['Pixel 9']);
      expect(select(three, device: '17e').targets, ['iPhone 17e']);
    });

    test('-d prefers an exact name over partial matches', () {
      final LiveTargetSelection<String> selection = select([
        'iPhone 17',
        'iPhone 17 Pro',
      ], device: 'iphone 17');

      expect(selection.targets, ['iPhone 17']);
    });

    test('-d matching several apps is ambiguous (exit code 2)', () {
      final LiveTargetSelection<String> selection = select(
        three,
        device: 'iPhone',
      );

      expect(selection.exitCode, 2);
      expect(selection.candidates, ['iPhone 17 Pro', 'iPhone 17e']);
    });

    test('identical device names can only be told apart by number', () {
      const List<String> twins = ['iPhone 17 Pro', 'iPhone 17 Pro'];

      expect(select(twins, device: 'iPhone 17 Pro').exitCode, 2);
      expect(select(twins, device: '2').targets, hasLength(1));
    });

    test('-d with no match is an error listing the apps', () {
      final LiveTargetSelection<String> selection = select(
        three,
        device: 'Galaxy',
      );

      expect(selection.exitCode, 1);
      expect(selection.error, contains('"Galaxy"'));
      expect(selection.candidates, three);
    });

    test('a blank -d behaves like no target', () {
      expect(select(['iPhone 17e'], device: '  ').targets, ['iPhone 17e']);
      expect(select(three, device: '').exitCode, 2);
    });
  });
}
