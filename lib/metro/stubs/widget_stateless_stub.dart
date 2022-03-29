import 'package:recase/recase.dart';

String widgetStatelessStub(ReCase rc) => '''
import 'package:flutter/material.dart';

class ${rc.pascalCase} extends StatelessWidget {
  const ${rc.pascalCase}({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }
}
''';
