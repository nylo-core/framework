import 'package:recase/recase.dart';

/// This stub is used to create ColorStyles in the /resources/themes/styles/ directory.
String themeColorsStub(ReCase rc) => '''
import 'package:flutter/material.dart';
import '/resources/themes/styles/color_styles.dart';

/* ${rc.titleCase} Theme Colors
|-------------------------------------------------------------------------- */

class ${rc.pascalCase}ThemeColors implements ColorStyles {
  // general
  @override
  Color get background => const Color(0xFFFFFFFF);

  @override
  Color get primaryContent => const Color(0xFF000000);
  @override
  Color get primaryAccent => const Color(0xFF87c694);

  @override
  Color get surfaceBackground => Colors.white;
  @override
  Color get surfaceContent => Colors.black;

  // app bar
  @override
  Color get appBarBackground => Colors.blue;
  @override
  Color get appBarPrimaryContent => Colors.white;

  // buttons
  @override
  Color get buttonBackground => Colors.blueAccent;
  @override
  Color get buttonPrimaryContent => Colors.white;

  // bottom tab bar
  @override
  Color get bottomTabBarBackground => Colors.white;

  // bottom tab bar - icons
  @override
  Color get bottomTabBarIconSelected => Colors.blue;
  @override
  Color get bottomTabBarIconUnselected => Colors.black54;

  // bottom tab bar - label
  @override
  Color get bottomTabBarLabelUnselected => Colors.black45;
  @override
  Color get bottomTabBarLabelSelected => Colors.black;
}
''';
