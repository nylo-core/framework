import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nylo_framework/theme/helper/theme_helper.dart';

class NyConfig {

  String name;
  bool debug;
  String url = "https://localhost:8080";
  String configAssetPath = "public/assets/";
  String timezone = "UTC";
  Locale defaultLocale = Locale("en", null);
  List<DeviceOrientation> deviceOrientations = [
    DeviceOrientation.portraitUp,
  ];
  ThemeData themeData = CurrentTheme.instance.theme;

  Iterable<Locale> supportedLocales = [
    Locale('en'),
  ];

  NyConfig({String name, bool debug, Iterable<Locale> supportedLocales}) {
    this.name = name;
    this.debug = debug;
    this.supportedLocales = supportedLocales;
  }
}