import 'package:flutter_test/flutter_test.dart';
import 'package:recase/recase.dart';
import 'package:nylo_framework/metro/stubs/api_service_stub.dart';
import 'package:nylo_framework/metro/commands/make/api_service.dart'
    show cleanApiServiceName;

/// Counts how many times [needle] appears in [haystack].
int _count(String haystack, String needle) =>
    needle.isEmpty ? 0 : haystack.split(needle).length - 1;

void main() {
  group('apiServiceStub imports', () {
    test('emits the nylo_framework import when a custom --url is used', () {
      final stub = apiServiceStub(
        ReCase('user'),
        model: ReCase('Model'),
        baseUrl: '"https://api.example.com"',
      );

      expect(stub, contains('class UserApiService extends NyApiService'));
      expect(
        stub,
        contains('String get baseUrl => "https://api.example.com";'),
      );
      expect(
        stub,
        contains("import 'package:nylo_framework/nylo_framework.dart';"),
      );
    });

    test('emits the nylo_framework import with the default getEnv baseUrl', () {
      final stub = apiServiceStub(
        ReCase('user'),
        model: ReCase('Model'),
        baseUrl: "getEnv('API_BASE_URL')",
      );

      expect(stub, contains("String get baseUrl => getEnv('API_BASE_URL');"));
      expect(
        stub,
        contains("import 'package:nylo_framework/nylo_framework.dart';"),
      );
    });

    test('emits the nylo_framework import exactly once (no duplication)', () {
      final withUrl = apiServiceStub(
        ReCase('payments'),
        model: ReCase('Payment'),
        baseUrl: '"https://api.example.com"',
      );
      final withEnv = apiServiceStub(
        ReCase('payments'),
        model: ReCase('Payment'),
        baseUrl: "getEnv('API_BASE_URL')",
      );

      const importLine = "import 'package:nylo_framework/nylo_framework.dart';";
      expect(_count(withUrl, importLine), 1);
      expect(_count(withEnv, importLine), 1);
    });

    test('only imports the model file when a model is supplied', () {
      final withoutModel = apiServiceStub(
        ReCase('user'),
        model: ReCase('Model'),
        baseUrl: '"https://api.example.com"',
      );
      final withModel = apiServiceStub(
        ReCase('user'),
        model: ReCase('Product'),
        baseUrl: '"https://api.example.com"',
      );

      expect(withoutModel, isNot(contains("import '/app/models/")));
      expect(withModel, contains("import '/app/models/product.dart';"));
    });
  });

  group('cleanApiServiceName suffix handling', () {
    // input -> expected cleaned snake_case resource name
    final expectations = <String, String>{
      'user': 'user',
      'user_api_service': 'user',
      'UserApiService': 'user',
      'PaymentsAPIService': 'payments',
      // Input that is nothing but the suffix falls back to a non-empty name.
      'APIService': 'api',
    };

    expectations.forEach((input, expected) {
      test('"$input" cleans to "$expected"', () {
        expect(cleanApiServiceName(input), expected);
      });

      test('"$input" never doubles the ApiService suffix', () {
        final className =
            '${ReCase(cleanApiServiceName(input)).pascalCase}'
            'ApiService';

        expect(cleanApiServiceName(input), isNotEmpty);
        expect(className, isNot(contains('ApiServiceApiService')));
        expect(className, isNot(contains('APIServiceApiService')));
      });
    });

    test('acronym-only input does not produce an empty class name', () {
      final className =
          '${ReCase(cleanApiServiceName('APIService')).pascalCase}ApiService';

      expect(className, 'ApiApiService');
    });
  });
}
