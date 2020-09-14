import 'package:nylo_framework/metro/helpers/tools.dart';

String pageWithControllerStub({String className, String importName}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/widgets/stateful_page_widget.dart';
import '../../app/controllers/${importName.toLowerCase()}_controller.dart';

class ${capitalize(className)}Page extends StatefulPageWidget {
  final ${capitalize(className)}Controller controller;
  
  ${capitalize(className)}Page({Key key, this.controller}) : super(key: key);
  
  @override
  _${capitalize(className)}PageState createState() => _${capitalize(className)}PageState();
}

class _${capitalize(className)}PageState extends State<${capitalize(className)}Page> {

  @override
  void initState() {
    super.initState();
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
        
      ),
    );
  }
}
''';
