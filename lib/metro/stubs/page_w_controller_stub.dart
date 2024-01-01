import 'package:recase/recase.dart';

/// This stub is used to create a new Page + Controller.
String pageWithControllerStub(
        {required String className, String? creationPath}) =>
    '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/${creationPath != null ? creationPath + "/${className.snakeCase}" : className.snakeCase}_controller.dart';

class ${className.pascalCase}Page extends NyStatefulWidget<${className.pascalCase}Controller> {
  static const path = '/${className.paramCase}';

  ${className.pascalCase}Page() : super(path, child: _${className.pascalCase}PageState());
}

class _${className.pascalCase}PageState extends NyState<${className.pascalCase}Page> {

  @override
  init() async {
    super.init();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${className.titleCase}")
      ),
      body: SafeArea(
         child: Container(),
      ),
    );
  }
}
''';
