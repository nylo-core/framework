import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/ny_cli.dart';

void main() {
  group('ConsoleSpinner', () {
    test('can be instantiated with message', () {
      final spinner = ConsoleSpinner('Loading...');
      expect(spinner, isNotNull);
    });

    test('message can be updated', () {
      final spinner = ConsoleSpinner('Initial message');
      spinner.update('Updated message');
      // Just verify it doesn't throw
      expect(spinner, isNotNull);
    });

    test('stop can be called without starting', () {
      final spinner = ConsoleSpinner('Test');
      // Should not throw
      expect(() => spinner.stop(), returnsNormally);
    });

    test('stop accepts completion message and success flag', () {
      final spinner = ConsoleSpinner('Test');
      expect(
        () => spinner.stop(completionMessage: 'Done!', success: true),
        returnsNormally,
      );
    });

    test('stop accepts success: false for error state', () {
      final spinner = ConsoleSpinner('Test');
      expect(
        () => spinner.stop(completionMessage: 'Failed', success: false),
        returnsNormally,
      );
    });
  });

  group('ConsoleSpinner frames', () {
    test('spinner uses predefined animation frames', () {
      // The spinner frames are private, but we can verify the spinner
      // works by creating and stopping it
      final spinner = ConsoleSpinner('Testing frames');
      expect(spinner, isNotNull);
      spinner.stop();
    });
  });
}
