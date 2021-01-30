String controllerStub({String controllerName}) => '''
import 'controller.dart';

class ${controllerName}Controller extends Controller {
  
  ${controllerName}Controller();

} 
''';
