import 'package:http/http.dart';
import 'package:nylo_framework/helpers/helper.dart';
import 'package:nylo_framework/metro/helpers/tools.dart';

class BaseApi {

  BaseApi();

  debugHttpLogger(Response response) async {
    bool debug = getEnv("APP_DEBUG");

    if (debug) {
      NyLogger()
          .addLn("[METHOD] : ${response.request.method.toUpperCase()}")
          .addLn("[URL] : " + response.request.url.toString())
          .addLn("[BODY] : " + response.body.toString())
          .addLn("[STATUS CODE] : " + response.statusCode.toString());
    }
  }
}