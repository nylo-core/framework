String modelStub({String modelName, bool isStorable}) => '''
${isStorable == true ? "import 'package:nylo_framework/helpers/helper.dart';\n\n" : ""}class $modelName ${isStorable == true ? "extends Storable " : ""}{
  $modelName();

${isStorable == true ? '''
    @override
    toStorage() => {
      // 'my_data_key': this.myVal
    };

    @override
    fromStorage(dynamic data) {
      // this.myVal = data['my_data_key'];
    }
''' : ""}}
''';
