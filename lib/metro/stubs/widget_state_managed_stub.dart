import 'package:recase/recase.dart';

/// This stub is used to create a State Managed Widget in the /resources/widgets/ directory.
String widgetStateManagedStub(ReCase rc) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase} extends StatefulWidget {
  const ${rc.pascalCase}({super.key});
  
  static String state = "${rc.snakeCase}";
  static action(String action, {dynamic data}) =>
      stateAction(action, data: data, state: state);

  @override
  createState() => _${rc.pascalCase}State();
}

class _${rc.pascalCase}State extends NyState<${rc.pascalCase}> {
  _${rc.pascalCase}State() {
    stateName = ${rc.pascalCase}.state;
  }

  @override
  get init => () {
   // initialization logic here
  };
  
  // @override
  // Map<String, Function> get stateActions => {
  //   "my_action": (data) {},
  //   "clear_data": () {
  //     // Invoke actions from anywhere in your app
  //     // Follow.action("my_action", data: "hello");
  //     // Follow.action("clear_data");
  //   },
  // };

  @override
  Widget view(BuildContext context) {
    return Container(
      
    );
  }
}
''';
