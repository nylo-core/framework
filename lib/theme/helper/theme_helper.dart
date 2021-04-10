import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

/// Class to get the apps present theme
class CurrentTheme {
  CurrentTheme._privateConstructor();

  static final CurrentTheme instance = CurrentTheme._privateConstructor();

  ThemeData? theme;
}

/// Class to help manage current theme in the app.
class AppThemeHelper {
  /// Changes the current theme to the new [theme]
  static set(BuildContext context, {required ThemeData theme}) async {
    CurrentTheme.instance.theme = theme;

    if (theme.brightness == Brightness.light) {
      AdaptiveTheme.of(context).setLight();
    } else if (theme.brightness == Brightness.dark) {
      AdaptiveTheme.of(context).setDark();
    } else {
      AdaptiveTheme.of(context).setSystem();
    }
  }
}
