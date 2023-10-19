import 'package:recase/recase.dart';

/// This stub is used to create a new Controller.
String controllerStub({required ReCase controllerName}) => '''
import 'controller.dart';
import 'package:flutter/widgets.dart';

class ${controllerName.pascalCase}Controller extends Controller {
  
  construct(BuildContext context) {
    super.construct(context);

  }

} 
''';
