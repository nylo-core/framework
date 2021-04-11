import 'package:flutter/material.dart';
import 'package:nylo_framework/router/models/base_arguments.dart';

typedef TypeNyGuard = Future<bool> Function(
  BuildContext? context,
  BaseArguments? args,
);

abstract class RouteGuard {
  RouteGuard();

  Future<bool> canOpen(
    BuildContext? context,
    BaseArguments? args,
  );

  factory RouteGuard.simple(TypeNyGuard canOpen) {
    return _RouteGuard(canOpen);
  }
}

class _RouteGuard extends RouteGuard {
  final TypeNyGuard routeGuard;

  _RouteGuard(this.routeGuard) : super();

  @override
  Future<bool> canOpen(
    BuildContext? context,
    BaseArguments? args,
  ) {
    return this.routeGuard(context, args);
  }
}
