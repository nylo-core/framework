library nylo_framework;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nylo_support/nylo.dart';
import 'package:nylo_framework/theme/helper/theme_helper.dart';
import 'package:nylo_support/router/router.dart';

/// Run to init classes used in Nylo
Future initNylo({required ThemeData theme, required NyRouter router}) async {
  await dotenv.load(fileName: ".env");

  CurrentTheme.instance.theme = theme;

  return Nylo(router: router, themeData: theme);
}
