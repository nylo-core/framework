import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/json_dart_generator/json_def.dart';
import 'package:nylo_framework/json_dart_generator/class_type.dart';

void main() {
  group('JsonDef', () {
    group('constructor', () {
      test('creates JsonDef from simple JSON object', () {
        final jsonDef = JsonDef(
          rootClassName: 'User',
          jsonData: {'name': 'John', 'age': 30},
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.jsonData, isNotNull);
        expect(jsonDef.classCode, isNotEmpty);
      });

      test('creates JsonDef from JSON array', () {
        final jsonDef = JsonDef(
          rootClassName: 'Items',
          jsonData: [1, 2, 3],
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.classCode, isNotEmpty);
      });

      test('handles null rootClassName', () {
        final jsonDef = JsonDef(
          rootClassName: null,
          jsonData: {'test': 'value'},
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.classCode, contains('class Root'));
      });
    });

    group('structString', () {
      test('returns structure representation for simple object', () {
        final jsonDef = JsonDef(
          rootClassName: 'Test',
          jsonData: {'key': 'value'},
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.structString, isNotEmpty);
        expect(jsonDef.structString, contains('Map'));
      });

      test('returns structure representation for array', () {
        final jsonDef = JsonDef(
          rootClassName: 'Test',
          jsonData: [1, 2],
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.structString, contains('List'));
      });
    });

    group('summarizeString', () {
      test('returns summarized structure', () {
        final jsonDef = JsonDef(
          rootClassName: 'Test',
          jsonData: {
            'items': [
              {'id': 1},
              {'id': 2}
            ]
          },
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.summarizeString, isNotEmpty);
      });
    });

    group('customObjectString', () {
      test('returns custom object structures for nested objects', () {
        final jsonDef = JsonDef(
          rootClassName: 'Parent',
          jsonData: {
            'child': {'name': 'test'}
          },
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.customObjectString, isNotEmpty);
      });

      test('returns empty string for flat objects', () {
        final jsonDef = JsonDef(
          rootClassName: 'Flat',
          jsonData: {'name': 'test', 'age': 30},
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.customObjectString, isEmpty);
      });
    });

    group('allCustomObject', () {
      test('returns list of custom objects for nested structures', () {
        final jsonDef = JsonDef(
          rootClassName: 'Root',
          jsonData: {
            'user': {'name': 'John'},
            'address': {'city': 'NYC'}
          },
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.allCustomObject, isNotEmpty);
      });

      test('returns empty list for primitive-only structures', () {
        final jsonDef = JsonDef(
          rootClassName: 'Simple',
          jsonData: {'count': 5},
          rootClassNameWithPrefixSuffix: true,
        );

        expect(jsonDef.allCustomObject, isEmpty);
      });
    });

    group('classCode', () {
      test('generates valid Dart class code', () {
        final jsonDef = JsonDef(
          rootClassName: 'Product',
          jsonData: {'name': 'Widget', 'price': 9.99},
          rootClassNameWithPrefixSuffix: true,
        );

        final code = jsonDef.classCode;
        expect(code, contains('class Product'));
        expect(code, contains('String? name'));
        expect(code, contains('double? price'));
        expect(code, contains('Product.fromJson'));
        expect(code, contains('toJson()'));
      });

      test('generates code for nested objects', () {
        final jsonDef = JsonDef(
          rootClassName: 'Order',
          jsonData: {
            'id': 1,
            'customer': {'name': 'John', 'email': 'john@test.com'}
          },
          rootClassNameWithPrefixSuffix: true,
        );

        final code = jsonDef.classCode;
        expect(code, contains('class Order'));
        expect(code, contains('class OrderCustomer'));
      });

      test('applies class name prefix and suffix', () {
        final jsonDef = JsonDef(
          rootClassName: 'User',
          jsonData: {'id': 1},
          rootClassNameWithPrefixSuffix: true,
          classNamePrefixSuffixBuilder: (name, isPrefix) {
            return isPrefix ? 'Api' : 'Model';
          },
        );

        final code = jsonDef.classCode;
        expect(code, contains('class ApiUserModel'));
      });
    });
  });

  group('ValueDef', () {
    group('type detection', () {
      test('detects string type', () {
        final valueDef = ValueDef(
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.type, equals(ClassType.tString));
      });

      test('detects int type', () {
        final valueDef = ValueDef(
          value: 42,
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.type, equals(ClassType.tInt));
      });

      test('detects double type', () {
        final valueDef = ValueDef(
          value: 3.14,
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.type, equals(ClassType.tDouble));
      });

      test('detects bool type', () {
        final valueDef = ValueDef(
          value: true,
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.type, equals(ClassType.tBool));
      });

      test('detects list type', () {
        final valueDef = ValueDef(
          value: [1, 2, 3],
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.type, equals(ClassType.tListDynamic));
      });

      test('detects object type', () {
        final valueDef = ValueDef(
          value: {'key': 'value'},
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.type, equals(ClassType.tObject));
      });

      test('detects null type', () {
        final valueDef = ValueDef(
          value: null,
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.type, equals(ClassType.tNull));
      });
    });

    group('isRoot', () {
      test('returns true when parent is null', () {
        final valueDef = ValueDef(
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.isRoot, isTrue);
      });
    });

    group('depth', () {
      test('returns 0 for root level', () {
        final valueDef = ValueDef(
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.depth, equals(0));
      });
    });

    group('classNameNoPrefixSuffix', () {
      test('returns rootClassName for root element', () {
        final valueDef = ValueDef(
          rootClassName: 'MyClass',
          value: {'test': 1},
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.classNameNoPrefixSuffix, equals('MyClass'));
      });

      test('returns Root when rootClassName is null', () {
        final valueDef = ValueDef(
          value: {'test': 1},
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.classNameNoPrefixSuffix, equals('Root'));
      });
    });

    group('classNameFull', () {
      test('returns class name with prefix and suffix', () {
        final valueDef = ValueDef(
          rootClassName: 'User',
          value: {'id': 1},
          rootClassNameWithPrefixSuffix: true,
          classNamePrefixSuffixBuilder: (name, isPrefix) {
            return isPrefix ? 'Api' : 'Dto';
          },
        );
        expect(valueDef.classNameFull, equals('ApiUserDto'));
      });

      test('returns class name without prefix/suffix when disabled', () {
        final valueDef = ValueDef(
          rootClassName: 'User',
          value: {'id': 1},
          rootClassNameWithPrefixSuffix: false,
          classNamePrefixSuffixBuilder: (name, isPrefix) {
            return isPrefix ? 'Api' : 'Dto';
          },
        );
        expect(valueDef.classNameFull, equals('User'));
      });
    });

    group('toString', () {
      test('returns structString', () {
        final valueDef = ValueDef(
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.toString(), equals(valueDef.structString));
      });
    });

    group('copyWith', () {
      test('creates copy with updated type', () {
        final original = ValueDef(
          rootClassName: 'Test',
          value: 'hello',
          rootClassNameWithPrefixSuffix: true,
        );
        final copy = original.copyWith(type: ClassType.tInt);

        expect(copy.type, equals(ClassType.tInt));
        expect(copy.rootClassName, equals(original.rootClassName));
      });

      test('creates copy with updated listType', () {
        final original = ValueDef(
          value: [1, 2, 3],
          rootClassNameWithPrefixSuffix: true,
        );
        final copy = original.copyWith(listType: ClassType.tString);

        expect(copy.listType, equals(ClassType.tString));
      });
    });

    group('summarize', () {
      test('summarizes array types', () {
        final valueDef = ValueDef(
          value: [1, 2, 3],
          rootClassNameWithPrefixSuffix: true,
        );
        final summarized = valueDef.summarize();

        expect(summarized.type, equals(ClassType.tListDynamic));
        expect(summarized.listType, equals(ClassType.tInt));
      });

      test('converts null types to dynamic', () {
        final valueDef = ValueDef(
          value: {'field': null},
          rootClassNameWithPrefixSuffix: true,
        );
        final summarized = valueDef.summarize();

        expect(summarized.childrenDef, isA<Map<String, ValueDef>>());
      });
    });

    group('isStructSame', () {
      test('returns true for matching primitive types', () {
        final def1 = ValueDef(
          key: 'name',
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        final def2 = ValueDef(
          key: 'name',
          value: 'other',
          rootClassNameWithPrefixSuffix: true,
        );

        expect(def1.isStructSame(def2), isTrue);
      });

      test('returns false for different keys', () {
        final def1 = ValueDef(
          key: 'name',
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        final def2 = ValueDef(
          key: 'title',
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );

        expect(def1.isStructSame(def2), isFalse);
      });

      test('returns false for different types', () {
        final def1 = ValueDef(
          key: 'value',
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        final def2 = ValueDef(
          key: 'value',
          value: 123,
          rootClassNameWithPrefixSuffix: true,
        );

        expect(def1.isStructSame(def2), isFalse);
      });
    });

    group('parentKey', () {
      test('returns key when available', () {
        final valueDef = ValueDef(
          key: 'myKey',
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.parentKey, equals('myKey'));
      });

      test('returns null when no key', () {
        final valueDef = ValueDef(
          value: 'test',
          rootClassNameWithPrefixSuffix: true,
        );
        expect(valueDef.parentKey, isNull);
      });
    });
  });

  group('ListInner', () {
    test('stores type, oriType, and className', () {
      final listInner = ListInner(
        type: ClassType.tString,
        oriType: ClassType.tString,
        className: 'String',
      );

      expect(listInner.type, equals(ClassType.tString));
      expect(listInner.oriType, equals(ClassType.tString));
      expect(listInner.className, equals('String'));
    });
  });

  group('StringExtension', () {
    group('upperCamel', () {
      test('converts snake_case to PascalCase', () {
        expect('hello_world'.upperCamel(), equals('HelloWorld'));
      });

      test('converts single word to PascalCase', () {
        expect('hello'.upperCamel(), equals('Hello'));
      });

      test('handles already PascalCase', () {
        expect('HelloWorld'.upperCamel(), equals('HelloWorld'));
      });

      test('handles numbers', () {
        // Numbers don't trigger capitalization - they're treated as part of word boundaries
        expect('test123value'.upperCamel(), equals('Test123value'));
      });

      test('handles multiple underscores', () {
        expect('one_two_three'.upperCamel(), equals('OneTwoThree'));
      });
    });

    group('lowerCamel', () {
      test('converts snake_case to camelCase', () {
        expect('hello_world'.lowerCamel(), equals('helloWorld'));
      });

      test('converts PascalCase to camelCase', () {
        expect('HelloWorld'.lowerCamel(), equals('helloWorld'));
      });

      test('handles single word', () {
        expect('Hello'.lowerCamel(), equals('hello'));
      });
    });
  });
}
