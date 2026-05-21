import 'package:recase/recase.dart';

/// This stub is used to create a Deep Link Provider class in the
/// /app/providers/ directory. The provider enables Nylo's deep-link
/// capture and gives a starting point for intercepting incoming URIs.
String deepLinkProviderStub(ReCase rc) =>
    '''
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase}Provider implements NyProvider {

  @override
  setup(Nylo nylo) async {
    // Enable platform deep-link capture (Android App Links, iOS Universal
    // Links, custom URL schemes, and web URLs).
    //
    // Pass a [fallbackRoute] to land somewhere sensible when an incoming URI
    // doesn't match a registered route:
    //
    //   nylo.useDeepLinks(fallbackRoute: HomePage.path);
    nylo.useDeepLinks();

    // Optional: intercept every incoming URI before Nylo routes it.
    // Return `true` to let Nylo route automatically, or `false` to handle
    // the URI yourself.
    //
    // nylo.onIncomingLink((Uri uri) async {
    //   // e.g. require auth on /account/* routes
    //   // if (uri.path.startsWith('/account') && !await isLoggedIn()) {
    //   //   routeTo(LoginPage.path);
    //   //   return false;
    //   // }
    //   return true;
    // });

    return nylo;
  }

  @override
  boot(Nylo nylo) async {
    // This method is called after all providers are setup.
  }
}
''';
