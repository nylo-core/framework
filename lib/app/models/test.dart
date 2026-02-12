import 'package:nylo_framework/nylo_framework.dart';

/// A test model used for framework testing.
class Test extends Model {
  /// The storage key for this model.
  static StorageKey key = "test";

  /// Creates a new [Test] instance.
  Test() : super(key: key);

  /// Creates a [Test] from JSON [data].
  Test.fromJson(dynamic data) : super(key: key) {}

  @override
  toJson() {
    return {};
  }
}
