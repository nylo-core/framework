import 'package:flutter/widgets.dart';
import 'package:nylo_framework/controllers/controller.dart';
import 'package:nylo_framework/widgets/stateful_page_widget.dart';
import 'package:sailor/sailor.dart';

class NyRouter extends Sailor {
  SailorRouteBuilder builder;

  NyRouter({
    options = const SailorOptions(isLoggingEnabled: false),
  }) : super(
          options: options,
        );
}

class NyNavigator {
  NyRouter router = NyRouter();

  NyNavigator._privateConstructor();
  static final NyNavigator instance = NyNavigator._privateConstructor();
}

typedef NyRouteView = Widget Function(
  BuildContext context,
);

/// Base class for a Route
class NyRoute extends SailorRoute {
  NyRoute({
    @required name,
    @required NyRouteView view,
    defaultArgs,
    defaultTransitions,
    defaultTransitionDuration,
    defaultTransitionCurve,
    params,
    customTransition,
    routeGuards,
  }) : super(
          name: name,
          builder: (context, arg, paramMap) {
            Widget widget = view(context);
            if (widget is StatefulPageWidget) {
              if (widget.controller != null) {
                widget.controller.request =
                    NyRequest(currentRoute: name, args: arg, params: paramMap);
              }
            }
            return widget;
          },
          defaultArgs: defaultArgs,
          defaultTransitions: defaultTransitions,
          defaultTransitionDuration: defaultTransitionDuration,
          defaultTransitionCurve: defaultTransitionCurve,
          params: params,
          customTransition: customTransition,
          routeGuards: routeGuards,
        );
}

/// Parameters to pass into the route
class NyParam<T> extends SailorParam {
  NyParam({
    name,
    defaultValue,
    isRequired = false,
  }) : super(name: name, defaultValue: defaultValue, isRequired: isRequired);
}

/// Builds the routes in the router.dart file
NyRouter nyCreateRoutes(Function(NyRouter router) build) {
  NyRouter nyRouter = NyRouter();
  build(nyRouter);

  NyNavigator.instance.router = nyRouter;
  return nyRouter;
}
