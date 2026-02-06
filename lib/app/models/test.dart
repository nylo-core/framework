import 'package:nylo_framework/nylo_framework.dart';

class Test extends Model {
  static StorageKey key = "test";
  Test() : super(key: key);
  
  Test.fromJson(data) : super(key: key) {

  }

  @override
  toJson() {
    return {};
  }
}
