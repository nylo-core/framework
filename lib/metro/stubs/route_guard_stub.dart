import 'package:recase/recase.dart';

/// This stub is used to create a Route Guard class in the /routes/guards/ directory.
String routeGuardStub(ReCase rc) => '''
import 'package:nylo_framework/nylo_framework.dart';

/* ${rc.pascalCase} Route Guard
|-------------------------------------------------------------------------- */

class ${rc.pascalCase}RouteGuard extends NyRouteGuard {
  ${rc.pascalCase}RouteGuard();

  @override
  onRequest(PageRequest pageRequest) async {
    // example
    // if ((await Auth.isAuthenticated()) == false) {
    //    return redirect(HomePage.path);
    // }
    //
    // helpers
    // data = will give you access to the data passed to the route
    // context = will give you access to the BuildContext
    return pageRequest;
  }
}
''';
