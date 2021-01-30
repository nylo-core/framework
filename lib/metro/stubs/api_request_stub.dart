import 'dart:convert';

import 'package:nylo_framework/metro/models/ny_api_request.dart';

String apiRequestStub(NyApiRequest nyApiRequest) => '''
Future<${nyApiRequest.modelType == 'list' ? 'List<${nyApiRequest.modelName}>' : nyApiRequest.modelName}> fetch${nyApiRequest.modelType == 'list' ? 'List' + nyApiRequest.modelName : nyApiRequest.modelName}(${nyApiRequest.strUrlParams() != "" ? "{${nyApiRequest.strUrlParams()}}" : ''}) async {
  
  try {
      Map<String, String> queryParameters = {${nyApiRequest.mapQueryParams()}};
    
      var uri = Uri.${nyApiRequest.getProtocol() == 'https' ? 'https' : 'http'}("${nyApiRequest.getBaseUrl()}", "/${nyApiRequest.getUrlPath()}", queryParameters);
    
      Response response = await _client.${nyApiRequest.method}(uri, ${nyApiRequest.method == 'post' ? 'body: ${jsonDecode(nyApiRequest.data).toString()}' : ''} ${nyApiRequest.headerMap().isNotEmpty ? 'headers: {${nyApiRequest.headerString()}}' : ''});
      this.debugHttpLogger(response);

      dynamic json = jsonDecode(response.body);
      ${nyApiRequest.modelType == 'list' ? 'List<${nyApiRequest.modelName}> listObj = (json as List).map((i) => ${nyApiRequest.modelName}.fromJson(i)).toList();' : '${nyApiRequest.modelName} obj = ${nyApiRequest.modelName}.fromJson(json);'}
      return ${nyApiRequest.modelType == 'list' ? 'listObj' : 'obj'};
  } on Exception catch(e) {
      print(e.toString());
      return null;
  }
}
''';
