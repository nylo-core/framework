import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:flutter/material.dart';

class CurrentTheme {
  CurrentTheme._privateConstructor();

  static final CurrentTheme instance = CurrentTheme._privateConstructor();

  ThemeData theme;
}

class AppThemeHelper {
  static set(BuildContext context, {@required ThemeData theme}) async {
    CurrentTheme.instance.theme = theme;
    await DynamicTheme.of(context).setBrightness(theme.brightness);
  }
}