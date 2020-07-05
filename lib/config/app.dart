import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class ConfigApp {
/*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/

  var name = "Flurlo";

/*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/
  var env = "development";

/*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/
  var debug = true;

/*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/
  var url = "https://localhost:8080";

/*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/
  var assetPath = "public/assets/";

/*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/
  var timezone = "UTC";

/*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/
  var defaultLocale = "en";

  /*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/
  var supportedLocales = [
    Locale('en'),
  ];

/*
|--------------------------------------------------------------------------
| App Name
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/
  ValueNotifier<Locale> locale = new ValueNotifier(Locale('en', ''));

/*
|--------------------------------------------------------------------------
| DEVICE ORIENTATIONS
|--------------------------------------------------------------------------
|
| This array of class aliases will be registered when this application
| is started. However, feel free to register as many as you wish as
| the aliases are "lazy" loaded so they don't hinder performance.
|
*/

  List<DeviceOrientation> deviceOrientations = [
    DeviceOrientation.portraitUp,
  ];
}