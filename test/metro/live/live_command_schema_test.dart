import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_command_schema.dart';

void main() {
  final LiveCommandSchema seedCart = LiveCommandSchema.fromJson({
    'name': 'cart:seed',
    'description': 'Fill the cart with sample items',
    'options': [
      {
        'kind': 'option',
        'name': 'count',
        'abbr': 'c',
        'help': 'How many items to add',
        'defaultValue': '3',
      },
      {
        'kind': 'option',
        'name': 'size',
        'allowed': ['small', 'large'],
      },
      {
        'kind': 'flag',
        'name': 'open',
        'help': 'Open the profile page afterwards',
        'defaultValue': false,
      },
    ],
  })!;

  group('LiveCommandSchema.fromJson', () {
    test('reads the name, description and options', () {
      expect(seedCart.name, 'cart:seed');
      expect(seedCart.description, 'Fill the cart with sample items');
      expect(seedCart.options.map((o) => o.name), ['count', 'size', 'open']);
      expect(seedCart.options.last.isFlag, isTrue);
    });

    test('drops entries without a name and bad abbreviations', () {
      final LiveCommandSchema schema = LiveCommandSchema.fromJson({
        'name': 'app:test',
        'options': [
          {'kind': 'option'},
          {'kind': 'flag', 'name': 'verbose', 'abbr': 'vv'},
        ],
      })!;

      expect(schema.options.map((o) => o.name), ['verbose']);
      expect(schema.options.single.abbr, isNull);
    });

    test('listFromResult reads a commands.list payload', () {
      final List<LiveCommandSchema> commands = LiveCommandSchema.listFromResult(
        {
          'commands': [
            {'name': 'cart:seed'},
            {'name': ''},
            'nope',
            {'name': 'user:fake'},
          ],
        },
      );

      expect(commands.map((c) => c.name), ['cart:seed', 'user:fake']);
      expect(LiveCommandSchema.listFromResult(null), isEmpty);
    });
  });

  group('LiveCommandSchema.parse', () {
    test('applies defaults', () {
      final result = seedCart.parse([]);

      expect(result.values, {'count': '3', 'size': null, 'open': false});
      expect(result.rest, isEmpty);
    });

    test('parses long, abbreviated and flag arguments', () {
      final result = seedCart.parse(['-c', '5', '--size', 'large', '--open']);

      expect(result.values, {'count': '5', 'size': 'large', 'open': true});
    });

    test('keeps positional arguments in rest', () {
      final result = seedCart.parse(['extra', '--count', '2', 'more']);

      expect(result.values['count'], '2');
      expect(result.rest, ['extra', 'more']);
    });

    test('rejects unknown options and values outside allowed', () {
      expect(() => seedCart.parse(['--colour', 'red']), throwsFormatException);
      expect(() => seedCart.parse(['--size', 'medium']), throwsFormatException);
    });

    test('a duplicated abbreviation is dropped instead of failing', () {
      final LiveCommandSchema schema = LiveCommandSchema.fromJson({
        'name': 'app:test',
        'options': [
          {'kind': 'option', 'name': 'count', 'abbr': 'c'},
          {'kind': 'flag', 'name': 'clear', 'abbr': 'c'},
        ],
      })!;

      final result = schema.parse(['-c', '4', '--clear']);

      expect(result.values, {'count': '4', 'clear': true});
    });
  });

  group('LiveCommandSchema usage and help', () {
    test('usage names the command and its options', () {
      expect(seedCart.usage, startsWith('Usage: metro cart:seed [options]'));
      expect(seedCart.usage, contains('Fill the cart with sample items'));
      expect(seedCart.usage, contains('--count'));
      expect(seedCart.usage, contains('How many items to add'));
    });

    test('wantsHelp spots --help and -h before --', () {
      expect(seedCart.wantsHelp(['--help']), isTrue);
      expect(seedCart.wantsHelp(['-c', '2', '-h']), isTrue);
      expect(seedCart.wantsHelp(['--', '--help']), isFalse);
      expect(seedCart.wantsHelp(['--count', '2']), isFalse);
    });

    test('wantsHelp respects commands that declare help themselves', () {
      final LiveCommandSchema schema = LiveCommandSchema.fromJson({
        'name': 'app:test',
        'options': [
          {'kind': 'flag', 'name': 'hidden', 'abbr': 'h'},
        ],
      })!;

      expect(schema.wantsHelp(['-h']), isFalse);
      expect(schema.wantsHelp(['--help']), isTrue);
    });
  });
}
