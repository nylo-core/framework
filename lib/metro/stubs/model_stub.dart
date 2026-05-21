import 'package:recase/recase.dart';

/// This stub is used to create a new Model.
String modelStub({required ReCase modelName}) =>
    '''
import 'package:nylo_framework/nylo_framework.dart';

class ${modelName.pascalCase} extends Model {
  static StorageKey key = "${modelName.snakeCase}";
  ${modelName.pascalCase}() : super(key: key);
  
  ${modelName.pascalCase}.fromJson(data) : super(key: key) {

  }

  @override
  toJson() {
    return {};
  }
}
''';
