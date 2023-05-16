import 'package:recase/recase.dart';

String providerStub(ReCase rc) => '''
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase}Provider implements NyProvider {

  boot(Nylo nylo) async {
   
     // boot your provider
     // ...
   
     return nylo;
  }
  
  afterBoot(Nylo nylo) async {
   
     // Called after booting your provider
     // ...
  }
}
''';
