String apiServiceStub({String imports, String apiRequests}) => '''
import 'dart:convert';
import 'package:nylo_framework/networking/base_networking.dart';
import 'package:http/http.dart';

$imports

class BaseApiService extends BaseApi {
  
  var _client;

  BaseApiService() : _client = new Client();
  
  $apiRequests
  
}
''';