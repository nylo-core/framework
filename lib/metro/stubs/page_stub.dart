
String pageStub({String pageName}) => '''
import 'package:flutter/material.dart';

class ${pageName}Page extends StatefulWidget {
  
  ${pageName}Page({Key key}) : super(key: key);
  
  @override
  _${pageName}PageState createState() => _${pageName}PageState();
}

class _${pageName}PageState extends State<${pageName}Page> {

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