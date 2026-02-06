import 'package:flutter/material.dart';
import 'package:nylo_support/themes/ny_themes.dart';

/// Class to help manage current theme in the app.
///
/// Example:
/// ```dart
/// // Set theme by ID
/// NyTheme.set(context, id: 'dark_theme');
///
/// // Set theme and remember as preferred for its type
/// NyTheme.set(context, id: 'dark_amoled', remember: true);
///
/// // Get current theme
/// final theme = NyTheme.current();
///
/// // Check if dark mode
/// if (NyTheme.isDark()) {
///   // do something for dark mode
/// }
///
/// // Get all dark themes
/// final darkThemes = NyTheme.darkThemes();
///
/// // Set preferred dark theme for system theme following
/// NyTheme.setPreferredDark('dark_amoled');
/// ```
class NyTheme {
  /// Changes the current theme to the new [theme]
  /// standard light [themeName] (id is "light_theme")
  /// standard dark [themeName] (id is "dark_theme")
  ///
  /// [remember] - If true, sets this theme as the preferred theme for its type
  ///              (light or dark). This is used when following system theme.
  ///
  /// Note: This will automatically disable system theme following.
  /// To re-enable, call [NyTheme.setFollowSystem(true)].
  static Future<void> set(BuildContext context,
      {required String id, bool remember = false}) async {
    await NyThemeManager.instance.setTheme(id, remember: remember);
  }

  /// Get the current theme ID.
  static String currentId() {
    return NyThemeManager.instance.currentThemeId;
  }

  /// Get the current [BaseThemeConfig].
  static BaseThemeConfig? current() {
    return NyThemeManager.instance.currentTheme;
  }

  /// Get the current [ThemeData].
  static ThemeData? themeData() {
    return NyThemeManager.instance.themeData;
  }

  /// Check if the current theme is dark.
  static bool isDark() {
    return NyThemeManager.instance.isDark;
  }

  /// Get typed color styles from the current theme.
  ///
  /// Example:
  /// ```dart
  /// final colors = NyTheme.colors<MyColorStyles>();
  /// print(colors.primaryAccent);
  /// ```
  static T colors<T>() {
    return NyThemeManager.instance.colorStyles<T>();
  }

  /// Enable or disable system theme following.
  ///
  /// When enabled, the app will automatically switch between light and dark
  /// themes based on the device's brightness setting.
  static Future<void> setFollowSystem(bool follow) async {
    await NyThemeManager.instance.setFollowSystemTheme(follow);
  }

  /// Check if the app is following system theme.
  static bool isFollowingSystem() {
    return NyThemeManager.instance.followSystemTheme;
  }

  /// Get a theme by its ID.
  ///
  /// Returns null if no theme with the given ID is found.
  static BaseThemeConfig? getById(String id) {
    return NyThemeManager.instance.getThemeById(id);
  }

  /// Get all registered themes.
  static List<BaseThemeConfig> all() {
    return NyThemeManager.instance.themes;
  }

  /// Get all light themes.
  static List<BaseThemeConfig> lightThemes() {
    return NyThemeManager.instance.lightThemes;
  }

  /// Get all dark themes.
  static List<BaseThemeConfig> darkThemes() {
    return NyThemeManager.instance.darkThemes;
  }

  /// Get themes by type.
  static List<BaseThemeConfig> getByType(NyThemeType type) {
    return NyThemeManager.instance.getThemesByType(type);
  }

  /// Set the preferred dark theme for system theme following.
  ///
  /// This theme will be used when the system is in dark mode and
  /// [isFollowingSystem] is true.
  ///
  /// Useful when you have multiple dark themes (e.g., dark, dark_amoled, dark_blue)
  /// and want the user to choose which one to use for dark mode.
  static Future<void> setPreferredDark(String themeId) async {
    await NyThemeManager.instance.setPreferredDarkTheme(themeId);
  }

  /// Set the preferred light theme for system theme following.
  ///
  /// This theme will be used when the system is in light mode and
  /// [isFollowingSystem] is true.
  static Future<void> setPreferredLight(String themeId) async {
    await NyThemeManager.instance.setPreferredLightTheme(themeId);
  }

  /// Get the preferred dark theme ID.
  static String? preferredDarkId() {
    return NyThemeManager.instance.preferredDarkThemeId;
  }

  /// Get the preferred light theme ID.
  static String? preferredLightId() {
    return NyThemeManager.instance.preferredLightThemeId;
  }

  /// Clear all saved theme preferences.
  ///
  /// Useful for testing and development to reset theme preferences.
  static Future<void> clearSavedTheme() async {
    await NyThemeManager.instance.clearSavedTheme();
  }
}
