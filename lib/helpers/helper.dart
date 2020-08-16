import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String getEnv(String key) {
  return DotEnv().env[key];
}

String getImageAsset(String imageName) {
  return "${getEnv("ASSET_PATH_IMAGES")}/$imageName";
}

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

Future<void> authTokenStore(String token, {String key = 'user_auth_token'}) async {
  final storage = new FlutterSecureStorage();
  await storage.write(key: key, value: token);
}

Future<String> authTokenGet({String key = 'user_auth_token'}) async {
  final storage = new FlutterSecureStorage();
  return await storage.read(key: key);
}

Future<void> authTokenDelete({String key = 'user_auth_token'}) async {
  final storage = new FlutterSecureStorage();
  await storage.delete(key: key);
}

Future<void> storageStore(String value, {String key = 'default_key'}) async {
  final storage = new FlutterSecureStorage();
  await storage.write(key: key, value: value);
}

Future<String> storageGet({String key = 'default_key'}) async {
  final storage = new FlutterSecureStorage();
  return await storage.read(key: key);
}

Future<void> storageDelete({String key = 'default_key'}) async {
  final storage = new FlutterSecureStorage();
  await storage.delete(key: key);
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}


