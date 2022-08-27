import 'package:flutter/material.dart';
import 'package:theme_provider/theme_provider.dart';

/// Class to help manage current theme in the app.
class NyTheme {
  /// Changes the current theme to the new [theme]
  /// standard light [themeName] (id is "light_theme")
  /// standard dark [themeName] (id is "dark_theme")
  static set(BuildContext context, {required String id}) {
    ThemeProvider.controllerOf(context).setTheme(id);
  }
}
