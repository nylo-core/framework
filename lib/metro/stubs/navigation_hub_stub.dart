import 'package:recase/recase.dart';

/// This stub is used to create a navigation hub widget
String navigationHubStub(ReCase rc) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase}NavigationHub extends NyStatefulWidget with BottomNavPageControls {
  static RouteView path = ("/${rc.paramCase}", (_) => ${rc.pascalCase}NavigationHub());
  
  ${rc.pascalCase}NavigationHub()
      : super(
            child: () => _${rc.pascalCase}NavigationHubState(),
            stateName: path.stateName());

  /// State actions
  static NavigationHubStateActions stateActions = NavigationHubStateActions(path.stateName());
}

class _${rc.pascalCase}NavigationHubState extends NavigationHub<${rc.pascalCase}NavigationHub> {

  /// Layouts: 
  /// - [NavigationHubLayout.bottomNav] Bottom navigation
  /// - [NavigationHubLayout.topNav] Top navigation
  /// - [NavigationHubLayout.journey] Journey navigation
  NavigationHubLayout? layout = NavigationHubLayout.bottomNav(
    // backgroundColor: Colors.white,
  );

  /// Should the state be maintained
  @override
  bool get maintainState => true;

  /// Navigation pages
  _${rc.pascalCase}NavigationHubState() : super(() async {
    /// * Creating Navigation Tabs
    /// [Navigation Tabs] 'dart run nylo_framework:main make:stateful_widget home_tab,settings_tab'
    /// [Journey States] 'dart run nylo_framework:main make:journey_widget welcome_tab,users_dob,users_info --parent=${rc.pascalCase}'
    return {
      // 0: NavigationTab(
      //   title: "Home",
      //   // page: HomeTab(),
      //   icon: Icon(Icons.home),
      //   activeIcon: Icon(Icons.home),
      // ),
      // 1: NavigationTab(
      //    title: "Settings",
      //    // page: SettingsTab(),
      //    icon: Icon(Icons.settings),
      //    activeIcon: Icon(Icons.settings),
      // ),
    };
  });

  /// Handle the tap event
  @override
  onTap(int index) {
    super.onTap(index);
  }
}
''';
