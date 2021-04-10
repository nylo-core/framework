import 'package:nylo_framework/router/models/base_arguments.dart';
import 'package:page_transition/page_transition.dart';

class RouteArgsPair {
  final String name;
  final BaseArguments? args;
  final PageTransitionType? pageTransition;
  final Duration? transitionDuration;

  RouteArgsPair(this.name,
      {this.args, this.pageTransition, this.transitionDuration});
}
