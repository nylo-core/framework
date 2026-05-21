import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/ny_cli.dart';

void main() {
  group('ScaffoldFile', () {
    test('can be created with required parameters', () {
      final file = ScaffoldFile(
        path: 'lib/test/file.dart',
        content: 'class Test {}',
      );

      expect(file.path, equals('lib/test/file.dart'));
      expect(file.content, equals('class Test {}'));
      expect(file.successMessage, isNull);
    });

    test('can be created with success message', () {
      final file = ScaffoldFile(
        path: 'lib/models/user.dart',
        content: 'class User {}',
        successMessage: 'Created User model successfully',
      );

      expect(file.path, equals('lib/models/user.dart'));
      expect(file.content, equals('class User {}'));
      expect(file.successMessage, equals('Created User model successfully'));
    });

    test('is a const class', () {
      const file = ScaffoldFile(path: 'test/path.dart', content: 'content');

      expect(file, isNotNull);
    });
  });

  group('CommandTask', () {
    test('can be created with name and action', () {
      final task = CommandTask('Run tests', () async {});

      expect(task.name, equals('Run tests'));
      expect(task.action, isNotNull);
      expect(task.stopOnError, isTrue); // default
    });

    test('can be created with stopOnError false', () {
      final task = CommandTask(
        'Optional task',
        () async {},
        stopOnError: false,
      );

      expect(task.stopOnError, isFalse);
    });

    test('action can be executed', () async {
      var executed = false;
      final task = CommandTask('Test task', () async {
        executed = true;
      });

      await task.action();
      expect(executed, isTrue);
    });

    test('is a const class', () {
      const task = CommandTask('Const task', _dummyAction);

      expect(task, isNotNull);
    });
  });
}

Future<void> _dummyAction() async {}
