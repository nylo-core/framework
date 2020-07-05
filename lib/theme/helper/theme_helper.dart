import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nylo_framework/theme/default/default_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeHelper {
  static set(BuildContext context, {@required ThemeData theme}) async {
    CurrentTheme.instance.theme = theme;
    await setBrightness(theme.brightness);
    await DynamicTheme.of(context).setBrightness(theme.brightness);
  }
}

class CurrentTheme {
  CurrentTheme._privateConstructor();

  static final CurrentTheme instance = CurrentTheme._privateConstructor();

  ThemeData theme = defaultTheme();
}

setBrightness(Brightness brightness) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  brightness == Brightness.dark
      ? prefs.setBool("isDark", true)
      : prefs.setBool("isDark", false);
}