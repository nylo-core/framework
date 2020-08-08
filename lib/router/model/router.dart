import 'package:flutter/cupertino.dart';
import 'package:nylo_framework/router/router.dart';

class AppRoute {
  String path = "";
  String controller = "";
  Function action;
  String name = "";
  List<String> middleware = [];
  bool isInitialRoute = false;

  AppRoute(
      {this.path,
        this.controller,
        this.action,
        this.name,
        this.middleware,
        this.isInitialRoute});

  AppRoute.prefix(prefix, Router router, {List<AppRoute> routes}) {
    router.addRoutes(routes: routes);
  }

  AppRoute setPath(String path) {
    this.path = "";
    return this;
  }

  AppRoute setController({@required String controller}) {
    this.controller = "";
    return this;
  }

  AppRoute setAsInitial() {
    this.isInitialRoute = true;
    return this;
  }

  AppRoute setAction({@required Function action}) {
    this.action = action;
    return this;
  }

  AppRoute setName(String name) {
    this.name = name;
    return this;
  }

  AppRoute setMiddleware(List<String> middleware) {
    this.middleware = middleware;
    return this;
  }

  dynamic doAction({RouteSettings settings}) {
    return this.action();
  }
}