import 'package:recase/recase.dart';

String widgetStatefulStub(ReCase rc) => '''
import 'package:flutter/material.dart';

class ${rc.pascalCase}Widget extends StatefulWidget {
  @override
  _${rc.pascalCase}WidgetState createState() => _${rc.pascalCase}WidgetState();
}

class _${rc.pascalCase}WidgetState extends State<${rc.pascalCase}Widget> {

  @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }
}
''';
