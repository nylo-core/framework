import 'package:recase/recase.dart';

/// This stub is used to create a Provider class in the /app/providers/ directory.
String providerStub(ReCase rc) => '''
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase}Provider implements NyProvider {

  @override
  boot(Nylo nylo) async {
   
     // boot your provider
     // ...
   
     return nylo;
  }
  
  @override
  afterBoot(Nylo nylo) async {
   
     // Called after booting your provider
     // ...
  }
}
''';
