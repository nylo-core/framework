import 'package:recase/recase.dart';

String pageStub({required ReCase pageName}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${pageName.pascalCase}Page extends StatefulWidget {
  ${pageName.pascalCase}Page({Key? key}) : super(key: key);
  
  @override
  _${pageName.pascalCase}PageState createState() => _${pageName.pascalCase}PageState();
}

class _${pageName.pascalCase}PageState extends NyState<${pageName.pascalCase}Page> {

  @override
  init() async {
    
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
         child: Container(),
      ),
    );
  }
}
''';
