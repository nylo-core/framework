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

class NyNavigator {
  NyRouter router = NyRouter();

  NyNavigator._privateConstructor();
  static final NyNavigator instance = NyNavigator._privateConstructor();
}


class NyNav {
  String routeName;
  Map<String, String> params;

  NyNav.to({@required String routeName, Map<String, String> params}) {
    this.routeName = routeName;
    this.params = params;
    NyNavigator.instance.router.navigate(this.routeName);
  }

  call() {
    NyNavigator.instance.router.navigate(this.routeName);
  }
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

class NyParam<T> extends SailorParam {
  NyParam({
    name,
    defaultValue,
    isRequired = false,
}) : super(name: name,
      defaultValue: defaultValue,
      isRequired: isRequired);
}

NyRouter nyCreateRoutes(Function(NyRouter router) build) {
  NyRouter nyRouter = NyRouter();
  build(nyRouter);

  NyNavigator.instance.router = nyRouter;

  return nyRouter;
}
