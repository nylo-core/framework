import 'package:flutter/material.dart';
import 'package:nylo_framework/plugin/nylo_plugin.dart';
import 'package:nylo_framework/router/router.dart';

class Nylo {
  NyRouter router;
  ThemeData themeData;
  Nylo({this.router, this.themeData});

  use(NyPlugin plugin) {
    plugin.initPackage(this);
  }
}
