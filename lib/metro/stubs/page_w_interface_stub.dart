
import 'package:nylo_framework/metro/helpers/tools.dart';

String pageWithInterfaceStub({String className, String importName}) => '''
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../../app/interface/${importName.toLowerCase()}_page_interface.dart';

class ${capitalize(className)}Page extends StatefulWidget {
  final ${capitalize(className)}PageInterface interface;
  
  ${capitalize(className)}Page({Key key, this.interface}) : super(key: key);
  
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