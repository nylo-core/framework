import 'package:flutter/widgets.dart';
import 'package:sailor/sailor.dart';

class NyRouter extends Sailor {

  SailorRouteBuilder builder;

  NyRouter({
    options = const SailorOptions(isLoggingEnabled: false),
  })  : super(
    options:options,
  );
}

class NyRoute extends SailorRoute {
  NyRoute({
    @required name,
    @required builder,
    defaultArgs,
    defaultTransitions,
    defaultTransitionDuration,
    defaultTransitionCurve,
    params,
    customTransition,
    routeGuards,
}) : super(
  name: name,
  builder: builder,
  defaultArgs: defaultArgs,
  defaultTransitions: defaultTransitions,
  defaultTransitionDuration: defaultTransitionDuration,
  defaultTransitionCurve: defaultTransitionCurve,
  params: params,
  customTransition: customTransition,
  routeGuards:routeGuards,
);
}

NyRouter nyCreateRoutes(Function(NyRouter router) build) {
  NyRouter nyRouter = NyRouter();
  build(nyRouter);
  return nyRouter;
}

