import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/helpers/metro_helpers.dart';

void main() {
  group('NyJson.tryDecode', () {
    test('valid JSON object returns Map', () {
      final result = NyJson.tryDecode('{"name": "test", "value": 123}');

      expect(result, isA<Map>());
      expect(result['name'], equals('test'));
      expect(result['value'], equals(123));
    });

    test('valid JSON array returns List', () {
      final result = NyJson.tryDecode('[1, 2, 3, "four"]');

      expect(result, isA<List>());
      expect(result.length, equals(4));
      expect(result[0], equals(1));
      expect(result[3], equals('four'));
    });

    test('invalid JSON returns null', () {
      final result = NyJson.tryDecode('not valid json {');

      expect(result, isNull);
    });

    test('empty string returns null', () {
      final result = NyJson.tryDecode('');

      expect(result, isNull);
    });

    test('nested JSON object returns correct structure', () {
      final result = NyJson.tryDecode('{"user": {"name": "John", "age": 30}}');

      expect(result, isA<Map>());
      expect(result['user'], isA<Map>());
      expect(result['user']['name'], equals('John'));
      expect(result['user']['age'], equals(30));
    });

    test('JSON with boolean values parses correctly', () {
      final result = NyJson.tryDecode('{"active": true, "deleted": false}');

      expect(result, isA<Map>());
      expect(result['active'], isTrue);
      expect(result['deleted'], isFalse);
    });

    test('JSON with null value parses correctly', () {
      final result = NyJson.tryDecode('{"value": null}');

      expect(result, isA<Map>());
      expect(result['value'], isNull);
    });
  });
}
