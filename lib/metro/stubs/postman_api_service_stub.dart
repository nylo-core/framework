import 'package:recase/recase.dart';

String postmanApiServiceStub(ReCase rc,
        {required String networkMethods,
        required,
        required String imports,
        required String baseUrl}) =>
    '''
${baseUrl == "getEnv('API_BASE_URL')" ? "import 'package:nylo_framework/nylo_framework.dart';\n" : ""}import 'package:flutter/material.dart';
${imports != "" ? imports + '\n' : ''}import '/app/networking/dio/base_api_service.dart';

class ${rc.pascalCase}ApiService extends BaseApiService {
  ${rc.pascalCase}ApiService({BuildContext? buildContext}) : super(buildContext);

  @override
  String get baseUrl => $baseUrl;

  $networkMethods
}
''';
