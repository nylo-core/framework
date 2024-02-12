import 'package:recase/recase.dart';

/// This stub is used to create a new Theme in the /resources/themes/ directory.
String themeStub(ReCase rc, {bool isDark = false}) => '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/config/font.dart';
import '/resources/themes/styles/color_styles.dart';
import '/resources/themes/text_theme/default_text_theme.dart';
import 'package:nylo_framework/nylo_framework.dart';

/* ${rc.titleCase} Theme
|--------------------------------------------------------------------------
| Theme Config - config/app_theme.dart
|-------------------------------------------------------------------------- */

ThemeData ${rc.camelCase}Theme(ColorStyles color) {
  TextTheme ${rc.camelCase}Theme = getAppTextTheme(
      appFont, defaultTextTheme.merge(_textTheme(color)));

  return ThemeData(
    useMaterial3: true,
    primaryColor: color.primaryContent,
    primaryColorLight: color.primaryAccent,
    focusColor: color.primaryContent,
    scaffoldBackgroundColor: color.background,
    hintColor: color.primaryAccent,
    appBarTheme: AppBarTheme(
      backgroundColor: color.appBarBackground,
      titleTextStyle: ${rc.camelCase}Theme.titleLarge!
          .copyWith(color: color.appBarPrimaryContent),
      iconTheme: IconThemeData(color: color.appBarPrimaryContent),
      elevation: 1.0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: color.buttonPrimaryContent,
      colorScheme: ColorScheme.light(primary: color.buttonBackground),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: color.primaryContent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: color.buttonPrimaryContent,
          backgroundColor: color.buttonBackground),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: color.bottomTabBarBackground,
      unselectedIconTheme:
          IconThemeData(color: color.bottomTabBarIconUnselected),
      selectedIconTheme:
          IconThemeData(color: color.bottomTabBarIconSelected),
      unselectedLabelStyle:
          TextStyle(color: color.bottomTabBarLabelUnselected),
      selectedLabelStyle:
          TextStyle(color: color.bottomTabBarLabelSelected),
      selectedItemColor: color.bottomTabBarLabelSelected,
    ),
    textTheme: ${rc.camelCase}Theme,
    colorScheme: ColorScheme.light(
      background: color.background
    ),
  );
}

/*
|--------------------------------------------------------------------------
| ${rc.titleCase} Text Theme
|--------------------------------------------------------------------------
*/

TextTheme _textTheme(ColorStyles color) {
  Color primaryContent = color.primaryContent;
  TextTheme textTheme = TextTheme().apply(displayColor: primaryContent);
  return textTheme.copyWith(
      labelLarge: TextStyle(color: primaryContent.withOpacity(0.8))
  );
}
''';
