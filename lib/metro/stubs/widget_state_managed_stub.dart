import 'package:recase/recase.dart';

/// This stub is used to create a State Managed Widget in the /resources/widgets/ directory.
String widgetStateManagedStub(ReCase rc) => '''
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
  get init => () async {
    // 'stateData' will contain the current state data
  };
  
  // @override
  // Map<String, Function> get stateActions => {
  //   "add_data": (myData) {},
  //   "clear_data": () {
  //     ...
  //
  //     // Example how to invoke this action from another widget or class
  //     // stateAction("clear_data", state: ${rc.pascalCase}.state);
  //   },
  // };

  @override
  Widget view(BuildContext context) {
    return Container(
      
    );
  }
}
''';
