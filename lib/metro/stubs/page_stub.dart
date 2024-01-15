import 'package:recase/recase.dart';

/// This stub is used to create a new Page.
String pageStub({required String className}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${className.pascalCase}Page extends NyStatefulWidget {
  static const path = '/${className.paramCase}';
  
  ${className.pascalCase}Page() : super(path, child: _${className.pascalCase}PageState());
}

class _${className.pascalCase}PageState extends NyState<${className.pascalCase}Page> {

  @override
  init() async {

  }
  
  /// Use boot if you need to load data before the view is rendered.
  // @override
  // boot() async {
  //
  // }

  @override
  Widget view(BuildContext context) {
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
