import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/stubs/live_command_stub.dart';
import 'package:recase/recase.dart';

void main() {
  group('liveCommandStub', () {
    test('creates a public command class extending LiveCommand', () {
      final String stub = liveCommandStub(customCommand: ReCase('seed_cart'));

      expect(stub, contains('class SeedCartCommand extends LiveCommand'));
      expect(stub, isNot(contains('class _')));
      expect(stub, isNot(contains('void main(')));
    });

    test('imports the framework and the live library', () {
      final String stub = liveCommandStub(customCommand: ReCase('seed_cart'));

      expect(
        stub,
        contains("import 'package:nylo_framework/nylo_framework.dart';"),
      );
      expect(stub, contains("import 'package:nylo_framework/live.dart';"));
    });

    test('documents how to run it with the category', () {
      final String stub = liveCommandStub(
        customCommand: ReCase('login_as'),
        category: 'user',
      );

      expect(stub, contains('[From Terminal] metro user:login_as'));
      expect(stub, contains('/// Login As Command'));
    });

    test('defaults the category to app', () {
      final String stub = liveCommandStub(customCommand: ReCase('seed_cart'));

      expect(stub, contains('metro app:seed_cart'));
    });

    test('mirrors the custom command builder and handle signatures', () {
      final String stub = liveCommandStub(customCommand: ReCase('seed_cart'));

      expect(stub, contains('CommandBuilder builder(CommandBuilder command)'));
      expect(stub, contains('Future<void> handle(CommandResult result) async'));
      expect(stub, contains('// command.addOption('));
      expect(stub, contains('// command.addFlag('));
    });

    test('uses the framework import in its default output', () {
      final String stub = liveCommandStub(customCommand: ReCase('seed_cart'));

      expect(stub, contains(r'${Nylo.getCurrentRouteName()}'));
    });
  });
}
