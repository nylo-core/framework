import 'package:recase/recase.dart';

/// This stub is used to create a new Page.
String pageStub({required String className}) =>
    '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${className.pascalCase}Page extends NyStatefulWidget {

  static RouteView path = ("/${className.paramCase}", (_) => ${className.pascalCase}Page());

  /// Actions e.g. ${className.pascalCase}Page.actions.showToast("hello");
  static final actions = path.actions;

  ${className.pascalCase}Page({super.key}) : super(child: () => _${className.pascalCase}PageState());
}

class _${className.pascalCase}PageState extends NyPage<${className.pascalCase}Page> {

  @override
  get init => () {

  };
  
  @override
  bool get stateManaged => true;

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
