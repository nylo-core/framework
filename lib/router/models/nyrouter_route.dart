import 'package:nylo_framework/controllers/controller.dart';
import 'package:nylo_framework/router/models/base_arguments.dart';
import 'package:nylo_framework/router/models/nyrouter_route_guard.dart';
import 'package:nylo_framework/router/router.dart';
import 'package:nylo_framework/widgets/ny_stateful_widget.dart';
import 'package:flutter/widgets.dart';
import 'package:page_transition/page_transition.dart';

import 'ny_argument.dart';

typedef NyRouterRouteBuilder = Widget Function(
  BuildContext context,
  BaseArguments? args,
);

class NyRouterRoute {
  final String name;
  late NyRouterRouteBuilder builder;
  final BaseArguments? defaultArgs;
  final NyRouteView view;
  PageTransitionType pageTransitionType;

  /// Ran before opening the route itself.
  /// If every route guard returns [true], the route is approved and opened.
  /// Anything else will result in the route being rejected and not open.
  final List<RouteGuard>? routeGuards;

  NyRouterRoute(
      {required this.name,
      required this.view,
      this.defaultArgs,
      this.routeGuards,
      this.pageTransitionType = PageTransitionType.rightToLeft}) {
    this.builder = (context, arg) {
      Widget widget = view(context);
      if (widget is NyStatefulWidget) {
        if (widget.controller != null) {
          widget.controller!.request =
              NyRequest(currentRoute: name, args: arg as NyArgument?);
          widget.controller!.construct(context);
        }
      }
      return widget;
    };
  }
}
