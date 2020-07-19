

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sends a Http request using a valid request [method] and [url] endpoint
/// from the WP_JSON_API plugin. The [body] and [userToken] is optional but
/// you can use these if the request requires them.
///
/// Returns a [dynamic] response from the server.
Future<dynamic> _http(
    {@required String method,
      @required String url,
      dynamic body}) async {
  var response;
  if (method == "GET") {
    response = await http.get(
      url,
//      headers: (userToken == null ? null : _authHeader(userToken)),
    );
  } else if (method == "POST") {
    Map<String, String> headers = {
      HttpHeaders.contentTypeHeader: "application/json",
    };
//    if (userToken != null) {
//      headers.addAll(_authHeader(userToken));
//    }

    response = await http.post(
      url,
      body: jsonEncode(body),
      headers: headers,
    );
  }

  // log output
  _devLogger(
      url: response.request.url.toString(),
      payload: method == "GET"
          ? response.request.url.queryParametersAll.toString()
          : body.toString(),
      result: response.body.toString());

  // return response
  return jsonDecode(response.body);
}

/// Logs the output of a app request.
/// [url] should be set containing the url route for the request.
/// The [payload] and [result] are optional but are used in the
/// log output if set. This will only log if shouldDebug is enabled.
///
/// Returns void.
_devLogger({@required String url, String payload, String result}) {
  String strOutput = "\nREQUEST: " + url;
  if (payload != null) strOutput += "\nPayload: " + payload;
  if (result != null) strOutput += "\nRESULT: " + result;

  // logs response if shouldDebug is enabled
  if (true) log(strOutput);
}