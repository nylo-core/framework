import 'package:nylo_framework/metro/helpers/tools.dart';

String pageWithControllerStub({String className, String importName}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/widgets/stateful_page_widget.dart';
import '../../app/controllers/${importName.toLowerCase()}_controller.dart';
import 'package:nylo_framework/widgets/ny_state.dart';

class ${capitalize(className)}Page extends StatefulPageWidget {
  final ${capitalize(className)}Controller controller = ${capitalize(className)}Controller();
  
  ${capitalize(className)}Page({Key key}) : super(key: key);
  
  @override
  _${capitalize(className)}PageState createState() => _${capitalize(className)}PageState();
}

class _${capitalize(className)}PageState extends NyState<${capitalize(className)}Page> {

  @override
  widgetDidLoad() async {
  
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
