import 'package:recase/recase.dart';

String pageWithControllerStub({required ReCase className}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/${className.snakeCase}_controller.dart';

class ${className.pascalCase}Page extends NyStatefulWidget {
  final ${className.pascalCase}Controller controller = ${className.pascalCase}Controller();
  
  ${className.pascalCase}Page({Key? key}) : super(key: key);
  
  @override
  _${className.pascalCase}PageState createState() => _${className.pascalCase}PageState();
}

class _${className.pascalCase}PageState extends NyState<${className.pascalCase}Page> {

  @override
  init() async {
    super.init();
    
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        
      ),
      body: SafeArea(
        child: Container()
      ),
    );
  }
}
''';
