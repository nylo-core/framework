
import 'package:nylo_framework/metro/helpers/tools.dart';

String interfaceStub({String interfaceName}) => '''
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ${capitalize(interfaceName)}PageInterface {
  ${capitalize(interfaceName)}PageInterface(this._context);

  BuildContext _context;
  
  // build your interface
 
}

''';