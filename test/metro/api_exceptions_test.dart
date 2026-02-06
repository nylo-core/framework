import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/ny_cli.dart';

void main() {
  group('ApiException', () {
    test('can be created with required parameters', () {
      final exception = ApiException(
        code: 404,
        message: 'Not found',
      );

      expect(exception.code, equals(404));
      expect(exception.message, equals('Not found'));
      expect(exception.data, isNull);
    });

    test('can be created with optional data', () {
      final exception = ApiException(
        code: 400,
        message: 'Bad request',
        data: {'field': 'email', 'error': 'invalid'},
      );

      expect(exception.code, equals(400));
      expect(exception.message, equals('Bad request'));
      expect(exception.data, isA<Map>());
      expect(exception.data['field'], equals('email'));
    });

    test('toString returns formatted message', () {
      final exception = ApiException(
        code: 500,
        message: 'Internal server error',
      );

      expect(exception.toString(),
          equals('ApiException: 500 - Internal server error'));
    });

    test('implements Exception', () {
      final exception = ApiException(code: 401, message: 'Unauthorized');

      expect(exception, isA<Exception>());
    });
  });

  group('TimeoutException', () {
    test('can be created with message', () {
      final exception = TimeoutException('Request timeout');

      expect(exception.message, equals('Request timeout'));
    });

    test('toString returns formatted message', () {
      final exception = TimeoutException('Connection timed out');

      expect(exception.toString(),
          equals('TimeoutException: Connection timed out'));
    });

    test('implements Exception', () {
      final exception = TimeoutException('timeout');

      expect(exception, isA<Exception>());
    });
  });

  group('NetworkException', () {
    test('can be created with message', () {
      final exception = NetworkException('No internet connection');

      expect(exception.message, equals('No internet connection'));
    });

    test('toString returns formatted message', () {
      final exception = NetworkException('Network error');

      expect(exception.toString(), equals('NetworkException: Network error'));
    });

    test('implements Exception', () {
      final exception = NetworkException('error');

      expect(exception, isA<Exception>());
    });
  });

  group('RequestCancelledException', () {
    test('can be created with message', () {
      final exception = RequestCancelledException('User cancelled request');

      expect(exception.message, equals('User cancelled request'));
    });

    test('toString returns formatted message', () {
      final exception = RequestCancelledException('Cancelled');

      expect(
          exception.toString(), equals('RequestCancelledException: Cancelled'));
    });

    test('implements Exception', () {
      final exception = RequestCancelledException('cancelled');

      expect(exception, isA<Exception>());
    });
  });

  group('UnknownException', () {
    test('can be created with message', () {
      final exception = UnknownException('Something went wrong');

      expect(exception.message, equals('Something went wrong'));
    });

    test('toString returns formatted message', () {
      final exception = UnknownException('Unknown error');

      expect(exception.toString(), equals('UnknownException: Unknown error'));
    });

    test('implements Exception', () {
      final exception = UnknownException('unknown');

      expect(exception, isA<Exception>());
    });
  });
}
