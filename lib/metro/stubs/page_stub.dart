import 'package:recase/recase.dart';

/// This stub is used to create a new Page.
String pageStub({required ReCase pageName}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${pageName.pascalCase}Page extends NyPage {

  static String path = '/${pageName.paramCase}';

  @override
  init() async {
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${pageName.titleCase}")
      ),
      body: SafeArea(
         child: Container(),
      ),
    );
  }
}
''';
