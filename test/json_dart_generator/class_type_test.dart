import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/json_dart_generator/class_type.dart';

void main() {
  group('ClassType', () {
    group('getType', () {
      test('returns tNull for null value', () {
        expect(ClassType.getType(null), equals(ClassType.tNull));
      });

      test('returns tString for String value', () {
        expect(ClassType.getType('hello'), equals(ClassType.tString));
      });

      test('returns tInt for int value', () {
        expect(ClassType.getType(42), equals(ClassType.tInt));
      });

      test('returns tDouble for double value', () {
        expect(ClassType.getType(3.14), equals(ClassType.tDouble));
      });

      test('returns tBool for bool value', () {
        expect(ClassType.getType(true), equals(ClassType.tBool));
        expect(ClassType.getType(false), equals(ClassType.tBool));
      });

      test('returns tListDynamic for List value', () {
        expect(ClassType.getType([1, 2, 3]), equals(ClassType.tListDynamic));
        expect(ClassType.getType(<String>[]), equals(ClassType.tListDynamic));
      });

      test('returns tObject for Map value', () {
        expect(ClassType.getType({'key': 'value'}), equals(ClassType.tObject));
      });
    });

    group('isPrimitiveType', () {
      test('returns true for primitive type names', () {
        expect(ClassType.isPrimitiveType('int'), isTrue);
        expect(ClassType.isPrimitiveType('double'), isTrue);
        expect(ClassType.isPrimitiveType('String'), isTrue);
        expect(ClassType.isPrimitiveType('bool'), isTrue);
      });

      test('returns false for non-primitive type names', () {
        expect(ClassType.isPrimitiveType('List'), isFalse);
        expect(ClassType.isPrimitiveType('dynamic'), isFalse);
        expect(ClassType.isPrimitiveType('object'), isFalse);
        expect(ClassType.isPrimitiveType('Null'), isFalse);
      });
    });

    group('isPrimitive getter', () {
      test('returns true for primitive types', () {
        expect(ClassType.tInt.isPrimitive, isTrue);
        expect(ClassType.tDouble.isPrimitive, isTrue);
        expect(ClassType.tString.isPrimitive, isTrue);
        expect(ClassType.tBool.isPrimitive, isTrue);
      });

      test('returns false for non-primitive types', () {
        expect(ClassType.tListDynamic.isPrimitive, isFalse);
        expect(ClassType.tDynamic.isPrimitive, isFalse);
        expect(ClassType.tObject.isPrimitive, isFalse);
        expect(ClassType.tNull.isPrimitive, isFalse);
      });
    });

    group('type check getters', () {
      test('isNull returns true only for tNull', () {
        expect(ClassType.tNull.isNull, isTrue);
        expect(ClassType.tString.isNull, isFalse);
        expect(ClassType.tInt.isNull, isFalse);
      });

      test('isList returns true only for tListDynamic', () {
        expect(ClassType.tListDynamic.isList, isTrue);
        expect(ClassType.tObject.isList, isFalse);
        expect(ClassType.tString.isList, isFalse);
      });

      test('isObject returns true only for tObject', () {
        expect(ClassType.tObject.isObject, isTrue);
        expect(ClassType.tListDynamic.isObject, isFalse);
        expect(ClassType.tString.isObject, isFalse);
      });

      test('isDynamic returns true only for tDynamic', () {
        expect(ClassType.tDynamic.isDynamic, isTrue);
        expect(ClassType.tString.isDynamic, isFalse);
        expect(ClassType.tObject.isDynamic, isFalse);
      });
    });

    group('value getter', () {
      test('returns correct string representation for each type', () {
        expect(ClassType.tInt.value, equals('int'));
        expect(ClassType.tDouble.value, equals('double'));
        expect(ClassType.tString.value, equals('String'));
        expect(ClassType.tBool.value, equals('bool'));
        expect(ClassType.tListDynamic.value, equals('List'));
        expect(ClassType.tDynamic.value, equals('dynamic'));
        expect(ClassType.tNull.value, equals('Null'));
        expect(ClassType.tObject.value, equals('object'));
      });
    });

    group('toString', () {
      test('returns the value string', () {
        expect(ClassType.tInt.toString(), equals('int'));
        expect(ClassType.tString.toString(), equals('String'));
      });
    });

    group('mergeType', () {
      test('returns newType when oriType is null', () {
        expect(ClassType.mergeType(null, ClassType.tString),
            equals(ClassType.tString));
      });

      test('returns oriType when newType is null', () {
        expect(ClassType.mergeType(ClassType.tString, null),
            equals(ClassType.tString));
      });

      test('returns newType when oriType isNull', () {
        expect(ClassType.mergeType(ClassType.tNull, ClassType.tString),
            equals(ClassType.tString));
      });

      test('returns oriType when newType isNull', () {
        expect(ClassType.mergeType(ClassType.tString, ClassType.tNull),
            equals(ClassType.tString));
      });

      test('returns same type when both are equal', () {
        expect(ClassType.mergeType(ClassType.tInt, ClassType.tInt),
            equals(ClassType.tInt));
        expect(ClassType.mergeType(ClassType.tString, ClassType.tString),
            equals(ClassType.tString));
      });

      test('int and double merge to double', () {
        expect(ClassType.mergeType(ClassType.tInt, ClassType.tDouble),
            equals(ClassType.tDouble));
        expect(ClassType.mergeType(ClassType.tDouble, ClassType.tInt),
            equals(ClassType.tDouble));
      });

      test('numeric types with bool or string merge to String', () {
        expect(ClassType.mergeType(ClassType.tInt, ClassType.tBool),
            equals(ClassType.tString));
        expect(ClassType.mergeType(ClassType.tInt, ClassType.tString),
            equals(ClassType.tString));
        expect(ClassType.mergeType(ClassType.tDouble, ClassType.tBool),
            equals(ClassType.tString));
        expect(ClassType.mergeType(ClassType.tDouble, ClassType.tString),
            equals(ClassType.tString));
      });

      test('bool with numeric or string types merge to String', () {
        expect(ClassType.mergeType(ClassType.tBool, ClassType.tInt),
            equals(ClassType.tString));
        expect(ClassType.mergeType(ClassType.tBool, ClassType.tDouble),
            equals(ClassType.tString));
        expect(ClassType.mergeType(ClassType.tBool, ClassType.tString),
            equals(ClassType.tString));
      });

      test('string with primitive types merge to String', () {
        expect(ClassType.mergeType(ClassType.tString, ClassType.tInt),
            equals(ClassType.tString));
        expect(ClassType.mergeType(ClassType.tString, ClassType.tDouble),
            equals(ClassType.tString));
        expect(ClassType.mergeType(ClassType.tString, ClassType.tBool),
            equals(ClassType.tString));
      });

      test('incompatible types merge to dynamic', () {
        expect(ClassType.mergeType(ClassType.tInt, ClassType.tObject),
            equals(ClassType.tDynamic));
        expect(ClassType.mergeType(ClassType.tString, ClassType.tListDynamic),
            equals(ClassType.tDynamic));
        expect(ClassType.mergeType(ClassType.tBool, ClassType.tObject),
            equals(ClassType.tDynamic));
      });
    });

    group('ClassType.name factory', () {
      test('returns correct ClassType for valid type name', () {
        expect(ClassType.name('int'), equals(ClassType.tInt));
        expect(ClassType.name('double'), equals(ClassType.tDouble));
        expect(ClassType.name('String'), equals(ClassType.tString));
        expect(ClassType.name('bool'), equals(ClassType.tBool));
        expect(ClassType.name('List'), equals(ClassType.tListDynamic));
        expect(ClassType.name('dynamic'), equals(ClassType.tDynamic));
        expect(ClassType.name('object'), equals(ClassType.tObject));
        expect(ClassType.name('Null'), equals(ClassType.tNull));
      });

      test('throws for invalid type name', () {
        expect(() => ClassType.name('InvalidType'), throwsA(equals('InvalidType')));
      });
    });

    group('values list', () {
      test('contains all ClassType constants', () {
        expect(ClassType.values.length, equals(8));
        expect(ClassType.values, contains(ClassType.tInt));
        expect(ClassType.values, contains(ClassType.tDouble));
        expect(ClassType.values, contains(ClassType.tString));
        expect(ClassType.values, contains(ClassType.tBool));
        expect(ClassType.values, contains(ClassType.tListDynamic));
        expect(ClassType.values, contains(ClassType.tDynamic));
        expect(ClassType.values, contains(ClassType.tObject));
        expect(ClassType.values, contains(ClassType.tNull));
      });
    });

    group('primitiveTypes list', () {
      test('contains only primitive types', () {
        expect(ClassType.primitiveTypes.length, equals(4));
        expect(ClassType.primitiveTypes, contains(ClassType.tInt));
        expect(ClassType.primitiveTypes, contains(ClassType.tDouble));
        expect(ClassType.primitiveTypes, contains(ClassType.tString));
        expect(ClassType.primitiveTypes, contains(ClassType.tBool));
      });

      test('does not contain non-primitive types', () {
        expect(ClassType.primitiveTypes, isNot(contains(ClassType.tListDynamic)));
        expect(ClassType.primitiveTypes, isNot(contains(ClassType.tDynamic)));
        expect(ClassType.primitiveTypes, isNot(contains(ClassType.tObject)));
        expect(ClassType.primitiveTypes, isNot(contains(ClassType.tNull)));
      });
    });
  });
}
