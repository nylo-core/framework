import 'package:recase/recase.dart';

String controllerStub({required ReCase controllerName}) => '''
import 'controller.dart';
import 'package:flutter/widgets.dart';

class ${controllerName.pascalCase}Controller extends Controller {
  
  construct(BuildContext context) {
    super.construct(context);

  }

} 
''';
