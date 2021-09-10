
import 'package:flutter/material.dart';
import 'package:theme_provider/theme_provider.dart';

/// Class to help manage current theme in the app.
class NyTheme {
  /// Changes the current theme to the new [theme]
  /// standard light [themeName] (id is default_light_theme)
  /// standard dark [themeName] (id is default_dark_theme)
  static set(BuildContext context, {required String themeName}) async {
    ThemeProvider.controllerOf(context).setTheme(themeName);
  }
}

/// Default base colors in the app.
abstract class NyBaseColors {
  Color get background;
  Color get primaryContent;
  Color get primaryAccent;
}