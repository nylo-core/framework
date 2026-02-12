import 'dart:convert';
import 'dart:io';

import 'json_def.dart';

/// Generates Dart model classes from raw JSON strings.
class DartCodeGenerator {
  /// The name of the root class to generate.
  final String? rootClassName;

  /// Whether to apply prefix/suffix to the root class name.
  final bool rootClassNameWithPrefixSuffix;

  /// Optional prefix for generated class names.
  final String? classPrefix;

  /// Optional suffix for generated class names.
  final String? classSuffix;

  /// Creates a [DartCodeGenerator] with optional naming configuration.
  DartCodeGenerator({
    this.rootClassName,
    this.rootClassNameWithPrefixSuffix = true,
    this.classPrefix,
    this.classSuffix,
  });

  /// Generates Dart class code from a [rawJson] string.
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
