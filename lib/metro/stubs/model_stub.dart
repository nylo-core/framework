/// This stub is used to create a new Model.
String modelStub({String? modelName}) => '''
import 'package:nylo_framework/nylo_framework.dart';

/// $modelName Model.

class $modelName extends Model {
  $modelName();
  
  $modelName.fromJson(data) {

  }

  @override
  toJson() {
    return {};
  }
}
''';
