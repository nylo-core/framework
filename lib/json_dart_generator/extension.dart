import 'class_type.dart';
import 'json_def.dart';

extension DartCodeGenerator on ValueDef {
  String get classCode {
    if (!(childrenDef is List) && !(childrenDef is Map)) {
      return '';
    }

    String fieldText() {
      String detectListInner(ValueDef def) {
        if (def.type.isList) {
          var defListType = def.listType!;
          if (defListType.isDynamic) {
            return 'List<${defListType.value}>?';
          } else if (defListType.isPrimitive) {
            return 'List<${defListType.value}>?';
          } else if (defListType.isList) {
            var childType =
                detectListInner((def.childrenDef as List<ValueDef>).first);
            return 'List<$childType>?';
          } else {
            return 'List<${detectListInner((def.childrenDef as List<ValueDef>).first)}>?';
          }
        }

        var obj = findCustomObject(def)!;
        return obj.classNameFull;
      }

      var text = '';
      if (childrenDef is List<ValueDef>) {
        var prefix = '${detectListInner(this)}';
        text += '$prefix value;';
      } else if (childrenDef is Map<String, ValueDef>) {
        var keyMap = childrenDef as Map<String, ValueDef>;
        keyMap.forEach((key, value) {
          if (value.type == ClassType.tListDynamic) {
            var prefix = '${detectListInner(value)}';
            text += '$prefix ${key.lowerCamel()};';
          } else if (value.type == ClassType.tObject) {
            late ValueDef findCustomDef;
            try {
              findCustomDef = findCustomObject(value)!;
            } catch (e) {
              print('$value');
            }
            text += '${findCustomDef.classNameFull}? ${key.lowerCamel()};';
          } else {
            var typeShow = '${value.type}';
            if (!value.type.isDynamic) {
              typeShow += '?';
            }
            text += '$typeShow ${key.lowerCamel()};';
          }
        });
      }
      return text;
    }

    // 建構子區域
    String constructorText() {
      var body = '';

      if (childrenDef is List<ValueDef>) {
        body += 'this.value';
      } else if (childrenDef is Map<String, ValueDef>) {
        var keyMap = childrenDef as Map<String, ValueDef>;
        keyMap.forEach((key, value) {
          body += 'this.${key.lowerCamel()},';
        });
      }

      if (body.isNotEmpty) {
        body = '{$body}';
      }

      return '$classNameFull($body);';
    }

    // fromJson
    String fromJsonText() {
      var body = '';
      var param = '';

      String listInnerContent(ListInner innerType) {
        if (innerType.type.isObject) {
          return '${innerType.className}.fromJson(e)';
        } else if (innerType.type.isPrimitive) {
          if (innerType.type == ClassType.tDouble) {
            return 'e.toDouble()';
          } else if (innerType.type == ClassType.tString) {
            return 'e.toString()';
          } else {
            return 'e as ${innerType.type.value}';
          }
        } else if (innerType.type.isDynamic) {
          return 'e';
        }
        return '';
      }

      String? listInnerTypeShow(ListInner innerType) {
        if (innerType.type.isPrimitive) {
          if (innerType.type == ClassType.tDouble) {
            return 'double';
          } else if (innerType.type == ClassType.tString) {
            return 'String';
          } else if (innerType.type == ClassType.tInt) {
            return 'int';
          } else if (innerType.type == ClassType.tBool) {
            return 'bool';
          }
        }
        return null;
      }

      String detectListInner(
        ValueDef def,
        String innerContent,
        String? innerTypeText, [
        int depth = 0,
      ]) {
        String nextInner() {
          return detectListInner(
            ((def.childrenDef as List<ValueDef>).first),
            innerContent,
            innerTypeText,
            depth + 1,
          );
        }

        if (depth == 0) {
          if (def.listType!.isDynamic) {
            return isListRoot && isRoot
                ? 'json'
                : 'json[\'${def.key}\'] as List';
          } else {
            return isListRoot && isRoot
                ? 'json${nextInner()}'
                : '(json[\'${def.key}\'] as List)${nextInner()}';
          }
        } else {
          if (def.type.isList) {
            if (def.listType!.isDynamic) {
              return '.map((e) => (e as List).toList()).toList()';
            } else {
              return '.map((e) => (e as List)${nextInner()}).toList()';
            }
          } else {
            if (innerTypeText != null) {
              return '.map<$innerTypeText>((e) => $innerContent).toList()';
            } else {
              return '.map((e) => $innerContent).toList()';
            }
          }
        }
      }

      if (childrenDef is List<ValueDef>) {
        param = 'List<dynamic> json';
        var innerType = listInnerType!;

        body += 'value = ${detectListInner(
          this,
          listInnerContent(innerType),
          listInnerTypeShow(innerType),
        )};';
      } else if (childrenDef is Map<String, ValueDef>) {
        param = 'Map<String, dynamic> json';
        var keyMap = childrenDef as Map<String, ValueDef>;
        keyMap.forEach((key, value) {
          if (body.isNotEmpty) {
            body += '\n';
          }

          if (value.type == ClassType.tListDynamic) {
            var innerType = value.listInnerType!;
            body +=
                'if (json[\'${value.key}\'] != null) {\n ${(value.key ?? value.parentKey)!.lowerCamel()} = ${detectListInner(
              value,
              listInnerContent(innerType),
              listInnerTypeShow(innerType),
            )}; \n}';
          } else if (value.type == ClassType.tObject) {
            var findCustomDef = findCustomObject(value)!;
            body +=
                '${key.lowerCamel()} = json[\'$key\'] != null ?  ${findCustomDef.classNameFull}.fromJson(json[\'${value.key}\']) : null;';
          } else {
            body += '${key.lowerCamel()} = json[\'$key\']';

            if (value.type == ClassType.tDouble) {
              body += '?.toDouble();';
            } else if (value.type == ClassType.tString) {
              body += '?.toString();';
            } else {
              body += ';';
            }
          }
        });
      }

      return '$classNameFull.fromJson($param) {\n$body\n}';
    }

    String toJsonText() {
      var body = '';
      var returnText = '';

      String detectListInner(ValueDef def, String innerContent,
          [int depth = 0]) {
        String nextInner() {
          return detectListInner(
            (def.childrenDef as List<ValueDef>).first,
            innerContent,
            depth + 1,
          );
        }

        if (depth == 0) {
          return '${isListRoot ? 'value' : (def.key ?? def.parentKey)!.lowerCamel()}?${nextInner()}';
        } else {
          if (def.type.isList) {
            return '.map((e) => e${nextInner()}).toList()';
          } else {
            return '.map((e) => $innerContent).toList()';
          }
        }
      }

      if (childrenDef is List<ValueDef>) {
        returnText = 'List<dynamic>?';

        var innerType = listInnerType!;

        if (innerType.type.isObject) {
          var innerContent = 'e.toJson()';
          body += 'return ${detectListInner(this, innerContent)};';
        } else {
          body += 'return value;';
        }
      } else if (childrenDef is Map<String, ValueDef>) {
        returnText = 'Map<String, dynamic>';
        var keyMap = childrenDef as Map<String, ValueDef>;
        keyMap.forEach((key, value) {
          if (body.isNotEmpty) {
            body += '\n';
          }

          if (value.type == ClassType.tListDynamic) {
            var innerType = value.listInnerType!;

            if (innerType.type.isObject) {
              var innerContent = 'e.toJson()';
              body += '\'$key\' : ${detectListInner(value, innerContent)},';
            } else {
              body += '\'$key\' : ${key.lowerCamel()},';
            }
          } else if (value.type == ClassType.tObject) {
            body += '\'$key\' : ${key.lowerCamel()}?.toJson(),';
          } else {
            body += '\'$key\' : ${key.lowerCamel()},';
          }
        });
        body = 'return {\n$body\n};';
      }

      return '$returnText toJson() {\n$body\n}';
    }

    return '''
class $classNameFull {
${fieldText()}

${constructorText()}

${fromJsonText()}

${toJsonText()}
}
    ''';
  }
}
