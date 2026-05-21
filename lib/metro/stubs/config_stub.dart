import 'package:recase/recase.dart';

/// This stub is used to create a new Config.
String configStub(ReCase configName) =>
    '''
/* ${configName.titleCase}
|--------------------------------------------------------------------------
| Learn more: https://nylo.dev/docs/7.x/configuration
|-------------------------------------------------------------------------- */

final class ${configName.pascalCase}Config {
  // Add your configuration values here
  static final String exampleValue = "exampleValue";

  // ...
}
''';
