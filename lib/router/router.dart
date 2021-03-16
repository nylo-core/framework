import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nylo_framework/helpers/helper.dart';
import 'package:nylo_framework/router/errors/route_not_found.dart';
import 'package:nylo_framework/router/models/arguments_wrapper.dart';
import 'package:nylo_framework/router/models/base_arguments.dart';
import 'package:nylo_framework/router/models/nyrouter_route_guard.dart';
import 'package:nylo_framework/router/models/route_args_pair.dart';
import 'package:nylo_framework/router/models/nyrouter_options.dart';
import 'package:nylo_framework/router/models/nyrouter_route.dart';
import 'package:nylo_framework/router/ui/page_not_found.dart';
import 'package:nylo_framework/widgets/stateful_page_widget.dart';
import 'package:page_transition/page_transition.dart';

class NyNavigator {
  NyRouter router = NyRouter();

  NyNavigator._privateConstructor();
  static final NyNavigator instance = NyNavigator._privateConstructor();
}

typedef NyRouteView = Widget Function(
  BuildContext context,
);

/// Builds the routes in the router.dart file
NyRouter nyCreateRoutes(Function(NyRouter router) build) {
  NyRouter nyRouter = NyRouter();
  build(nyRouter);

  NyNavigator.instance.router = nyRouter;
  return nyRouter;
}

enum NavigationType { push, pushReplace, pushAndRemoveUntil, popAndPushNamed }

/// NyRouterRoute manages routing, registering routes with transitions, navigating to
/// routes, closing routes. It is a thin layer on top of [Navigator] to help
/// you encapsulate and manage routing at one place.
class NyRouter {
  NyRouter({
    this.options = const NyRouterOptions(),
  }) : assert(options != null) {
    if (options != null && options.navigatorKey != null) {
      this._navigatorKey = options.navigatorKey;
    } else {
      this._navigatorKey = GlobalKey<NavigatorState>();
    }
  }

  /// Configuration options for [NyRouterRoute].
  ///
  /// Check out [NyRouterRouteOptions] for available options.
  final NyRouterOptions options;

  /// Store all the mappings of route names and corresponding [NyRouterRouteRoute]
  /// Used to generate routes
  Map<String, NyRouterRoute> _routeNameMappings = {};

  /// A navigator key lets NyRouterRoute grab the [NavigatorState] from a [MaterialApp]
  /// or a [CupertinoApp]. All navigation operations (push, pop, etc) are carried
  /// out using this [NavigatorState].
  ///
  /// This is the same [NavigatorState] that is returned by [Navigator.of(context)]
  /// (when there is only a single [Navigator] in Widget tree, i.e. from [MaterialApp]
  /// or [CupertinoApp]).
  GlobalKey<NavigatorState> _navigatorKey;

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// Get the registered routes names as a list.
  List<String> getRegisteredRouteNames() {
    return _routeNameMappings.keys.toList();
  }

  /// Retrieves the arguments passed in when calling the [navigate] function.
  ///
  /// Returned arguments are casted with the type provided, the type will always
  /// be a subtype of [BaseArguments].
  ///
  /// Make sure to provide the appropriate type, that is, provide the same type
  /// as the one passed while calling [navigate], else a cast error will be
  /// thrown.
  static T args<T extends BaseArguments>(BuildContext context) {
    return (ModalRoute.of(context).settings.arguments as ArgumentsWrapper)
        .baseArguments as T;
  }

  route(String name, NyRouteView view,
      {PageTransitionType transition, List<RouteGuard> routeGuards}) {
    this._addRoute(NyRouterRoute(
        name: name,
        view: view,
        pageTransitionType: transition ?? PageTransitionType.rightToLeft,
        routeGuards: routeGuards));
  }

  /// Add a new route to [NyRouterRoute].
  ///
  /// Route is stored in [_routeNameMappings].
  ///
  /// If a route is provided with a name that was previously added, it will
  /// override the old one.
  void _addRoute(NyRouterRoute route) {
    assert(route != null, "'route' argument cannot be null.");

    if (_routeNameMappings.containsKey(route.name)) {
      NyLogger.info(
          "'${route.name}' has already been registered before. Overriding it!");
    }

    _routeNameMappings[route.name] = route;
  }

  /// Add a list of routes at once.
  void addRoutes(List<NyRouterRoute> routes) {
    if (routes != null && routes.isNotEmpty) {
      routes.forEach((route) => this._addRoute(route));
    }
  }

  /// Makes this a callable class. Delegates to [navigate].
  Future<T> call<T>(String name,
      {BaseArguments args,
      NavigationType navigationType = NavigationType.push,
      dynamic result,
      bool Function(Route<dynamic> route) removeUntilPredicate,
      Map<String, dynamic> params,
      PageTransitionType pageTransitionType}) {
    assert(name != null);
    assert(navigationType != null);
    assert(navigationType != NavigationType.pushAndRemoveUntil ||
        removeUntilPredicate != null);

    _checkAndThrowRouteNotFound(name, args, navigationType);

    return navigate<T>(name,
        navigationType: navigationType,
        result: result,
        removeUntilPredicate: removeUntilPredicate,
        args: args,
        pageTransitionType: pageTransitionType);
  }

  /// Function used to navigate pages.
  ///
  /// [name] is the route name that was registered using [addRoute].
  ///
  /// [args] are optional arguments that can be passed to the next page.
  /// To retrieve these arguments use [args] method on [NyRouterRoute].
  ///
  /// [navigationType] can be specified to choose from various navigation
  /// strategies such as [NavigationType.push], [NavigationType.pushReplace],
  /// [NavigationType.pushAndRemoveUntil].
  ///
  /// [removeUntilPredicate] should be provided if using
  /// [NavigationType.pushAndRemoveUntil] strategy.
  Future<T> navigate<T>(String name,
      {BaseArguments args,
      NavigationType navigationType = NavigationType.push,
      dynamic result,
      bool Function(Route<dynamic> route) removeUntilPredicate,
      PageTransitionType pageTransitionType,
      Duration transitionDuration = const Duration(milliseconds: 300)}) {
    assert(name != null);
    assert(navigationType != null);
    assert(navigationType != NavigationType.pushAndRemoveUntil ||
        removeUntilPredicate != null);

    _checkAndThrowRouteNotFound(name, args, navigationType);

    return _navigate(name, args, navigationType, result, removeUntilPredicate,
            pageTransitionType, transitionDuration)
        .then((value) => value as T);
  }

  /// Push multiple routes at the same time.
  ///
  /// [routeArgsPairs] is a list of [RouteArgsPair]. Each [RouteArgsPair]
  /// contains the name of a route and its corresponding argument (if any).
  Future<List> navigateMultiple(
    List<RouteArgsPair> routeArgsPairs,
  ) {
    assert(routeArgsPairs != null);
    assert(routeArgsPairs.isNotEmpty);

    final pageResponses = <Future>[];

    // For each route check if it exists.
    // Push the route.
    routeArgsPairs.forEach((routeArgs) {
      _checkAndThrowRouteNotFound(
        routeArgs.name,
        routeArgs.args,
        NavigationType.push,
      );

      final response = _navigate(
          routeArgs.name,
          routeArgs.args,
          NavigationType.push,
          null,
          null,
          routeArgs.pageTransition,
          routeArgs.transitionDuration);

      pageResponses.add(response);
    });

    return Future.wait(pageResponses);
  }

  /// Actual navigation is delegated by [navigate] method to this method.
  ///
  /// [name] is the route name that was registered using [addRoute].
  ///
  /// [args] are optional arguments that can be passed to the next page.
  /// To retrieve these arguments use [arguments] method on [NyRouterRoute].
  ///
  /// [navigationType] can be specified to choose from various navigation
  /// strategies such as [NavigationType.push], [NavigationType.pushReplace],
  /// [NavigationType.pushAndRemoveUntil].
  ///
  /// [removeUntilPredicate] should be provided is using
  /// [NavigationType.pushAndRemoveUntil] strategy.
  Future<dynamic> _navigate(
      String name,
      BaseArguments args,
      NavigationType navigationType,
      dynamic result,
      bool Function(Route<dynamic> route) removeUntilPredicate,
      PageTransitionType pageTransitionType,
      Duration transitionDuration) async {
    final argsWrapper = ArgumentsWrapper(
      baseArguments: args,
      pageTransitionType: pageTransitionType,
      transitionDuration: transitionDuration,
    );

    // Evaluate if the route can be opened using route guard.
    final route = _routeNameMappings[name];

    if (route != null &&
        route.routeGuards != null &&
        route.routeGuards.isNotEmpty) {
      bool canOpen = true;
      for (RouteGuard routeGuard in route.routeGuards) {
        final result = await routeGuard.canOpen(
          navigatorKey.currentContext,
          argsWrapper.baseArguments,
        );
        if (result != true) {
          canOpen = false;
          break;
        }
      }
      if (canOpen != true) {
        NyLogger.info("'$name' route rejected by route guard!");
        return null;
      }
    }

    switch (navigationType) {
      case NavigationType.push:
        return this
            .navigatorKey
            .currentState
            .pushNamed(name, arguments: argsWrapper);
      case NavigationType.pushReplace:
        return this
            .navigatorKey
            .currentState
            .pushReplacementNamed(name, result: result, arguments: argsWrapper);
      case NavigationType.pushAndRemoveUntil:
        return this.navigatorKey.currentState.pushNamedAndRemoveUntil(
            name, removeUntilPredicate,
            arguments: argsWrapper);
      case NavigationType.popAndPushNamed:
        return this
            .navigatorKey
            .currentState
            .popAndPushNamed(name, result: result, arguments: argsWrapper);
    }

    return null;
  }

  /// If the route is not registered throw an error
  /// Make sure to use the correct name while calling navigate.
  void _checkAndThrowRouteNotFound(
    String name,
    BaseArguments args,
    NavigationType navigationType,
  ) {
    assert(name != null);

    if (!_routeNameMappings.containsKey(name)) {
      if (this.options.handleNameNotFoundUI) {
        NyLogger.error("Page not found\n"
            "[Route Name] $name\n"
            "[ARGS] ${args.toString()}");
        this.navigatorKey.currentState.push(
          MaterialPageRoute(builder: (BuildContext context) {
            return PageNotFound();
          }),
        );
      }
      throw RouteNotFoundError(name: name);
    }
  }

  /// Delegation for [Navigator.pop].
  void pop([dynamic result]) {
    this.navigatorKey.currentState.pop(result);
  }

  /// Delegation for [Navigator.popUntil].
  void popUntil(void Function(Route<dynamic>) predicate) {
    this.navigatorKey.currentState.popUntil(predicate);
  }

  /// Generates the [RouteFactory] which builds a [Route] on request.
  ///
  /// These routes are built using the [NyRouterRoute]s [addRoute] method.
  RouteFactory generator() {
    return (settings) {
      final NyRouterRoute route = _routeNameMappings[settings.name];

      if (route == null) return null;

      ArgumentsWrapper argsWrapper;
      if (settings.arguments is ArgumentsWrapper) {
        argsWrapper = settings.arguments as ArgumentsWrapper;
      } else {
        argsWrapper = ArgumentsWrapper();
        argsWrapper.baseArguments = NyArgument(settings.arguments);
      }

      if (argsWrapper == null) {
        argsWrapper = ArgumentsWrapper();
      }

      final BaseArguments baseArgs = argsWrapper.baseArguments;

      return PageTransition(
        child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          Widget widget = route.builder(context, baseArgs ?? route.defaultArgs);
          if (widget is StatefulPageWidget && widget.controller != null) {
            widget.controller.context = context;
            widget.controller.construct(context);
          }
          return widget;
        }),
        type: argsWrapper.pageTransitionType ?? route.pageTransitionType,
        settings: settings,
        duration:
            argsWrapper.transitionDuration ?? this.options.transitionDuration,
      );
    };
  }

  static RouteFactory unknownRouteGenerator() {
    return (settings) {
      return MaterialPageRoute(
        settings: settings,
        builder: (BuildContext context) {
          return PageNotFound();
        },
      );
    };
  }
}
