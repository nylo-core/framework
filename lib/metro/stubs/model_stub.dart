String modelStub({String? modelName, bool? isStorable}) => '''
${isStorable == true ? "import 'package:nylo_support/helpers/helper.dart';\n\n" : ""}class $modelName ${isStorable == true ? "extends Storable " : ""}{
  $modelName();

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
