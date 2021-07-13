String widgetStatelessStub(String widgetName) => '''
import 'package:flutter/material.dart';

class ${widgetName}Widget extends StatelessWidget {
  const ${widgetName}Widget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }
}
''';
