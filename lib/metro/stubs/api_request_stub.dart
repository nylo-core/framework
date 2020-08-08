
import 'dart:convert';

import 'package:nylo_framework/metro/models/ny_api_request.dart';

String apiRequestStub(NyApiRequest nyApiRequest) => '''
Future<${nyApiRequest.modelType == 'list' ? 'List<${nyApiRequest.modelName}>' : nyApiRequest.modelName}> fetch${nyApiRequest.modelType == 'list' ? 'List' + nyApiRequest.modelName : nyApiRequest.modelName}(${nyApiRequest.strUrlParams()}) async {
  try {
  
      var queryParameters = {${nyApiRequest.mapQueryParams()}};
    
      var uri = Uri.http("${nyApiRequest.urlUri().host}", "${nyApiRequest.urlUri().path}", queryParameters);
    
      Response response = await _client.${nyApiRequest.method}(uri, ${nyApiRequest.method == 'post' ? 'body: ${jsonDecode(nyApiRequest.data).toString()},' : ''} headers: ${nyApiRequest.headerMap()});
      debugHttpLogger(response);

      dynamic json = jsonDecode(response.body);
      ${nyApiRequest.modelType == 'list' ? 'List<${nyApiRequest.modelName}> listObj = (json as List).map((i) => ${nyApiRequest.modelName}.fromJson(i)).toList();' : '${nyApiRequest.modelName} obj = ${nyApiRequest.modelName}.fromJson(json);'}
      return ${nyApiRequest.modelType == 'list' ? 'listObj' : 'obj'};
  } on Exception catch(e) {
    print(e.toString());
    return null;
  }
}
''';