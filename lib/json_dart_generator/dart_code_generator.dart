import 'dart:convert';
import 'dart:io';

import 'json_def.dart';

/// [DartCodeGenerator] code
class DartCodeGenerator {
  final String? rootClassName;

  final bool rootClassNameWithPrefixSuffix;

  final String? classPrefix;

  final String? classSuffix;

  DartCodeGenerator({
    this.rootClassName,
    this.rootClassNameWithPrefixSuffix = true,
    this.classPrefix,
    this.classSuffix,
  });

  String generate(String rawJson) {
    dynamic jsonData;
    try {
      jsonData = json.decode(rawJson);
    } catch (e) {
      stderr.write('json invalid\n$e\n');
      return '';
    }

    var def = JsonDef(
      rootClassName: rootClassName,
      jsonData: jsonData,
      rootClassNameWithPrefixSuffix: rootClassNameWithPrefixSuffix,
      classNamePrefixSuffixBuilder: (String name, bool isPrefix) {
        if (isPrefix) {
          return classPrefix;
        } else {
          return classSuffix;
        }
      },
    );

    return def.classCode;
  }
}
