import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/json_dart_generator/dart_code_generator.dart';

void main() {
  group('DartCodeGenerator', () {
    group('generate', () {
      test('generates class for simple JSON object', () {
        final generator = DartCodeGenerator(rootClassName: 'User');
        final result = generator.generate('{"name": "John", "age": 30}');

        expect(result, contains('class User'));
        expect(result, contains('String? name'));
        expect(result, contains('int? age'));
        expect(result, contains('User.fromJson'));
        expect(result, contains('toJson()'));
      });

      test('generates class for nested JSON object', () {
        final generator = DartCodeGenerator(rootClassName: 'Person');
        final result = generator.generate('''
        {
          "name": "John",
          "address": {
            "city": "NYC",
            "zip": "10001"
          }
        }
        ''');

        expect(result, contains('class Person'));
        expect(result, contains('PersonAddress'));
        expect(result, contains('String? city'));
        expect(result, contains('String? zip'));
      });

      test('generates class with list type', () {
        final generator = DartCodeGenerator(rootClassName: 'Response');
        final result = generator.generate('{"items": [1, 2, 3]}');

        expect(result, contains('class Response'));
        expect(result, contains('List<int>'));
      });

      test('generates class with list of objects', () {
        final generator = DartCodeGenerator(rootClassName: 'Response');
        final result = generator.generate('''
        {
          "users": [
            {"name": "John"},
            {"name": "Jane"}
          ]
        }
        ''');

        expect(result, contains('class Response'));
        expect(result, contains('ResponseUsers'));
      });

      test('uses custom class prefix', () {
        final generator = DartCodeGenerator(
          rootClassName: 'User',
          classPrefix: 'Api',
        );
        final result = generator.generate('{"name": "John"}');

        expect(result, contains('class ApiUser'));
      });

      test('uses custom class suffix', () {
        final generator = DartCodeGenerator(
          rootClassName: 'User',
          classSuffix: 'Model',
        );
        final result = generator.generate('{"name": "John"}');

        expect(result, contains('class UserModel'));
      });

      test('uses both prefix and suffix', () {
        final generator = DartCodeGenerator(
          rootClassName: 'User',
          classPrefix: 'Api',
          classSuffix: 'Dto',
        );
        final result = generator.generate('{"name": "John"}');

        expect(result, contains('class ApiUserDto'));
      });

      test('handles rootClassNameWithPrefixSuffix false', () {
        final generator = DartCodeGenerator(
          rootClassName: 'User',
          rootClassNameWithPrefixSuffix: false,
          classPrefix: 'Api',
          classSuffix: 'Model',
        );
        final result = generator.generate('{"name": "John"}');

        expect(result, contains('class User'));
        expect(result, isNot(contains('class ApiUserModel')));
      });

      test('returns empty string for invalid JSON', () {
        final generator = DartCodeGenerator(rootClassName: 'Test');
        final result = generator.generate('invalid json {');

        expect(result, isEmpty);
      });

      test('handles boolean values', () {
        final generator = DartCodeGenerator(rootClassName: 'Config');
        final result = generator.generate('{"enabled": true, "debug": false}');

        expect(result, contains('bool? enabled'));
        expect(result, contains('bool? debug'));
      });

      test('handles double values', () {
        final generator = DartCodeGenerator(rootClassName: 'Metrics');
        final result = generator.generate(
          '{"temperature": 36.6, "ratio": 0.5}',
        );

        expect(result, contains('double? temperature'));
        expect(result, contains('double? ratio'));
      });

      test('handles null values as dynamic', () {
        final generator = DartCodeGenerator(rootClassName: 'Data');
        final result = generator.generate('{"unknown": null}');

        expect(result, contains('dynamic unknown'));
      });

      test('generates fromJson with correct type conversions', () {
        final generator = DartCodeGenerator(rootClassName: 'Item');
        final result = generator.generate('{"price": 19.99}');

        expect(result, contains('toDouble()'));
      });

      test('handles empty object', () {
        final generator = DartCodeGenerator(rootClassName: 'Empty');
        final result = generator.generate('{}');

        expect(result, contains('class Empty'));
        expect(result, contains('Empty()'));
      });

      test('handles JSON array as root', () {
        final generator = DartCodeGenerator(rootClassName: 'Items');
        final result = generator.generate('[{"id": 1}, {"id": 2}]');

        expect(result, contains('class Items'));
      });

      test('handles empty JSON array', () {
        final generator = DartCodeGenerator(rootClassName: 'EmptyList');
        final result = generator.generate('[]');

        expect(result, contains('class EmptyList'));
        expect(result, contains('List<dynamic>'));
      });

      test('handles deeply nested objects', () {
        final generator = DartCodeGenerator(rootClassName: 'Deep');
        final result = generator.generate('''
        {
          "level1": {
            "level2": {
              "level3": {
                "value": "deep"
              }
            }
          }
        }
        ''');

        expect(result, contains('class Deep'));
        expect(result, contains('DeepLevel1'));
      });

      test('handles mixed array types as String list', () {
        // Mixed types in arrays are converted to String with .toString() mapping
        final generator = DartCodeGenerator(rootClassName: 'Mixed');
        final result = generator.generate('{"mixed": [1, "two", true]}');

        expect(result, contains('List<String>'));
      });

      test('uses Root as default class name when not specified', () {
        final generator = DartCodeGenerator();
        final result = generator.generate('{"test": 123}');

        expect(result, contains('class Root'));
      });
    });
  });
}
