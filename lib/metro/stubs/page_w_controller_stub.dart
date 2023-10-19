import 'package:recase/recase.dart';

/// This stub is used to create a new Page + Controller.
String pageWithControllerStub({required ReCase className}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/${className.snakeCase}_controller.dart';

class ${className.pascalCase}Page extends NyPage<${className.pascalCase}Controller> {

  static String path = '/${className.paramCase}';

  @override
  init() async {
    
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
