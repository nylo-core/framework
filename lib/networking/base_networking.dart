import 'package:connectivity/connectivity.dart';
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

  /// Performs a checks to see if the device has connectivity.
  Future<bool> hasConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      return true;
    }
    return false;
  }

  /// Returns the type of connectivity a device current has.
  Future<String> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.mobile) {
      return "mobile";
    } else if (connectivityResult == ConnectivityResult.wifi) {
      return "wifi";
    }
    return null;
  }
}
