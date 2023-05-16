import 'package:recase/recase.dart';

String routeGuardStub(ReCase rc) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

/*
|--------------------------------------------------------------------------
| ${rc.pascalCase} Route Guard
|--------------------------------------------------------------------------
*/

class ${rc.pascalCase}RouteGuard extends NyRouteGuard {
  ${rc.pascalCase}RouteGuard();

  @override
  Future<bool> canOpen(BuildContext? context, NyArgument? data) async {
    // implement your check
    return true; // true/false
  }

  @override
  redirectTo(BuildContext? context, NyArgument? data) async {
    // redirect if canOpen is false
    // e.g. await routeTo(HomePage.path);
  }
}
''';
