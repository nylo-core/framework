import 'package:http/http.dart';
import 'package:nylo_framework/helpers/helper.dart';

/// Base class for handling API networking
abstract class BaseApi {
  BaseApi();

  /// logs the [response]
  debugHttpLogger(Response response) async {
    if (getEnv("APP_DEBUG", defaultValue: false)) {
      NyLogger.debug("[METHOD] : ${response.request.method.toUpperCase()}\n" +
          "[URL] : ${response.request.url.toString()}\n" +
          "[BODY] : ${response.body.toString()}\n" +
          "[STATUS CODE] : ${response.statusCode.toString()}");
    }
  }
}
