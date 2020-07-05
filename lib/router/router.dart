import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nylo_framework/middleware/register.dart';
import 'package:nylo_framework/router/model/router.dart';

class Router {
  List<AppRoute> routes = [];

  Router();

  Router addRoute(AppRoute route) {
    this.routes.add(route);
    return this;
  }

  Router addRoutes({@required List<AppRoute> routes}) {
    this.routes.addAll(routes);
    return this;
  }

  Map<String, WidgetBuilder> buildRoutes(BuildContext context) {
    Map<String, WidgetBuilder> map = {};
    this.routes.forEach((r) {
      map.addAll({r.path: (context) => r.doAction()});
    });
    return map;
  }

  Route<dynamic> buildAppRoutes(RouteSettings settings) {
    AppRoute appRoute = this.routes.firstWhere((r) => r.path == settings.name);

    return MaterialPageRoute(
      settings: settings,
      builder: (context) {
        if (appRoute.middleware != null) {
          for (final el in appRoute.middleware
              .where((element) => element != null)
              .toList()) {
            AppRoute routeMiddle =
            register()[el].handle(context, settings.arguments);
            if (routeMiddle != null) {
              return routeMiddle.doAction(settings: settings);
            }
          }
        }
        if (settings.arguments != null) {
          return appRoute.doAction(settings: settings);
        } else {
          return appRoute.doAction();
        }
      },
    );
  }

  String getInitialRoute() {
    if (this
        .routes
        .firstWhere((e) => e.isInitialRoute == true, orElse: () => null) !=
        null) {
      return this
          .routes
          .firstWhere((e) => e.isInitialRoute == true, orElse: () => null)
          .path;
    }
    return "/";
  }

  getRouteNamed(String routeName) {
    return this.routes.firstWhere((e) => e.name == routeName);
  }

  pushTo(BuildContext context,
      {@required String routeName,
        Object arguments,
        bool forgetAll = false,
        int forgetLast}) {
    AppRoute route = this
        .routes
        .firstWhere((element) => element.name == routeName, orElse: () => null);

    if (forgetAll) {
      Navigator.of(context).pushNamedAndRemoveUntil(
          routeName, (Route<dynamic> route) => false,
          arguments: arguments ?? null);
    }
    if (forgetLast != null) {
      int count = 0;
      Navigator.of(context).popUntil((route) {
        return count++ == forgetLast;
      });
    }
    Navigator.of(context).pushNamed(route.path, arguments: arguments ?? null);
  }
}

Router buildRoutes(Function(Router) router) {
  Router initRouter = Router();
  return router(initRouter);
}

Router routes(RouteCallback router) {
  Router routers = new Router();
  List<AppRoute> routes = router(routers);
  return routers.addRoutes(routes: routes);
}

typedef RouteCallback = List<AppRoute> Function(Router router);
