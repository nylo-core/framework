import 'package:collection/collection.dart';

import 'class_type.dart';
import 'extension.dart';

typedef ClassNamePrefixSuffixBuilder = String? Function(
  String name,
  bool isPrefix,
);

class JsonDef {
  final dynamic jsonData;

  late ValueDef _jsonStruct;

  late ValueDef _summarizeStruct;

  List<ValueDef> get allCustomObject => _summarizeStruct.customObjects;

  JsonDef({
    String? rootClassName,
    this.jsonData,
    required bool rootClassNameWithPrefixSuffix,
    ClassNamePrefixSuffixBuilder? classNamePrefixSuffixBuilder,
  }) {
    _jsonStruct = ValueDef(
      rootClassName: rootClassName,
      rootClassNameWithPrefixSuffix: rootClassNameWithPrefixSuffix,
      value: jsonData,
      classNamePrefixSuffixBuilder: classNamePrefixSuffixBuilder,
    );
    _summarizeStruct = _jsonStruct.summarize();
  }

  String get structString {
    return _jsonStruct.structString;
  }

  String get summarizeString {
    return _summarizeStruct.structString;
  }

  String get customObjectString {
    return _summarizeStruct.customObjectString;
  }

  String get classCode {
    var code = '';
    code += _summarizeStruct.classCode;
    code += allCustomObject.map((e) => e.classCode).join('\n\n');
    return code;
  }
}

class ListInner {
  ClassType type;

  ClassType oriType;

  String className;

  ListInner({
    required this.type,
    required this.oriType,
    required this.className,
  });
}

class ValueDef {
  ClassType type;

  ClassType? listType;

  String? rootClassName;

  bool rootClassNameWithPrefixSuffix;

  ListInner? get listInnerType {
    if (listType == null) {
      return null;
    }

    ListInner findInner(ValueDef def) {
      if (def.type == ClassType.tListDynamic) {
        if (def.listType == ClassType.tDynamic) {
          return ListInner(
            type: ClassType.tDynamic,
            oriType: ClassType.tDynamic,
            className: ClassType.tDynamic.value,
          );
        } else {
          return findInner((def.childrenDef as List<ValueDef>).first);
        }
      } else if (def.type == ClassType.tObject) {
        var customObject = findCustomObject(def)!;
        return ListInner(
          type: def.type,
          oriType: def.type,
          className: customObject.classNameFull,
        );
      } else {
        return ListInner(
          type: def.type,
          oriType: ClassType.getType(def.value),
          className: def.type.value,
        );
      }
    }

    return findInner(this);
  }

  bool get isRoot => parent == null;

  bool get isListRoot {
    var parentDef = this;

    while (true) {
      if (parentDef.parent == null) {
        break;
      }
      parentDef = parentDef.parent!;
    }
    return parentDef.type.isList;
  }

  ValueDef? parent;

  int get depth {
    return (parent?.depth ?? -1) + 1;
  }

  String get _intentSpace {
    return '  ';
  }

  String get _depthIntentSpace {
    var text = '';
    for (var i = 0; i < depth; i++) {
      text += _intentSpace;
    }
    return text;
  }

  /// get parent key
  String? get parentKey {
    ValueDef? parentDef = this;
    var key = parentDef.key;

    while (key == null && parentDef != null) {
      key = parentDef.key;
      parentDef = parentDef.parent;
    }
    return key;
  }

  final String? key;

  final dynamic value;

  dynamic childrenDef;

  ClassNamePrefixSuffixBuilder? classNamePrefixSuffixBuilder;

  String get classNamePrefix =>
      classNamePrefixSuffixBuilder?.call(
        classNameNoPrefixSuffix,
        true,
      ) ??
      '';

  String get classNameSuffix =>
      classNamePrefixSuffixBuilder?.call(
        classNameNoPrefixSuffix,
        false,
      ) ??
      '';

  List<ValueDef> get customObjects {
    var objects = <ValueDef>[];
    if (depth != 0 && type == ClassType.tObject) {
      objects.add(this);
    }

    if (childrenDef is List<ValueDef>) {
      var childrenObject = (childrenDef as List<ValueDef>)
          .map((e) => e.customObjects)
          .expand((element) => element)
          .toList();

      // 一個一個加, 重複的去除
      childrenObject.forEach((outerE) {
        var isExist = objects.any((innerE) {
          var result = innerE.isStructSame(outerE);
          if (innerE.key == 'ios') {
            print('$result');
          }
          return result;
        });

        if (!isExist) {
          objects.add(outerE);
        }
      });
    } else if (childrenDef is Map<String, ValueDef>) {
      var childrenObject = (childrenDef as Map<String, ValueDef>)
          .entries
          .map((e) => e.value.customObjects)
          .expand((element) => element)
          .toList();

      childrenObject.forEach((outerE) {
        var isExist = objects.any((innerE) {
          var result = innerE.isStructSame(outerE);
          return result;
        });

        if (!isExist) {
          objects.add(outerE);
        }
      });
    }
    return objects;
  }

  /// all custom object
  List<ValueDef> get _allCustomObject {
    ValueDef? parentDef = this;
    do {
      parentDef = parentDef?.parent;
    } while (parentDef?.parent != null);
    return parentDef?.customObjects ?? customObjects;
  }

  ValueDef? findCustomObject(ValueDef def) {
    var find = _allCustomObject.firstWhereOrNull(
      (element) => def.isStructSame(element),
    );
    return find;
  }

  bool isStructSame(ValueDef other, {bool debug = false}) {
    if (childrenDef is List<ValueDef> && other.childrenDef is List<ValueDef>) {
      var thisFirst = (childrenDef as List<ValueDef>).first;
      var otherFirst = (other.childrenDef as List<ValueDef>).first;
      return thisFirst.isStructSame(otherFirst);
    } else if (childrenDef is Map<String, ValueDef> &&
        other.childrenDef is Map<String, ValueDef>) {
      var thisKeyList = (childrenDef as Map<String, ValueDef>).entries;
      var otherKeyList = (other.childrenDef as Map<String, ValueDef>).entries;
      var isLengthSame = thisKeyList.length == otherKeyList.length;

      if (debug) {
        print(
            'ori($key) = ${thisKeyList.length}, other(${other.key}) = ${otherKeyList.length}');
      }

      if (isLengthSame) {
        var isSame = !thisKeyList.any((element) {
          var thisKey = element.key;
          var thisValue = element.value;

          var findOther = otherKeyList
              .firstWhereOrNull((element) => element.key == thisKey);

          if (findOther != null) {
            var isSame = thisValue.isStructSame(findOther.value);
            return !isSame;
          } else {
            return true;
          }
        });

        if (debug) {
          print('$isSame');
        }

        return isSame;
      }
    } else if (type == other.type && key == other.key) {
      return true;
    }

    return false;
  }

  ValueDef copyWith(
      {ClassType? type, ClassType? listType, dynamic childrenDef}) {
    return ValueDef._(
      rootClassName: rootClassName,
      type: type ?? this.type,
      listType: listType,
      key: key,
      rootClassNameWithPrefixSuffix: rootClassNameWithPrefixSuffix,
      childrenDef: childrenDef ?? this.childrenDef,
    )..classNamePrefixSuffixBuilder = classNamePrefixSuffixBuilder;
  }

  ValueDef._({
    this.rootClassName,
    required this.rootClassNameWithPrefixSuffix,
    required this.type,
    this.listType,
    this.key,
    this.childrenDef,
  }) : value = null {
    _detectAllParentNode();
  }

  ValueDef({
    this.rootClassName,
    required this.rootClassNameWithPrefixSuffix,
    this.key,
    this.value,
    this.classNamePrefixSuffixBuilder,
  }) : type = ClassType.getType(value) {
    _childDef();
    _detectAllParentNode();
  }

  void _detectAllParentNode() {
    if (childrenDef is List<ValueDef>) {
      (childrenDef as List<ValueDef>).forEach((element) {
        element.parent = this;
        element._detectAllParentNode();
      });
    } else if (childrenDef is Map<String, ValueDef>) {
      (childrenDef as Map<String, ValueDef>).forEach((key, value) {
        value.parent = this;
        value._detectAllParentNode();
      });
    }
  }

  void _childDef() {
    switch (type) {
      case ClassType.tListDynamic:
        childrenDef = (value as List)
            .map((e) => ValueDef(
                  value: e,
                  rootClassNameWithPrefixSuffix: false,
                  classNamePrefixSuffixBuilder: classNamePrefixSuffixBuilder,
                ))
            .toList();
        break;
      case ClassType.tObject:
        childrenDef =
            (value as Map<String, dynamic>).map((key, value) => MapEntry(
                key,
                ValueDef(
                  key: key,
                  rootClassNameWithPrefixSuffix: false,
                  value: value,
                  classNamePrefixSuffixBuilder: classNamePrefixSuffixBuilder,
                )));
        break;
      default:
        childrenDef = value;
        break;
    }
  }

  ValueDef _summarizeData(ValueDef other) {
    if (type == ClassType.tListDynamic &&
        other.type == ClassType.tListDynamic) {
      ValueDef? elementDef;

      var keyList = List<ValueDef?>.from(childrenDef)
        ..addAll(other.childrenDef)
        ..whereNotNull();

      for (var i = 0; i < keyList.length; i++) {
        var element = keyList[i];

        elementDef ??= element;
        elementDef = elementDef!._summarizeData(element!);

        listType = elementDef.type;
        if (listType == ClassType.tDynamic) {
          break;
        }
      }

      return copyWith(
        type: type,
        listType: listType,
        childrenDef: listType == ClassType.tDynamic ? [] : [elementDef],
      );
    } else if (type == ClassType.tObject && other.type == ClassType.tObject) {
      var keyMap = Map<String, ValueDef>.from(childrenDef);

      (other.childrenDef as Map<String, ValueDef>).forEach((key, value) {
        if (keyMap.containsKey(key)) {
          keyMap[key] = keyMap[key]!._summarizeData(value);
        } else {
          keyMap[key] = value;
        }
      });
      return copyWith(type: type, childrenDef: keyMap);
    } else {
      var resultType = ClassType.mergeType(type, other.type);

      var mergeListType = ClassType.mergeType(listType, other.listType);
      var children = type.isNull ? other.childrenDef : childrenDef;

      return copyWith(
        type: resultType,
        listType: mergeListType,
        childrenDef: children,
      );
    }
  }

  ValueDef _summarizeEntry() {
    switch (type) {
      case ClassType.tListDynamic:
        if ((childrenDef as List).isEmpty) {
          listType = ClassType.tDynamic;

          return copyWith(
            type: type,
            listType: listType,
          );
        } else {
          ValueDef? elementDef;

          var keyList = List<ValueDef>.from(childrenDef);
          for (var i = 0; i < keyList.length; i++) {
            var element = keyList[i];

            elementDef ??= element;
            elementDef = elementDef._summarizeData(element);

            listType = elementDef.type;
            if (listType == ClassType.tDynamic) {
              break;
            }
          }

          return copyWith(
            type: type,
            listType: listType,
            childrenDef: listType == ClassType.tDynamic ? [] : [elementDef],
          );
        }
      case ClassType.tObject:
        var keyMap = Map<String, ValueDef>.from(childrenDef);
        (childrenDef as Map<String, ValueDef>).forEach((key, value) {
          keyMap[key] = value._summarizeEntry();
        });
        return copyWith(type: type, childrenDef: keyMap);
      default:
        return this;
    }
  }

  ValueDef _convertNullToDynamic(ValueDef def) {
    switch (def.type) {
      case ClassType.tListDynamic:
        var listType = def.listType!;
        if (listType.isNull || listType.isDynamic) {
          listType = ClassType.tDynamic;
          return def.copyWith(
            type: def.type,
            listType: listType,
          );
        } else {
          var keyList = List<ValueDef>.from(def.childrenDef);
          for (var i = 0; i < keyList.length; i++) {
            keyList[i] = _convertNullToDynamic(keyList[i]);
          }
          return def.copyWith(
            type: def.type,
            listType: listType,
            childrenDef: keyList,
          );
        }
      case ClassType.tObject:
        var keyMap = Map<String, ValueDef>.from(def.childrenDef);
        (def.childrenDef as Map<String, ValueDef>).forEach((key, value) {
          keyMap[key] = _convertNullToDynamic(value);
        });
        return def.copyWith(type: def.type, childrenDef: keyMap);
      default:
        if (def.type.isNull) {
          def.type = ClassType.tDynamic;
        }
        return def;
    }
  }

  ValueDef summarize() {
    var def = _summarizeEntry();

    return _convertNullToDynamic(def);
  }

  @override
  String toString() => structString;

  String get structString {
    var keyShow = '';
    if (key != null) {
      keyShow = '($key)';
    }
    if (childrenDef is Map) {
      return '${_depthIntentSpace}Map$keyShow {\n${(childrenDef as Map).values.join(',\n')}\n$_depthIntentSpace}';
    } else if (childrenDef is List) {
      if ((childrenDef as List).isEmpty) {
        return '${_depthIntentSpace}List<$listType>$keyShow []';
      } else {
        return '${_depthIntentSpace}List<$listType>$keyShow [\n${(childrenDef as List).join(',\n')}\n$_depthIntentSpace]';
      }
    } else {
      return '$_depthIntentSpace$type$keyShow $childrenDef';
    }
  }

  String get customObjectString {
    var text = '';

    customObjects.forEach((element) {
      if (text.isNotEmpty) {
        text += '\n\n';
      }
      var tempParent = parent;
      element.parent = null;
      text += element.structString;
      element.parent = tempParent;
    });
    return text;
  }

  String get classNameFull {
    if (isRoot && !rootClassNameWithPrefixSuffix) {
      return classNameNoPrefixSuffix;
    } else {
      return '$classNamePrefix$classNameNoPrefixSuffix$classNameSuffix';
    }
  }

  String get classNameNoPrefixSuffix {
    if (isRoot) {
      return rootClassName ?? 'Root';
    } else {
      var parentName = parent?.classNameNoPrefixSuffix;

      if (parentKey == null && type.isObject) {
        return '${parentName}Value'.upperCamel();
      } else {
        if (key == null) {
          return '$parentName'.upperCamel();
        } else {
          return '$parentName${key!.upperCamel()}'.upperCamel();
        }
      }
    }
  }
}

extension StringExtension on String {
  String upperCamel() {
    String capitalize(Match match) {
      var text = match[0];
      if (text == null) return '';
      if (text.length >= 2) {
        return '${text[0].toUpperCase()}${text.substring(1)}';
      } else if (text.length == 1) {
        return '${text[0].toUpperCase()}';
      } else {
        return text;
      }
    }

    String skip(String s) => '';

    return splitMapJoin(
      RegExp(r'[a-zA-Z0-9]+'),
      onMatch: capitalize,
      onNonMatch: skip,
    );
  }

  String lowerCamel() {
    var upper = upperCamel();
    return '${upper[0].toLowerCase()}${upper.substring(1)}';
  }
}
