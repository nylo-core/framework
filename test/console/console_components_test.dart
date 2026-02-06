import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/ny_cli.dart';

void main() {
  group('ConsoleProgressBar', () {
    test('current starts at 0', () {
      final progressBar = ConsoleProgressBar(total: 100);

      expect(progressBar.current, equals(0));
    });

    test('percentage calculates correctly (50/100 = 50%)', () {
      final progressBar = ConsoleProgressBar(total: 100);
      progressBar.update(50);

      expect(progressBar.percentage, equals(50.0));
    });

    test('percentage calculates correctly for different values', () {
      final progressBar = ConsoleProgressBar(total: 200);
      progressBar.update(50);

      expect(progressBar.percentage, equals(25.0));
    });

    test('tick() increments by 1', () {
      final progressBar = ConsoleProgressBar(total: 100);
      progressBar.tick();

      expect(progressBar.current, equals(1));
    });

    test('tick(n) increments by n', () {
      final progressBar = ConsoleProgressBar(total: 100);
      progressBar.tick(10);

      expect(progressBar.current, equals(10));
    });

    test('multiple ticks accumulate', () {
      final progressBar = ConsoleProgressBar(total: 100);
      progressBar.tick(5);
      progressBar.tick(3);
      progressBar.tick();

      expect(progressBar.current, equals(9));
    });

    test('update(150) clamps to total (100)', () {
      final progressBar = ConsoleProgressBar(total: 100);
      progressBar.update(150);

      expect(progressBar.current, equals(100));
    });

    test('tick beyond total clamps to total', () {
      final progressBar = ConsoleProgressBar(total: 10);
      progressBar.tick(15);

      expect(progressBar.current, equals(10));
    });

    test('update with negative value clamps to 0', () {
      final progressBar = ConsoleProgressBar(total: 100);
      progressBar.update(-10);

      expect(progressBar.current, equals(0));
    });

    test('percentage is 0 when total is 0', () {
      final progressBar = ConsoleProgressBar(total: 0);

      expect(progressBar.percentage, equals(0.0));
    });

    test('percentage is 100 when current equals total', () {
      final progressBar = ConsoleProgressBar(total: 50);
      progressBar.update(50);

      expect(progressBar.percentage, equals(100.0));
    });

    test('message can be set', () {
      final progressBar =
          ConsoleProgressBar(total: 100, message: 'Processing...');

      expect(progressBar.message, equals('Processing...'));
    });

    test('message can be updated', () {
      final progressBar =
          ConsoleProgressBar(total: 100, message: 'Initial message');
      progressBar.updateMessage('Updated message');

      expect(progressBar.message, equals('Updated message'));
    });
  });

  group('ConsoleTable', () {
    test('renders without error with valid data', () {
      final table = ConsoleTable(
        headers: ['Name', 'Age', 'City'],
        rows: [
          ['John', '30', 'New York'],
          ['Jane', '25', 'Los Angeles'],
        ],
      );

      expect(() => table.render(), returnsNormally);
    });

    test('handles empty rows', () {
      final table = ConsoleTable(
        headers: ['Name', 'Age'],
        rows: [],
      );

      expect(() => table.render(), returnsNormally);
    });

    test('handles single row', () {
      final table = ConsoleTable(
        headers: ['Column1'],
        rows: [
          ['Value1']
        ],
      );

      expect(() => table.render(), returnsNormally);
    });

    test('handles rows with fewer columns than headers', () {
      final table = ConsoleTable(
        headers: ['Name', 'Age', 'City'],
        rows: [
          ['John'],
        ],
      );

      expect(() => table.render(), returnsNormally);
    });

    test('does not render when headers are empty', () {
      final table = ConsoleTable(
        headers: [],
        rows: [
          ['Value']
        ],
      );

      expect(() => table.render(), returnsNormally);
    });

    test('handles long content in cells', () {
      final table = ConsoleTable(
        headers: ['Short', 'Very Long Header Name'],
        rows: [
          ['A', 'This is a very long content string'],
        ],
      );

      expect(() => table.render(), returnsNormally);
    });
  });
}
