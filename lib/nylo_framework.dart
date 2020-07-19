library nylo_framework;

import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppBuildSettings<T> {
  Locale locale;
  String title;
  Iterable<Locale> supportedLocales;
  Brightness defaultBrightness;
  ThemeData themeData;
  bool debugMode;

  AppBuildSettings({this.defaultBrightness, this.debugMode = false, this.themeData, this.locale, this.title = "", this.supportedLocales});
}

Future<void> initMain({List<DeviceOrientation> preferredOrientations, Future<void> didFinishInit}) async {
await SystemChrome.setPreferredOrientations(preferredOrientations);

return await didFinishInit;
}

// ignore: must_be_immutable
class AppBuild extends StatelessWidget {
  final String initialRoute;
   AppBuildSettings appBuildSettings;

  final Route<dynamic> Function(RouteSettings settings) onGenerateRoute;
  Brightness defaultBrightness;

  AppBuild({Key key, this.initialRoute, this.appBuildSettings, this.defaultBrightness, this.onGenerateRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DynamicTheme(
      defaultBrightness: appBuildSettings.defaultBrightness,
      data: (brightness) => appBuildSettings.themeData,
      themedWidgetBuilder: (context, theme) {
        return ValueListenableBuilder(
          valueListenable: ValueNotifier(appBuildSettings.locale),
          builder: (context, Locale value, _) => MaterialApp(
            title: appBuildSettings.title,
            debugShowCheckedModeBanner: false,
            initialRoute: initialRoute,
            onGenerateRoute: this.onGenerateRoute,
            theme: theme,
            supportedLocales: appBuildSettings.supportedLocales ?? [],
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
