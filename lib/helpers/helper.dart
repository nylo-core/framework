import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:nylo_framework/localization/app_localization.dart';
import 'package:nylo_framework/router/router.dart';
import 'package:sailor/sailor.dart';

/// Returns a value from the .env file
/// the [key] must exist as a string value e.g. APP_NAME.
///
/// Returns a String|bool|null|dynamic
/// depending on the value type.
dynamic getEnv(String key, {dynamic defaultValue}) {
  if (!DotEnv().env.containsKey(key) && defaultValue != null) {
    return defaultValue;
  }

  String value = DotEnv().env[key];

  if (value == 'null' || value == null) {
    return null;
  }

  if (value.toLowerCase() == 'true') {
    return true;
  }

  if (value.toLowerCase() == 'false') {
    return false;
  }

  return value.toString();
}

/// Returns the full image path for a image in /public/assets/images/ directory.
/// Provide the name of the image, using [imageName] parameter.
///
/// Returns a [String].
String getImageAsset(String imageName) {
  return "${getEnv("ASSET_PATH_IMAGES")}/$imageName";
}

/// Returns the full path for an asset in /public/assets directory.
/// Usage e.g. getPublicAsset('videos/welcome.mp4');
///
/// Returns a [String].
String getPublicAsset(String asset) {
  return "${getEnv("ASSET_PATH_PUBLIC")}/$asset";
}

/// Returns a text theme for a app font.
/// Returns a [TextTheme].
TextTheme getAppTextTheme(TextStyle appThemeFont, TextTheme textTheme) {
  return TextTheme(
    headline1: appThemeFont.merge(textTheme?.headline1),
    headline2: appThemeFont.merge(textTheme?.headline2),
    headline3: appThemeFont.merge(textTheme?.headline3),
    headline4: appThemeFont.merge(textTheme?.headline4),
    headline5: appThemeFont.merge(textTheme?.headline5),
    headline6: appThemeFont.merge(textTheme?.headline6),
    subtitle1: appThemeFont.merge(textTheme?.subtitle1),
    subtitle2: appThemeFont.merge(textTheme?.subtitle2),
    bodyText1: appThemeFont.merge(textTheme?.bodyText1),
    bodyText2: appThemeFont.merge(textTheme?.bodyText2),
    caption: appThemeFont.merge(textTheme?.caption),
    button: appThemeFont.merge(textTheme?.button),
    overline: appThemeFont.merge(textTheme?.overline),
  );
}

/// Useful helper to store a [String] auth token.
/// Use case - After authenticating a user, adding their token.
Future<void> authTokenStore(String token,
    {String key = 'user_auth_token'}) async {
  final storage = new FlutterSecureStorage();
  await storage.write(key: key, value: token);
}

/// Helper method to return a auth token stored on the users device.
/// Pass in the [key] if it's not stored in the default location.
Future<String> authTokenGet({String key = 'user_auth_token'}) async {
  final storage = new FlutterSecureStorage();
  return await storage.read(key: key);
}

/// Helper method to delete a auth token stored on the users device.
/// Use case - If a user signs out from your app.
Future<void> authTokenDelete({String key = 'user_auth_token'}) async {
  final storage = new FlutterSecureStorage();
  await storage.delete(key: key);
}

/// Extensions for String
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

/// Storable class to implement local storage for Models.
/// This class can be used to then storage models using the [NyStorage] class.
abstract class Storable {
  /// Return a representation of the model class.
  /// E.g. Product class
  ///
  ///import 'package:nylo_framework/helpers/helper.dart';
  ///
  /// class Product extends Storable {
  /// ...
  ///   @override
  ///   toStorage() {
  ///     return {
  ///       "title": title,
  ///       "price": price,
  ///       "imageUrl": imageUrl
  ///     };
  ///   }
  /// }
  ///

  toStorage() {
    return {};
  }

  /// Used to initialize the object using the [data] parameter.
  /// E.g. Product class
  ///
  ///import 'package:nylo_framework/helpers/helper.dart';
  ///
  /// class Product extends Storable {
  /// ...
  ///   @override
  ///   fromStorage(dynamic data) {
  ///     this.title = data["title"];
  ///     this.price = data["price"];
  ///     this.imageUrl = data["imageUrl"];
  ///   }
  /// }
  ///
  fromStorage(dynamic data) {}

  /// Save the object to secure storage using a unique [key].
  /// E.g. User class
  ///
  /// User user = new User();
  /// user.name = "Anthony";
  /// user.save('com.company.app.auth_user');
  ///
  /// Get user
  /// User user = await NyStorage.read<User>('com.company.app.auth_user', model: new User());
  save(String key) {
    NyStorage.store(key, this);
  }

  /// Check if the object implements [Storable].
  isStoreable() {
    return true;
  }
}

class StorageManager {
  static final storage = new FlutterSecureStorage();
}

/// Base class to help manage local storage
class NyStorage {
  /// Saves an [object] to local storage.
  static store(String key, object) async {
    assert(object != null);

    if (object is String) {
      return await StorageManager.storage.write(key: key, value: object);
    }

    if (object is int) {
      return await StorageManager.storage
          .write(key: key, value: object.toString());
    }

    if (object is double) {
      return await StorageManager.storage
          .write(key: key, value: object.toString());
    }

    if (object is Storable) {
      return await StorageManager.storage
          .write(key: key, value: jsonEncode(object.toStorage()));
    }
  }

  /// Read a value from the local storage
  static Future<dynamic> read<T>(String key, {Storable model}) async {
    assert(key != null);

    String data = await StorageManager.storage.read(key: key);
    if (data == null) {
      return null;
    }

    if (model != null) {
      try {
        if (model.isStoreable() != null && model.isStoreable() == true) {
          String data = await StorageManager.storage.read(key: key);
          if (data == null) {
            return null;
          }

          model.fromStorage(jsonDecode(data));
          return model;
        }
      } on Exception catch (e) {
        print(e.toString());
      }
    }

    if (T == null) {
      return data;
    }

    if (T.toString() == "String") {
      return data.toString();
    }

    if (T.toString() == "int") {
      return int.parse(data.toString());
    }

    if (T.toString() == "double") {
      return double.parse(data);
    }

    return data;
  }

  /// Deletes associated value for the given [key].
  static delete(String key) async {
    return await StorageManager.storage.delete(key: key);
  }
}

class NyArgument extends BaseArguments {
  dynamic data;
  NyArgument(this.data);
}

/// Helper class for navigation
class NyNav {
  NyNav.to({
    @required String routeName,
    dynamic data,
    NavigationType navigationType = NavigationType.push,
    dynamic result,
    bool Function(Route<dynamic> route) removeUntilPredicate,
    List<SailorTransition> transitions,
    Duration transitionDuration,
    Curve transitionCurve,
    Map<String, dynamic> params,
    CustomSailorTransition customTransition,
  }) {
    NyArgument nyArgument = NyArgument(data);
    NyNavigator.instance.router.navigate(
      routeName,
      args: nyArgument,
      navigationType: navigationType,
      result: result,
      removeUntilPredicate: removeUntilPredicate,
      transitions: transitions,
      transitionDuration: transitionDuration,
      transitionCurve: transitionCurve,
      params: params,
      customTransition: customTransition,
    );
  }
}

NavigationType navigationType(NavType navType) {
  if (navType == NavType.push) {
    return NavigationType.push;
  }
  if (navType == NavType.pushReplace) {
    return NavigationType.pushReplace;
  }
  if (navType == NavType.pushAndRemoveUntil) {
    return NavigationType.pushAndRemoveUntil;
  }
  if (navType == NavType.popAndPushNamed) {
    return NavigationType.popAndPushNamed;
  }
  return null;
}

enum NavType { push, pushReplace, pushAndRemoveUntil, popAndPushNamed }

List<SailorTransition> routeTransitions(
    void Function(List<RouteTransition> list) transition) {
  List<RouteTransition> transitions = [];
  transition(transitions);
  List<SailorTransition> tmp = [];

  if (transitions.contains(RouteTransition.fade_in)) {
    tmp.add(SailorTransition.fade_in);
  }
  if (transitions.contains(RouteTransition.slide_from_right)) {
    tmp.add(SailorTransition.slide_from_right);
  }
  if (transitions.contains(RouteTransition.slide_from_left)) {
    tmp.add(SailorTransition.slide_from_left);
  }
  if (transitions.contains(RouteTransition.slide_from_top)) {
    tmp.add(SailorTransition.slide_from_top);
  }
  if (transitions.contains(RouteTransition.slide_from_bottom)) {
    tmp.add(SailorTransition.slide_from_bottom);
  }
  if (transitions.contains(RouteTransition.zoom_in)) {
    tmp.add(SailorTransition.zoom_in);
  }
  return tmp;
}

/// Logger used for messages you want to print to the console.
class NyLogger {
  Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      printTime: true,
    ),
  );

  NyLogger.debug(String message) {
    _logger.d(message);
  }

  NyLogger.error(String message) {
    _logger.e(message);
  }

  NyLogger.info(String message) {
    _logger.i(message);
  }
}

/// Returns the translation value from the [key] you provide.
/// E.g. trans(context, "hello")
/// lang translation will be returned for the app locale.
String trans(BuildContext context, String key) =>
    AppLocalizations.of(context).trans(key);

/// Nylo version
const String nyloVersion = 'v0.5-beta.0';
