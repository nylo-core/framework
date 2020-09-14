String controllerStub({String controllerName}) => '''
import 'controller.dart';
import 'package:flutter/material.dart';

class ${controllerName}Controller extends Controller {
  
  ${controllerName}Controller.of(BuildContext context) {
    super.context = context;
  }

} 
''';
