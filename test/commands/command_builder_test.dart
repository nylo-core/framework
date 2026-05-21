import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/ny_cli.dart';

void main() {
  group('CommandBuilder', () {
    test('addOption parses --name value', () {
      final builder = CommandBuilder()..addOption('name', abbr: 'n');
      final result = builder.parse(['--name', 'John']);

      expect(result.getString('name'), equals('John'));
    });

    test('addOption parses abbreviated -n value', () {
      final builder = CommandBuilder()..addOption('name', abbr: 'n');
      final result = builder.parse(['-n', 'Jane']);

      expect(result.getString('name'), equals('Jane'));
    });

    test('addFlag parses --force as boolean true', () {
      final builder = CommandBuilder()..addFlag('force', abbr: 'f');
      final result = builder.parse(['--force']);

      expect(result.getBool('force'), isTrue);
    });

    test('addFlag defaults to false when not provided', () {
      final builder = CommandBuilder()..addFlag('force', abbr: 'f');
      final result = builder.parse([]);

      expect(result.getBool('force'), isFalse);
    });

    test('addFlag parses abbreviated -f as boolean true', () {
      final builder = CommandBuilder()..addFlag('force', abbr: 'f');
      final result = builder.parse(['-f']);

      expect(result.getBool('force'), isTrue);
    });

    test('default values used when option not provided', () {
      final builder = CommandBuilder()
        ..addOption('name', abbr: 'n', defaultValue: 'DefaultName');
      final result = builder.parse([]);

      expect(result.getString('name'), equals('DefaultName'));
    });

    test('provided value overrides default', () {
      final builder = CommandBuilder()
        ..addOption('name', abbr: 'n', defaultValue: 'DefaultName');
      final result = builder.parse(['--name', 'CustomName']);

      expect(result.getString('name'), equals('CustomName'));
    });

    test('multiple options parsed correctly', () {
      final builder = CommandBuilder()
        ..addOption('name', abbr: 'n')
        ..addOption('email', abbr: 'e')
        ..addFlag('verbose', abbr: 'v');
      final result = builder.parse([
        '--name',
        'John',
        '--email',
        'john@example.com',
        '--verbose',
      ]);

      expect(result.getString('name'), equals('John'));
      expect(result.getString('email'), equals('john@example.com'));
      expect(result.getBool('verbose'), isTrue);
    });

    test('rest captures unparsed arguments', () {
      final builder = CommandBuilder()..addFlag('force', abbr: 'f');
      final result = builder.parse(['--force', 'arg1', 'arg2']);

      expect(result.rest, contains('arg1'));
      expect(result.rest, contains('arg2'));
    });

    test('usage returns help text', () {
      final builder = CommandBuilder()
        ..addOption('name', abbr: 'n', help: 'The name to use')
        ..addFlag('force', abbr: 'f', help: 'Force the operation');
      final usage = builder.usage;

      expect(usage, contains('name'));
      expect(usage, contains('force'));
    });
  });

  group('CommandResult', () {
    test('hasForceFlag returns true when force flag is set', () {
      final builder = CommandBuilder()..addFlag('force', abbr: 'f');
      final result = builder.parse(['--force']);

      expect(result.hasForceFlag, isTrue);
    });

    test('hasForceFlag returns false when force flag not set', () {
      final builder = CommandBuilder()..addFlag('force', abbr: 'f');
      final result = builder.parse([]);

      expect(result.hasForceFlag, isFalse);
    });

    test('hasHelpFlag returns true when help flag is set', () {
      final builder = CommandBuilder()..addFlag('help', abbr: 'h');
      final result = builder.parse(['--help']);

      expect(result.hasHelpFlag, isTrue);
    });

    test('hasHelpFlag returns false when help flag not set', () {
      final builder = CommandBuilder()..addFlag('help', abbr: 'h');
      final result = builder.parse([]);

      expect(result.hasHelpFlag, isFalse);
    });

    test('arguments returns all provided arguments', () {
      final builder = CommandBuilder()..addOption('name', abbr: 'n');
      final result = builder.parse(['--name', 'John', 'extra']);

      expect(result.arguments, contains('--name'));
      expect(result.arguments, contains('John'));
      expect(result.arguments, contains('extra'));
    });

    test('getString with fallback returns fallback when not provided', () {
      final builder = CommandBuilder()..addOption('name', abbr: 'n');
      final result = builder.parse([]);

      expect(
        result.getString('name', defaultValue: 'Fallback'),
        equals('Fallback'),
      );
    });

    test('getBool with fallback returns fallback when flag not set', () {
      final builder = CommandBuilder()..addFlag('verbose', abbr: 'v');
      final result = builder.parse([]);

      expect(result.getBool('verbose', defaultValue: true), isFalse);
    });

    test('get returns null for unparsed option without default', () {
      final builder = CommandBuilder()..addOption('name', abbr: 'n');
      final result = builder.parse([]);

      expect(result.get<String>('name'), isNull);
    });
  });
}
