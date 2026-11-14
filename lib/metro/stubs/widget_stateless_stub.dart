import 'package:recase/recase.dart';

/// This stub is used to create a Stateless Widget in the /resources/widgets/ directory.
String widgetStatelessStub(ReCase rc) =>
    '''
import 'package:material_ui/material_ui.dart';

class ${rc.pascalCase} extends StatelessWidget {
  const ${rc.pascalCase}({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      
    );
  }
}
''';
