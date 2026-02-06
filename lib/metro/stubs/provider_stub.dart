import 'package:recase/recase.dart';

/// This stub is used to create a Provider class in the /app/providers/ directory.
String providerStub(ReCase rc) => '''
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase}Provider implements NyProvider {

  @override
  setup(Nylo nylo) async => nylo;
  
  @override
  boot(Nylo nylo) async {
    // This method is called after all providers are setup.
    // You can use it to perform any additional bootstrapping tasks.
    // ...
  }
}
''';
