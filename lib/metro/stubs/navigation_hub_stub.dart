import 'package:recase/recase.dart';

/// Build a Navigation Hub stub with a chosen layout and tabs/states.
String navigationHubStub({
  required ReCase rc,
  required String layoutBuilder,
  required List<String> imports,
  required List<String> navigationEntries,
}) =>
    '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
${imports.join('\n')}

class ${rc.pascalCase}NavigationHub extends NyStatefulWidget with BottomNavPageControls {
  static RouteView path = ("/${rc.paramCase}", (_) => ${rc.pascalCase}NavigationHub());
  
  ${rc.pascalCase}NavigationHub({super.key})
      : super(
            child: () => _${rc.pascalCase}NavigationHubState(),
            stateName: path.stateName());

  /// State actions
  static NavigationHubStateActions stateActions = NavigationHubStateActions(path.stateName());
}

class _${rc.pascalCase}NavigationHubState extends NavigationHub<${rc.pascalCase}NavigationHub> {

  /// Layout builder
  @override
  NavigationHubLayout? layout(BuildContext context) => $layoutBuilder;

  /// Should the state be maintained
  @override
  bool get maintainState => true;
  
  /// The initial index
  @override
  int get initialIndex => 0;

  /// Navigation pages
  _${rc.pascalCase}NavigationHubState() : super(() => {
${navigationEntries.join('\n')}
  });

  /// Handle the tap event
  @override
  onTap(int index) {
    super.onTap(index);
  }
}
''';
