import 'package:recase/recase.dart';

/// This stub is used to create a State Managed Widget in the /resources/widgets/ directory.
String widgetStateManagedStub(ReCase rc) =>
    '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase} extends NyStateManaged {
  ${rc.pascalCase}({super.key, super.stateName})
      : super(child: () => _${rc.pascalCase}State(stateName));

  static String state = "${rc.snakeCase}";

  static String _stateFor(String? state) =>
      state == null ? ${rc.pascalCase}.state : "\${${rc.pascalCase}.state}_\$state";

  static action(String action, {dynamic data, String? stateName}) {
    return stateAction(action, data: data, state: _stateFor(stateName));
  }
}

class _${rc.pascalCase}State extends NyState<${rc.pascalCase}> {
  _${rc.pascalCase}State(String? stateName) {
    this.stateName = ${rc.pascalCase}._stateFor(stateName);
  }

  @override
  get init => () {
   // initialization logic here
  };

  @override
  Map<String, Function> get stateActions => {
    "my_action": (data) {},
    "clear_data": () {
      // Invoke actions from anywhere in your app
      // ${rc.pascalCase}.action("my_action", data: "hello world");
      // ${rc.pascalCase}.action("clear_data");
    },
  };

  @override
  Widget view(BuildContext context) {
    return Container(
      child: Text("My Widget").bodyMedium(),
    );
  }
}
''';
