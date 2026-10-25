import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/stubs/one_of_model_stub.dart';
import 'package:recase/recase.dart';

void main() {
  group('parseOneOfTypes', () {
    test('splits comma separated names', () {
      final List<ReCase> types = parseOneOfTypes(
        'login_success,two_factor_required',
      );

      expect(types.map((type) => type.pascalCase), [
        'LoginSuccess',
        'TwoFactorRequired',
      ]);
    });

    test('trims spaces and drops blank entries', () {
      final List<ReCase> types = parseOneOfTypes(' accepted , ,rejected, ');

      expect(types.map((type) => type.pascalCase), ['Accepted', 'Rejected']);
    });

    test('drops duplicate names', () {
      final List<ReCase> types = parseOneOfTypes(
        'accepted,Accepted,rejected,accepted',
      );

      expect(types.map((type) => type.pascalCase), ['Accepted', 'Rejected']);
    });

    test('returns an empty list for empty input', () {
      expect(parseOneOfTypes(''), isEmpty);
      expect(parseOneOfTypes(' , '), isEmpty);
    });
  });

  group('supportsPrimaryConstructors', () {
    String pubspec(String sdk) => 'name: app\nenvironment:\n  sdk: $sdk\n';

    test('is true from SDK 3.13', () {
      expect(supportsPrimaryConstructors(pubspec('^3.13.0')), isTrue);
      expect(supportsPrimaryConstructors(pubspec("'>=3.14.0 <4.0.0'")), isTrue);
      expect(supportsPrimaryConstructors(pubspec('^4.0.0')), isTrue);
    });

    test('is false below SDK 3.13', () {
      expect(supportsPrimaryConstructors(pubspec('^3.12.0')), isFalse);
      expect(supportsPrimaryConstructors(pubspec("'>=3.0.0 <4.0.0'")), isFalse);
    });

    test('is false when the constraint can not be read', () {
      expect(supportsPrimaryConstructors('name: app\n'), isFalse);
      expect(supportsPrimaryConstructors(pubspec('any')), isFalse);
    });

    test('ignores the flutter sdk lines under dependencies', () {
      const String file = '''
name: app
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
''';

      expect(supportsPrimaryConstructors(file), isFalse);
    });
  });

  group('oneOfModelStub', () {
    final String stub = oneOfModelStub(
      modelName: ReCase('login_result'),
      types: parseOneOfTypes('login_success,two_factor_required'),
    );

    test('declares a sealed parent with no base class', () {
      expect(stub, contains('sealed class LoginResult {}'));
      expect(stub, isNot(contains('extends Model')));
      expect(stub, isNot(contains('import ')));
    });

    test('declares each subtype with a fromJson', () {
      expect(stub, contains('class LoginSuccess extends LoginResult {'));
      expect(stub, contains('LoginSuccess.fromJson(dynamic json);'));
      expect(stub, contains('class TwoFactorRequired extends LoginResult {'));
      expect(stub, contains('TwoFactorRequired.fromJson(dynamic json);'));
    });

    test('uses primary constructors when asked', () {
      final String primary = oneOfModelStub(
        modelName: ReCase('login_result'),
        types: parseOneOfTypes('login_success'),
        primaryConstructors: true,
      );

      expect(primary, contains('class LoginSuccess() extends LoginResult {'));
      expect(
        primary,
        contains('LoginSuccess.fromJson(dynamic json) : this();'),
      );
    });
  });

  group('addOneOfDecoders', () {
    const String decoders = '''
import '/app/models/user.dart';

final Map<Type, dynamic> modelDecoders = {
  User: (data) => User.fromJson(data),
};

final Map<Type, dynamic> apiDecoders = {};
''';

    final String result = addOneOfDecoders(
      decoders,
      modelName: ReCase('login_result'),
      types: parseOneOfTypes('login_success,two_factor_required'),
    );

    test('adds one byKey entry with each subtype under its name', () {
      expect(
        result,
        contains('''
  User: (data) => User.fromJson(data),

  // TODO: change 'type' to the field your API uses, or use OneOf.byStatus / OneOf.byJson
  LoginResult: OneOf<LoginResult>.byKey('type', {
    'login_success': LoginSuccess.fromJson,
    'two_factor_required': TwoFactorRequired.fromJson,
  }),
};'''),
      );
    });

    test('imports nylo_framework once', () {
      expect(
        result,
        startsWith("import 'package:nylo_framework/nylo_framework.dart';\n"),
      );

      final String again = addOneOfDecoders(
        result,
        modelName: ReCase('feed_item'),
        types: parseOneOfTypes('post,ad'),
      );
      expect(
        "import 'package:nylo_framework/nylo_framework.dart';"
            .allMatches(again)
            .length,
        1,
      );
    });

    test('adds no decoder entry per subtype', () {
      expect(result, isNot(contains('LoginSuccess: (data)')));
    });

    test('leaves the other maps alone', () {
      expect(result, contains('final Map<Type, dynamic> apiDecoders = {};'));
    });

    test('still finds the end of a map that already has a OneOf', () {
      final String again = addOneOfDecoders(
        result,
        modelName: ReCase('feed_item'),
        types: parseOneOfTypes('post,ad'),
      );

      expect(
        again,
        contains('''
    'two_factor_required': TwoFactorRequired.fromJson,
  }),

  // TODO: change 'type' to the field your API uses, or use OneOf.byStatus / OneOf.byJson
  FeedItem: OneOf<FeedItem>.byKey('type', {
    'post': Post.fromJson,
    'ad': Ad.fromJson,
  }),
};'''),
      );
    });

    test('returns the file unchanged without a modelDecoders map', () {
      const String file = 'final Map<Type, dynamic> apiDecoders = {};\n';

      expect(
        addOneOfDecoders(
          file,
          modelName: ReCase('login_result'),
          types: parseOneOfTypes('login_success'),
        ),
        file,
      );
    });
  });

  group('addOneOfDecoders with decoders([...])', () {
    const String decoders = '''
import 'package:nylo_framework/nylo_framework.dart';

final Map<Type, dynamic> modelDecoders = decoders([
  Decode(User.fromJson),
]);
''';

    test('adds the OneOf entry without a key', () {
      final String result = addOneOfDecoders(
        decoders,
        modelName: ReCase('login_result'),
        types: parseOneOfTypes('login_success,two_factor_required'),
      );

      expect(result, '''
import 'package:nylo_framework/nylo_framework.dart';

final Map<Type, dynamic> modelDecoders = decoders([
  Decode(User.fromJson),
  // TODO: change 'type' to the field your API uses, or use OneOf.byStatus / OneOf.byJson
  OneOf<LoginResult>.byKey('type', {
    'login_success': LoginSuccess.fromJson,
    'two_factor_required': TwoFactorRequired.fromJson,
  }),
]);
''');
    });

    test('adds a second OneOf after the first', () {
      final String once = addOneOfDecoders(
        decoders,
        modelName: ReCase('login_result'),
        types: parseOneOfTypes('login_success'),
      );
      final String twice = addOneOfDecoders(
        once,
        modelName: ReCase('feed_item'),
        types: parseOneOfTypes('post'),
      );

      expect(
        twice,
        contains('''
    'login_success': LoginSuccess.fromJson,
  }),
  // TODO: change 'type' to the field your API uses, or use OneOf.byStatus / OneOf.byJson
  OneOf<FeedItem>.byKey('type', {
    'post': Post.fromJson,
  }),
]);'''),
      );
    });
  });
}
