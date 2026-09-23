import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/stubs/seeder_stub.dart';
import 'package:recase/recase.dart';

void main() {
  group('seederStub', () {
    test('creates a public seeder class with up() and down()', () {
      final String stub = seederStub(seeder: ReCase('demo_user'));

      expect(stub, contains('class DemoUserSeeder extends Seeder'));
      expect(stub, contains('Future<void> up() async'));
      expect(stub, contains('Future<void> down() async'));
      expect(stub, contains('await restore();'));
      expect(stub, isNot(contains('class _')));
    });

    test('imports the framework and the live library', () {
      final String stub = seederStub(seeder: ReCase('demo_user'));

      expect(
        stub,
        contains("import 'package:nylo_framework/nylo_framework.dart';"),
      );
      expect(stub, contains("import 'package:nylo_framework/live.dart';"));
      expect(stub, contains(r'${Nylo.getCurrentRouteName()}'));
    });

    test('documents how to run and undo it', () {
      final String stub = seederStub(seeder: ReCase('demo_user'));

      expect(stub, contains('/// Demo User Seeder'));
      expect(stub, contains('/// Run it in metro live:  seed demo_user\n'));
      expect(
        stub,
        contains('/// Undo it in metro live: seed:rollback demo_user\n'),
      );
      // No metro live:<command>: these commands only run inside the shell.
      expect(stub, isNot(matches(r'metro live:\w')));
      expect(stub, isNot(contains('--down')));
    });

    test('uses the description, escaped for a Dart string', () {
      expect(
        seederStub(seeder: ReCase('demo_user')),
        contains("description => 'Describe the state this seeder creates';"),
      );
      expect(
        seederStub(
          seeder: ReCase('demo_user'),
          description: r"Jane's account, $5 credit",
        ),
        contains(r"description => 'Jane\'s account, \$5 credit';"),
      );
    });
  });
}
