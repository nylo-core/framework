import 'package:collection/collection.dart';

/// Represents a Dart type used during JSON-to-Dart code generation.
class ClassType {
  final String _value;

  const ClassType._internal(this._value);

  /// Creates a [ClassType] from a type name string.
  factory ClassType.name(String typeName) {
    var find = values.firstWhereOrNull((element) => element.value == typeName);

    if (find == null) {
      print(typeName);
      throw typeName;
    }
    return find;
  }

  /// The string representation of this type.
  String get value => _value;

  /// Returns true if [typeName] is a primitive Dart type.
  static bool isPrimitiveType(String typeName) {
    return primitiveTypes.map((e) => e.value).contains(typeName);
  }

  /// Whether this is a primitive type (int, double, String, bool).
  bool get isPrimitive {
    return primitiveTypes.contains(this);
  }

  /// Whether this represents a null type.
  bool get isNull {
    return this == ClassType.tNull;
  }

  /// Whether this represents a List type.
  bool get isList {
    return this == ClassType.tListDynamic;
  }

  /// Whether this represents an object/map type.
  bool get isObject {
    return this == ClassType.tObject;
  }

  /// Whether this represents a dynamic type.
  bool get isDynamic {
    return this == ClassType.tDynamic;
  }

  /// Returns the [ClassType] for the given runtime [value].
  static ClassType getType(dynamic value) {
    if (value == null) {
      return tNull;
    }

    if (value is String) {
      return tString;
    } else if (value is int) {
      return tInt;
    } else if (value is double) {
      return tDouble;
    } else if (value is bool) {
      return tBool;
    } else if (value is List) {
      return tListDynamic;
    } else {
      return tObject;
    }
  }

  /// (int -> double) / bool -> string -> dynamic
  /// Class / List -> dynamic
  static ClassType? mergeType(ClassType? oriType, ClassType? newType) {
    if (oriType == null || oriType.isNull) {
      return newType;
    } else if (newType == null || newType.isNull) {
      return oriType;
    } else if (oriType == newType) {
      return oriType;
    }

    if (oriType == ClassType.tInt || oriType == ClassType.tDouble) {
      if (newType == ClassType.tInt || newType == ClassType.tDouble) {
        return ClassType.tDouble;
      } else if (newType == ClassType.tBool || newType == ClassType.tString) {
        return ClassType.tString;
      } else {
        return ClassType.tDynamic;
      }
    } else if (oriType == ClassType.tBool) {
      if (newType == ClassType.tInt ||
          newType == ClassType.tDouble ||
          newType == ClassType.tString) {
        return ClassType.tString;
      } else {
        return ClassType.tDynamic;
      }
    } else if (oriType == ClassType.tString) {
      if (newType == ClassType.tInt ||
          newType == ClassType.tDouble ||
          newType == ClassType.tBool) {
        return ClassType.tString;
      } else {
        return ClassType.tDynamic;
      }
    } else {
      return ClassType.tDynamic;
    }
  }

  /// The set of primitive Dart types.
  static const primitiveTypes = <ClassType>[
    tInt,
    tDouble,
    tString,
    tBool,
  ];

  /// All available class types.
  static const values = <ClassType>[
    tInt,
    tDouble,
    tString,
    tBool,
    tListDynamic,
    tDynamic,
    tObject,
    tNull,
  ];

  /// The int type.
  static const tInt = ClassType._internal(ClassType._int);

  /// The double type.
  static const tDouble = ClassType._internal(ClassType._double);

  /// The String type.
  static const tString = ClassType._internal(ClassType._string);

  /// The bool type.
  static const tBool = ClassType._internal(ClassType._bool);

  /// The List type.
  static const tListDynamic = ClassType._internal(ClassType._listDynamic);

  /// The dynamic type.
  static const tDynamic = ClassType._internal(ClassType._dynamic);

  /// The null type.
  static const tNull = ClassType._internal(ClassType._null);

  /// The object/map type.
  static const tObject = ClassType._internal(ClassType._object);

  static const String _int = 'int';
  static const String _double = 'double';
  static const String _string = 'String';
  static const String _bool = 'bool';
  static const String _listDynamic = 'List';
  static const String _dynamic = 'dynamic';
  static const String _object = 'object';
  static const String _null = 'Null';

  @override
  String toString() {
    return value;
  }
}
