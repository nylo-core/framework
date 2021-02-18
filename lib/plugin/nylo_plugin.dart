import 'package:nylo_framework/nylo.dart';

class NyPlugin {
  Nylo nyloApp;
  initPackage(Nylo nylo) {
    nyloApp = nylo;
    this.construct();
  }

  construct() {}
}
