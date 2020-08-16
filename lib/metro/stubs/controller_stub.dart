

String controllerStub({String controllerName}) => '''
import 'package:nylo_framework/metro/controllers/controller.dart';
import 'package:flutter/material.dart';

class ${controllerName}Controller extends Controller {
  
  ${controllerName}Controller.of(BuildContext context) {
    super.context = context;
  }

} 
''';