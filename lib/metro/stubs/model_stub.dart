String modelStub({String modelName, bool isStorable}) => '''
${isStorable == true ? "import 'package:nylo_framework/helpers/helper.dart';\n\n" : ""}class $modelName ${isStorable == true ? "extends Storable " : ""}{
  $modelName();

${isStorable == true ? '''
    @override
    toStorage() => {
      
    };

    @override
    fromStorage(dynamic data) {
      
    }
''' : ""}
}
''';
