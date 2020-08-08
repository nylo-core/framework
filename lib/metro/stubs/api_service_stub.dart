String apiServiceStub({String imports, String apiRequests}) => '''
import 'dart:convert';
import '../base_api.dart';
import 'package:http/http.dart';

$imports

class BaseUrlApiService extends BaseApi {
  
  var _client;

  BaseUrlApiService() : _client = new Client();
  
  $apiRequests
  
}
''';