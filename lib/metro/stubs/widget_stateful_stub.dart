import 'package:recase/recase.dart';

/// This stub is used to create a Stateful Widget in the /resources/widgets/ directory.
String widgetStatefulStub(ReCase rc) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase} extends StatefulWidget {
  
  const ${rc.pascalCase}({super.key});
  
  static String state = "${rc.snakeCase}";

  @override
  createState() => _${rc.pascalCase}State();
}

class _${rc.pascalCase}State extends NyState<${rc.pascalCase}> {

  _${rc.pascalCase}State() {
    stateName = ${rc.pascalCase}.state;
  }

  @override
  init() async {
    
  }
  
  @override
  stateUpdated(dynamic data) async {
    // e.g. to update this state from another class
    // updateState(${rc.pascalCase}.state, data: "example payload");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }
}
''';
