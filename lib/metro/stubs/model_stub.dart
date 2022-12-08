String modelStub({String? modelName, bool? isStorable}) => '''
import 'package:nylo_framework/nylo_framework.dart';\n\nclass $modelName implements JsonOperations ${isStorable == true ? "extends Storable " : ""}{
  $modelName();
  
  @override
  $modelName.fromJson(data) {

  }

  @override
  toJson() {

  }
${isStorable == true ? '''
    /// Example [foo] below. 
    /// New to Storable? Learn more https://nylo.dev/docs/storage#introduction-to-storable-models
    late String foo; 

    @override
    toStorage() => {
      // "foo": this.foo
    };

    @override
    fromStorage(dynamic data) {
      // this.foo = data['foo'];
    }
''' : ""}}
''';
