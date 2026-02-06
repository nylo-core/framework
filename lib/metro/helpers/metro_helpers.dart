import 'dart:convert';
import '/metro/ny_cli.dart';
import 'package:recase/recase.dart';

/// Helper to encode and decode JSON data
class NyJson {
  static dynamic tryDecode(data) {
    try {
      return jsonDecode(data);
    } catch (e) {
      return null;
    }
  }
}

/// Creates a new Model file
Future<void> createNyloModel(String classReCase,
    {required String stubModel,
    bool? hasForceFlag,
    String? creationPath,
    bool skipIfExist = false}) async {
  await MetroService.makeModel(classReCase.snakeCase, stubModel,
      forceCreate: hasForceFlag ?? false,
      addToConfig: true,
      creationPath: creationPath,
      skipIfExist: skipIfExist);
}
