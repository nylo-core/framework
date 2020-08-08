

String controllerStub({String controllerName}) => '''
import 'controller.dart';
import 'package:nylo_framework/view/ny_view.dart';
import 'package:flutter/widgets.dart';

class $controllerName extends Controller {
  $controllerName();


} 
''';