import 'package:recase/recase.dart';

String widgetStatefulStub(ReCase rc) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase} extends StatefulWidget {
  @override
  _${rc.pascalCase}State createState() => _${rc.pascalCase}State();
}

class _${rc.pascalCase}State extends NyState<${rc.pascalCase}> {

  @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }
}
''';
