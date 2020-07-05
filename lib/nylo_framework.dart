library nylo_framework;

import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nylo_framework/config/helper/config_helper.dart';
import 'package:nylo_framework/theme/helper/theme_helper.dart';

class AppBuild extends StatelessWidget {
  final String initialRoute;
  final Route<dynamic> Function(RouteSettings settings) onGenerateRoute;
  Brightness defaultBrightness;

  AppBuild({Key key, this.initialRoute, this.defaultBrightness, this.onGenerateRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DynamicTheme(
      defaultBrightness: CurrentTheme.instance.theme.brightness,
      data: (brightness) => CurrentTheme.instance.theme,
      themedWidgetBuilder: (context, theme) {
        return ValueListenableBuilder(
          valueListenable: ConfigHelper.app().locale,
          builder: (context, Locale value, _) => MaterialApp(
            title: ConfigHelper.app().name,
            debugShowCheckedModeBanner: false,
            initialRoute: initialRoute,
            onGenerateRoute: this.onGenerateRoute,
            theme: theme,
            supportedLocales: ConfigHelper.app().supportedLocales,
//            localizationsDelegates: [
//              AppLocalizations.delegate,
//              GlobalWidgetsLocalizations.delegate,
//              GlobalMaterialLocalizations.delegate
//            ],
            localeResolutionCallback:
                (Locale locale, Iterable<Locale> supportedLocales) {
              return locale;
            },
          ),
        );
      },
    );
  }
}

//class AppBuild extends StatelessWidget {
//  final String initialRoute;
//  AppBuild({Key key, this.initialRoute}) : super(key: key);
//
//  @override
//  Widget build(BuildContext context) {
//    return MaterialApp(
//      home: Scaffold(
//        body: SafeArea(
//          child: Text("Hello Nylo"),
//        ),
//      ),
//    );
//  }
//}

