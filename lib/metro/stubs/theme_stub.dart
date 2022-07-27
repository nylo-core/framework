import 'package:recase/recase.dart';

String themeStub(ReCase rc, {bool isDark = false}) => '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/font.dart';
import '../../resources/themes/styles/base_styles.dart';
import '../../resources/themes/text_theme/default_text_theme.dart';
import 'package:nylo_framework/nylo_framework.dart';

/*
|--------------------------------------------------------------------------
| ${rc.titleCase} Theme
|
| Theme Config - config/app_theme.dart
|--------------------------------------------------------------------------
*/

ThemeData ${rc.camelCase}Theme(BaseColorStyles ${rc.camelCase}Colors) {
  TextTheme ${rc.camelCase}TextTheme =
  getAppTextTheme(appFont, defaultTextTheme.merge(_${rc.camelCase}TextTheme(${rc.camelCase}Colors)));

  return ThemeData(
    primaryColor: ${rc.camelCase}Colors.primaryContent,
    backgroundColor: ${rc.camelCase}Colors.background,
    colorScheme: ColorScheme.${isDark == true ? 'dark' : 'light'}(),
    primaryColorLight: ${rc.camelCase}Colors.primaryAccent,
    focusColor: ${rc.camelCase}Colors.primaryContent,
    scaffoldBackgroundColor: ${rc.camelCase}Colors.background,
    hintColor: ${rc.camelCase}Colors.primaryAccent,
    appBarTheme: AppBarTheme(
      backgroundColor: ${rc.camelCase}Colors.appBarBackground,
      titleTextStyle: ${rc.camelCase}TextTheme.headline6!
          .copyWith(color: ${rc.camelCase}Colors.appBarPrimaryContent),
      iconTheme: IconThemeData(color: ${rc.camelCase}Colors.appBarPrimaryContent),
      elevation: 1.0,
      systemOverlayStyle: SystemUiOverlayStyle.${isDark == true ? 'dark' : 'light'},
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: ${rc.camelCase}Colors.buttonPrimaryContent,
      colorScheme: ColorScheme.light(primary: ${rc.camelCase}Colors.buttonBackground),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(primary: ${rc.camelCase}Colors.primaryContent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: TextButton.styleFrom(
          primary: ${rc.camelCase}Colors.buttonPrimaryContent,
          backgroundColor: ${rc.camelCase}Colors.buttonBackground),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: ${rc.camelCase}Colors.bottomTabBarBackground,
      unselectedIconTheme:
      IconThemeData(color: ${rc.camelCase}Colors.bottomTabBarIconUnselected),
      selectedIconTheme:
      IconThemeData(color: ${rc.camelCase}Colors.bottomTabBarIconSelected),
      unselectedLabelStyle:
      TextStyle(color: ${rc.camelCase}Colors.bottomTabBarLabelUnselected),
      selectedLabelStyle:
      TextStyle(color: ${rc.camelCase}Colors.bottomTabBarLabelSelected),
      selectedItemColor: ${rc.camelCase}Colors.bottomTabBarLabelSelected,
    ),
    textTheme: ${rc.camelCase}TextTheme,
  );
}

/*
|--------------------------------------------------------------------------
| ${rc.titleCase} Text Theme
|--------------------------------------------------------------------------
*/

TextTheme _${rc.camelCase}TextTheme(BaseColorStyles ${rc.camelCase}Colors) {
  return TextTheme(
    headline6: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    headline5: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    headline4: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    headline3: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    headline2: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    headline1: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    subtitle2: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    subtitle1: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    overline: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    button: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent.withOpacity(0.8),
    ),
    bodyText2: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent.withOpacity(0.8),
    ),
    bodyText1: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
    caption: TextStyle(
      color: ${rc.camelCase}Colors.primaryContent,
    ),
  );
}
''';
