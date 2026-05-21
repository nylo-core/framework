import 'package:recase/recase.dart';

/// This stub is used to create a Route Guard class in the /routes/guards/ directory.
String routeGuardStub(ReCase rc) =>
    '''
import 'package:nylo_framework/nylo_framework.dart';

/* ${rc.pascalCase} Route Guard
|-------------------------------------------------------------------------- */

class ${rc.pascalCase}RouteGuard extends NyRouteGuard {
  ${rc.pascalCase}RouteGuard();

  @override
  Future<GuardResult> onBefore(RouteContext context) async {
    // example
    // if ((await Auth.isAuthenticated()) == false) {
    //    return redirect(HomePage.path);
    // }
    //
    // helpers
    // context.data - data passed to the route
    // context.queryParameters - query parameters from the URL
    // context.routeName - the route being navigated to
    // context.context - the BuildContext
    return next();
  }
}
''';
