import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
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

/// Helper to store items into local storage, pass a [value] and also a [key]
/// for the location.
Future<void> storageStore(String value, {String key = 'default_key'}) async {
  final storage = new FlutterSecureStorage();
  await storage.write(key: key, value: value);
}

/// Helper to return a value from the local storage on the users device.
/// This method returns objects back as type [String].
Future<String> storageGet({String key = 'default_key'}) async {
  final storage = new FlutterSecureStorage();
  return await storage.read(key: key);
}

/// Helper to delete an object from local storage when providing a [key].
Future<void> storageDelete({String key = 'default_key'}) async {
  final storage = new FlutterSecureStorage();
  await storage.delete(key: key);
}

/// Extensions for String
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

/// CanStore implementation for [Storable] objects.
abstract class CanStore {
  dynamic toStorage();
  fromStorage(dynamic data);
}

/// Storable class to implement local storage for Models.
/// This class can be used to then storage models using the [NyStorage] class.
abstract class Storable implements CanStore {
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
  @override
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
  @override
  fromStorage(dynamic data) {}
}

/// Base class to help manage local storage
class NyStorage {
  /// If your object should be storage as a collection of item, use saveToList
  /// This will store the [object] in an array of objects to return later using
  /// [NyStorageParser] toList method.
  static saveToList(String key, Storable object) async {
    final storage = new FlutterSecureStorage();
    dynamic json = await fetch(key);

    List<dynamic> list = [];

    if (json != null) {
      list.addAll(jsonDecode(json));
    }

    list.add(jsonEncode(object.toStorage()));

    return await storage.write(key: key, value: jsonEncode(list));
  }

  /// Removes an index from the [List] array.
  static deleteAtIndex(String key, int i) async {
    final storage = new FlutterSecureStorage();
    dynamic json = await fetch(key);

    List<dynamic> list = [];

    if (json == null) {
      throw new Exception("Index does not exist");
    }

    list.addAll(jsonDecode(json));
    list.removeAt(i);

    await storage.write(key: key, value: jsonEncode(list));

    return true;
  }

  /// Saves an [object] to local storage.
  /// Use the [NyStorageParser] to return the model with the toObject method.
  static saveTo(String key, Storable object) async {
    final storage = new FlutterSecureStorage();
    return await storage.write(key: key, value: jsonEncode(object.toStorage()));
  }

  /// Fetch a value from the local storage
  static Future<dynamic> fetch(String key) async {
    final storage = new FlutterSecureStorage();
    return await storage.read(key: key);
  }
}

/// Base class to handle parsing objects from the local storage
class NyStorageParser {
  /// You can return a single [Storable] object by passing in the storage
  /// location [key] and also the new [object] instance.
  ///
  /// Example - Returning a user
  /// User user = NyStorageParser.toObject("current_user", User());
  ///
  /// The the above would return the [User] from storage if it exists.
  static Future<Storable> toObject(String key, Storable object) async {
    String str = await NyStorage.fetch(key);
    dynamic data = jsonDecode(str);

    Storable tmp = object;
    tmp.fromStorage(data);
    return tmp;
  }

  /// You can return a list of [Storable] objects by passing in the storage
  /// location [key] and also the new [object] instance.
  ///
  /// Example - Returning a list Products in a users cart
  /// List<Product> products = (NyStorageParser.toList("current_cart", Cart())) as List<Product>;
  ///
  /// The the above would return a list [Cart] models from storage if they exists.
  static Future<List<Storable>> toList(String key, Storable object) async {
    String str = await NyStorage.fetch(key);
    List<dynamic> data = jsonDecode(str);

    List<Storable> tmp = [];
    data.forEach((element) {
      dynamic json = jsonDecode(element.toString());
      Storable tmpObj = object;

      tmpObj.fromStorage(json);
      tmp.add(tmpObj);
    });

    return tmp;
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

/// Logger used for messages you want to print to the console.
class NyLogger {
  Logger _logger = Logger(
      printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 8,
          lineLength: 100,
          colors: true,
          printEmojis: false,
          printTime: true));

  NyLogger.debug(String message) {
    _logger.d(message);
  }
}
