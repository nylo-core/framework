import 'package:recase/recase.dart';

String widgetStatelessStub(ReCase rc) => '''
import 'package:flutter/material.dart';

class ${rc.pascalCase}Widget extends StatelessWidget {
  const ${rc.pascalCase}Widget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }
}
''';
