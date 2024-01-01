import 'package:recase/recase.dart';

/// This stub is used to create an API Service class in the /app/networking/ directory.
String postmanApiServiceStub(ReCase rc,
        {required String networkMethods,
        required,
        required String imports,
        required String baseUrl}) =>
    '''import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/config/decoders.dart';${imports != "" ? '\n' + imports + '' : ''}

class ${rc.pascalCase}ApiService extends NyApiService {
  ${rc.pascalCase}ApiService({BuildContext? buildContext}) : super(buildContext, decoders: modelDecoders);

  @override
  String get baseUrl => "";

  $networkMethods
}
''';
