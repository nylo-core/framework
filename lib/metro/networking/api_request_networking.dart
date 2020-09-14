import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nylo_framework/metro/models/ny_api_request.dart';

/// class used for managing the networking in Metro
Future<http.Response> metroApiRequest(NyApiRequest nyApiRequest) async {
  var url = nyApiRequest.url;
  http.Response response;

  switch (nyApiRequest.method) {
    case "post":
      {
        response = await http.post(url,
            body: jsonEncode(nyApiRequest.data),
            headers: nyApiRequest.headerMap());
        break;
      }
    case "get":
      {
        response = await http.get(url, headers: nyApiRequest.headerMap());
        break;
      }
    case "put":
      {
        response = await http.put(url,
            body: jsonEncode(nyApiRequest.data),
            headers: nyApiRequest.headerMap());
        break;
      }
    case "delete":
      {
        response = await http.delete(url, headers: nyApiRequest.headerMap());
        break;
      }
    default:
      {
        return null;
      }
  }

  return response;
}
