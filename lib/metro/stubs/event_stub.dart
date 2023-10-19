import 'package:recase/recase.dart';

/// This stub is used to create a new Event.
String eventStub({required ReCase eventName}) => '''
import 'package:nylo_framework/nylo_framework.dart';

class ${eventName.pascalCase}Event implements NyEvent {

  @override
  final listeners = {
    DefaultListener: DefaultListener(),
  };
}

class DefaultListener extends NyListener {

  @override
  handle(dynamic event) async {
   // Handle the event
   
  }
}
''';
