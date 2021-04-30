String pageStub({String? pageName}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/widgets/ny_state.dart';

class ${pageName}Page extends StatefulWidget {
  
  ${pageName}Page({Key key}) : super(key: key);
  
  @override
  _${pageName}PageState createState() => _${pageName}PageState();
}

class _${pageName}PageState extends NyState<${pageName}Page> {

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
         child: Container(),
      ),
    );
  }
}
''';
