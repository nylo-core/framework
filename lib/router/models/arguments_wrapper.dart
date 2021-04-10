import 'package:nylo_framework/router/models/base_arguments.dart';
import 'package:page_transition/page_transition.dart';

class ArgumentsWrapper {
  BaseArguments? baseArguments;
  PageTransitionType? pageTransitionType;
  Duration? transitionDuration;

  ArgumentsWrapper(
      {this.baseArguments, this.transitionDuration, this.pageTransitionType});

  ArgumentsWrapper copyWith(
      {BaseArguments? baseArguments, PageTransitionType? pageTransitionType}) {
    return ArgumentsWrapper(
        baseArguments: baseArguments ?? this.baseArguments,
        transitionDuration: transitionDuration ?? this.transitionDuration,
        pageTransitionType: pageTransitionType ?? this.pageTransitionType);
  }

  @override
  String toString() {
    return 'ArgumentsWrapper{baseArguments: $baseArguments, '
        'transitionDuration: $transitionDuration, ';
  }
}
