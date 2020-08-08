
String middlewareStub({String middlewareName}) => '''
import 'package:flutter/cupertino.dart';
import 'package:flutter_app/routes/router.dart';

class $middlewareName {
  $middlewareName();

  void handle(
    BuildContext context,
    Object request,
  ) {
    
    return null;
  }
}
''';