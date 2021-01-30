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

  route(String name,
      NyRouteView view,
  {List<RouteTransition> defaultTransitions,
      defaultTransitionDuration,
      defaultTransitionCurve,
      CustomRouteTransition customTransition}) {
    this.addRoute(NyRoute(name: name, view: view, defaultTransitions: defaultTransitions, defaultTransitionCurve: defaultTransitionCurve, defaultTransitionDuration: defaultTransitionDuration, customTransition:customTransition));
  }
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
    List<RouteTransition> defaultTransitions,
    defaultTransitionDuration,
    defaultTransitionCurve,
    CustomRouteTransition customTransition,
  }) : super(
          name: name,
          builder: (context, arg, paramMap) {
            Widget widget = view(context);
            if (widget is StatefulPageWidget) {
              if (widget.controller != null) {
                widget.controller.request =
                    NyRequest(currentRoute: name, args: arg, params: paramMap);
                widget.controller.context = context;
              }
            }
            return widget;
          },
          defaultArgs: null,
          defaultTransitions: [],
          defaultTransitionDuration: defaultTransitionDuration,
          defaultTransitionCurve: defaultTransitionCurve,
          params: [],
          customTransition: customTransition,
          routeGuards: [],
        );
}

/// Builds the routes in the router.dart file
NyRouter nyCreateRoutes(Function(NyRouter router) build) {
  NyRouter nyRouter = NyRouter();
  build(nyRouter);

  NyNavigator.instance.router = nyRouter;
  return nyRouter;
}

/// Custom route transition
abstract class CustomRouteTransition extends CustomSailorTransition {
  Widget buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  );
}

enum RouteTransition {
  /// Slide in the new page from right
  slide_from_right,

  /// Slide in the new page from left
  slide_from_left,

  /// Slide in the new page from top
  slide_from_top,

  /// Slide in the new page from bottom
  slide_from_bottom,

  /// Zoom in the page
  zoom_in,

  /// Fade in the page
  fade_in
}
