import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nylo_framework/config/config.dart';
import 'package:nylo_framework/theme/helper/theme_helper.dart';

class NyConfigManager {
  NyConfigManager._privateConstructor();

  static final NyConfigManager instance = NyConfigManager._privateConstructor();

  NyConfig nyConfig;

  init({NyConfig nyConfig}) {
    this.nyConfig = nyConfig;
  }
}