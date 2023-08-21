import 'package:collection/collection.dart';

class ClassType {
  final String _value;

  const ClassType._internal(this._value);

  factory ClassType.name(String typeName) {
    var find = values.firstWhereOrNull((element) => element.value == typeName);

    if (find == null) {
      print('$typeName');
      throw '$typeName';
    }
    return find;
  }

  String get value => _value;

  static bool isPrimitiveType(String typeName) {
    return primitiveTypes.map((e) => e.value).contains(typeName);
  }

  bool get isPrimitive {
    return primitiveTypes.contains(this);
  }

  bool get isNull {
    return this == ClassType.tNull;
  }

  bool get isList {
    return this == ClassType.tListDynamic;
  }

  bool get isObject {
    return this == ClassType.tObject;
  }

  bool get isDynamic {
    return this == ClassType.tDynamic;
  }

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

  static const primitiveTypes = <ClassType>[
    tInt,
    tDouble,
    tString,
    tBool,
  ];

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

  static const tInt = ClassType._internal(ClassType._int);
  static const tDouble = ClassType._internal(ClassType._double);
  static const tString = ClassType._internal(ClassType._string);
  static const tBool = ClassType._internal(ClassType._bool);
  static const tListDynamic = ClassType._internal(ClassType._listDynamic);
  static const tDynamic = ClassType._internal(ClassType._dynamic);
  static const tNull = ClassType._internal(ClassType._null);
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
    return '$value';
  }
}
